import AuthenticationServices
import Combine
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "com.kinex.fit", category: "AuthViewModel")

/// ViewModel managing authentication state and operations
@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var authState: AuthState = .unknown
    @Published private(set) var isLoading = false
    @Published var error: AuthError?

    private let authService: AuthService
    private let userRepository: UserRepository
    private let googleSignInManager: GoogleSignInManager
    private let facebookSignInManager: FacebookSignInManager
    private let emailPasswordAuthService: EmailPasswordAuthService

    #if DEBUG
    /// Enable dev mode to bypass authentication (DEBUG builds only)
    @Published var devModeEnabled: Bool = false
    #endif

    init(authService: AuthService, userRepository: UserRepository, googleSignInManager: GoogleSignInManager, facebookSignInManager: FacebookSignInManager, emailPasswordAuthService: EmailPasswordAuthService) {
        self.authService = authService
        self.userRepository = userRepository
        self.googleSignInManager = googleSignInManager
        self.facebookSignInManager = facebookSignInManager
        self.emailPasswordAuthService = emailPasswordAuthService
    }

    // MARK: - Initialization

    /// Check for existing session on app launch
    func checkExistingSession() async {
        logger.info("Checking existing session")

        #if DEBUG
        // Dev mode bypass - automatically sign in with mock user
        if devModeEnabled {
            logger.info("Dev mode enabled - bypassing authentication")
            authState = .signedIn(User.devModeUser)
            return
        }
        #endif

        if authService.hasValidSession {
            // Try to load user from local database
            do {
                if let user = try await userRepository.getCurrentUser() {
                    authState = .signedIn(user)
                    logger.info("Restored session for user: \(user.id)")
                    return
                }
            } catch {
                logger.error("Failed to load user: \(error.localizedDescription)")
            }

            // Have tokens but no user - try to refresh
            do {
                try await authService.refreshTokens()
                if let user = try await userRepository.getCurrentUser() {
                    authState = .signedIn(user)
                    return
                }
            } catch {
                logger.warning("Token refresh failed: \(error.localizedDescription)")
            }
        }

        authState = .signedOut
    }

    // MARK: - Development Bypass

    #if DEBUG
    /// Bypass authentication for development (DEBUG builds only)
    func bypassAuthForDevelopment() {
        logger.info("Bypassing authentication for development")
        devModeEnabled = true
        authState = .signedIn(User.devModeUser)
    }
    #endif

    // MARK: - Sign In with Apple

    /// Handle Sign in with Apple authorization result
    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        isLoading = true
        error = nil

        defer { isLoading = false }

        switch result {
        case .success(let authorization):
            guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                error = .invalidIdentityToken
                return
            }

            guard let identityTokenData = appleCredential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                error = .invalidIdentityToken
                logger.error("Failed to get identity token from Apple credential")
                return
            }

            // Extract name (only provided on first sign-in)
            let firstName = appleCredential.fullName?.givenName
            let lastName = appleCredential.fullName?.familyName

            logger.info("Received Apple credential, signing in with backend")

            do {
                let user = try await authService.signIn(
                    provider: .apple,
                    identityToken: identityToken,
                    firstName: firstName,
                    lastName: lastName
                )
                authState = .signedIn(user)
                logger.info("Sign in successful")
            } catch let authError as AuthError {
                error = authError
                logger.error("Sign in failed: \(authError.localizedDescription)")
            } catch {
                self.error = .networkError(error)
                logger.error("Sign in failed: \(error.localizedDescription)")
            }

        case .failure(let authError):
            // User cancelled is not an error we need to show
            if let asError = authError as? ASAuthorizationError,
               asError.code == .canceled {
                logger.info("User cancelled Apple sign in")
                return
            }

            error = .providerError(authError.localizedDescription)
            logger.error("Apple sign in failed: \(authError.localizedDescription)")
        }
    }

    // MARK: - Sign In with Google

    /// Handle Google Sign In
    func handleGoogleSignIn() async {
        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            logger.info("Starting Google Sign In")
            let googleResult = try await googleSignInManager.signIn()

            logger.info("Google Sign In successful, authenticating with backend")

            let user = try await authService.signIn(
                provider: .google,
                identityToken: googleResult.idToken,
                firstName: googleResult.firstName,
                lastName: googleResult.lastName
            )

            authState = .signedIn(user)
            logger.info("Google authentication successful")
        } catch let googleError as GoogleSignInError {
            // Don't show error for user cancellation
            if case .userCancelled = googleError {
                logger.info("User cancelled Google Sign In")
                return
            }

            error = .providerError(googleError.localizedDescription ?? "Google Sign In failed")
            logger.error("Google Sign In failed: \(googleError.localizedDescription ?? "unknown")")
        } catch let authError as AuthError {
            error = authError
            logger.error("Backend authentication failed: \(authError.localizedDescription)")
        } catch {
            self.error = .networkError(error)
            logger.error("Google Sign In failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Sign In with Facebook

    /// Handle Facebook Sign In
    func handleFacebookSignIn() async {
        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            logger.info("Starting Facebook Sign In")
            let facebookResult = try await facebookSignInManager.signIn()

            logger.info("Facebook Sign In successful, authenticating with backend")

            let user = try await authService.signIn(
                provider: .facebook,
                identityToken: facebookResult.accessToken,
                firstName: facebookResult.firstName,
                lastName: facebookResult.lastName
            )

            authState = .signedIn(user)
            logger.info("Facebook authentication successful")
        } catch let facebookError as FacebookSignInError {
            // Don't show error for user cancellation
            if case .userCancelled = facebookError {
                logger.info("User cancelled Facebook Sign In")
                return
            }

            error = .providerError(facebookError.localizedDescription ?? "Facebook Sign In failed")
            logger.error("Facebook Sign In failed: \(facebookError.localizedDescription ?? "unknown")")
        } catch let authError as AuthError {
            error = authError
            logger.error("Backend authentication failed: \(authError.localizedDescription)")
        } catch {
            self.error = .networkError(error)
            logger.error("Facebook Sign In failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Email/Password Sign In

    /// Handle email/password sign in
    func handleEmailPasswordSignIn(email: String, password: String) async {
        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            logger.info("Starting email/password sign in")
            let user = try await emailPasswordAuthService.signIn(email: email, password: password)

            authState = .signedIn(user)
            logger.info("Email/password sign in successful")
        } catch let authError as AuthError {
            error = authError
            logger.error("Email/password sign in failed: \(authError.localizedDescription)")
        } catch {
            self.error = .networkError(error)
            logger.error("Email/password sign in failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Email/Password Sign Up

    /// Handle email/password sign up
    func handleEmailPasswordSignUp(
        email: String,
        password: String,
        passwordConfirmation: String,
        firstName: String?,
        lastName: String?
    ) async {
        isLoading = true
        error = nil

        defer { isLoading = false }

        // Validate passwords match
        guard password == passwordConfirmation else {
            error = .passwordsDoNotMatch
            logger.warning("Passwords do not match")
            return
        }

        do {
            logger.info("Starting email/password sign up")
            let user = try await emailPasswordAuthService.signUp(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName
            )

            authState = .signedIn(user)
            logger.info("Email/password sign up successful")
        } catch let authError as AuthError {
            error = authError
            logger.error("Email/password sign up failed: \(authError.localizedDescription)")
        } catch {
            self.error = .networkError(error)
            logger.error("Email/password sign up failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        isLoading = true
        defer { isLoading = false }

        // Sign out from OAuth providers
        googleSignInManager.signOut()
        facebookSignInManager.signOut()

        await authService.signOut()
        authState = .signedOut
        logger.info("User signed out")
    }

    // MARK: - Error Handling

    func clearError() {
        error = nil
    }
}

// MARK: - Preview Support

extension AuthViewModel {
    static var preview: AuthViewModel {
        AuthViewModel(
            authService: AppEnvironment.preview.authService,
            userRepository: AppEnvironment.preview.userRepository,
            googleSignInManager: GoogleSignInManager(),
            facebookSignInManager: FacebookSignInManager(),
            emailPasswordAuthService: AppEnvironment.preview.emailPasswordAuthService
        )
    }

    static var previewSignedIn: AuthViewModel {
        let vm = preview
        vm.authState = .signedIn(User.preview)
        return vm
    }
}

// MARK: - Preview User

extension User {
    static var preview: User {
        User(
            id: "preview-user-id",
            email: "user@example.com",
            firstName: "John",
            lastName: "Doe",
            subscriptionTier: .free,
            subscriptionStatus: .active,
            scanQuotaUsed: 1,
            aiQuotaUsed: 0,
            onboardingCompleted: true,
            updatedAt: Date()
        )
    }

    #if DEBUG
    /// Mock user for development mode bypass
    static var devModeUser: User {
        User(
            id: "dev-mode-user-id",
            email: "dev@kinexfit.local",
            firstName: "Dev",
            lastName: "User",
            subscriptionTier: .free,
            subscriptionStatus: .active,
            scanQuotaUsed: 0,
            aiQuotaUsed: 0,
            onboardingCompleted: false,
            updatedAt: Date()
        )
    }
    #endif
}
