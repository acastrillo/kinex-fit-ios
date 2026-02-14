import Foundation
import UIKit
import UserNotifications
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "NotificationManager")

/// Manages push notifications and local notifications
@MainActor
final class NotificationManager: NSObject, ObservableObject {
    @Published var permissionStatus: UNAuthorizationStatus = .notDetermined
    @Published var deviceToken: String?

    private let apiClient: APIClient
    private let center = UNUserNotificationCenter.current()

    init(apiClient: APIClient) {
        self.apiClient = apiClient
        super.init()
        center.delegate = self
    }

    // MARK: - Permission

    /// Request notification permissions
    func requestPermission() async throws -> Bool {
        let options: UNAuthorizationOptions = [.alert, .badge, .sound]

        let granted = try await center.requestAuthorization(options: options)

        if granted {
            logger.info("Notification permission granted")
            await updatePermissionStatus()

            // Register for remote notifications on main thread
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } else {
            logger.warning("Notification permission denied")
            await updatePermissionStatus()
        }

        return granted
    }

    /// Check current permission status
    func checkPermissionStatus() async {
        await updatePermissionStatus()
    }

    private func updatePermissionStatus() async {
        let settings = await center.notificationSettings()
        permissionStatus = settings.authorizationStatus
        logger.debug("Notification permission status: \(String(describing: settings.authorizationStatus))")
    }

    // MARK: - Device Token

    /// Handle device token received from APNs
    func didReceiveDeviceToken(_ deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString
        logger.info("Device token received: \(tokenString.prefix(20))...")

        // Send token to backend
        Task {
            await registerDeviceToken(tokenString)
        }
    }

    /// Handle device token registration failure
    func didFailToRegisterForRemoteNotifications(error: Error) {
        logger.error("Failed to register for remote notifications: \(error.localizedDescription)")
    }

    private func registerDeviceToken(_ token: String) async {
        do {
            struct RegisterTokenRequest: Encodable {
                let deviceToken: String
                let platform: String = "ios"
            }

            let request = try APIRequest.json(
                path: "/api/mobile/notifications/register",
                method: .post,
                body: RegisterTokenRequest(deviceToken: token)
            )

            struct EmptyResponse: Decodable {}
            let _: EmptyResponse = try await apiClient.send(request)

            logger.info("Device token registered with backend")
        } catch {
            logger.error("Failed to register device token: \(error.localizedDescription)")
        }
    }

    // MARK: - Local Notifications

    /// Schedule a local workout reminder
    func scheduleWorkoutReminder(
        title: String,
        body: String,
        date: Date,
        identifier: String = UUID().uuidString
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "WORKOUT_REMINDER"

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        try await center.add(request)
        logger.info("Scheduled workout reminder for \(date)")
    }

    /// Cancel a scheduled notification
    func cancelNotification(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        logger.debug("Cancelled notification: \(identifier)")
    }

    /// Cancel all scheduled notifications
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
        logger.info("Cancelled all pending notifications")
    }

    /// Get pending notification count
    func getPendingNotificationCount() async -> Int {
        let requests = await center.pendingNotificationRequests()
        return requests.count
    }

    // MARK: - Notification Categories

    /// Register notification categories and actions
    func registerNotificationCategories() {
        // Workout reminder category
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE_WORKOUT",
            title: "Mark Complete",
            options: []
        )

        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_WORKOUT",
            title: "Remind me in 1 hour",
            options: []
        )

        let workoutCategory = UNNotificationCategory(
            identifier: "WORKOUT_REMINDER",
            actions: [completeAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        // Streak reminder category
        let viewStreakAction = UNNotificationAction(
            identifier: "VIEW_STREAK",
            title: "View Progress",
            options: .foreground
        )

        let streakCategory = UNNotificationCategory(
            identifier: "STREAK_REMINDER",
            actions: [viewStreakAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([workoutCategory, streakCategory])
        logger.info("Registered notification categories")
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        logger.info("Notification received in foreground: \(notification.request.identifier)")

        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier
        let notificationIdentifier = response.notification.request.identifier

        logger.info("Notification action: \(actionIdentifier) for \(notificationIdentifier)")

        Task { @MainActor in
            await handleNotificationAction(actionIdentifier, notificationIdentifier: notificationIdentifier)
            completionHandler()
        }
    }

    private func handleNotificationAction(_ actionIdentifier: String, notificationIdentifier: String) async {
        switch actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification
            logger.info("User tapped notification")
            // TODO: Navigate to relevant screen

        case "COMPLETE_WORKOUT":
            logger.info("User marked workout complete")
            // TODO: Mark workout as complete

        case "SNOOZE_WORKOUT":
            logger.info("User snoozed workout")
            // Schedule reminder for 1 hour later
            let snoozeDate = Date().addingTimeInterval(3600)
            try? await scheduleWorkoutReminder(
                title: "Workout Reminder",
                body: "Don't forget to log your workout!",
                date: snoozeDate,
                identifier: "\(notificationIdentifier)-snoozed"
            )

        case "VIEW_STREAK":
            logger.info("User wants to view streak")
            // TODO: Navigate to progress/stats screen

        default:
            break
        }
    }
}

// MARK: - Preview

extension NotificationManager {
    static var preview: NotificationManager {
        NotificationManager(
            apiClient: APIClient(
                baseURL: URL(string: "https://kinexfit.com")!,
                tokenStore: InMemoryTokenStore()
            )
        )
    }
}
