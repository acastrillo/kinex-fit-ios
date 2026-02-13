import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    let environment: AppEnvironment

    /// Service for managing Instagram imports from Share Extension
    let instagramImportService = InstagramImportService()

    // MARK: - Instagram Fetch State

    /// Pending Instagram workout from URL fetch (for edit sheet)
    @Published var pendingInstagramWorkout: FetchedWorkout?

    /// Controls visibility of Instagram workout edit sheet
    @Published var showInstagramEditSheet = false

    init(environment: AppEnvironment = .live) {
        self.environment = environment

        // Ensure App Group directories exist
        AppGroup.ensureDirectoriesExist()
    }

    /// Check for pending imports (call on app activation)
    func checkForPendingImports() {
        instagramImportService.refreshPendingImports()
    }

    // MARK: - Navigation Helpers

    /// Navigate to Instagram workout edit view
    func navigateToInstagramEdit(_ workout: FetchedWorkout) {
        pendingInstagramWorkout = workout
        showInstagramEditSheet = true
    }
}
