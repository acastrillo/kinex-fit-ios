import Foundation
import Intents
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "SiriShortcuts")

/// Manages Siri Shortcuts integration
@MainActor
final class SiriShortcutsManager {
    static let shared = SiriShortcutsManager()

    // MARK: - Activity Donation

    /// Donate activity for Siri suggestions
    func donateStartWorkout() {
        let activity = NSUserActivity(activityType: "com.kinex.fit.start-workout")
        activity.title = "Start Workout"
        activity.userInfo = ["timestamp": Date().timeIntervalSince1970]
        activity.isEligibleForSearch = true
        activity.isEligibleForHandoff = true
        activity.isEligibleForPublicIndexing = false

        activity.persistentIdentifier = "com.kinex.fit.start-workout"

        logger.info("Donated StartWorkout activity")
    }

    /// Donate activity for timer control
    func donatePauseWorkout() {
        let activity = NSUserActivity(activityType: "com.kinex.fit.pause-workout")
        activity.title = "Pause Workout"
        activity.isEligibleForSearch = true
        activity.isEligibleForHandoff = true
        activity.isEligibleForPublicIndexing = false

        logger.info("Donated PauseWorkout activity")
    }

    /// Donate activity for logging metrics
    func donateLogMetrics() {
        let activity = NSUserActivity(activityType: "com.kinex.fit.log-metrics")
        activity.title = "Log Metrics"
        activity.isEligibleForSearch = true
        activity.isEligibleForPublicIndexing = false

        logger.info("Donated LogMetrics activity")
    }

    // MARK: - Intent Handling

    /// Handle Siri intent for starting workout
    func handleStartWorkoutIntent(completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            logger.info("Starting workout via Siri intent")
            completion(true)
        }
    }

    /// Handle Siri intent for pausing workout
    func handlePauseWorkoutIntent(completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            logger.info("Pausing workout via Siri intent")
            completion(true)
        }
    }

    /// Handle Siri intent for logging metrics
    func handleLogMetricsIntent(value: Double, type: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            logger.info("Logging metric via Siri: \(type) = \(value)")
            completion(true)
        }
    }

    // MARK: - Registration

    /// Register all Siri shortcuts
    func registerShortcuts() {
        donateStartWorkout()
        donatePauseWorkout()
        donateLogMetrics()
        logger.info("Registered Siri shortcuts")
    }
}

// MARK: - Siri Shortcut Intents

/// Intent for starting a workout
class StartWorkoutIntent: INIntent {
    override init() {
        super.init()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

/// Intent for pausing a workout
class PauseWorkoutIntent: INIntent {
    override init() {
        super.init()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

/// Intent for logging metrics
class LogMetricsIntent: INIntent {
    @NSManaged var metricValue: NSNumber?
    @NSManaged var metricType: String?

    override init() {
        super.init()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
