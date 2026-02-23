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

        do {
            try GoogleSignInManager.configureSharedInstanceForLaunch()
        } catch let configError as GoogleSignInError {
            logger.error("Google Sign In launch configuration error: \(configError.localizedDescription, privacy: .public)")
        } catch {
            logger.error("Unexpected Google Sign In launch configuration error: \(error.localizedDescription)")
        }

        // Initialize Facebook SDK
        ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)

        configureSystemAppearance()

        // Register notification categories
        if let notificationManager = AppState.shared?.environment.notificationManager {
            Task { @MainActor in
                notificationManager.registerNotificationCategories()
            }
        }

        BackgroundSyncTask.registerBackgroundTask()
        BackgroundSyncTask.scheduleBackgroundSync()

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

    func applicationDidEnterBackground(_ application: UIApplication) {
        BackgroundSyncTask.scheduleBackgroundSync()
    }

    private func configureSystemAppearance() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor.black
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor.black
        tabAppearance.shadowColor = UIColor(white: 1.0, alpha: 0.08)

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
}
