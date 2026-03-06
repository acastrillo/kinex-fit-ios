import Foundation
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "URLExpansion")

/// Resolves TikTok short links (vm.tiktok.com / vt.tiktok.com) to canonical URLs
actor URLExpansionService {
    private var cache: [String: String] = [:]

    func expand(_ shortURL: String) async -> String {
        if let cached = cache[shortURL] { return cached }

        guard let url = URL(string: shortURL),
              let host = url.host?.lowercased(),
              host == "vm.tiktok.com" || host == "vt.tiktok.com" else {
            return shortURL
        }

        if let finalURL = await resolve(url: url, method: "HEAD") {
            logger.info("Resolved \(shortURL) → \(finalURL)")
            cache[shortURL] = finalURL
            return finalURL
        }

        if let finalURL = await resolve(url: url, method: "GET") {
            logger.info("Resolved \(shortURL) → \(finalURL)")
            cache[shortURL] = finalURL
            return finalURL
        }

        logger.warning("Could not resolve short URL: \(shortURL)")
        return shortURL
    }

    private func resolve(url: URL, method: String) async -> String? {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 3.0
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)",
            forHTTPHeaderField: "User-Agent"
        )

        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let finalURL = (response as? HTTPURLResponse)?.url?.absoluteString else {
            return nil
        }
        return finalURL
    }
}
