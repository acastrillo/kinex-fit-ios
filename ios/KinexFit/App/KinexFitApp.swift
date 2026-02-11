import SwiftUI

@main
struct KinexFitApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView(environment: appState.environment)
                .environmentObject(appState)
                .environmentObject(appState.environment.notificationManager)
        }
    }
}
