import Foundation
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "InstagramFetchService")

/// Service for fetching and parsing Instagram workout content
actor InstagramFetchService {
    private let apiClient: APIClient
    private let urlExpander = URLExpansionService()

    // Instagram URL validation pattern
    private static let instagramURLPattern = #"^https?://(www\.)?(instagram\.com|instagr\.am)/(p|reel)/[\w-]+/?.*$"#

    // TikTok URL validation pattern (canonical, short-share, and legacy mobile forms)
    private static let tiktokURLPattern =
        #"^https?://(?:(?:www|m)\.)?tiktok\.com/(?:@[\w\.-]+/video/\d+|t/[\w-]+|v/\d+\.html|[\w-]+)/?(?:\?.*)?$|^https?://(?:vm|vt)\.tiktok\.com/[\w-]+/?(?:\?.*)?$"#

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Public Methods

    /// Fetch Instagram post content from backend scraper
    /// - Parameter url: Instagram post or reel URL
    /// - Returns: Instagram fetch response with content and parsed workout
    /// - Throws: InstagramFetchError if fetch fails
    func fetchInstagramPost(url: String) async throws -> InstagramFetchResponse {
        let normalizedURL = Self.normalizeInputURL(url)

        // Validate URL format
        guard isValidInstagramURL(normalizedURL) else {
            throw InstagramFetchError.invalidURL
        }

        logger.info("Fetching Instagram post")

        do {
            let request = try APIRequest.fetchInstagram(url: normalizedURL)
            let response: InstagramFetchResponse = try await apiClient.send(request)

            logger.info("Successfully fetched Instagram post")
            return response

        } catch let error as APIError {
            throw mapAPIError(error, context: .socialFetch)
        } catch {
            throw InstagramFetchError.networkError(error)
        }
    }

    /// Parse workout caption into structured data
    /// - Parameters:
    ///   - caption: Raw caption text
    ///   - url: Optional source URL for context
    /// - Returns: Parsed workout structure
    /// - Throws: InstagramFetchError if parsing fails
    func parseCaption(_ caption: String, url: String? = nil) async throws -> WorkoutIngestResponse {
        logger.info("Parsing caption (length: \(caption.count))")

        do {
            let request = try APIRequest.ingestCaption(caption: caption, url: url)
            let response: WorkoutIngestResponse = try await apiClient.send(request)

            logger.info("Successfully parsed caption into \(response.exercises.count) exercises")
            return response

        } catch let error as APIError {
            throw mapAPIError(error, context: .captionIngest)
        } catch {
            throw InstagramFetchError.parsingFailed
        }
    }

    /// Fetch TikTok post content from backend
    /// - Parameter url: TikTok video URL
    /// - Returns: Fetch response with content and parsed workout
    /// - Throws: InstagramFetchError if fetch fails
    func fetchTikTokPost(url: String) async throws -> InstagramFetchResponse {
        let normalizedURL = Self.normalizeInputURL(url)
        let resolvedURL = await urlExpander.expand(normalizedURL)

        guard isValidTikTokURL(resolvedURL) else {
            throw InstagramFetchError.invalidURL
        }

        logger.info("Fetching TikTok post")

        do {
            let request = try APIRequest.fetchTikTok(url: resolvedURL)
            let response: InstagramFetchResponse = try await apiClient.send(request)

            logger.info("Successfully fetched TikTok post")
            return response

        } catch let error as APIError {
            var oEmbedFailure: InstagramFetchError?

            // Production currently may not expose /api/tiktok-fetch. Fall back to TikTok oEmbed.
            if Self.shouldFallbackTikTokToOEmbed(error) {
                logger.warning("TikTok endpoint failed, retrying with TikTok oEmbed")
                do {
                    let fallbackResponse = try await fetchTikTokPostViaOEmbed(url: resolvedURL)
                    logger.info("Successfully fetched TikTok post via oEmbed fallback")
                    return fallbackResponse
                } catch let fallbackError as InstagramFetchError {
                    oEmbedFailure = fallbackError
                    logger.warning("TikTok oEmbed fallback failed: \(fallbackError.localizedDescription)")
                }
            }

            // Keep legacy fallback for older backend deployments that accept TikTok on instagram-fetch.
            if Self.shouldFallbackTikTokToInstagram(error) {
                logger.warning("TikTok endpoint failed, retrying with legacy Instagram endpoint")
                do {
                    let fallbackRequest = try APIRequest.fetchInstagram(url: resolvedURL)
                    let fallbackResponse: InstagramFetchResponse = try await apiClient.send(fallbackRequest)
                    logger.info("Successfully fetched TikTok post via legacy fallback endpoint")
                    return fallbackResponse
                } catch let fallbackError as APIError {
                    if let oEmbedFailure {
                        throw oEmbedFailure
                    }
                    throw mapAPIError(fallbackError, context: .socialFetch)
                } catch {
                    if let oEmbedFailure {
                        throw oEmbedFailure
                    }
                    throw InstagramFetchError.networkError(error)
                }
            }

            if let oEmbedFailure {
                throw oEmbedFailure
            }
            throw mapAPIError(error, context: .socialFetch)
        } catch {
            throw InstagramFetchError.networkError(error)
        }
    }

    /// Fetch social media post and parse caption in one operation
    /// - Parameter url: Instagram or TikTok URL
    /// - Returns: Combined FetchedWorkout model ready for UI
    /// - Throws: InstagramFetchError if either fetch or parse fails
    func fetchAndParse(url: String) async throws -> FetchedWorkout {
        let normalizedURL = Self.normalizeInputURL(url)

        logger.info("Starting fetch and parse")

        // Step 1: Fetch content based on detected platform
        let platform = SocialPlatform.detect(from: normalizedURL)
        let fetchResponse: InstagramFetchResponse

        switch platform {
        case .instagram:
            fetchResponse = try await fetchInstagramPost(url: normalizedURL)
        case .tiktok:
            fetchResponse = try await fetchTikTokPost(url: normalizedURL)
        case .unknown:
            throw InstagramFetchError.invalidURL
        }

        // Step 2: Parse caption (or use pre-parsed data if available)
        let ingestResponse: WorkoutIngestResponse
        if let parsedWorkout = fetchResponse.parsedWorkout,
           let exercises = parsedWorkout.exercises, !exercises.isEmpty {
            // Use pre-parsed data from fetch response
            logger.info("Using pre-parsed workout data from fetch response")
            ingestResponse = WorkoutIngestResponse(
                title: parsedWorkout.title,
                workoutType: parsedWorkout.workoutType,
                exercises: exercises,
                rows: nil,
                summary: parsedWorkout.summary,
                breakdown: parsedWorkout.breakdown,
                structure: parsedWorkout.structure,
                amrapBlocks: nil,
                emomBlocks: nil,
                usedLLM: parsedWorkout.usedLLM,
                workoutV1: nil
            )
        } else {
            // Parse caption separately
            ingestResponse = try await parseCaption(fetchResponse.content, url: normalizedURL)
        }

        // Step 3: Combine into FetchedWorkout model
        let fetchedWorkout = FetchedWorkout(
            from: fetchResponse,
            ingestResponse: ingestResponse
        )

        logger.info("Successfully created FetchedWorkout with \(fetchedWorkout.exerciseCount) exercises")
        return fetchedWorkout
    }

    // MARK: - Validation

    /// Validate Instagram URL format
    /// - Parameter url: URL string to validate
    /// - Returns: true if URL matches Instagram pattern
    nonisolated func isValidInstagramURL(_ url: String) -> Bool {
        Self.matchesPattern(url, pattern: Self.instagramURLPattern)
    }

    /// Validate TikTok URL format
    /// - Parameter url: URL string to validate
    /// - Returns: true if URL matches TikTok pattern
    nonisolated func isValidTikTokURL(_ url: String) -> Bool {
        Self.matchesPattern(url, pattern: Self.tiktokURLPattern)
    }

    /// Validate URL against either Instagram or TikTok patterns
    /// - Parameter url: URL string to validate
    /// - Returns: true if URL matches any supported social platform
    nonisolated func isValidSocialURL(_ url: String) -> Bool {
        isValidInstagramURL(url) || isValidTikTokURL(url)
    }

    private nonisolated static func matchesPattern(_ url: String, pattern: String) -> Bool {
        let normalizedURL = normalizeInputURL(url)
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return false
        }
        let range = NSRange(location: 0, length: normalizedURL.utf16.count)
        return regex.firstMatch(in: normalizedURL, options: [], range: range) != nil
    }

    // MARK: - TikTok Fallbacks

    private func fetchTikTokPostViaOEmbed(url: String) async throws -> InstagramFetchResponse {
        guard var components = URLComponents(string: "https://www.tiktok.com/oembed") else {
            throw InstagramFetchError.serverError(statusCode: 0)
        }
        components.queryItems = [URLQueryItem(name: "url", value: url)]
        guard let endpoint = components.url else {
            throw InstagramFetchError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 8.0
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)",
            forHTTPHeaderField: "User-Agent"
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await apiClient.session.data(for: request)
        } catch {
            throw InstagramFetchError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw InstagramFetchError.serverError(statusCode: 0)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            switch httpResponse.statusCode {
            case 400:
                throw InstagramFetchError.invalidURL
            case 404:
                throw InstagramFetchError.postNotFound
            default:
                throw InstagramFetchError.serverError(statusCode: httpResponse.statusCode)
            }
        }

        let payload: TikTokOEmbedResponse
        do {
            payload = try JSONDecoder().decode(TikTokOEmbedResponse.self, from: data)
        } catch {
            throw InstagramFetchError.decodingError(error)
        }

        let caption = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !caption.isEmpty else {
            throw InstagramFetchError.parsingFailed
        }

        let username = Self.usernameFromTikTokAuthorURL(payload.authorURL)
            ?? payload.authorName.replacingOccurrences(of: " ", with: "").lowercased()
        let normalizedUsername = username.isEmpty ? "unknown" : username

        return InstagramFetchResponse(
            url: url,
            title: caption,
            content: caption,
            author: AuthorInfo(username: normalizedUsername, fullName: payload.authorName),
            stats: nil,
            image: payload.thumbnailURL,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            mediaType: payload.type,
            parsedWorkout: nil,
            scanQuotaUsed: nil,
            scanQuotaLimit: nil,
            quotaUsed: nil,
            quotaLimit: nil
        )
    }

    // MARK: - Error Mapping

    private enum APIErrorContext {
        case socialFetch
        case captionIngest
    }

    /// Map APIError to InstagramFetchError
    private func mapAPIError(_ apiError: APIError, context: APIErrorContext) -> InstagramFetchError {
        switch apiError {
        case .httpStatus(let statusCode, let data):
            if let data,
               let errorResponse = decodeErrorResponse(from: data) {
                return mapErrorResponse(errorResponse, statusCode: statusCode, context: context)
            }

            switch statusCode {
            case 401:
                if let data,
                   let responseText = String(data: data, encoding: .utf8)?.lowercased() {
                    return Self.map401AuthenticationMessage(responseText, context: context)
                }
                return .unauthorized
            case 404:
                return .postNotFound
            case 429:
                return .rateLimited
            default:
                return .serverError(statusCode: statusCode)
            }

        case .decoding(let error):
            return .decodingError(error)

        case .invalidURL, .invalidResponse:
            return .serverError(statusCode: 0)
        }
    }

    /// Map structured error response to InstagramFetchError
    private func mapErrorResponse(
        _ errorResponse: ErrorResponse,
        statusCode: Int,
        context: APIErrorContext
    ) -> InstagramFetchError {
        let message = errorResponse.normalizedMessage
        let normalizedMessage = message.lowercased()

        // Check for quota exceeded
        if normalizedMessage.contains("quota") || normalizedMessage.contains("limit") {
            // Try to extract quota numbers if available
            return .quotaExceeded(used: errorResponse.quotaUsed ?? 0, limit: errorResponse.quotaLimit ?? 100)
        }

        // Check for rate limiting
        if statusCode == 429 || normalizedMessage.contains("rate limit") {
            return .rateLimited
        }

        if statusCode == 400, Self.isInvalidURLMessage(normalizedMessage) {
            return .invalidURL
        }

        if statusCode == 401 {
            if let codedError = Self.map401ErrorCode(errorResponse, context: context) {
                return codedError
            }
            return Self.map401AuthenticationMessage(normalizedMessage, context: context)
        }

        if statusCode == 403, Self.isSourceAuthenticationError(normalizedMessage) {
            return .sourceAuthenticationRequired
        }

        // Check for not found
        if statusCode == 404 || normalizedMessage.contains("not found") {
            return .postNotFound
        }

        // Default to server error
        return .serverError(statusCode: statusCode)
    }

    private func decodeErrorResponse(from data: Data) -> ErrorResponse? {
        try? JSONDecoder().decode(ErrorResponse.self, from: data)
    }

    private nonisolated static func map401AuthenticationMessage(
        _ normalizedMessage: String,
        context: APIErrorContext
    ) -> InstagramFetchError {
        if isLikelyAppAuthenticationError(normalizedMessage) {
            return .unauthorized
        }

        // Some scraper providers return generic "please login" 401 responses
        // when the source post is not publicly accessible.
        if isSourceAuthenticationError(normalizedMessage)
            || (context == .socialFetch && isAmbiguousSourceLoginPrompt(normalizedMessage)) {
            return .sourceAuthenticationRequired
        }

        return .unauthorized
    }

    private nonisolated static func map401ErrorCode(
        _ errorResponse: ErrorResponse,
        context: APIErrorContext
    ) -> InstagramFetchError? {
        let normalizedCode = (errorResponse.errorCode ?? errorResponse.code ?? "").lowercased()
        guard !normalizedCode.isEmpty else { return nil }

        let appCodes = [
            "app_auth_required",
            "invalid_token",
            "token_expired",
            "session_expired",
            "unauthorized"
        ]
        if appCodes.contains(where: { normalizedCode.contains($0) }) {
            return .unauthorized
        }

        let sourceCodes = [
            "source_auth_required",
            "instagram_auth_required",
            "tiktok_auth_required",
            "source_login_required",
            "private_post"
        ]
        if sourceCodes.contains(where: { normalizedCode.contains($0) }) {
            return .sourceAuthenticationRequired
        }

        if context == .socialFetch, normalizedCode.contains("auth_required") {
            return .sourceAuthenticationRequired
        }
        return nil
    }

    private nonisolated static func isSourceAuthenticationError(_ normalizedMessage: String) -> Bool {
        let sourceKeywords = [
            "instagram",
            "tiktok",
            "private post",
            "private account",
            "restricted",
            "requires login",
            "login required",
            "authentication required",
            "sign in to view",
            "not publicly available",
            "checkpoint",
            "cookie"
        ]

        return sourceKeywords.contains { normalizedMessage.contains($0) }
    }

    private nonisolated static func isAmbiguousSourceLoginPrompt(_ normalizedMessage: String) -> Bool {
        let ambiguousKeywords = [
            "please login",
            "please log in",
            "error please login"
        ]

        return ambiguousKeywords.contains { normalizedMessage.contains($0) }
    }

    private nonisolated static func isLikelyAppAuthenticationError(_ normalizedMessage: String) -> Bool {
        let appKeywords = [
            "unauthorized",
            "please sign in",
            "sign in to continue",
            "login to continue",
            "access token",
            "refresh token",
            "token expired",
            "jwt",
            "session expired"
        ]

        return appKeywords.contains { normalizedMessage.contains($0) }
    }

    private nonisolated static func normalizeInputURL(_ url: String) -> String {
        var normalized = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.hasPrefix("<"), normalized.hasSuffix(">"), normalized.count > 2 {
            normalized = String(normalized.dropFirst().dropLast())
        }
        return normalized
    }

    private nonisolated static func shouldFallbackTikTokToOEmbed(_ apiError: APIError) -> Bool {
        guard case .httpStatus(let statusCode, _) = apiError else { return false }
        switch statusCode {
        case 400, 404, 405, 422, 500, 501, 502, 503, 504:
            return true
        default:
            return false
        }
    }

    private nonisolated static func shouldFallbackTikTokToInstagram(_ apiError: APIError) -> Bool {
        guard case .httpStatus(let statusCode, _) = apiError else { return false }
        return statusCode == 400 || statusCode == 404 || statusCode == 422
    }

    private nonisolated static func usernameFromTikTokAuthorURL(_ authorURL: String?) -> String? {
        guard let authorURL,
              let components = URLComponents(string: authorURL),
              let host = components.host?.lowercased(),
              host.contains("tiktok.com") else {
            return nil
        }

        let parts = components.path.split(separator: "/")
        guard let handle = parts.first(where: { $0.hasPrefix("@") }) else {
            return nil
        }

        let username = handle.trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        return username.isEmpty ? nil : username
    }

    private nonisolated static func isInvalidURLMessage(_ normalizedMessage: String) -> Bool {
        let invalidURLKeywords = [
            "invalid url",
            "invalid link",
            "invalid tiktok",
            "malformed url",
            "unsupported url",
            "url is required",
            "bad request"
        ]
        return invalidURLKeywords.contains(where: { normalizedMessage.contains($0) })
    }
}

