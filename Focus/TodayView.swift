import SwiftUI

struct TodayView: View {
    @Environment(Store.self) private var store

    @State private var showCelebration = false
    @State private var celebratedDay: Date?
    @State private var startTrigger = 0
    @State private var successTrigger = 0

    // Fires once a second to check for goal completion. The visible countdown is driven by
    // TimelineView below, so this view's body does NOT recompute every second — which keeps
    // this subscription stable.
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Tick every second while running; essentially idle otherwise.
    private var tickSchedule: PeriodicTimelineSchedule {
        .periodic(from: .now, by: store.isRunning ? 1 : 3600)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let activity = store.selectedActivity {
                    content(for: activity)
                } else {
                    ContentUnavailableView {
                        Label("No activities yet", systemImage: "timer")
                    } description: {
                        Text("Add something you want to dedicate time to in Settings.")
                    }
                }
            }
            .navigationTitle("Focus")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onReceive(ticker) { _ in
            if store.isRunning { checkGoal() }
        }
        .onAppear {
            // If today's goal is already met, treat it as celebrated so restarting a timer
            // later the same day doesn't pop the celebration again.
            if let activity = store.selectedActivity, store.goalReachedToday(for: activity) {
                celebratedDay = Calendar.current.startOfDay(for: Date())
            }
        }
        .sensoryFeedback(.impact, trigger: startTrigger)
        .sensoryFeedback(.success, trigger: successTrigger)
        .overlay {
            if showCelebration, let activity = store.selectedActivity {
                CelebrationOverlay(activity: activity) {
                    withAnimation { showCelebration = false }
                }
            }
        }
    }

    // MARK: Content

    @ViewBuilder
    private func content(for activity: Activity) -> some View {
        VStack(spacing: 24) {
            if store.activities.count > 1 {
                pillBar
            }
            Spacer(minLength: 0)
            TimelineView(tickSchedule) { context in
                ringStack(for: activity, now: context.date)
            }
            Spacer(minLength: 0)
            startButton(for: activity)
            TimelineView(tickSchedule) { context in
                statusLine(for: activity, now: context.date)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
        .padding(.top, store.activities.count > 1 ? 8 : 0)
    }

    private var pillBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(store.activities) { activity in
                    ActivityPill(activity: activity, isSelected: activity.id == store.selectedActivityID) {
                        if !store.isRunning { store.select(activity.id) }
                    }
                    .opacity(store.isRunning && activity.id != store.selectedActivityID ? 0.35 : 1)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func ringStack(for activity: Activity, now: Date) -> some View {
        let goal = activity.dailyGoalSeconds
        let done = store.secondsToday(for: activity.id, asOf: now)
        let remaining = max(0, goal - done)
        let progress = goal > 0 ? done / goal : 0
        let color = Color(hex: activity.colorHex)
        let reached = remaining <= 0

        ZStack {
            RingView(progress: progress, color: color)
                .frame(width: 280, height: 280)

            VStack(spacing: 6) {
                if reached {
                    Image(systemName: "checkmark")
                        .font(.system(size: 46, weight: .bold))
                        .foregroundStyle(color)
                    Text("Done for today")
                        .font(.headline)
                    Text("\(Format.hm(done)) logged")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(store.isRunning ? "REMAINING" : "TO GO TODAY")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(Format.clock(remaining))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("of \(Format.niceHours(activity.dailyGoalHours))h goal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 40)
            .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private func startButton(for activity: Activity) -> some View {
        let color = Color(hex: activity.colorHex)
        let running = store.isRunning

        Button {
            store.toggle()
            startTrigger += 1
        } label: {
            HStack(spacing: 10) {
                Image(systemName: running ? "pause.fill" : "play.fill")
                Text(running ? "Pause" : "Start")
            }
            .font(.title3.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(running ? AnyShapeStyle(Color.secondary.opacity(0.18)) : AnyShapeStyle(color.gradient))
            )
            .foregroundStyle(running ? color : .white)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func statusLine(for activity: Activity, now: Date) -> some View {
        let done = store.secondsToday(for: activity.id, asOf: now)
        let streak = store.currentStreak(for: activity, asOf: now)

        HStack(spacing: 6) {
            Text("\(Format.hours(done)) of \(Format.niceHours(activity.dailyGoalHours)) hrs today")
            if streak > 0 {
                Text("·")
                Text("🔥 \(streak)-day streak")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    // MARK: Goal detection

    private func checkGoal() {
        guard let activity = store.selectedActivity else { return }
        let now = Date()
        let today = Calendar.current.startOfDay(for: now)
        guard store.goalReachedToday(for: activity, asOf: now), celebratedDay != today else { return }
        celebratedDay = today
        successTrigger += 1
        withAnimation { showCelebration = true }
    }
}

// MARK: - Celebration

struct CelebrationOverlay: View {
    let activity: Activity
    let dismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)

            VStack(spacing: 16) {
                Text("🎉").font(.system(size: 64))
                Text("Goal complete").font(.title2.bold())
                Text("You gave \(Format.hm(activity.dailyGoalSeconds)) to \(activity.name) today — on discipline, not motivation. That's how it compounds.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                Button("Nice", action: dismiss)
                    .font(.headline)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color(hex: activity.colorHex).gradient))
                    .foregroundStyle(.white)
            }
            .padding(28)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.regularMaterial))
            .padding(40)
        }
        .transition(.opacity)
    }
}
