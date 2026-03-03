import Foundation
import Network
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "OfflineMode")

/// Manages offline-mode functionality and network monitoring
@MainActor
final class OfflineModeManager: NSObject, ObservableObject {
    @Published var isOnline: Bool = true
    @Published var isOfflineModeEnabled: Bool = false

    static let shared = OfflineModeManager()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.kinex.fit.network")

    override private init() {
        super.init()
        setupNetworkMonitoring()
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
                logger.info("Network status: \(path.status == .satisfied ? "Online" : "Offline")")
            }
        }
        monitor.start(queue: queue)
    }

    // MARK: - Offline Mode

    /// Enable offline mode to use only cached data
    func enableOfflineMode() {
        isOfflineModeEnabled = true
        logger.info("Offline mode enabled")
    }

    /// Disable offline mode and resume normal syncing
    func disableOfflineMode() {
        isOfflineModeEnabled = false
        logger.info("Offline mode disabled")
    }

    /// Check if a specific feature is available in offline mode
    func isFeatureAvailableOffline(_ feature: OfflineFeature) -> Bool {
        switch feature {
        case .viewWorkouts:
            return true  // Workouts cached locally
        case .viewStats:
            return true  // Stats cached locally
        case .createWorkout:
            return true  // Can be synced later
        case .completeWorkout:
            return true  // Can be synced later
        case .viewProfile:
            return true  // Profile cached locally
        case .editProfile:
            return false // Requires network to sync
        case .syncData:
            return isOnline  // Only available when online
        }
    }

    deinit {
        monitor.cancel()
    }
}

// MARK: - Offline Features

enum OfflineFeature {
    case viewWorkouts
    case viewStats
    case createWorkout
    case completeWorkout
    case viewProfile
    case editProfile
    case syncData

    var displayName: String {
        switch self {
        case .viewWorkouts: return "View Workouts"
        case .viewStats: return "View Statistics"
        case .createWorkout: return "Create Workout"
        case .completeWorkout: return "Complete Workout"
        case .viewProfile: return "View Profile"
        case .editProfile: return "Edit Profile"
        case .syncData: return "Sync Data"
        }
    }

    var description: String {
        switch self {
        case .viewWorkouts: return "View cached workouts"
        case .viewStats: return "View cached statistics"
        case .createWorkout: return "Create new workout (syncs when online)"
        case .completeWorkout: return "Log completed workout (syncs when online)"
        case .viewProfile: return "View your profile"
        case .editProfile: return "Edit profile (requires internet)"
        case .syncData: return "Sync data with server"
        }
    }
}

// MARK: - Offline Banner

struct OfflineModeBanner: View {
    @ObservedObject var manager = OfflineModeManager.shared

    var body: some View {
        if !manager.isOnline {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 14, weight: .semibold))
                    Text("You're offline")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text("Limited features")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if manager.isOfflineModeEnabled {
                    Text("Offline mode active. Data will sync when you're back online.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
    }
}

#if DEBUG
struct OfflineModeBanner_Previews: PreviewProvider {
    static var previews: some View {
        OfflineModeBanner()
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif
