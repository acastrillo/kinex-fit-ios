import Foundation
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "APIClient")

struct APIClient {
    let baseURL: URL
    let tokenStore: TokenStore
    let session: URLSession
    private static let refreshCoordinator = TokenRefreshCoordinator()

    init(baseURL: URL, tokenStore: TokenStore, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore
        self.session = session
    }

    func send(_ request: APIRequest) async throws -> Data {
        try await send(
            request,
            allowRefreshRetry: true,
            includeAuthorizationOverride: nil,
            allowUnauthenticatedSocialRetry: true
        )
    }

    private func send(
        _ request: APIRequest,
        allowRefreshRetry: Bool,
        includeAuthorizationOverride: Bool?,
        allowUnauthenticatedSocialRetry: Bool
    ) async throws -> Data {
        // Auth endpoints accept provider/credential payloads and should not be coupled to
        // any previously stored bearer token (which may be stale in Keychain).
        let shouldIncludeAuthorization =
            includeAuthorizationOverride ?? shouldIncludeAuthorizationHeader(path: request.path)
        var urlRequest = try makeURLRequest(for: request, includeAuthorization: shouldIncludeAuthorization)
        let authTraceID = UUID().uuidString
        if isAuthEndpoint(path: request.path) {
            urlRequest.setValue(authTraceID, forHTTPHeaderField: "X-Kinex-Auth-Trace-ID")
            logger.info("Sending auth request: path=\(request.path, privacy: .public) traceID=\(authTraceID, privacy: .public)")
        }
        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if (200..<300).contains(httpResponse.statusCode) {
            return data
        }

        if shouldRetrySocialImportWithoutAuthorization(
            request: request,
            statusCode: httpResponse.statusCode,
            includedAuthorization: shouldIncludeAuthorization,
            allowUnauthenticatedSocialRetry: allowUnauthenticatedSocialRetry
        ) {
            logger.warning(
                "Social import request returned 504 with Authorization; retrying once without Authorization. path=\(request.path, privacy: .public)"
            )
            return try await send(
                request,
                allowRefreshRetry: false,
                includeAuthorizationOverride: false,
                allowUnauthenticatedSocialRetry: false
            )
        }

        if shouldAttemptSocialImportTokenRefresh(
            request: request,
            statusCode: httpResponse.statusCode,
            includedAuthorization: shouldIncludeAuthorization,
            allowRefreshRetry: allowRefreshRetry,
            responseData: data
        ) {
            logger.warning(
                "Social import request returned app-auth 401; refreshing token and retrying once. path=\(request.path, privacy: .public)"
            )
            let didRefresh = await Self.refreshCoordinator.refresh(using: self)
            if didRefresh {
                return try await send(
                    request,
                    allowRefreshRetry: false,
                    includeAuthorizationOverride: nil,
                    allowUnauthenticatedSocialRetry: allowUnauthenticatedSocialRetry
                )
            }
            try? tokenStore.clearAll()
            NotificationCenter.default.post(name: .authSessionInvalidated, object: nil)
        }

        if shouldAttemptTokenRefresh(for: request, statusCode: httpResponse.statusCode, allowRefreshRetry: allowRefreshRetry) {
            let didRefresh = await Self.refreshCoordinator.refresh(using: self)
            if didRefresh {
                return try await send(
                    request,
                    allowRefreshRetry: false,
                    includeAuthorizationOverride: nil,
                    allowUnauthenticatedSocialRetry: allowUnauthenticatedSocialRetry
                )
            }
            try? tokenStore.clearAll()
            NotificationCenter.default.post(name: .authSessionInvalidated, object: nil)
        }

        if shouldInvalidateSessionWithoutRefresh(
            for: request,
            statusCode: httpResponse.statusCode,
            allowRefreshRetry: allowRefreshRetry
        ) {
            try? tokenStore.clearAll()
            NotificationCenter.default.post(name: .authSessionInvalidated, object: nil)
        }

        if isAuthEndpoint(path: request.path) {
            let responseText = String(data: data, encoding: .utf8) ?? "<non-utf8-body>"
            let headers = httpResponse.allHeaderFields
                .map { "\($0.key)=\($0.value)" }
                .sorted()
                .joined(separator: "; ")
            logger.error("Auth request failed: path=\(request.path, privacy: .public) traceID=\(authTraceID, privacy: .public) status=\(httpResponse.statusCode) headers=\(headers, privacy: .public) body=\(responseText, privacy: .public)")
        }

        if shouldLogDiagnostics(path: request.path) {
            let responseText = String(data: data, encoding: .utf8) ?? "<non-utf8-body>"
            logger.error("Request failed: path=\(request.path, privacy: .public) status=\(httpResponse.statusCode) body=\(responseText, privacy: .public)")
        }

        throw APIError.httpStatus(httpResponse.statusCode, data)
    }

