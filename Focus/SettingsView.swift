import SwiftUI

struct SettingsView: View {
    @Environment(Store.self) private var store
    @State private var editing: Activity?
    @State private var creatingNew = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Activities") {
                    ForEach(store.activities) { activity in
                        Button { editing = activity } label: {
                            HStack(spacing: 12) {
                                Image(systemName: activity.iconName)
                                    .foregroundStyle(Color(hex: activity.colorHex))
                                    .frame(width: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(activity.name).foregroundStyle(.primary)
                                    Text("\(Format.niceHours(activity.dailyGoalHours))h per day"
                                         + (activity.hasReward ? " · \(activity.rewardName)" : ""))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { store.activities[$0] }.forEach { store.deleteActivity($0) }
                    }

                    Button { creatingNew = true } label: {
                        Label("Add activity", systemImage: "plus.circle.fill")
                    }
                }

                Section {
                    Toggle("Remind me to start", isOn: Binding(
                        get: { store.reminderEnabled },
                        set: { store.setReminder(enabled: $0) }
                    ))
                    if store.reminderEnabled {
                        DatePicker("Time", selection: Binding(
                            get: { store.reminderTime },
                            set: { store.setReminderTime($0) }
                        ), displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Daily reminder")
                } footer: {
                    Text("A gentle once-a-day nudge — never a guilt trip. You can turn it off anytime.")
                }

                Section {
                    Text("Discipline over motivation. Small, repeated effort is what compounds — show up even when you don't feel like it, and let the totals prove it to you.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("The idea")
                }
            }
            .navigationTitle("Settings")
            .sheet(item: $editing) { activity in
                ActivityEditView(activity: activity)
            }
            .sheet(isPresented: $creatingNew) {
                ActivityEditView(activity: nil)
            }
        }
    }
}
