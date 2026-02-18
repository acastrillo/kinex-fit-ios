import Foundation
import GoogleSignIn
import OSLog
import UIKit

private let logger = Logger(subsystem: "com.kinex.fit", category: "GoogleSignInManager")

/// Result from successful Google Sign In
struct GoogleSignInResult {
    let idToken: String
    let email: String
    let firstName: String?
    let lastName: String?
}

/// Errors that can occur during Google Sign In
enum GoogleSignInError: Error, LocalizedError {
    case missingClientID
    case missingURLScheme
    case noRootViewController
    case noIDToken
    case userCancelled
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "Google Sign In is not configured correctly"
        case .missingURLScheme:
            return "Google Sign In callback URL scheme is missing"
        case .noRootViewController:
            return "Unable to present Google Sign In"
        case .noIDToken:
            return "Failed to obtain authentication token from Google"
        case .userCancelled:
            return nil // Don't show error for user cancellation
        case .unknown(let error):
            return "Google Sign In failed: \(error.localizedDescription)"
        }
    }
}

/// Manager for Google Sign In operations
@MainActor
final class GoogleSignInManager {

    /// Sign in with Google
    /// - Returns: GoogleSignInResult containing ID token and user info
    /// - Throws: GoogleSignInError if sign in fails
    func signIn() async throws -> GoogleSignInResult {
        logger.info("Starting Google Sign In")

        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
              !clientID.isEmpty else {
            logger.error("Missing GIDClientID in Info.plist")
            throw GoogleSignInError.missingClientID
        }

        guard hasGoogleURLScheme(clientID: clientID) else {
            logger.error("Missing Google URL scheme for client ID")
            throw GoogleSignInError.missingURLScheme
        }

        if GIDSignIn.sharedInstance.configuration == nil {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }

        // Get the root view controller
        guard let rootViewController = getRootViewController() else {
            logger.error("No root view controller found")
            throw GoogleSignInError.noRootViewController
        }

        do {
            // Initiate Google Sign In (must be on main thread)
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: rootViewController
            )

            // Extract ID token
            guard let idToken = result.user.idToken?.tokenString else {
                logger.error("No ID token in Google Sign In result")
                throw GoogleSignInError.noIDToken
            }

            let email = result.user.profile?.email ?? ""
            let firstName = result.user.profile?.givenName
            let lastName = result.user.profile?.familyName

            logger.info("Google Sign In successful for: \(email.isEmpty ? "unknown" : email)")

            return GoogleSignInResult(
                idToken: idToken,
                email: email,
                firstName: firstName,
                lastName: lastName
            )
        } catch let error as GIDSignInError {
            // Handle specific Google Sign In errors
            if error.code == .canceled {
                logger.info("User cancelled Google Sign In")
                throw GoogleSignInError.userCancelled
            }
            logger.error("Google Sign In error (\(error.code.rawValue)): \(error.localizedDescription)")
            throw GoogleSignInError.unknown(error)
        } catch {
            logger.error("Unexpected Google Sign In error: \(error.localizedDescription)")
            throw GoogleSignInError.unknown(error)
        }
    }

    /// Sign out from Google
    func signOut() {
        logger.info("Signing out from Google")
        GIDSignIn.sharedInstance.signOut()
    }

    /// Restore previous sign-in if available
    /// - Returns: GoogleSignInResult if restoration successful, nil otherwise
    func restorePreviousSignIn() async -> GoogleSignInResult? {
        logger.info("Attempting to restore previous Google Sign In")

        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()

            guard let idToken = user.idToken?.tokenString else {
                logger.warning("Restored user has no ID token")
                return nil
            }

            let email = user.profile?.email ?? ""
            logger.info("Restored previous Google Sign In for: \(email.isEmpty ? "unknown" : email)")

            return GoogleSignInResult(
                idToken: idToken,
                email: email,
                firstName: user.profile?.givenName,
                lastName: user.profile?.familyName
            )
        } catch {
            logger.info("No previous Google Sign In to restore")
            return nil
        }
    }

    // MARK: - Private Helpers

    private func getRootViewController() -> UIViewController? {
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let rootViewController = windowScenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
            ?? windowScenes.first?.windows.first?.rootViewController

        return topMostViewController(from: rootViewController)
    }

    private func topMostViewController(from viewController: UIViewController?) -> UIViewController? {
        guard let viewController else { return nil }

        if let navigationController = viewController as? UINavigationController {
            return topMostViewController(from: navigationController.visibleViewController ?? navigationController.topViewController)
        }

        if let tabBarController = viewController as? UITabBarController {
            return topMostViewController(from: tabBarController.selectedViewController)
        }

        if let presentedViewController = viewController.presentedViewController {
            return topMostViewController(from: presentedViewController)
        }

        return viewController
    }

    private func hasGoogleURLScheme(clientID: String) -> Bool {
        let clientIDSuffix = ".apps.googleusercontent.com"
        guard clientID.hasSuffix(clientIDSuffix) else {
            return false
        }

        let clientIDPrefix = String(clientID.dropLast(clientIDSuffix.count))
        let expectedScheme = "com.googleusercontent.apps.\(clientIDPrefix)".lowercased()

        guard let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
            return false
        }

        for urlType in urlTypes {
            guard let schemes = urlType["CFBundleURLSchemes"] as? [String] else {
                continue
            }
            if schemes.contains(where: { $0.lowercased() == expectedScheme }) {
                return true
            }
        }

        return false
    }
}
