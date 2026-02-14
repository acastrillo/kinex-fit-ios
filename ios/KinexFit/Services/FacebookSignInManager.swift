import Foundation
import FacebookLogin
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "FacebookSignInManager")

/// Result from successful Facebook Sign In
struct FacebookSignInResult {
    let accessToken: String
    let email: String
    let firstName: String?
    let lastName: String?
}

/// Errors that can occur during Facebook Sign In
enum FacebookSignInError: Error, LocalizedError {
    case noRootViewController
    case noAccessToken
    case noEmailPermission
    case userCancelled
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .noRootViewController:
            return "Unable to present Facebook Sign In"
        case .noAccessToken:
            return "Failed to obtain authentication token from Facebook"
        case .noEmailPermission:
            return "Email permission is required to sign in with Facebook"
        case .userCancelled:
            return nil // Don't show error for user cancellation
        case .unknown(let error):
            return "Facebook Sign In failed: \(error.localizedDescription)"
        }
    }
}

/// Manager for Facebook Sign In operations
@MainActor
final class FacebookSignInManager {
    private let loginManager = LoginManager()

    /// Sign in with Facebook
    /// - Returns: FacebookSignInResult containing access token and user info
    /// - Throws: FacebookSignInError if sign in fails
    func signIn() async throws -> FacebookSignInResult {
        logger.info("Starting Facebook Sign In")

        // Get the root view controller (must be on main thread)
        guard let rootViewController = getRootViewController() else {
            logger.error("No root view controller found")
            throw FacebookSignInError.noRootViewController
        }

        return try await withCheckedThrowingContinuation { continuation in
            loginManager.logIn(
                permissions: ["email", "public_profile"],
                from: rootViewController
            ) { result, error in
                if let error = error {
                    logger.error("Facebook login error: \(error.localizedDescription)")
                    continuation.resume(throwing: FacebookSignInError.unknown(error))
                    return
                }

                guard let result = result else {
                    logger.error("Facebook login returned nil result")
                    continuation.resume(throwing: FacebookSignInError.unknown(NSError(
                        domain: "FacebookSignIn",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "No result from Facebook"]
                    )))
                    return
                }

                // Check if user cancelled
                if result.isCancelled {
                    logger.info("User cancelled Facebook Sign In")
                    continuation.resume(throwing: FacebookSignInError.userCancelled)
                    return
                }

                // Get access token
                guard let accessToken = result.token?.tokenString else {
                    logger.error("No access token in Facebook result")
                    continuation.resume(throwing: FacebookSignInError.noAccessToken)
                    return
                }

                // Fetch user profile
                Task {
                    do {
                        let profile = try await self.fetchUserProfile(accessToken: accessToken)
                        continuation.resume(returning: profile)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    /// Sign out from Facebook
    func signOut() {
        logger.info("Signing out from Facebook")
        loginManager.logOut()
    }

    // MARK: - Private Helpers

    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return nil
        }

        return windowScene.windows.first?.rootViewController
    }

    nonisolated private func fetchUserProfile(accessToken: String) async throws -> FacebookSignInResult {
        logger.info("Fetching Facebook user profile")

        let urlString = "https://graph.facebook.com/me?fields=id,email,first_name,last_name&access_token=\(accessToken)"

        guard let url = URL(string: urlString) else {
            throw FacebookSignInError.unknown(NSError(
                domain: "FacebookSignIn",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid Facebook Graph API URL"]
            ))
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            logger.error("Facebook Graph API request failed")
            throw FacebookSignInError.unknown(NSError(
                domain: "FacebookSignIn",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Facebook API request failed"]
            ))
        }

        struct GraphAPIResponse: Decodable {
            let id: String
            let email: String?
            let first_name: String?
            let last_name: String?
        }

        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(GraphAPIResponse.self, from: data)

        guard let email = apiResponse.email else {
            logger.error("No email in Facebook profile")
            throw FacebookSignInError.noEmailPermission
        }

        logger.info("Facebook profile fetched successfully")

        return FacebookSignInResult(
            accessToken: accessToken,
            email: email,
            firstName: apiResponse.first_name,
            lastName: apiResponse.last_name
        )
    }
}
