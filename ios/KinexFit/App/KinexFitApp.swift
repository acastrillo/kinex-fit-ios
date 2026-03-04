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
