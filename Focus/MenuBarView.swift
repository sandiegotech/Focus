import SwiftUI

#if os(macOS)
import AppKit

struct FocusMenuBarLabel: View {
    let store: Store

    var body: some View {
        TimelineView(.periodic(from: .now, by: store.isRunning ? 1 : 60)) { context in
            if let activity = store.selectedActivity {
                let remaining = store.remainingToday(for: activity, asOf: context.date)
                HStack(spacing: 5) {
                    Image(systemName: activity.iconName)
                    Text(remaining <= 0 ? "Done" : Format.clock(remaining))
                        .monospacedDigit()
                }
            } else {
                Label("Focus", systemImage: "timer")
            }
        }
    }
}

struct FocusMenuBarView: View {
    @Environment(Store.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        TimelineView(.periodic(from: .now, by: store.isRunning ? 1 : 30)) { context in
            VStack(alignment: .leading, spacing: 14) {
                if let activity = store.selectedActivity {
                    activityControls(for: activity, now: context.date)
                } else {
                    emptyState
                }

                Divider()

                HStack {
                    Button {
                        openMainWindow()
                    } label: {
                        Label("Open Focus", systemImage: "arrow.up.forward.app")
                    }

                    Spacer()

                    Button("Quit") {
                        NSApp.terminate(nil)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(width: 300)
        }
    }

    @ViewBuilder
    private func activityControls(for activity: Activity, now: Date) -> some View {
        let color = Color(hex: activity.colorHex)
        let done = store.secondsToday(for: activity.id, asOf: now)
        let remaining = store.remainingToday(for: activity, asOf: now)
        let progress = activity.dailyGoalSeconds > 0 ? min(1, done / activity.dailyGoalSeconds) : 0
        let reached = remaining <= 0

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: activity.iconName)
                    .font(.title2)
                    .foregroundStyle(color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(activity.name)
                        .font(.headline)
                    Text("\(Format.hm(done)) of \(Format.hm(activity.dailyGoalSeconds)) today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if store.activities.count > 1 {
                Picker("Activity", selection: Binding(
                    get: { store.selectedActivityID ?? activity.id },
                    set: { store.select($0) }
                )) {
                    ForEach(store.activities) { option in
                        Label(option.name, systemImage: option.iconName).tag(option.id)
                    }
                }
                .pickerStyle(.menu)
                .disabled(store.isRunning)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(reached ? "Done for today" : Format.clock(remaining))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())

                ProgressView(value: progress, total: 1)
                    .tint(color)
            }

            HStack(spacing: 8) {
                Button {
                    store.toggle()
                } label: {
                    Label(store.isRunning ? "Pause" : "Start", systemImage: store.isRunning ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(store.isRunning ? .secondary : color)

                Button {
                    store.addManualSession(activityID: activity.id, date: Date(), seconds: 15 * 60)
                } label: {
                    Label("+15m", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)
                .disabled(store.isRunning)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Focus", systemImage: "timer")
                .font(.headline)
            Text("No activity yet")
                .foregroundStyle(.secondary)
            Button {
                openMainWindow()
            } label: {
                Label("Open Focus", systemImage: "arrow.up.forward.app")
            }
        }
    }

    private func openMainWindow() {
        openWindow(id: "main")
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
#endif
