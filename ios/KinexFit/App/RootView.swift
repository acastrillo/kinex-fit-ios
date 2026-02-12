import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var authViewModel: AuthViewModel
    @State private var showOnboarding = false

    init(environment: AppEnvironment) {
        _authViewModel = StateObject(wrappedValue: AuthViewModel(
            authService: environment.authService,
            userRepository: environment.userRepository,
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
                SignInView(viewModel: authViewModel)

            case .signedIn(let user):
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
        .onChange(of: authViewModel.authState) { _, newState in
            // Check if onboarding is needed when user signs in
            if case .signedIn(let user) = newState {
                showOnboarding = !user.onboardingCompleted
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
