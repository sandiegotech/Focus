import SwiftUI

struct ActivityEditView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let existing: Activity?

    @State private var name: String
    @State private var iconName: String
    @State private var colorHex: String
    @State private var dailyGoal: Double
    @State private var rewardName: String
    @State private var rewardTarget: Double

    init(activity: Activity?) {
        self.existing = activity
        _name = State(initialValue: activity?.name ?? "")
        _iconName = State(initialValue: activity?.iconName ?? "music.note")
        _colorHex = State(initialValue: activity?.colorHex ?? Self.palette[0])
        _dailyGoal = State(initialValue: activity?.dailyGoalHours ?? 8)
        _rewardName = State(initialValue: activity?.rewardName ?? "")
        _rewardTarget = State(initialValue: activity?.rewardTargetHours ?? 100)
    }

    static let palette = ["7E6CF2", "EF5DA8", "F2A65A", "57C28F", "5AA9E6", "E5544B", "9B59B6", "2DD4BF"]
    static let icons = ["music.note", "guitars.fill", "pencil", "book.fill", "dumbbell.fill", "paintbrush.fill",
                        "laptopcomputer", "figure.run", "camera.fill", "mic.fill", "brain.head.profile", "leaf.fill"]

    private var color: Color { Color(hex: colorHex) }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Music", text: $name)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(Self.icons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.title3)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(iconName == icon ? color.opacity(0.22) : Color.secondary.opacity(0.12)))
                                .foregroundStyle(iconName == icon ? color : .secondary)
                                .overlay(Circle().stroke(iconName == icon ? color : .clear, lineWidth: 2))
                                .onTapGesture { iconName = icon }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                        ForEach(Self.palette, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 30, height: 30)
                                .overlay(Circle().stroke(Color.primary, lineWidth: colorHex == hex ? 2 : 0).padding(-3))
                                .onTapGesture { colorHex = hex }
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Daily goal") {
                    Stepper(value: $dailyGoal, in: 0.5...16, step: 0.5) {
                        Text("\(Format.niceHours(dailyGoal)) hours per day")
                    }
                }

                Section {
                    TextField("Reward — e.g. Buy that pedal", text: $rewardName)
                    Stepper(value: $rewardTarget, in: 1...2000, step: 5) {
                        Text("after \(Int(rewardTarget)) total hours")
                    }
                } header: {
                    Text("Reward (optional)")
                } footer: {
                    Text("Pick something you genuinely want. When your all-time hours reach the target, it's yours — earned, not bought on a whim.")
                }
            }
            .navigationTitle(existing == nil ? "New activity" : "Edit activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        let cleanedReward = rewardName.trimmingCharacters(in: .whitespaces)

        if var activity = existing {
            activity.name = trimmedName
            activity.iconName = iconName
            activity.colorHex = colorHex
            activity.dailyGoalHours = dailyGoal
            activity.rewardName = cleanedReward
            activity.rewardTargetHours = rewardTarget
            store.updateActivity(activity)
        } else {
            store.addActivity(Activity(
                name: trimmedName,
                iconName: iconName,
                colorHex: colorHex,
                dailyGoalHours: dailyGoal,
                rewardName: cleanedReward,
                rewardTargetHours: rewardTarget
            ))
        }
        dismiss()
    }
}
