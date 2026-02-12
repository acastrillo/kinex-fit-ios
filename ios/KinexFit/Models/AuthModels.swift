import Foundation

// MARK: - Auth Provider

enum AuthProvider: String, Codable {
    case apple
    case google
    case facebook
}

// MARK: - Sign In Request/Response

struct SignInRequest: Encodable {
    let provider: AuthProvider
    let identityToken: String
    let firstName: String?
    let lastName: String?

    init(provider: AuthProvider, identityToken: String, firstName: String? = nil, lastName: String? = nil) {
        self.provider = provider
        self.identityToken = identityToken
        self.firstName = firstName
        self.lastName = lastName
    }
}

struct SignInResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
    let user: UserResponse
    let isNewUser: Bool

    struct UserResponse: Decodable {
        let id: String
        let email: String
        let firstName: String?
        let lastName: String?
        let subscriptionTier: String
        let onboardingCompleted: Bool

        func toUser() -> User {
            User(
                id: id,
                email: email,
                firstName: firstName,
                lastName: lastName,
                subscriptionTier: SubscriptionTier(rawValue: subscriptionTier) ?? .free,
                subscriptionStatus: .active,
                scanQuotaUsed: 0,
                aiQuotaUsed: 0,
                onboardingCompleted: onboardingCompleted,
                updatedAt: Date()
            )
        }
    }
}

// MARK: - Token Refresh Request/Response

struct RefreshTokenRequest: Encodable {
    let refreshToken: String
}

struct RefreshTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
}

// MARK: - Sign Out Request

struct SignOutRequest: Encodable {
    let refreshToken: String
}

// MARK: - API Error Response

struct APIErrorResponse: Decodable {
    let error: String
    let message: String?
    let code: String?
    let retryAfter: Int?
}

// MARK: - Auth State

enum AuthState: Equatable {
    case unknown
    case signedOut
    case signedIn(User)

    var isSignedIn: Bool {
        if case .signedIn = self {
            return true
        }
        return false
    }

    var user: User? {
        if case .signedIn(let user) = self {
            return user
        }
        return nil
    }
}

// MARK: - Auth Error

enum AuthError: Error, LocalizedError {
    case invalidIdentityToken
    case providerError(String)
    case networkError(Error)
    case tokenExpired
    case sessionInvalid
    case rateLimited(retryAfter: Int)
    case serverError(String)
    case unknown

    // Email/Password specific errors
    case invalidPassword([PasswordValidationError])
    case passwordsDoNotMatch
    case emailAlreadyExists
    case weakPassword
    case emailNotVerified
    case accountDisabled
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .invalidIdentityToken:
            return "Invalid authentication token"
        case .providerError(let message):
            return message
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .tokenExpired:
            return "Your session has expired. Please sign in again."
        case .sessionInvalid:
            return "Your session is no longer valid. Please sign in again."
        case .rateLimited(let retryAfter):
            return "Too many attempts. Please try again in \(retryAfter) seconds."
        case .serverError(let message):
            return message
        case .unknown:
            return "An unexpected error occurred"
        case .invalidPassword(let errors):
            return "Password requirements not met: \(errors.map { $0.rawValue }.joined(separator: ", "))"
        case .passwordsDoNotMatch:
            return "Passwords do not match"
        case .emailAlreadyExists:
            return "An account with this email already exists. Please sign in."
        case .weakPassword:
            return "Password is too weak. Please use a stronger password."
        case .emailNotVerified:
            return "Please verify your email before signing in"
        case .accountDisabled:
            return "Your account has been disabled. Please contact support."
        case .userCancelled:
            return nil // Don't show error for user cancellation
        }
    }
}
