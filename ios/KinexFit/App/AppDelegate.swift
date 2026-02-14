import UIKit
import UserNotifications
import FacebookCore
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "AppDelegate")

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        logger.info("App launched")

        // Initialize Facebook SDK
        ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)

        // Register notification categories
        if let notificationManager = AppState.shared?.environment.notificationManager {
            Task { @MainActor in
                notificationManager.registerNotificationCategories()
            }
        }

        return true
    }

    // MARK: - Push Notifications

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        logger.info("Did register for remote notifications")

        // Pass token to NotificationManager
        if let notificationManager = AppState.shared?.environment.notificationManager {
            Task { @MainActor in
                notificationManager.didReceiveDeviceToken(deviceToken)
            }
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        logger.error("Failed to register for remote notifications: \(error.localizedDescription)")

        // Pass error to NotificationManager
        if let notificationManager = AppState.shared?.environment.notificationManager {
            Task { @MainActor in
                notificationManager.didFailToRegisterForRemoteNotifications(error: error)
            }
        }
    }
}
