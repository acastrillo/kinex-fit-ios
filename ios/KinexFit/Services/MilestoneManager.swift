import Foundation
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "Milestones")

/// Manages milestone achievements and notifications
@MainActor
final class MilestoneManager {
    static let shared = MilestoneManager()

    private let notificationManager = NotificationManager(
        apiClient: AppState.shared?.environment.apiClient ?? AppEnvironment.preview.apiClient
    )
    private let userDefaults = UserDefaults.standard

    // MARK: - Milestones

    enum Milestone: Int, CaseIterable {
        case tenWorkouts = 10
        case twentyFiveWorkouts = 25
        case fiftyWorkouts = 50
        case hundredWorkouts = 100
        case twoHundredFiftyWorkouts = 250
        case fiveHundredWorkouts = 500
        case oneThousandWorkouts = 1000

        var displayName: String {
            switch self {
            case .tenWorkouts: return "🎯 First 10"
            case .twentyFiveWorkouts: return "💪 25 Workouts"
            case .fiftyWorkouts: return "🔥 50 Workouts"
            case .hundredWorkouts: return "💯 100 Workouts"
            case .twoHundredFiftyWorkouts: return "🏆 250 Workouts"
            case .fiveHundredWorkouts: return "⭐ 500 Workouts"
            case .oneThousandWorkouts: return "👑 1000 Workouts"
            }
        }

        var message: String {
            switch self {
            case .tenWorkouts:
                return "You've completed 10 workouts! Keep the momentum going!"
            case .twentyFiveWorkouts:
                return "25 workouts down! You're building a solid habit."
            case .fiftyWorkouts:
                return "50 workouts! You're officially a fitness enthusiast."
            case .hundredWorkouts:
                return "🎉 100 workouts! That's incredible dedication!"
            case .twoHundredFiftyWorkouts:
                return "250 workouts! You're a fitness legend!"
            case .fiveHundredWorkouts:
                return "500 workouts! Nothing can stop you now!"
            case .oneThousandWorkouts:
                return "1000 workouts! You're unstoppable! 👑"
            }
        }
    }

    // MARK: - Check Milestones

    /// Check if workout count reached a milestone
    func checkForMilestone(workoutCount: Int) async {
        for milestone in Milestone.allCases {
            if workoutCount == milestone.rawValue {
                await triggerMilestone(milestone)
                break
            }
        }
    }

    /// Get next milestone
    func getNextMilestone(workoutCount: Int) -> (milestone: Milestone, remaining: Int)? {
        for milestone in Milestone.allCases {
            if workoutCount < milestone.rawValue {
                return (milestone, milestone.rawValue - workoutCount)
            }
        }
        return nil
    }

    // MARK: - Trigger Milestone

    private func triggerMilestone(_ milestone: Milestone) async {
        let key = "milestone_\(milestone.rawValue)_shown"

        // Don't show duplicate notifications
        guard !userDefaults.bool(forKey: key) else {
            logger.debug("Milestone already shown: \(milestone.displayName)")
            return
        }

        // Send notification
        await sendMilestoneNotification(milestone)

        // Mark as shown
        userDefaults.set(true, forKey: key)

        logger.info("Milestone triggered: \(milestone.displayName)")
    }

    private func sendMilestoneNotification(_ milestone: Milestone) async {
        do {
            try await notificationManager.scheduleReminder(
                title: milestone.displayName,
                body: milestone.message,
                date: Date(),
                importance: .high,
                identifier: "milestone_\(milestone.rawValue)"
            )
        } catch {
            logger.error("Failed to send milestone notification: \(error.localizedDescription)")
        }
    }

    // MARK: - Progress

    /// Get progress towards next milestone
    func getProgressTowardsMilestone(workoutCount: Int) -> (current: Int, next: Int, percent: Double) {
        guard let nextMilestone = getNextMilestone(workoutCount: workoutCount) else {
            return (workoutCount, workoutCount, 100)
        }

        let previousMilestone = Milestone.allCases
            .filter { $0.rawValue < nextMilestone.milestone.rawValue }
            .last?.rawValue ?? 0

        let current = workoutCount - previousMilestone
        let next = nextMilestone.milestone.rawValue - previousMilestone
        let percent = Double(current) / Double(next) * 100

        return (current, next, percent)
    }
}
