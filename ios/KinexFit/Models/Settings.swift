import Foundation

// MARK: - Settings Model

struct AppSettings: Codable {
    var preferredUnits: UnitSystem
    var theme: Theme
    var notificationsEnabled: Bool

    static let `default` = AppSettings(
        preferredUnits: .metric,
        theme: .system,
        notificationsEnabled: false
    )
}

// MARK: - Unit System

enum UnitSystem: String, Codable, CaseIterable {
    case metric
    case imperial

    var displayName: String {
        switch self {
        case .metric: return "Metric (kg, cm)"
        case .imperial: return "Imperial (lbs, in)"
        }
    }
}

// MARK: - Theme

enum Theme: String, Codable, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

// MARK: - Settings Manager

@MainActor
class SettingsManager: ObservableObject {
    @Published var settings: AppSettings

    private let userDefaultsKey = "appSettings"

    init() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = .default
        }
    }

    func save() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    func updateUnits(_ units: UnitSystem) {
        settings.preferredUnits = units
        save()
    }

    func updateTheme(_ theme: Theme) {
        settings.theme = theme
        save()
    }

    func updateNotifications(_ enabled: Bool) {
        settings.notificationsEnabled = enabled
        save()
    }
}
