import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static weak var shared: AppState?

    struct WorkoutCardNavigationRequest: Equatable {
        let requestID = UUID()
        let workoutID: String
    }

    enum MainTab: String {
        case home
        case library
        case add
        case stats
        case calendar
    }

    let environment: AppEnvironment

    /// Manages guest mode usage limits (3 saves, 1 AI generation).
    let guestModeManager = GuestModeManager()

    /// True when a user has completed import-first onboarding without signing in.
    @Published var isGuestMode: Bool = false

    /// Service for managing Instagram imports from Share Extension
    let instagramImportService = InstagramImportService()

    /// Service for managing TikTok imports from Share Extension
    let tiktokImportService: TikTokImportService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Instagram Fetch State

    /// Pending Instagram workout from URL fetch (for edit sheet)
    @Published var pendingInstagramWorkout: FetchedWorkout?

    /// Controls visibility of Instagram workout edit sheet
    @Published var showInstagramEditSheet = false

    /// Global tab selection for app-wide routing (e.g., notification actions).
    @Published var selectedMainTab: MainTab = .home

    /// Pending request to open a saved workout in the library card/detail view.
    @Published var pendingWorkoutCardNavigation: WorkoutCardNavigationRequest?

    /// Runtime feature flags fetched from backend app config.
    @Published private(set) var featureFlags: AppFeatureFlags = .default

    init(environment: AppEnvironment) {
        self.environment = environment
        self.tiktokImportService = TikTokImportService(apiClient: environment.apiClient)
        AppState.shared = self

        // Ensure App Group directories exist
        AppGroup.ensureDirectoriesExist()

        environment.featureFlagService.$flags
            .sink { [weak self] flags in
                self?.featureFlags = flags
            }
            .store(in: &cancellables)

        if environment.apiClient.baseURL != AppConfig.previewAPIBaseURL {
            Task { @MainActor in
                await environment.featureFlagService.refresh()
            }
        }
    }

    /// Check for pending imports (call on app activation)
    func checkForPendingImports() {
        instagramImportService.refreshPendingImports()
        tiktokImportService.refreshPendingImports()
    }

    // MARK: - Navigation Helpers

    /// Navigate to Instagram workout edit view
    func navigateToInstagramEdit(_ workout: FetchedWorkout) {
        pendingInstagramWorkout = workout
        showInstagramEditSheet = true
    }

    /// Navigate to a main tab destination.
    func navigateToTab(_ tab: MainTab) {
        selectedMainTab = tab
    }

    /// Navigate to the library tab and open the specified workout card/detail view.
    func navigateToWorkoutCard(workoutID: String) {
        selectedMainTab = .library
        pendingWorkoutCardNavigation = WorkoutCardNavigationRequest(workoutID: workoutID)
    }

    /// Mark a workout card navigation request as handled.
    func completeWorkoutCardNavigation(requestID: UUID) {
        guard pendingWorkoutCardNavigation?.requestID == requestID else { return }
        pendingWorkoutCardNavigation = nil
    }

    // MARK: - Guest Mode

    /// Enter guest mode after completing import-first onboarding without signing in.
    func enterGuestMode() async {
        // Guest mode should always start in the local library tab and should not
        // inherit a stale authenticated workspace from a prior session.
        selectedMainTab = .library
        pendingWorkoutCardNavigation = nil
        pendingInstagramWorkout = nil
        showInstagramEditSheet = false
        await environment.authService.clearSessionLocally()
        isGuestMode = true
    }

    /// Exit guest mode (e.g., user signed in). Resets guest counters.
    func exitGuestMode() {
        isGuestMode = false
        selectedMainTab = .home
        guestModeManager.reset()
    }
}
