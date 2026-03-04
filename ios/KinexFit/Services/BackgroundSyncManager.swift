import Foundation
import BackgroundTasks
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "BackgroundSync")

/// Manages background syncing of workout data
@MainActor
final class BackgroundSyncManager {
    static let shared = BackgroundSyncManager()
    static let backgroundSyncIdentifier = "com.kinex.fit.background.sync"

    private let workoutRepository: WorkoutRepository
    private let userRepository: UserRepository

    init(
        workoutRepository: WorkoutRepository? = nil,
        userRepository: UserRepository? = nil
    ) {
        self.workoutRepository = workoutRepository ?? AppState.shared?.environment.workoutRepository ?? AppEnvironment.preview.workoutRepository
        self.userRepository = userRepository ?? AppState.shared?.environment.userRepository ?? AppEnvironment.preview.userRepository
    }

    // MARK: - Setup

    /// Register background sync task
    func registerBackgroundSync() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.backgroundSyncIdentifier,
            using: nil
        ) { task in
            Task {
                await self.performBackgroundSync(task as! BGProcessingTask)
            }
        }
        logger.debug("Background sync task registered")
    }

    /// Schedule background sync task
    func scheduleBackgroundSync() {
        let request = BGProcessingTaskRequest(identifier: Self.backgroundSyncIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Background sync task scheduled")
        } catch {
            logger.error("Failed to schedule background sync: \(error.localizedDescription)")
        }
    }

    // MARK: - Background Sync

    private func performBackgroundSync(_ task: BGProcessingTask) async {
        // Create expiration handler
        task.expirationHandler = {
            logger.warning("Background sync task expired")
            task.setTaskCompleted(success: false)
        }

        do {
            logger.info("Starting background sync...")

            // Sync pending workouts
            try await syncPendingWorkouts()

            // Sync user data
            try await syncUserData()

            // Mark as complete
            task.setTaskCompleted(success: true)
            logger.info("Background sync completed successfully")

            // Schedule next sync
            scheduleBackgroundSync()
        } catch {
            logger.error("Background sync failed: \(error.localizedDescription)")
            task.setTaskCompleted(success: false)
        }
    }

    private func syncPendingWorkouts() async throws {
        logger.debug("Syncing pending workouts...")
        // Implementation would fetch pending workouts and sync to backend
        // This is a stub; actual implementation depends on WorkoutRepository
    }

    private func syncUserData() async throws {
        logger.debug("Syncing user data...")
        // Implementation would fetch user profile and sync to backend
        // This is a stub; actual implementation depends on UserRepository
    }
}

// MARK: - AppDelegate Integration

extension BackgroundSyncManager {
    /// Call from AppDelegate.applicationDidFinishLaunching
    static func setupBackgroundSync() {
        DispatchQueue.main.async {
            shared.registerBackgroundSync()
            shared.scheduleBackgroundSync()
        }
    }
}
