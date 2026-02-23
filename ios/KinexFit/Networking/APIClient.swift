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
        try await send(request, allowRefreshRetry: true)
    }

    private func send(_ request: APIRequest, allowRefreshRetry: Bool) async throws -> Data {
        // Auth endpoints accept provider/credential payloads and should not be coupled to
        // any previously stored bearer token (which may be stale in Keychain).
        let shouldIncludeAuthorization = shouldIncludeAuthorizationHeader(path: request.path)
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

        if shouldAttemptTokenRefresh(for: request, statusCode: httpResponse.statusCode, allowRefreshRetry: allowRefreshRetry) {
            let didRefresh = await Self.refreshCoordinator.refresh(using: self)
            if didRefresh {
                return try await send(request, allowRefreshRetry: false)
            }
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
        return !isAuthEndpoint(path: request.path)
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

    private func shouldIncludeAuthorizationHeader(path: String) -> Bool {
        let noAuthorizationPrefixes = [
            "/api/mobile/auth/signin",
            "/api/mobile/auth/signin-credentials",
            "/api/mobile/auth/signup",
            "/api/mobile/auth/refresh"
        ]
        return !noAuthorizationPrefixes.contains { path.hasPrefix($0) }
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
