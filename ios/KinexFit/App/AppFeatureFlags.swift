import Foundation

struct AppFeatureFlags: Equatable {
    var facebookAuthEnabled: Bool = true
    var emailPasswordAuthEnabled: Bool = false
    var shareExtensionImportEnabled: Bool = true
    var pushActionRoutingEnabled: Bool = true

    static let `default` = AppFeatureFlags()
}
