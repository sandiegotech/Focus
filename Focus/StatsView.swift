import SwiftUI
import Charts

struct StatsView: View {
    @Environment(Store.self) private var store
    @State private var now = Date()
    @State private var showAddTime = false

    var body: some View {
        NavigationStack {
            Group {
                if let activity = store.selectedActivity {
                    ScrollView {
                        VStack(spacing: 18) {
                            if store.activities.count > 1 { picker }
                            statsGrid(for: activity)
                            chartCard(for: activity)
                            if activity.hasReward { rewardCard(for: activity) }
                            recentSessions(for: activity)
                        }
                        .padding()
                    }
                } else {
                    ContentUnavailableView(
                        "Nothing logged yet",
                        systemImage: "chart.bar",
                        description: Text("Start a timer on the Today tab.")
                    )
                }
            }
            .navigationTitle("Progress")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddTime = true } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(store.selectedActivity == nil)
                }
            }
            .sheet(isPresented: $showAddTime) {
                if let activity = store.selectedActivity {
                    AddTimeSheet(activity: activity)
                }
            }
            .onAppear { now = Date() }
        }
    }

    private var picker: some View {
        Picker("Activity", selection: Binding(
            get: { store.selectedActivityID ?? store.activities.first?.id },
            set: { if let id = $0 { store.select(id) } }
        )) {
            ForEach(store.activities) { activity in
                Text(activity.name).tag(Optional(activity.id))
            }
        }
        .pickerStyle(.segmented)
    }

    private func statsGrid(for activity: Activity) -> some View {
        let color = Color(hex: activity.colorHex)
        let total = store.totalSeconds(for: activity.id, asOf: now)
        let today = store.secondsToday(for: activity.id, asOf: now)
        let days = store.daysPracticed(for: activity.id, asOf: now)
        let streak = store.currentStreak(for: activity, asOf: now)

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(title: "All-time", value: Format.hm(total), systemImage: "hourglass", tint: color)
            StatCard(title: "Today", value: Format.hm(today), systemImage: "sun.max.fill", tint: color)
            StatCard(title: "Days practiced", value: "\(days)", systemImage: "calendar", tint: color)
            StatCard(title: "Current streak", value: streak == 1 ? "1 day" : "\(streak) days", systemImage: "flame.fill", tint: color)
        }
    }

    private func chartCard(for activity: Activity) -> some View {
        let bars = store.last7Days(for: activity.id, asOf: now)
        let color = Color(hex: activity.colorHex)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Last 7 days").font(.headline)
            Chart {
                ForEach(bars) { bar in
                    BarMark(
                        x: .value("Day", bar.day, unit: .day),
                        y: .value("Hours", bar.seconds / 3600)
                    )
                    .foregroundStyle(color.gradient)
                    .cornerRadius(6)
                }
                RuleMark(y: .value("Goal", activity.dailyGoalHours))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text("Goal \(Format.niceHours(activity.dailyGoalHours))h")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial))
    }

    private func rewardCard(for activity: Activity) -> some View {
        let color = Color(hex: activity.colorHex)
        let total = store.totalSeconds(for: activity.id, asOf: now)
        let target = activity.rewardTargetSeconds
        let progress = target > 0 ? total / target : 0
        let reached = total >= target

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: reached ? "gift.fill" : "gift")
                Text(activity.rewardName).font(.headline)
                Spacer()
                if reached {
                    Text("Unlocked!")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(color)
                }
            }
            ProgressBar(progress: progress, color: color)
            Text("\(Format.hm(total)) of \(Format.niceHours(activity.rewardTargetHours))h")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial))
    }

    private func recentSessions(for activity: Activity) -> some View {
        let recent = Array(store.loggedSessions(for: activity.id)
            .sorted { $0.start > $1.start }
            .prefix(15))

        return VStack(alignment: .leading, spacing: 10) {
            Text("Recent sessions").font(.headline)

            if recent.isEmpty {
                Text("No sessions yet. Press start on the Today tab, or add time with +.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recent) { session in
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.start, format: .dateTime.weekday().month().day())
                                    .font(.subheadline)
                                Text(session.start, format: .dateTime.hour().minute())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(Format.hm(session.seconds))
                                .font(.subheadline.weight(.medium))
                                .monospacedDigit()
                        }
                        .padding(.vertical, 8)
                        .contextMenu {
                            Button(role: .destructive) {
                                store.deleteSession(session)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        if session.id != recent.last?.id { Divider() }
                    }
                }
                Text("Long-press a session to delete it.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial))
    }
}

// MARK: - Add time by hand

struct AddTimeSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let activity: Activity

    @State private var hours = 1
    @State private var minutes = 0
    @State private var date = Date()

    private var isEmpty: Bool { hours == 0 && minutes == 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("How long?") {
                    Stepper(value: $hours, in: 0...16) { Text("\(hours) h") }
                    Stepper(value: $minutes, in: 0...59, step: 5) { Text("\(minutes) m") }
                }
                Section("When?") {
                    DatePicker("Day", selection: $date, in: ...Date(), displayedComponents: .date)
                }
            }
            .navigationTitle("Add time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let seconds = TimeInterval(hours * 3600 + minutes * 60)
                        if seconds > 0 {
                            store.addManualSession(activityID: activity.id, date: date, seconds: seconds)
                        }
                        dismiss()
                    }
                    .disabled(isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
