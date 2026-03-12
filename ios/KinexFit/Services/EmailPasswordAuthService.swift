import Foundation
import GRDB
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
    private enum RequestContext {
        case signIn
        case signUp

        var unavailableMessage: String {
            switch self {
            case .signIn:
                return "Email/password sign in is temporarily unavailable on mobile. Please use Apple, Google, or Facebook."
            case .signUp:
                return "Email/password sign up is temporarily unavailable on mobile. Please use Apple, Google, or Facebook."
            }
        }
    }

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
                path: "/api/mobile/auth/signup",
                method: .post,
                body: request
            )

            let _: SignUpResponse = try await apiClient.send(apiRequest)

            logger.info("Signup successful, now signing in")

            // Automatically sign in after successful signup
            return try await signIn(email: email, password: password)
        } catch let error as APIError {
            throw mapAPIError(error, context: .signUp)
        } catch let error as AuthError {
            // Preserve domain-specific auth errors from automatic sign-in
            throw error
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
            let tier = SubscriptionTier(rawValue: response.user.subscriptionTier) ?? .free
            let user = User(
                id: response.user.id,
                email: response.user.email,
                firstName: response.user.firstName,
                lastName: response.user.lastName,
                subscriptionTier: tier,
                subscriptionStatus: .active,
                scanQuotaUsed: 0,
                scanQuotaLimit: tier.defaultScanLimit,
                aiQuotaUsed: 0,
                aiQuotaLimit: tier.defaultAILimit,
                onboardingCompleted: response.user.onboardingCompleted,
                updatedAt: Date()
            )

            if try await shouldResetLocalData(for: user.id) {
                try await clearUserScopedData()
                logger.info("Cleared local user-scoped data due to account switch")
            }

            // Save user to local database
            try await saveUser(user)

            logger.info("Sign in successful")
            return user
        } catch let error as APIError {
            throw mapAPIError(error, context: .signIn)
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
            _ = try User.deleteAll(db)
            try user.save(db)
        }
        logger.debug("User saved to local database")
    }

    private func shouldResetLocalData(for incomingUserID: String) async throws -> Bool {
        try await database.dbQueue.read { db in
            let existingUserID = try String.fetchOne(db, sql: "SELECT id FROM users LIMIT 1")
            guard let existingUserID else { return false }
            return existingUserID != incomingUserID
        }
    }

    private func clearUserScopedData() async throws {
        try await database.dbQueue.write { db in
            _ = try Workout.deleteAll(db)
            try db.execute(sql: "DELETE FROM body_metrics")
            try db.execute(sql: "DELETE FROM sync_queue")
        }
    }

    private func mapAPIError(_ error: APIError, context: RequestContext) -> AuthError {
        if case .httpStatus(let code, let data) = error {
            if let backendError = parseBackendError(from: data) {
                switch backendError.code?.uppercased() {
                case "EMAIL_EXISTS":
                    return .emailAlreadyExists
                case "WEAK_PASSWORD":
                    return .weakPassword
                default:
                    break
                }

                if let message = backendError.message?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !message.isEmpty,
                   code != 404 {
                    return .serverError(message)
                }
            }
        }

        switch error {
        case .httpStatus(400, _):
            return .serverError("Invalid request. Please check your information and try again.")
        case .httpStatus(401, _):
            return .invalidIdentityToken
        case .httpStatus(403, _):
            return .emailNotVerified
        case .httpStatus(404, _):
            return .serverError(context.unavailableMessage)
        case .httpStatus(429, _):
            return .rateLimited(retryAfter: 60)
        case .httpStatus(409, _):
            return .emailAlreadyExists
        case .httpStatus(let code, _) where code >= 500:
            return .serverError("Server error (\(code))")
        case .decoding:
            return .serverError("Invalid response from server")
        default:
            return .unknown
        }
    }

    private func parseBackendError(from data: Data?) -> APIErrorResponse? {
        guard let data, !data.isEmpty else { return nil }
        return try? JSONCoding.apiDecoder().decode(APIErrorResponse.self, from: data)
    }
}
