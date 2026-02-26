import Foundation

extension APIRequest {
    /// Fetch Instagram post content via backend scraper
    /// - Parameter url: Instagram post or reel URL
    /// - Returns: APIRequest configured for Instagram fetch
    static func fetchInstagram(url: String) throws -> APIRequest {
        try json(
            path: "/api/instagram-fetch",
            method: .post,
            body: InstagramFetchRequest(url: url)
        )
    }

    /// Fetch TikTok post content via backend scraper
    /// - Parameter url: TikTok video URL
    /// - Returns: APIRequest configured for TikTok fetch
    static func fetchTikTok(url: String) throws -> APIRequest {
        try json(
            path: "/api/tiktok-fetch",
            method: .post,
            body: InstagramFetchRequest(url: url)
        )
    }

    /// Parse workout caption into structured data
    /// - Parameters:
    ///   - caption: Raw caption text from Instagram
    ///   - url: Optional source URL for context
    /// - Returns: APIRequest configured for caption parsing
    static func ingestCaption(caption: String, url: String? = nil) throws -> APIRequest {
        try json(
            path: "/api/ingest",
            method: .post,
            body: IngestRequest(caption: caption, url: url)
        )
    }
}
