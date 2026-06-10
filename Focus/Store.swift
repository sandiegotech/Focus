import Foundation
import SwiftUI
import Observation
import UserNotifications

/// Single source of truth for the app: activities, logged sessions, the live timer,
/// derived stats, persistence, and the gentle reminder.
@MainActor
@Observable
final class Store {

    // MARK: Persisted state

    private(set) var activities: [Activity] = []
    private(set) var sessions: [FocusSession] = []

    /// The currently running session, if any. `activeStart` is the wall-clock start.
    private(set) var activeActivityID: UUID?
    private(set) var activeStart: Date?

    /// Which activity the Today/Progress screens are focused on.
    private(set) var selectedActivityID: UUID?

    /// Daily reminder settings.
    private(set) var reminderEnabled: Bool = false
    private(set) var reminderTime: Date = Store.defaultReminderTime

    // MARK: Derived

    var isRunning: Bool { activeStart != nil }

    var selectedActivity: Activity? {
        activities.first(where: { $0.id == selectedActivityID }) ?? activities.first
    }

    var selectedActivityColor: Color {
        Color(hex: selectedActivity?.colorHex ?? "234E70")
    }

    // MARK: Storage

    private let saveURL: URL
    private let cloudStore = NSUbiquitousKeyValueStore.default
    private var cloudObserver: NSObjectProtocol?
    private var lastModified: Date = .distantPast

    static let reminderID = "focus.dailyReminder"
    static let goalNotificationID = "focus.goalCompletion"
    static let cloudSnapshotKey = "focus.persisted.v1"

    static let defaultReminderTime: Date = {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    }()

    // MARK: Lifecycle

    init() {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ?? fm.temporaryDirectory
        let folder = base.appendingPathComponent("Focus", isDirectory: true)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        self.saveURL = folder.appendingPathComponent("data.json")

        load()
        migrateLegacyStarterActivityIfNeeded()

        // Drop a stale running session (e.g. app was killed and reopened much later)
        // so we never credit hours nobody actually worked. Short gaps resume normally.
        if let start = activeStart, Date().timeIntervalSince(start) >= 10 * 3600 {
            activeActivityID = nil
            activeStart = nil
        }

        if activities.isEmpty { seed() }
        if selectedActivityID == nil { selectedActivityID = activities.first?.id }
        startCloudSync()
        save()
    }

    // MARK: - Timer

    func start() {
        guard let id = selectedActivityID, !isRunning else { return }
        activeActivityID = id
        activeStart = Date()
        if reminderEnabled { scheduleGoalCompletionNotification() }
        save()
    }

