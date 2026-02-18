import Foundation
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "AuthService")

/// Service responsible for authentication operations
/// Handles sign-in, token refresh, and sign-out with the backend API
final class AuthService {
    private let apiClient: APIClient
    private let tokenStore: TokenStore
    private let database: AppDatabase

    init(apiClient: APIClient, tokenStore: TokenStore, database: AppDatabase) {
        self.apiClient = apiClient
        self.tokenStore = tokenStore
        self.database = database
    }

    // MARK: - Sign In

    /// Sign in with an identity token from a provider (Apple, Google, Facebook)
    /// - Parameters:
    ///   - provider: The authentication provider
    ///   - identityToken: The identity token from the provider
    ///   - firstName: Optional first name (provided by Apple on first sign-in)
    ///   - lastName: Optional last name (provided by Apple on first sign-in)
    /// - Returns: The authenticated user
    func signIn(
        provider: AuthProvider,
        identityToken: String,
        firstName: String? = nil,
        lastName: String? = nil
    ) async throws -> User {
        logger.info("Signing in with provider: \(provider.rawValue)")

        let request = SignInRequest(
            provider: provider,
            identityToken: identityToken,
            firstName: firstName,
            lastName: lastName
        )

        do {
            let apiRequest = try APIRequest.json(
                path: "/api/mobile/auth/signin",
                method: .post,
                body: request
            )

            let response: SignInResponse = try await apiClient.send(apiRequest)

            // Store tokens
            try tokenStore.setAccessToken(response.accessToken)
            try tokenStore.setRefreshToken(response.refreshToken)

            // Convert to User model and save to local database
            let user = response.user.toUser()
            try await saveUser(user)

            logger.info("Sign-in successful for user: \(user.id)")
            return user
        } catch let error as APIError {
            throw mapAPIError(error)
        } catch {
            logger.error("Sign-in failed: \(error.localizedDescription)")
            throw AuthError.networkError(error)
        }
    }

    // MARK: - Token Refresh

    /// Refresh the access token using the stored refresh token
    /// - Returns: True if refresh was successful
    @discardableResult
    func refreshTokens() async throws -> Bool {
        guard let refreshToken = tokenStore.refreshToken else {
            logger.warning("No refresh token available")
            throw AuthError.sessionInvalid
        }

        logger.info("Refreshing tokens")

        let request = RefreshTokenRequest(refreshToken: refreshToken)

        do {
            let apiRequest = try APIRequest.json(
                path: "/api/mobile/auth/refresh",
                method: .post,
                body: request
            )

            let response: RefreshTokenResponse = try await apiClient.send(apiRequest)

            // Update stored tokens
            try tokenStore.setAccessToken(response.accessToken)
            try tokenStore.setRefreshToken(response.refreshToken)

            logger.info("Token refresh successful")
            return true
        } catch let error as APIError {
            if case .httpStatus(let code) = error, code == 401 {
                // Refresh token is invalid, clear tokens
                try? tokenStore.clearAll()
                throw AuthError.sessionInvalid
            }
            throw mapAPIError(error)
        } catch {
            logger.error("Token refresh failed: \(error.localizedDescription)")
            throw AuthError.networkError(error)
        }
    }

    // MARK: - Sign Out

    /// Sign out the current user
    /// Clears local tokens and notifies the backend
    func signOut() async {
        logger.info("Signing out")

        // Notify backend (best effort, don't fail if this errors)
        if let refreshToken = tokenStore.refreshToken {
            do {
                let request = SignOutRequest(refreshToken: refreshToken)
                let apiRequest = try APIRequest.json(
                    path: "/api/mobile/auth/signout",
                    method: .post,
                    body: request
                )
                _ = try await apiClient.send(apiRequest)
            } catch {
                logger.warning("Backend signout failed: \(error.localizedDescription)")
            }
        }

        // Clear local state
        do {
            try tokenStore.clearAll()
            try await clearLocalUser()
            logger.info("Sign-out complete")
        } catch {
            logger.error("Failed to clear local state: \(error.localizedDescription)")
        }
    }

    // MARK: - Session Check

    /// Check if the user has a valid session
    var hasValidSession: Bool {
        tokenStore.accessToken != nil
    }

    /// Get the current user from local storage
    func getCurrentUser() async throws -> User? {
        try await database.dbQueue.read { db in
            try User.fetchOne(db)
        }
    }

    // MARK: - Private Helpers

    private func saveUser(_ user: User) async throws {
        try await database.dbQueue.write { db in
            try user.save(db)
        }
        logger.debug("User saved to local database")
    }

    private func clearLocalUser() async throws {
        try await database.dbQueue.write { db in
            try User.deleteAll(db)
        }
        logger.debug("Local user data cleared")
    }

    private func mapAPIError(_ error: APIError) -> AuthError {
        switch error {
        case .httpStatus(401):
            return .invalidIdentityToken
        case .httpStatus(429):
            return .rateLimited(retryAfter: 60)
        case .httpStatus(let code) where code >= 500:
            return .serverError("Server error (\(code))")
        case .decoding:
            return .serverError("Invalid response from server")
        default:
            return .unknown
        }
    }
}
