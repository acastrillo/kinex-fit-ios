import Foundation
import Network
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "NetworkMonitor")

@MainActor
final class NetworkMonitor: ObservableObject {
    @Published var isConnected = false
    @Published var connectionType: NWInterface.InterfaceType?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.kinex.fit.network-monitor")
    private var onConnectivityChange: ((Bool) -> Void)?

    init() {
        startMonitoring()
    }

    deinit {
        monitor.cancel()
    }

    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied

            Task { @MainActor [weak self] in
                guard let self else { return }

                let wasConnected = self.isConnected
                self.isConnected = connected

                // Determine connection type
                if connected {
                    if path.usesInterfaceType(.wifi) {
                        self.connectionType = .wifi
                    } else if path.usesInterfaceType(.cellular) {
                        self.connectionType = .cellular
                    } else if path.usesInterfaceType(.wiredEthernet) {
                        self.connectionType = .wiredEthernet
                    } else {
                        self.connectionType = .other
                    }
                } else {
                    self.connectionType = nil
                }

                // Log connection changes
                if connected != wasConnected {
                    if connected {
                        logger.info("Network connected (\(self.connectionType?.name ?? "unknown"))")
                    } else {
                        logger.info("Network disconnected")
                    }

                    // Notify callback
                    self.onConnectivityChange?(connected)
                }
            }
        }

        monitor.start(queue: queue)
        logger.info("Network monitoring started")
    }

    func stopMonitoring() {
        monitor.cancel()
        logger.info("Network monitoring stopped")
    }

    /// Set a callback to be invoked when connectivity changes
    func onConnectivityChange(_ callback: @escaping (Bool) -> Void) {
        self.onConnectivityChange = callback
    }
}

// MARK: - Interface Type Extension

extension NWInterface.InterfaceType {
    var name: String {
        switch self {
        case .wifi: return "WiFi"
        case .cellular: return "Cellular"
        case .wiredEthernet: return "Ethernet"
        case .loopback: return "Loopback"
        case .other: return "Other"
        @unknown default: return "Unknown"
        }
    }
}
