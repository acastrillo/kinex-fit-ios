import UIKit
import UserNotifications
import FacebookCore
import GoogleSignIn
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "AppDelegate")

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        logger.info("App launched")

        if let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
           !clientID.isEmpty {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        } else {
            logger.error("Missing GIDClientID in Info.plist")
        }

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

    @discardableResult
    func handleOAuthCallback(
        application: UIApplication = .shared,
        url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        logger.info("Received OAuth callback URL with scheme: \(url.scheme ?? "unknown", privacy: .public)")

        if GIDSignIn.sharedInstance.handle(url) {
            logger.info("OAuth callback handled by Google Sign In")
            return true
        }

        let handledByFacebook = ApplicationDelegate.shared.application(
            application,
            open: url,
            sourceApplication: options[.sourceApplication] as? String,
            annotation: options[.annotation]
        )

        if handledByFacebook {
            logger.info("OAuth callback handled by Facebook SDK")
        } else {
            logger.warning("OAuth callback was not handled by Google or Facebook")
        }

        return handledByFacebook
    }

    func application(
        _ application: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        handleOAuthCallback(application: application, url: url, options: options)
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
