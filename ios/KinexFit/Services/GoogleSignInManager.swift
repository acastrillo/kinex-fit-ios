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
    case missingServerClientID
    case invalidServerClientID
    case idTokenAudienceMismatch(expected: String, actual: String)
    case missingURLScheme
    case noRootViewController
    case noIDToken
    case userCancelled
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "Google Sign In is not configured correctly"
        case .missingServerClientID:
            return "Google Sign In backend auth is not configured. Set GIDServerClientID to your Web client ID."
        case .invalidServerClientID:
            return "Google Sign In is misconfigured. GIDServerClientID must be a different Web client ID, not the iOS GIDClientID."
        case .idTokenAudienceMismatch(let expected, let actual):
            return "Google token audience mismatch. Expected \(expected), got \(actual)."
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
    nonisolated static func configureSharedInstanceForLaunch() throws {
        let clientIDs = try resolveClientIDs(requireServerClientID: false)
        GIDSignIn.sharedInstance.configuration = buildConfiguration(clientIDs: clientIDs)
    }

    /// Sign in with Google
    /// - Returns: GoogleSignInResult containing ID token and user info
    /// - Throws: GoogleSignInError if sign in fails
    func signIn() async throws -> GoogleSignInResult {
        logger.info("Starting Google Sign In")

        let clientIDs: (clientID: String, serverClientID: String?)
        do {
            clientIDs = try Self.resolveClientIDs(requireServerClientID: true)
            GIDSignIn.sharedInstance.configuration = Self.buildConfiguration(clientIDs: clientIDs)
        } catch let configError as GoogleSignInError {
            logger.error("Google Sign In configuration error: \(configError.localizedDescription, privacy: .public)")
            throw configError
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

            try Self.logAndValidateIDTokenClaims(idToken, expectedAudience: clientIDs.serverClientID)

            let email = result.user.profile?.email ?? ""
            let firstName = result.user.profile?.givenName
            let lastName = result.user.profile?.familyName

            logger.info("Google Sign In successful")

            return GoogleSignInResult(
                idToken: idToken,
                email: email,
                firstName: firstName,
                lastName: lastName
            )
        } catch let error as GoogleSignInError {
            throw error
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

        let clientIDs: (clientID: String, serverClientID: String?)
        do {
            clientIDs = try Self.resolveClientIDs(requireServerClientID: true)
            GIDSignIn.sharedInstance.configuration = Self.buildConfiguration(clientIDs: clientIDs)
        } catch let configError as GoogleSignInError {
            logger.error("Google Sign In restore configuration error: \(configError.localizedDescription, privacy: .public)")
            return nil
        } catch {
            logger.error("Unexpected Google Sign In restore configuration error: \(error.localizedDescription)")
            return nil
        }

        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()

            guard let idToken = user.idToken?.tokenString else {
                logger.warning("Restored user has no ID token")
                return nil
            }

            try Self.logAndValidateIDTokenClaims(idToken, expectedAudience: clientIDs.serverClientID)

            let email = user.profile?.email ?? ""
            logger.info("Restored previous Google Sign In")

            return GoogleSignInResult(
                idToken: idToken,
                email: email,
                firstName: user.profile?.givenName,
                lastName: user.profile?.familyName
            )
        } catch {
            logger.info("No previous Google Sign In to restore or restore token invalid")
            return nil
        }
    }

    // MARK: - Private Helpers

    nonisolated private static func resolveClientIDs(requireServerClientID: Bool) throws -> (clientID: String, serverClientID: String?) {
        guard let rawClientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else {
            throw GoogleSignInError.missingClientID
        }

        let clientID = rawClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientID.isEmpty else {
            throw GoogleSignInError.missingClientID
        }

        guard hasGoogleURLScheme(clientID: clientID) else {
            throw GoogleSignInError.missingURLScheme
        }

        let rawServerClientID = Bundle.main.object(forInfoDictionaryKey: "GIDServerClientID") as? String
        let serverClientID = rawServerClientID?.trimmingCharacters(in: .whitespacesAndNewlines)

        if requireServerClientID {
            guard let serverClientID, !serverClientID.isEmpty else {
                throw GoogleSignInError.missingServerClientID
            }
            guard serverClientID != clientID else {
                throw GoogleSignInError.invalidServerClientID
            }
            return (clientID: clientID, serverClientID: serverClientID)
        }

        if let serverClientID, !serverClientID.isEmpty {
            guard serverClientID != clientID else {
                throw GoogleSignInError.invalidServerClientID
            }
            return (clientID: clientID, serverClientID: serverClientID)
        }

        return (clientID: clientID, serverClientID: nil)
    }

    nonisolated private static func buildConfiguration(clientIDs: (clientID: String, serverClientID: String?)) -> GIDConfiguration {
        if let serverClientID = clientIDs.serverClientID {
            return GIDConfiguration(clientID: clientIDs.clientID, serverClientID: serverClientID)
        }
        return GIDConfiguration(clientID: clientIDs.clientID)
    }

    nonisolated private static func logAndValidateIDTokenClaims(_ idToken: String, expectedAudience: String?) throws {
        guard let claims = decodeJWTClaims(idToken) else {
            logger.warning("Failed to decode Google ID token claims")
            return
        }

        let iss = claims["iss"] as? String ?? "unknown"
        let aud = claims["aud"] as? String ?? "unknown"
        let azp = claims["azp"] as? String ?? "unknown"
        let exp = claims["exp"] as? NSNumber
        let iat = claims["iat"] as? NSNumber
        let hasEmail = claims["email"] != nil
        let expected = expectedAudience ?? "none"

        logger.info("Google ID token claims: iss=\(iss, privacy: .public) aud=\(aud, privacy: .public) expectedAud=\(expected, privacy: .public) azp=\(azp, privacy: .public) exp=\(exp?.stringValue ?? "unknown", privacy: .public) iat=\(iat?.stringValue ?? "unknown", privacy: .public) hasEmail=\(hasEmail, privacy: .public)")

        if let expectedAudience {
            guard aud == expectedAudience else {
                throw GoogleSignInError.idTokenAudienceMismatch(expected: expectedAudience, actual: aud)
            }
        }

        if let exp, exp.doubleValue < Date().timeIntervalSince1970 {
            logger.warning("Google ID token appears expired before backend call")
        }
    }

    nonisolated private static func decodeJWTClaims(_ token: String) -> [String: Any]? {
        let segments = token.split(separator: ".")
        guard segments.count >= 2 else { return nil }
        guard let payload = decodeBase64URL(String(segments[1])) else { return nil }
        return try? JSONSerialization.jsonObject(with: payload) as? [String: Any]
    }

    nonisolated private static func decodeBase64URL(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = 4 - (base64.count % 4)
        if padding < 4 {
            base64.append(String(repeating: "=", count: padding))
        }
        return Data(base64Encoded: base64)
    }

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

    nonisolated private static func hasGoogleURLScheme(clientID: String) -> Bool {
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
