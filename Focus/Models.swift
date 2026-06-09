import Foundation

/// Something you want to dedicate time to — e.g. "Music", with an 8h/day goal.
struct Activity: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var iconName: String          // SF Symbol name
    var colorHex: String          // accent color, e.g. "7E6CF2"
    var dailyGoalHours: Double     // e.g. 8

    // Reward: a thing you'll let yourself have once your all-time hours hit the target.
    var rewardName: String         // empty == no reward set
    var rewardTargetHours: Double  // cumulative hours that unlock the reward

    var createdAt: Date = Date()

    var dailyGoalSeconds: TimeInterval { dailyGoalHours * 3600 }
    var rewardTargetSeconds: TimeInterval { rewardTargetHours * 3600 }

    var hasReward: Bool {
        !rewardName.trimmingCharacters(in: .whitespaces).isEmpty && rewardTargetHours > 0
    }
}

/// A single chunk of logged time against an activity.
struct FocusSession: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var activityID: UUID
    var start: Date
    var seconds: TimeInterval

    var end: Date { start.addingTimeInterval(seconds) }

    /// The calendar day this session is credited to (based on when it started, local time).
    var day: Date { Calendar.current.startOfDay(for: start) }
}
