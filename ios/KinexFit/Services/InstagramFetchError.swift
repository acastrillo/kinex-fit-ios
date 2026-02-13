import Foundation

/// Errors that can occur during Instagram fetch operations
enum InstagramFetchError: LocalizedError {
    case invalidURL
    case quotaExceeded(used: Int, limit: Int)
    case rateLimited
    case postNotFound
    case networkError(Error)
    case parsingFailed
    case unauthorized
    case serverError(statusCode: Int)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Instagram URL"
        case .quotaExceeded(let used, let limit):
            return "Monthly scan quota exceeded (\(used)/\(limit) used)"
        case .rateLimited:
            return "Too many requests. Please try again later"
        case .postNotFound:
            return "Instagram post not found"
        case .networkError:
            return "Network connection error"
        case .parsingFailed:
            return "Failed to parse workout content"
        case .unauthorized:
            return "Authentication required"
        case .serverError(let statusCode):
            return "Server error (Status: \(statusCode))"
        case .decodingError:
            return "Failed to decode server response"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidURL:
            return "Please enter a valid Instagram post or reel URL (e.g., https://instagram.com/p/abc123)"
        case .quotaExceeded(_, let limit):
            return "You've used all \(limit) of your monthly scans. Upgrade your plan for more scans."
        case .rateLimited:
            return "You've made too many requests. Wait a few minutes and try again."
        case .postNotFound:
            return "The post may be private, deleted, or the URL may be incorrect. Please verify the URL and try again."
        case .networkError:
            return "Check your internet connection and try again."
        case .parsingFailed:
            return "The workout content couldn't be parsed automatically. Try manual entry instead."
        case .unauthorized:
            return "Please log in to continue."
        case .serverError:
            return "Our servers are experiencing issues. Please try again later."
        case .decodingError:
            return "There was a problem processing the response. Please try again."
        }
    }

    /// Whether the error is recoverable by retrying
    var isRetryable: Bool {
        switch self {
        case .networkError, .serverError, .rateLimited:
            return true
        case .invalidURL, .quotaExceeded, .postNotFound, .parsingFailed, .unauthorized, .decodingError:
            return false
        }
    }

    /// Whether the error should trigger an upgrade prompt
    var shouldShowUpgradePrompt: Bool {
        if case .quotaExceeded = self {
            return true
        }
        return false
    }
}
