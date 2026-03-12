import Foundation
import Combine
import OSLog

private let featureFlagLogger = Logger(subsystem: "com.kinex.fit", category: "FeatureFlagService")

@MainActor
final class FeatureFlagService: ObservableObject {
    @Published private(set) var flags: AppFeatureFlags = .default

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func refresh() async {
        do {
            let request = APIRequest(path: "/api/mobile/app-config")
            let data = try await apiClient.send(request)
            let resolved = Self.parseFlags(from: data) ?? .default
            flags = resolved
            featureFlagLogger.info("Feature flags refreshed")
        } catch {
            featureFlagLogger.warning("Feature flag refresh failed; using defaults")
            flags = .default
        }
    }

    private static func parseFlags(from data: Data) -> AppFeatureFlags? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let featuresObject = root["features"] as? [String: Any]
        let merged = root.merging(featuresObject ?? [:]) { _, new in new }

        let facebookEnabled = boolValue(
            in: merged,
            keys: ["facebookAuthEnabled", "facebook_auth_enabled", "facebookAuth"],
            defaultValue: true
        )

        let emailPasswordAuthEnabled = boolValue(
            in: merged,
            keys: ["emailPasswordAuthEnabled", "email_password_auth_enabled", "emailAuthEnabled", "email_auth_enabled"],
            defaultValue: false
        )

        let shareImportEnabled = boolValue(
            in: merged,
            keys: ["shareExtensionImportEnabled", "share_extension_import_enabled", "shareImportEnabled", "shareImport"],
            defaultValue: true
        )

        let pushRoutingEnabled = boolValue(
            in: merged,
            keys: ["pushActionRoutingEnabled", "push_action_routing_enabled", "pushRoutingEnabled", "pushRouting"],
            defaultValue: true
        )

        return AppFeatureFlags(
            facebookAuthEnabled: facebookEnabled,
            emailPasswordAuthEnabled: emailPasswordAuthEnabled,
            shareExtensionImportEnabled: shareImportEnabled,
            pushActionRoutingEnabled: pushRoutingEnabled
        )
    }

    private static func boolValue(in object: [String: Any], keys: [String], defaultValue: Bool) -> Bool {
        for key in keys {
            if let value = object[key] as? Bool {
                return value
            }
            if let value = object[key] as? NSNumber {
                return value.boolValue
            }
            if let value = object[key] as? String {
                switch value.lowercased() {
                case "true", "1", "yes":
                    return true
                case "false", "0", "no":
                    return false
                default:
                    break
                }
            }
        }
        return defaultValue
    }
}