// MARK: - Error Response Model

/// Error response structure from backend
private struct ErrorResponse: Decodable {
    let message: String?
    let error: String?
    let detail: String?
    let details: String?
    let code: String?
    let errorCode: String?
    let quotaUsed: Int?
    let quotaLimit: Int?

    private enum CodingKeys: String, CodingKey {
        case message
        case error
        case detail
        case details
        case code
        case errorCode
        case error_code
        case quotaUsed
        case quota_used
        case quotaLimit
        case quota_limit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        error = try container.decodeIfPresent(String.self, forKey: .error)
        detail = try container.decodeIfPresent(String.self, forKey: .detail)
        details = try container.decodeIfPresent(String.self, forKey: .details)
        code =
            (try? container.decodeIfPresent(String.self, forKey: .code))
            ?? (try? container.decodeIfPresent(String.self, forKey: .error_code))
        errorCode = try container.decodeIfPresent(String.self, forKey: .errorCode)
        quotaUsed =
            (try? container.decodeIfPresent(Int.self, forKey: .quotaUsed))
            ?? (try? container.decodeIfPresent(Int.self, forKey: .quota_used))
        quotaLimit =
            (try? container.decodeIfPresent(Int.self, forKey: .quotaLimit))
            ?? (try? container.decodeIfPresent(Int.self, forKey: .quota_limit))
    }

    var normalizedMessage: String {
        message?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? error?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? detail?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? details?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""
    }
}

/// Response from TikTok public oEmbed endpoint.
private struct TikTokOEmbedResponse: Decodable {
    let type: String?
    let title: String
    let authorName: String
    let authorURL: String?
    let thumbnailURL: String?

    private enum CodingKeys: String, CodingKey {
        case type
        case title
        case authorName = "author_name"
        case authorURL = "author_url"
        case thumbnailURL = "thumbnail_url"
    }
}