    private func makeURLRequest(for request: APIRequest, includeAuthorization: Bool) throws -> URLRequest {
        var url = baseURL.appendingPathComponent(request.path)
        if !request.queryItems.isEmpty {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw APIError.invalidURL
            }
            components.queryItems = request.queryItems
            guard let resolved = components.url else {
                throw APIError.invalidURL
            }
            url = resolved
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        request.headers.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        if includeAuthorization, let token = tokenStore.accessToken {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return urlRequest
    }

    func send<T: Decodable>(_ request: APIRequest, decoder: JSONDecoder = JSONCoding.apiDecoder()) async throws -> T {
        let data = try await send(request)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    private func shouldAttemptTokenRefresh(
        for request: APIRequest,
        statusCode: Int,
        allowRefreshRetry: Bool
    ) -> Bool {
        guard allowRefreshRetry else { return false }
        guard statusCode == 401 else { return false }
        guard tokenStore.accessToken != nil, tokenStore.refreshToken != nil else { return false }
        guard isSessionManagedEndpoint(path: request.path) else { return false }
        return !isAuthEndpoint(path: request.path)
    }

    private func shouldInvalidateSessionWithoutRefresh(
        for request: APIRequest,
        statusCode: Int,
        allowRefreshRetry: Bool
    ) -> Bool {
        guard statusCode == 401 else { return false }
        guard !isAuthEndpoint(path: request.path) else { return false }
        guard isSessionManagedEndpoint(path: request.path) else { return false }

        // If a refresh attempt is still possible, let refresh logic handle session invalidation.
        if shouldAttemptTokenRefresh(for: request, statusCode: statusCode, allowRefreshRetry: allowRefreshRetry) {
            return false
        }

        return tokenStore.accessToken != nil
    }

    private func isAuthEndpoint(path: String) -> Bool {
        let authPrefixes = [
            "/api/mobile/auth/signin",
            "/api/mobile/auth/signin-credentials",
            "/api/mobile/auth/signup",
            "/api/mobile/auth/refresh",
            "/api/mobile/auth/signout"
        ]
        return authPrefixes.contains { path.hasPrefix($0) }
    }

    /// Endpoints whose 401 responses should participate in session refresh/invalidation flow.
    /// Social import endpoints are handled by a dedicated flow because they may return 401
    /// for either app-session errors or source visibility/authentication constraints.
    private func isSessionManagedEndpoint(path: String) -> Bool {
        path.hasPrefix("/api/mobile/")
            || path.hasPrefix("/api/workouts")
            || path.hasPrefix("/api/ingest")
            || path.hasPrefix("/api/body-metrics")
            || path.hasPrefix("/api/user/")
    }

    private func shouldIncludeAuthorizationHeader(path: String) -> Bool {
        let noAuthorizationPrefixes = [
            "/api/mobile/auth/signin",
            "/api/mobile/auth/signin-credentials",
            "/api/mobile/auth/signup",
            "/api/mobile/auth/refresh"
        ]
        return !noAuthorizationPrefixes.contains { path.hasPrefix($0) }
    }

    private func shouldLogDiagnostics(path: String) -> Bool {
        path.hasPrefix("/api/mobile/workouts")
            || path.hasPrefix("/api/workouts")
            || path.hasPrefix("/api/mobile/user/onboarding")
            || path.hasPrefix("/api/mobile/ai")
            || path.hasPrefix("/api/instagram-fetch")
            || path.hasPrefix("/api/tiktok-fetch")
            || path.hasPrefix("/api/ingest")
            || path.hasPrefix("/api/user/settings")
    }

    private func shouldRetrySocialImportWithoutAuthorization(
        request: APIRequest,
        statusCode: Int,
        includedAuthorization: Bool,
        allowUnauthenticatedSocialRetry: Bool
    ) -> Bool {
        guard allowUnauthenticatedSocialRetry else { return false }
        guard includedAuthorization else { return false }
        guard statusCode == 504 else { return false }
        return isSocialImportEndpoint(path: request.path)
    }

    private func shouldAttemptSocialImportTokenRefresh(
        request: APIRequest,
        statusCode: Int,
        includedAuthorization: Bool,
        allowRefreshRetry: Bool,
        responseData: Data?
    ) -> Bool {
        guard allowRefreshRetry else { return false }
        guard includedAuthorization else { return false }
        guard statusCode == 401 else { return false }
        guard tokenStore.accessToken != nil, tokenStore.refreshToken != nil else { return false }
        guard isSocialImportEndpoint(path: request.path) else { return false }
        guard let normalizedResponseText = normalizedResponseText(from: responseData), !normalizedResponseText.isEmpty else {
            return false
        }
        guard !Self.isLikelySourceAuthenticationError(normalizedResponseText) else { return false }
        return Self.isLikelyAppAuthenticationError(normalizedResponseText)
    }

    private func isSocialImportEndpoint(path: String) -> Bool {
        path.hasPrefix("/api/instagram-fetch") || path.hasPrefix("/api/tiktok-fetch")
    }

    private func normalizedResponseText(from data: Data?) -> String? {
        guard let data else { return nil }
        return String(data: data, encoding: .utf8)?.lowercased()
    }

    private static func isLikelyAppAuthenticationError(_ normalizedMessage: String) -> Bool {
        let appKeywords = [
            "unauthorized",
            "please sign in",
            "sign in to continue",
            "login to continue",
            "access token",
            "refresh token",
            "token expired",
            "jwt",
            "session expired",
            "app_auth_required"
        ]

        return appKeywords.contains { normalizedMessage.contains($0) }
    }

    private static func isLikelySourceAuthenticationError(_ normalizedMessage: String) -> Bool {
        let sourceKeywords = [
            "instagram",
            "tiktok",
            "private post",
            "private account",
            "not publicly available",
            "sign in to view",
            "requires login",
            "checkpoint",
            "cookie"
        ]

        return sourceKeywords.contains { normalizedMessage.contains($0) }
    }

    fileprivate func performTokenRefresh() async -> Bool {
        guard let refreshToken = tokenStore.refreshToken else {
            return false
        }

        struct RefreshTokenRequest: Encodable {
            let refreshToken: String
        }

        struct RefreshTokenResponse: Decodable {
            let accessToken: String
            let refreshToken: String
        }

        do {
            let refreshRequest = try APIRequest.json(
                path: "/api/mobile/auth/refresh",
                method: .post,
                body: RefreshTokenRequest(refreshToken: refreshToken)
            )
            let urlRequest = try makeURLRequest(for: refreshRequest, includeAuthorization: false)
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return false
            }

            let refreshResponse = try JSONCoding.apiDecoder().decode(RefreshTokenResponse.self, from: data)
            try tokenStore.setAccessToken(refreshResponse.accessToken)
            try tokenStore.setRefreshToken(refreshResponse.refreshToken)
            return true
        } catch {
            return false
        }
    }
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int, Data?)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid request URL."
        case .invalidResponse:
            return "Received an invalid server response."
        case .httpStatus(let code, _):
            return "Server returned an error (HTTP \(code))."
        case .decoding(let error):
            return "Failed to parse server response: \(error.localizedDescription)"
        }
    }
}

private actor TokenRefreshCoordinator {
    private var isRefreshing = false
    private var waiters: [CheckedContinuation<Bool, Never>] = []

    func refresh(using client: APIClient) async -> Bool {
        if isRefreshing {
            return await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }

        isRefreshing = true
        let result = await client.performTokenRefresh()
        isRefreshing = false

        for waiter in waiters {
            waiter.resume(returning: result)
        }
        waiters.removeAll()

        return result
    }
}
