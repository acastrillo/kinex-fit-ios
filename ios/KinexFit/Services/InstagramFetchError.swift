import Foundation

/// Errors that can occur during Instagram fetch operations
enum InstagramFetchError: LocalizedError {
    case invalidURL
    case quotaExceeded(used: Int, limit: Int)
    case rateLimited
    case postNotFound
    case sourceAuthenticationRequired
    case networkError(Error)
    case parsingFailed
    case unauthorized
    case serverError(statusCode: Int)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .quotaExceeded(let used, let limit):
            return "Monthly scan quota exceeded (\(used)/\(limit) used)"
        case .rateLimited:
            return "Too many requests. Please try again later"
        case .postNotFound:
            return "Post not found"
        case .sourceAuthenticationRequired:
            return "Instagram access restricted"
        case .networkError:
            return "Network connection error"
        case .parsingFailed:
            return "Failed to parse workout content"
        case .unauthorized:
            return "Session expired"
        case .serverError(let statusCode):
            return "Server error (Status: \(statusCode))"
        case .decodingError:
            return "Failed to decode server response"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidURL:
            return "Please enter a valid Instagram or TikTok URL (e.g., instagram.com/p/abc123 or tiktok.com/@user/video/123)"
        case .quotaExceeded(_, let limit):
            return "You've used all \(limit) of your monthly scans. Upgrade your plan for more scans."
        case .rateLimited:
            return "You've made too many requests. Wait a few minutes and try again."
        case .postNotFound:
            return "The post may be private, deleted, or the URL may be incorrect. Please verify the URL and try again."
        case .sourceAuthenticationRequired:
            return "This Instagram post requires login or has restricted visibility. Try a public post URL or use manual import."
        case .networkError:
            return "Check your internet connection and try again."
        case .parsingFailed:
            return "The workout content couldn't be parsed automatically. Try manual entry instead."
        case .unauthorized:
            return "Your session expired. Sign in again and retry this import."
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
        case .invalidURL, .quotaExceeded, .postNotFound, .sourceAuthenticationRequired, .parsingFailed, .unauthorized, .decodingError:
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
