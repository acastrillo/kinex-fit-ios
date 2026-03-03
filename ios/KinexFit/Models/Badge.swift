import Foundation

/// Achievement badges earned by user activity
enum Badge: String, Codable, CaseIterable {
    case workoutTen = "10_workouts"
    case workoutFifty = "50_workouts"
    case workoutHundred = "100_workouts"
    case workoutThousandMinutes = "1000_minutes"
    case newPersonalRecord = "new_personal_record"
    case streakWeek = "streak_week"
    case streakMonth = "streak_month"
    case bodyMetricsLogged = "body_metrics_logged"
    case consistentWeek = "consistent_week"
    case earlyBird = "early_bird"

    var title: String {
        switch self {
        case .workoutTen: return "Getting Started"
        case .workoutFifty: return "Consistent"
        case .workoutHundred: return "Dedicated"
        case .workoutThousandMinutes: return "Endurance"
        case .newPersonalRecord: return "New PR!"
        case .streakWeek: return "Week on Fire"
        case .streakMonth: return "Month Strong"
        case .bodyMetricsLogged: return "Tracker"
        case .consistentWeek: return "Disciplined"
        case .earlyBird: return "Early Riser"
        }
    }

    var description: String {
        switch self {
        case .workoutTen: return "Completed 10 workouts"
        case .workoutFifty: return "Completed 50 workouts"
        case .workoutHundred: return "Completed 100 workouts"
        case .workoutThousandMinutes: return "Logged 1000+ minutes"
        case .newPersonalRecord: return "Hit a new personal record"
        case .streakWeek: return "7-day workout streak"
        case .streakMonth: return "30-day workout streak"
        case .bodyMetricsLogged: return "Logged body metrics"
        case .consistentWeek: return "5 workouts in one week"
        case .earlyBird: return "Completed 5 workouts before 8 AM"
        }
    }

    var emoji: String {
        switch self {
        case .workoutTen: return "🏅"
        case .workoutFifty: return "🥈"
        case .workoutHundred: return "🥇"
        case .workoutThousandMinutes: return "⏱️"
        case .newPersonalRecord: return "💪"
        case .streakWeek: return "🔥"
        case .streakMonth: return "🔥🔥"
        case .bodyMetricsLogged: return "📊"
        case .consistentWeek: return "💯"
        case .earlyBird: return "🌅"
        }
    }

    var color: String {
        switch self {
        case .workoutTen: return "#FFFACD"
        case .workoutFifty: return "#C0C0C0"
        case .workoutHundred: return "#FFD700"
        case .workoutThousandMinutes: return "#FF6B6B"
        case .newPersonalRecord: return "#4ECDC4"
        case .streakWeek, .streakMonth: return "#FF6B35"
        case .bodyMetricsLogged: return "#667BC6"
        case .consistentWeek: return "#95E1D3"
        case .earlyBird: return "#F8B195"
        }
    }
}

/// User's earned badges
struct BadgeProgress: Codable {
    var earnedBadges: [Badge] = []
    var workoutCount: Int = 0
    var totalMinutes: Int = 0
    var currentStreak: Int = 0
    var metricsLogged: Bool = false
    var personalRecordsCount: Int = 0

    /// Check which badges should be earned
    func checkAndEarnBadges() -> [Badge] {
        var newBadges: [Badge] = []

        if workoutCount >= 10 && !earnedBadges.contains(.workoutTen) {
            newBadges.append(.workoutTen)
        }
        if workoutCount >= 50 && !earnedBadges.contains(.workoutFifty) {
            newBadges.append(.workoutFifty)
        }
        if workoutCount >= 100 && !earnedBadges.contains(.workoutHundred) {
            newBadges.append(.workoutHundred)
        }
        if totalMinutes >= 1000 && !earnedBadges.contains(.workoutThousandMinutes) {
            newBadges.append(.workoutThousandMinutes)
        }
        if personalRecordsCount > 0 && !earnedBadges.contains(.newPersonalRecord) {
            newBadges.append(.newPersonalRecord)
        }
        if currentStreak >= 7 && !earnedBadges.contains(.streakWeek) {
            newBadges.append(.streakWeek)
        }
        if currentStreak >= 30 && !earnedBadges.contains(.streakMonth) {
            newBadges.append(.streakMonth)
        }
        if metricsLogged && !earnedBadges.contains(.bodyMetricsLogged) {
            newBadges.append(.bodyMetricsLogged)
        }

        return newBadges
    }
}
