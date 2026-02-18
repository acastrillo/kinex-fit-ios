import Foundation

/// Stats model for the Home tab dashboard
struct HomeStats {
    let workoutsThisWeek: Int
    let totalWorkouts: Int
    let hoursTrainedMinutes: Int  // Estimated: workouts × 45 min
    let streak: Int               // Consecutive days with workouts

    /// Formatted hours trained string (shows hours if >= 60 min)
    var formattedHoursTrained: String {
        if hoursTrainedMinutes >= 60 {
            let hours = hoursTrainedMinutes / 60
            return "\(hours)"
        }
        return "\(hoursTrainedMinutes)m"
    }

    /// Formatted streak string
    var formattedStreak: String {
        if streak == 1 {
            return "1 day"
        }
        return "\(streak) days"
    }

    /// Empty stats for initial state
    static let empty = HomeStats(
        workoutsThisWeek: 0,
        totalWorkouts: 0,
        hoursTrainedMinutes: 0,
        streak: 0
    )
}

// MARK: - Stats Calculator

/// Calculator for computing home stats from workout data
struct HomeStatsCalculator {
    private let estimatedWorkoutDurationMinutes = 45

    /// Calculate stats from workout data
    /// - Parameters:
    ///   - workouts: All workouts
    ///   - workoutDates: Dates of all workouts (for streak calculation)
    /// - Returns: Computed HomeStats
    func calculate(workouts: [Workout], workoutDates: [Date]) -> HomeStats {
        let totalWorkouts = workouts.count
        let workoutsThisWeek = countWorkoutsThisWeek(workouts: workouts)
        let hoursTrainedMinutes = totalWorkouts * estimatedWorkoutDurationMinutes
        let streak = calculateStreak(dates: workoutDates)

        return HomeStats(
            workoutsThisWeek: workoutsThisWeek,
            totalWorkouts: totalWorkouts,
            hoursTrainedMinutes: hoursTrainedMinutes,
            streak: streak
        )
    }

    /// Count workouts created in the current week (Monday-Sunday)
    private func countWorkoutsThisWeek(workouts: [Workout]) -> Int {
        let calendar = Calendar.current
        let now = Date()

        // Get start of current week (Monday)
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
            return 0
        }

        return workouts.filter { workout in
            workout.createdAt >= weekStart && workout.createdAt <= now
        }.count
    }

    /// Calculate consecutive days streak from today/yesterday backwards
    private func calculateStreak(dates: [Date]) -> Int {
        guard !dates.isEmpty else { return 0 }

        let calendar = Calendar.current

        // Get unique days (normalized to start of day)
        let uniqueDays = Set(dates.compactMap { date in
            calendar.startOfDay(for: date)
        }).sorted(by: >)

        guard !uniqueDays.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // Check if streak starts from today or yesterday
        guard let mostRecentDay = uniqueDays.first,
              mostRecentDay == today || mostRecentDay == yesterday else {
            return 0
        }

        var streak = 0
        var expectedDay = mostRecentDay

        for day in uniqueDays {
            if day == expectedDay {
                streak += 1
                expectedDay = calendar.date(byAdding: .day, value: -1, to: expectedDay)!
            } else if day < expectedDay {
                // Gap in streak
                break
            }
        }

        return streak
    }
}
