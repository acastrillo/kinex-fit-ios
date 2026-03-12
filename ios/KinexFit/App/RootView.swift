import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var authViewModel: AuthViewModel
    @State private var showOnboarding = false
    @AppStorage("hasSeenFeatureShowcase") private var hasSeenFeatureShowcase: Bool = false
    @AppStorage("hasSeenImportOnboarding") private var hasSeenImportOnboarding: Bool = false

    init(environment: AppEnvironment) {
        _authViewModel = StateObject(wrappedValue: AuthViewModel(
            authService: environment.authService,
            userRepository: environment.userRepository,
            workoutRepository: environment.workoutRepository,
            googleSignInManager: environment.googleSignInManager,
            facebookSignInManager: environment.facebookSignInManager,
            emailPasswordAuthService: environment.emailPasswordAuthService
        ))
    }

    var body: some View {
        Group {
            switch authViewModel.authState {
            case .unknown:
                SplashView()

            case .signedOut:
                if appState.isGuestMode {
                    // Legacy guest mode path — kept for backwards compatibility.
                    MainTabView(authViewModel: authViewModel)
                        .environmentObject(appState.guestModeManager)
                } else if !hasSeenFeatureShowcase {
                    // First launch or just logged out — always show feature showcase.
                    FeatureShowcaseView {
                        hasSeenFeatureShowcase = true
                    }
                } else {
                    SignInView(viewModel: authViewModel)
                }

            case .signedIn:
                if showOnboarding {
                    OnboardingCoordinator(onComplete: {
                        showOnboarding = false
                    })
                } else {
                    MainTabView(authViewModel: authViewModel)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authViewModel.authState)
        .task {
            await authViewModel.checkExistingSession()
        }
        .onChange(of: authViewModel.authState) { oldState, newState in
            if case .signedIn(let user) = newState {
                // User signed in — exit guest mode, reset guest counters.
                appState.exitGuestMode()

                // Skip old 8-step onboarding if:
                //   (a) user already completed it, OR
                //   (b) user went through import-first onboarding as a guest
                let didImportFirstOnboarding = UserDefaults.standard.bool(forKey: "hasSeenImportOnboarding")
                showOnboarding = !user.onboardingCompleted && !didImportFirstOnboarding
            } else if case .signedOut = newState, case .signedIn = oldState {
                // User just logged out — reset feature showcase so it always
                // appears as the first screen on the next sign-in attempt.
                hasSeenFeatureShowcase = false
            }
        }
    }
}

// MARK: - Splash View

private struct SplashView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(AppTheme.accent)

            Text("Kinex Fit")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.primaryText)

            ProgressView()
                .tint(AppTheme.accent)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }
}

// MARK: - Preview

#Preview("Signed Out") {
    RootView(environment: .preview)
        .environmentObject(AppState(environment: .preview))
}

#Preview("Signed In") {
    let env = AppEnvironment.preview
    return MainTabView(authViewModel: .previewSignedIn)
        .environmentObject(AppState(environment: env))
}