    func stop() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Store.goalNotificationID])
        guard let start = activeStart, let id = activeActivityID else { return }
        let elapsed = Date().timeIntervalSince(start)
        if elapsed >= 1 { // ignore accidental taps under a second
            sessions.append(FocusSession(activityID: id, start: start, seconds: elapsed))
        }
        activeActivityID = nil
        activeStart = nil
        save()
    }

    func toggle() { isRunning ? stop() : start() }

    /// Live elapsed time of the running session as of `now`.
    func activeElapsed(asOf now: Date) -> TimeInterval {
        guard let start = activeStart else { return 0 }
        return max(0, now.timeIntervalSince(start))
    }

    // MARK: - Selection

    func select(_ id: UUID) {
        selectedActivityID = id
        save()
    }

    // MARK: - Stats

    func loggedSessions(for activityID: UUID) -> [FocusSession] {
        sessions.filter { $0.activityID == activityID }
    }

    /// Seconds logged today for an activity, including the live session if it's running.
    func secondsToday(for activityID: UUID, asOf now: Date = Date()) -> TimeInterval {
        let startOfDay = Calendar.current.startOfDay(for: now)
        var total = sessions
            .filter { $0.activityID == activityID && $0.start >= startOfDay }
            .reduce(0) { $0 + $1.seconds }
        if isRunning, activeActivityID == activityID, let start = activeStart {
            total += max(0, now.timeIntervalSince(max(start, startOfDay)))
        }
        return total
    }

    /// All-time seconds for an activity, including the live session.
    func totalSeconds(for activityID: UUID, asOf now: Date = Date()) -> TimeInterval {
        var total = loggedSessions(for: activityID).reduce(0) { $0 + $1.seconds }
        if isRunning, activeActivityID == activityID {
            total += activeElapsed(asOf: now)
        }
        return total
    }

    func remainingToday(for activity: Activity, asOf now: Date = Date()) -> TimeInterval {
        max(0, activity.dailyGoalSeconds - secondsToday(for: activity.id, asOf: now))
    }

    func goalReachedToday(for activity: Activity, asOf now: Date = Date()) -> Bool {
        secondsToday(for: activity.id, asOf: now) >= activity.dailyGoalSeconds
    }

    /// Seconds per calendar day for an activity (live session folded into today).
    private func secondsByDay(for activityID: UUID, asOf now: Date) -> [Date: TimeInterval] {
        var totals: [Date: TimeInterval] = [:]
        for session in loggedSessions(for: activityID) {
            totals[session.day, default: 0] += session.seconds
        }
        if isRunning, activeActivityID == activityID, let start = activeStart {
            let day = Calendar.current.startOfDay(for: start)
            totals[day, default: 0] += activeElapsed(asOf: now)
        }
        return totals
    }

    func daysPracticed(for activityID: UUID, asOf now: Date = Date()) -> Int {
        secondsByDay(for: activityID, asOf: now).values.filter { $0 > 0 }.count
    }

    /// Consecutive days meeting the goal, counting back from today. A not-yet-finished
    /// today doesn't break the streak — it just isn't counted until you meet the goal.
    func currentStreak(for activity: Activity, asOf now: Date = Date()) -> Int {
        let totals = secondsByDay(for: activity.id, asOf: now)
        let met = Set(totals.filter { $0.value >= activity.dailyGoalSeconds }.keys)
        let cal = Calendar.current

        var day = cal.startOfDay(for: now)
        if !met.contains(day) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }

        var streak = 0
        while met.contains(day) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    struct DayBar: Identifiable {
        var id: Date { day }
        let day: Date
        let seconds: TimeInterval
    }

    /// Seven bars ending today, oldest first — for the weekly chart.
    func last7Days(for activityID: UUID, asOf now: Date = Date()) -> [DayBar] {
        let cal = Calendar.current
        let totals = secondsByDay(for: activityID, asOf: now)
        let today = cal.startOfDay(for: now)
        return (0..<7).reversed().compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DayBar(day: day, seconds: totals[day] ?? 0)
        }
    }

    // MARK: - Activity CRUD

    func addActivity(_ activity: Activity) {
        activities.append(activity)
        if selectedActivityID == nil { selectedActivityID = activity.id }
        save()
    }

    func updateActivity(_ activity: Activity) {
        guard let index = activities.firstIndex(where: { $0.id == activity.id }) else { return }
        activities[index] = activity
        save()
    }

    func deleteActivity(_ activity: Activity) {
        activities.removeAll { $0.id == activity.id }
        sessions.removeAll { $0.activityID == activity.id }
        if activeActivityID == activity.id {
            activeActivityID = nil
            activeStart = nil
        }
        if selectedActivityID == activity.id {
            selectedActivityID = activities.first?.id
        }
        save()
    }

    // MARK: - Manual sessions

    /// Log time by hand (e.g. you forgot to start the timer). Anchored at noon on the chosen day.
    func addManualSession(activityID: UUID, date: Date, seconds: TimeInterval) {
        let cal = Calendar.current
        let day = cal.startOfDay(for: date)
        let start = cal.date(byAdding: .hour, value: 12, to: day) ?? date
        sessions.append(FocusSession(activityID: activityID, start: start, seconds: max(0, seconds)))
        save()
    }

    func deleteSession(_ session: FocusSession) {
        sessions.removeAll { $0.id == session.id }
        save()
    }

    // MARK: - Reminder

    func setReminder(enabled: Bool) {
        reminderEnabled = enabled
        save()
        if enabled {
            requestAuthorizationThenSchedule()
        } else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: [Store.reminderID, Store.goalNotificationID]
            )
        }
    }

    func setReminderTime(_ date: Date) {
        reminderTime = date
        save()
        if reminderEnabled { scheduleDailyReminder() }
    }

    private func requestAuthorizationThenSchedule() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            Task { @MainActor in
                if granted {
                    self.scheduleDailyReminder()
                } else {
                    self.reminderEnabled = false
                    self.save()
                }
            }
        }
    }

    private func scheduleDailyReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Store.reminderID])

        let content = UNMutableNotificationContent()
        content.title = "Time to focus"
        let name = selectedActivity?.name ?? "your goal"
        content.body = "A little progress on \(name) today. Press start when you're ready — discipline over motivation."
        content.sound = .default

        var components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        components.second = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: Store.reminderID, content: content, trigger: trigger))
    }

    /// Scheduled at the moment you press Start, so the cheer can land even if the app is in the
    /// background when you cross the finish line. Cancelled on pause.
    private func scheduleGoalCompletionNotification() {
        guard let id = activeActivityID,
              let activity = activities.first(where: { $0.id == id }) else { return }
        let remaining = remainingToday(for: activity, asOf: Date())
        guard remaining > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Goal complete 🎉"
        content.body = "You gave \(Format.hm(activity.dailyGoalSeconds)) to \(activity.name) today. That's discipline."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remaining, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: Store.goalNotificationID, content: content, trigger: trigger)
        )
    }

    // MARK: - Persistence

    private struct Persisted: Codable, Equatable {
        var activities: [Activity]
        var sessions: [FocusSession]
        var activeActivityID: UUID?
        var activeStart: Date?
        var selectedActivityID: UUID?
        var reminderEnabled: Bool
        var reminderHour: Int
        var reminderMinute: Int
        var lastModified: Date?
    }

    private func save(syncToICloud: Bool = true) {
        lastModified = Date()
        let snapshot = makeSnapshot(lastModified: lastModified)
        save(snapshot, syncToICloud: syncToICloud)
    }

    private func save(_ snapshot: Persisted, syncToICloud: Bool = true) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let refreshed = Persisted(
            activities: snapshot.activities,
            sessions: snapshot.sessions,
            activeActivityID: snapshot.activeActivityID,
            activeStart: snapshot.activeStart,
            selectedActivityID: snapshot.selectedActivityID,
            reminderEnabled: snapshot.reminderEnabled,
            reminderHour: components.hour ?? snapshot.reminderHour,
            reminderMinute: components.minute ?? snapshot.reminderMinute,
            lastModified: snapshot.lastModified
        )
        do {
            let data = try Self.encoder.encode(refreshed)
            try data.write(to: saveURL, options: [.atomic])
            if syncToICloud { publishToCloud(data) }
        } catch {
            print("Focus: save failed — \(error)")
        }
    }

    private func makeSnapshot(lastModified: Date) -> Persisted {
        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        return Persisted(
            activities: activities,
            sessions: sessions,
            activeActivityID: activeActivityID,
            activeStart: activeStart,
            selectedActivityID: selectedActivityID,
            reminderEnabled: reminderEnabled,
            reminderHour: components.hour ?? 9,
            reminderMinute: components.minute ?? 0,
            lastModified: lastModified
        )
    }

    private func load() {
        guard
            let data = try? Data(contentsOf: saveURL),
            let snapshot = try? Self.decoder.decode(Persisted.self, from: data)
        else { return }

        apply(snapshot)
        lastModified = snapshot.lastModified ?? localSaveModificationDate()
    }

    private func apply(_ snapshot: Persisted) {
        activities = snapshot.activities
        sessions = snapshot.sessions
        activeActivityID = snapshot.activeActivityID
        activeStart = snapshot.activeStart
        selectedActivityID = snapshot.selectedActivityID
        reminderEnabled = snapshot.reminderEnabled
        reminderTime = Self.reminderDate(hour: snapshot.reminderHour, minute: snapshot.reminderMinute)
        lastModified = snapshot.lastModified ?? lastModified
        normalizeSelection()
    }

    private func normalizeSelection() {
        if selectedActivityID == nil || !activities.contains(where: { $0.id == selectedActivityID }) {
            selectedActivityID = activities.first?.id
        }
        if let activeActivityID, !activities.contains(where: { $0.id == activeActivityID }) {
            self.activeActivityID = nil
            activeStart = nil
        }
    }

    private static func reminderDate(hour: Int, minute: Int) -> Date {
        Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: Date()
        ) ?? Store.defaultReminderTime
    }

    private func localSaveModificationDate() -> Date {
        (try? saveURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    // MARK: - iCloud Sync

    private func startCloudSync() {
        cloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloudStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.applyCloudSnapshotIfAvailable()
            }
        }

        cloudStore.synchronize()
        applyCloudSnapshotIfAvailable()
    }

    private func publishToCloud(_ data: Data) {
        guard data.count < 900_000 else {
            print("Focus: iCloud sync skipped because saved data is too large for key-value storage.")
            return
        }

        cloudStore.set(data, forKey: Self.cloudSnapshotKey)
        cloudStore.synchronize()
    }

    private func applyCloudSnapshotIfAvailable() {
        guard
            let data = cloudStore.data(forKey: Self.cloudSnapshotKey),
            let remote = try? Self.decoder.decode(Persisted.self, from: data)
        else { return }

        let local = makeSnapshot(lastModified: lastModified)
        let merged = merge(local: local, remote: remote)
        guard !sameUserData(merged, local) else { return }

        apply(merged)
        save()
    }

    private func merge(local: Persisted, remote: Persisted) -> Persisted {
        let localDate = local.lastModified ?? .distantPast
        let remoteDate = remote.lastModified ?? .distantPast
        var merged = remoteDate > localDate ? remote : local

        var seenSessionIDs: Set<UUID> = []
        merged.sessions = (local.sessions + remote.sessions)
            .sorted { $0.start < $1.start }
            .filter { seenSessionIDs.insert($0.id).inserted }

        let validActivityIDs = Set(merged.activities.map(\.id))
        merged.sessions.removeAll { !validActivityIDs.contains($0.activityID) }
        if let selected = merged.selectedActivityID, !validActivityIDs.contains(selected) {
            merged.selectedActivityID = merged.activities.first?.id
        }
        if let active = merged.activeActivityID, !validActivityIDs.contains(active) {
            merged.activeActivityID = nil
            merged.activeStart = nil
        }

        return merged
    }

    private func sameUserData(_ lhs: Persisted, _ rhs: Persisted) -> Bool {
        lhs.activities == rhs.activities &&
            lhs.sessions == rhs.sessions &&
            lhs.activeActivityID == rhs.activeActivityID &&
            lhs.activeStart == rhs.activeStart &&
            lhs.selectedActivityID == rhs.selectedActivityID &&
            lhs.reminderEnabled == rhs.reminderEnabled &&
            lhs.reminderHour == rhs.reminderHour &&
            lhs.reminderMinute == rhs.reminderMinute
    }

    // MARK: - Seed

    private func starterActivity(id: UUID = UUID(), createdAt: Date = Date()) -> Activity {
        Activity(
            id: id,
            name: "Read",
            iconName: "book.fill",
            colorHex: "234E70",
            dailyGoalHours: 1,
            rewardName: "",
            rewardTargetHours: 100,
            createdAt: createdAt
        )
    }

    private func migrateLegacyStarterActivityIfNeeded() {
        guard activities.count == 1, let activity = activities.first else { return }
        guard activity.name == "Music",
              activity.iconName == "music.note",
              activity.colorHex == "7E6CF2",
              activity.dailyGoalHours == 8,
              activity.rewardName.isEmpty,
              activity.rewardTargetHours == 100
        else { return }

        activities[0] = starterActivity(id: activity.id, createdAt: activity.createdAt)
    }

    private func seed() {
        let read = starterActivity()
        activities = [read]
        selectedActivityID = read.id
    }
}
