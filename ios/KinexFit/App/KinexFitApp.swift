import SwiftUI
import GoogleSignIn
import FacebookCore

@main
struct KinexFitApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState(environment: .live)

    var body: some Scene {
        WindowGroup {
            RootView(environment: appState.environment)
                .environmentObject(appState)
                .environmentObject(appState.environment.notificationManager)
                .onOpenURL { url in
                    // Handle OAuth URL callbacks

                    // Try Google Sign In first
                    if GIDSignIn.sharedInstance.handle(url) {
                        return
                    }

                    // Try Facebook
                    ApplicationDelegate.shared.application(
                        UIApplication.shared,
                        open: url,
                        sourceApplication: nil,
                        annotation: [UIApplication.OpenURLOptionsKey.annotation]
                    )
                }
        }
    }
}
