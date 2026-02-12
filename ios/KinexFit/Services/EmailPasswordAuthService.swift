import Foundation
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "EmailPasswordAuthService")

/// Errors for password validation
enum PasswordValidationError: String, CaseIterable {
    case tooShort = "At least 8 characters"
    case noLowercase = "One lowercase letter"
    case noUppercase = "One uppercase letter"
    case noNumber = "One number"
    case noSpecialChar = "One special character"

    var isMet: Bool {
        // This will be checked against actual password in validatePassword
        false
    }
}

/// Service for handling email/password authentication
final class EmailPasswordAuthService {
    private let apiClient: APIClient
    private let tokenStore: TokenStore
    private let database: AppDatabase

    init(apiClient: APIClient, tokenStore: TokenStore, database: AppDatabase) {
        self.apiClient = apiClient
        self.tokenStore = tokenStore
        self.database = database
    }

    // MARK: - Sign Up

    /// Sign up a new user with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password (will be validated)
    ///   - firstName: Optional first name
    ///   - lastName: Optional last name
    /// - Returns: User object after successful signup
    /// - Throws: AuthError if signup fails
    func signUp(
        email: String,
        password: String,
        firstName: String?,
        lastName: String?
    ) async throws -> User {
        logger.info("Signing up user with email")

        // Validate password
        let validationErrors = validatePassword(password)
        if !validationErrors.isEmpty {
            logger.warning("Password validation failed: \(validationErrors.count) errors")
            throw AuthError.invalidPassword(validationErrors)
        }

        // Call signup endpoint
        struct SignUpRequest: Encodable {
            let email: String
            let password: String
            let firstName: String?
            let lastName: String?
        }

        struct SignUpResponse: Decodable {
            let success: Bool
            let message: String
        }

        let request = SignUpRequest(
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName
        )

        do {
            let apiRequest = try APIRequest.json(
                path: "/api/auth/signup",
                method: .post,
                body: request
            )

            let _: SignUpResponse = try await apiClient.send(apiRequest)

            logger.info("Signup successful, now signing in")

            // Automatically sign in after successful signup
            return try await signIn(email: email, password: password)
        } catch let error as APIError {
            throw mapAPIError(error)
        } catch {
            logger.error("Signup failed: \(error.localizedDescription)")
            throw AuthError.networkError(error)
        }
    }

    // MARK: - Sign In

    /// Sign in with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    /// - Returns: User object after successful sign in
    /// - Throws: AuthError if sign in fails
    func signIn(email: String, password: String) async throws -> User {
        logger.info("Signing in with email/password")

        struct SignInRequest: Encodable {
            let email: String
            let password: String
        }

        struct SignInResponse: Decodable {
            let accessToken: String
            let refreshToken: String
            let expiresIn: Int
            let tokenType: String
            let isNewUser: Bool
            let user: UserData

            struct UserData: Decodable {
                let id: String
                let email: String
                let firstName: String?
                let lastName: String?
                let subscriptionTier: String
                let onboardingCompleted: Bool
            }
        }

        let request = SignInRequest(email: email, password: password)

        do {
            let apiRequest = try APIRequest.json(
                path: "/api/mobile/auth/signin-credentials",
                method: .post,
                body: request
            )

            let response: SignInResponse = try await apiClient.send(apiRequest)

            // Store tokens
            try tokenStore.setAccessToken(response.accessToken)
            try tokenStore.setRefreshToken(response.refreshToken)

            // Create User object
            let user = User(
                id: response.user.id,
                email: response.user.email,
                firstName: response.user.firstName,
                lastName: response.user.lastName,
                subscriptionTier: SubscriptionTier(rawValue: response.user.subscriptionTier) ?? .free,
                subscriptionStatus: .active,
                scanQuotaUsed: 0,
                aiQuotaUsed: 0,
                onboardingCompleted: response.user.onboardingCompleted,
                updatedAt: Date()
            )

            // Save user to local database
            try await saveUser(user)

            logger.info("Sign in successful")
            return user
        } catch let error as APIError {
            throw mapAPIError(error)
        } catch {
            logger.error("Sign in failed: \(error.localizedDescription)")
            throw AuthError.networkError(error)
        }
    }

    // MARK: - Password Validation

    /// Validate password against requirements
    /// - Parameter password: Password to validate
    /// - Returns: Array of validation errors (empty if valid)
    func validatePassword(_ password: String) -> [PasswordValidationError] {
        var errors: [PasswordValidationError] = []

        if password.count < 8 {
            errors.append(.tooShort)
        }

        if !password.contains(where: { $0.isLowercase }) {
            errors.append(.noLowercase)
        }

        if !password.contains(where: { $0.isUppercase }) {
            errors.append(.noUppercase)
        }

        if !password.contains(where: { $0.isNumber }) {
            errors.append(.noNumber)
        }

        // Check for special characters (anything that's not a letter or number)
        if !password.contains(where: { !$0.isLetter && !$0.isNumber }) {
            errors.append(.noSpecialChar)
        }

        return errors
    }

    /// Check if specific requirement is met
    /// - Parameters:
    ///   - requirement: The requirement to check
    ///   - password: Password to check against
    /// - Returns: True if requirement is met
    func isRequirementMet(_ requirement: PasswordValidationError, in password: String) -> Bool {
        switch requirement {
        case .tooShort:
            return password.count >= 8
        case .noLowercase:
            return password.contains(where: { $0.isLowercase })
        case .noUppercase:
            return password.contains(where: { $0.isUppercase })
        case .noNumber:
            return password.contains(where: { $0.isNumber })
        case .noSpecialChar:
            return password.contains(where: { !$0.isLetter && !$0.isNumber })
        }
    }

    // MARK: - Private Helpers

    private func saveUser(_ user: User) async throws {
        try await database.dbQueue.write { db in
            try user.save(db)
        }
        logger.debug("User saved to local database")
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
