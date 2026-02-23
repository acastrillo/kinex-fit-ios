import Foundation

struct AppFeatureFlags: Equatable {
    var facebookAuthEnabled: Bool = true
    var shareExtensionImportEnabled: Bool = true
    var pushActionRoutingEnabled: Bool = true

    static let `default` = AppFeatureFlags()
}
