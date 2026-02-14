import Foundation
import BackgroundTasks
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "BackgroundSync")

final class BackgroundSyncTask {
    static let shared = BackgroundSyncTask()
    static let taskIdentifier = "com.kinex.fit.sync"

    private let syncEngine: SyncEngine?

    private init() {
        // SyncEngine will be injected when app starts
        self.syncEngine = nil
    }

    // MARK: - Registration

    /// Register background task handler
    /// Call this from AppDelegate or App init
    static func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            guard let task = task as? BGProcessingTask else { return }
            shared.handleBackgroundSync(task: task)
        }
        logger.info("Background sync task registered")
    }

    // MARK: - Scheduling

    /// Schedule next background sync
    static func scheduleBackgroundSync() {
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)

        // Allow app to run in background
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false

        // Schedule to run in 15 minutes (earliest)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Background sync scheduled for 15 minutes from now")
        } catch {
            logger.error("Failed to schedule background sync: \(error.localizedDescription)")
        }
    }

    /// Cancel all pending background sync tasks
    static func cancelBackgroundSync() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
        logger.info("Background sync cancelled")
    }

    // MARK: - Execution

    private func handleBackgroundSync(task: BGProcessingTask) {
        logger.info("Background sync task started")

        // Schedule next sync
        Self.scheduleBackgroundSync()

        // Set expiration handler
        task.expirationHandler = {
            logger.warning("Background sync task expired")
            task.setTaskCompleted(success: false)
        }

        // Perform sync
        Task {
            do {
                guard let syncEngine = await AppState.shared?.environment.syncEngine else {
                    logger.error("SyncEngine not available")
                    task.setTaskCompleted(success: false)
                    return
                }

                try await syncEngine.processSyncQueue()
                logger.info("Background sync completed successfully")
                task.setTaskCompleted(success: true)
            } catch {
                logger.error("Background sync failed: \(error.localizedDescription)")
                task.setTaskCompleted(success: false)
            }
        }
    }
}

// MARK: - Info.plist Configuration

/*
 To enable background tasks, add the following to Info.plist:

 <key>BGTaskSchedulerPermittedIdentifiers</key>
 <array>
     <string>com.kinex.fit.sync</string>
 </array>

 Also add Background Modes capability in Xcode:
 - Background fetch
 - Background processing
 */
