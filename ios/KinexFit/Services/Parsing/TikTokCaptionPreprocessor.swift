import Foundation

/// Preprocesses raw TikTok caption text before parsing
struct TikTokCaptionPreprocessor {

    /// Patterns that indicate the real workout content is not in the caption
    static let lowConfidencePatterns: [String] = [
        "workout in comments",
        "breakdown in comments",
        "details in comments",
        "link in bio",
        "full workout below",
        "save for later",
    ]

    /// Returns true if the caption matches a low-confidence pattern
    static func isLowConfidence(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return lowConfidencePatterns.contains { lowered.contains($0) }
    }

    static func preprocess(_ raw: String) -> String {
        var text = raw

        // 1. Strip hashtags (#legday, #HYROX)
        text = text.replacingOccurrences(of: #"#\w+"#, with: "", options: .regularExpression)

        // 2. Strip @mentions
        text = text.replacingOccurrences(of: #"@\w+"#, with: "", options: .regularExpression)

        // 3. Replace common workout emojis with newlines (act as list delimiters)
        let workoutEmojis = ["🔥", "💪", "✅", "👊", "⚡️", "🏋️", "🏃", "🏋", "•"]
        for emoji in workoutEmojis {
            text = text.replacingOccurrences(of: emoji, with: "\n")
        }

        // 4. Normalize whitespace — trim lines and remove empty ones
        text = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        return text
    }
}
