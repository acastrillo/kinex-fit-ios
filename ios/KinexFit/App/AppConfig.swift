import Foundation

enum AppConfig {
    static let liveAPIBaseURL = URL(string: "https://kinexfit.com")!
    static let previewAPIBaseURL = URL(string: "https://example.invalid")!

    static let apiBaseURL = liveAPIBaseURL
}
