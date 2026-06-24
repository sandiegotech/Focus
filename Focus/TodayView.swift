import SwiftUI

struct TodayView: View {
    @Environment(Store.self) private var store

    @State private var showCelebration = false
    @State private var celebratedDay: Date?
    @State private var startTrigger = 0
    @State private var successTrigger = 0
    @State private var secondsAtGoal: TimeInterval = 0

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
            .focusInlineNavigationTitle()
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
        .focusImpactFeedback(trigger: startTrigger)
        .focusSuccessFeedback(trigger: successTrigger)
        .overlay {
            if showCelebration, let activity = store.selectedActivity {
                CelebrationOverlay(activity: activity, secondsDone: secondsAtGoal) {
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
                        .font(.system(size: 36))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(color)
                    Text("Done for today")
                        .font(.sditDisplay(22))
                        .foregroundStyle(Color.sditInk)
                    Text("\(Format.hm(done)) logged")
                        .font(.sditMono(12))
                        .tracking(0.5)
                        .foregroundStyle(Color.sditMuted)
                } else {
                    Text(store.isRunning ? "REMAINING" : "TO GO TODAY")
                        .font(.sditMono(10))
                        .tracking(2)
                        .foregroundStyle(Color.sditGold)
                    Text(Format.clock(remaining))
                        .font(.sditMono(52))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(Color.sditInk)
                    Text("of \(Format.hm(activity.dailyGoalSeconds)) goal")
                        .font(.sditMono(12))
                        .tracking(0.5)
                        .foregroundStyle(Color.sditMuted)
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
                Image(systemName: running ? "pause" : "play")
                    .symbolRenderingMode(.monochrome)
                Text((running ? "Pause" : "Start").uppercased())
                    .tracking(2)
            }
            .font(.sditMono(14))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .foregroundStyle(running ? Color.sditMuted : color)
            .overlay(
                Rectangle().stroke(running ? Color.sditHairline : color, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func statusLine(for activity: Activity, now: Date) -> some View {
        let done = store.secondsToday(for: activity.id, asOf: now)
        let streak = store.currentStreak(for: activity, asOf: now)

        HStack(spacing: 6) {
            Text("\(Format.hm(done)) of \(Format.hm(activity.dailyGoalSeconds)) today")
            if streak > 0 {
                Text("·")
                Text("\(streak)-day streak")
            }
        }
        .font(.sditMono(11))
        .tracking(0.4)
        .foregroundStyle(Color.sditMuted)
    }

    // MARK: Goal detection

    private func checkGoal() {
        guard let activity = store.selectedActivity else { return }
        let now = Date()
        let today = Calendar.current.startOfDay(for: now)
        guard store.goalReachedToday(for: activity, asOf: now), celebratedDay != today else { return }
        celebratedDay = today
        secondsAtGoal = store.secondsToday(for: activity.id, asOf: now)
        successTrigger += 1
        withAnimation { showCelebration = true }
    }
}

// MARK: - Celebration

struct CelebrationOverlay: View {
    let activity: Activity
    let secondsDone: TimeInterval
    let dismiss: () -> Void

    #if canImport(UIKit)
    @State private var shareImage: UIImage?
    @State private var showShareSheet = false
    #endif

    var body: some View {
        ZStack {
            Color.sditInk.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)

            VStack(spacing: 20) {
                Text("Goal complete")
                    .font(.sditDisplay(26))
                    .foregroundStyle(Color.sditInk)
                Text("Discipline builds habits.")
                    .multilineTextAlignment(.center)
                    .font(.sditBody())
                    .foregroundStyle(Color.sditInk)
                    .padding(.horizontal)
                Text("Still recording \(activity.name) — keep going to get ahead and reach your bigger goal sooner.")
                    .multilineTextAlignment(.center)
                    .font(.sditBody())
                    .foregroundStyle(Color.sditMuted)
                    .padding(.horizontal)
                Button(action: dismiss) {
                    Text("Keep going")
                        .font(.sditDisplay(17, italic: true))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .foregroundStyle(Color.sditInk)
                        .overlay(Rectangle().stroke(Color.sditInk, lineWidth: 1))
                }
                .buttonStyle(.plain)

                #if canImport(UIKit)
                if shareImage != nil {
                    Button { showShareSheet = true } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 11))
                            Text("share")
                                .font(.sditMono(11))
                                .tracking(1.5)
                        }
                        .foregroundStyle(Color.sditMuted)
                    }
                    .buttonStyle(.plain)
                }
                #endif
            }
            .padding(28)
            .background(Color.sditPaper)
            .overlay(Rectangle().stroke(Color.sditHairline, lineWidth: 1))
            .padding(40)
        }
        .transition(.opacity)
        #if canImport(UIKit)
        .onAppear {
            let renderer = ImageRenderer(content: ShareCard(activity: activity, secondsDone: secondsDone))
            renderer.scale = UIScreen.main.scale
            shareImage = renderer.uiImage
        }
        .sheet(isPresented: $showShareSheet) {
            if let img = shareImage {
                ShareSheetView(items: [img, "Put \(Format.hm(secondsDone)) into \(activity.name) today."])
                    .ignoresSafeArea()
            }
        }
        #endif
    }
}

// MARK: - Share Sheet (UIKit bridge)

#if canImport(UIKit)
struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
#endif

// MARK: - Share Card

struct ShareCard: View {
    let activity: Activity
    let secondsDone: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            Text(Format.hm(secondsDone))
                .font(.sditMono(52))
                .foregroundStyle(Color(hex: activity.colorHex))
            Spacer().frame(height: 10)
            Text(activity.name)
                .font(.sditDisplay(30))
                .foregroundStyle(Color(hex: "FCFBF8"))
            Spacer().frame(height: 4)
            Text("today")
                .font(.sditBody(15))
                .foregroundStyle(Color(hex: "5A6472"))
            Spacer()
            Text("FOCUS")
                .font(.sditMono(10))
                .tracking(3)
                .foregroundStyle(Color(hex: "5A6472"))
        }
        .padding(28)
        .frame(width: 320, height: 320)
        .background(Color(hex: "101C2C"))
    }
}
