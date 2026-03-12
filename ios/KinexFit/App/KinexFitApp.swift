import SwiftUI
import UIKit

@main
struct KinexFitApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState(environment: .live)

    var body: some Scene {
        WindowGroup {
            RootView(environment: appState.environment)
                .environmentObject(appState)
                .environmentObject(appState.environment.notificationManager)
                .appDarkTheme()
                .task {
                    // Warm up the exercise library matcher on a background thread so its
                    // first access (parsing OCR results, workout detail view) is instant.
                    Task.detached(priority: .utility) {
                        _ = FreeExerciseDBLoader.sharedMatcher
                    }
                }
                .onOpenURL { url in
                    if appDelegate.handleOAuthCallback(url: url) {
                        return
                    }
                    NotificationCenter.default.post(name: .subscriptionDeepLinkReceived, object: url)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    if appState.featureFlags.shareExtensionImportEnabled {
                        appState.checkForPendingImports()
                    }
                }
        }
    }
}

extension Notification.Name {
    static let subscriptionDeepLinkReceived = Notification.Name("com.kinex.fit.subscriptionDeepLinkReceived")
}
