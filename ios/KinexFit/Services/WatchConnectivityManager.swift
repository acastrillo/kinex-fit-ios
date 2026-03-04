import Foundation
import WatchConnectivity
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "WatchConnectivity")

/// Manages communication with Apple Watch companion app
final class WatchConnectivityManager: NSObject, WCSessionDelegate, ObservableObject {
    @Published var isWatchPaired: Bool = false
    @Published var isWatchAppInstalled: Bool = false

    static let shared = WatchConnectivityManager()

    private var session: WCSession?

    override init() {
        super.init()
        setupWatchConnectivity()
    }

    // MARK: - Setup

    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            logger.warning("WatchConnectivity not supported on this device")
            return
        }

        session = WCSession.default
        session?.delegate = self
        session?.activate()
        logger.info("WatchConnectivity session activated")
    }

    // MARK: - Messaging

    /// Send workout data to Watch
    func sendWorkoutToWatch(
        title: String,
        duration: TimeInterval,
        exerciseCount: Int
    ) {
        guard let session = session, session.isReachable else {
            logger.warning("Watch not reachable")
            return
        }

        let message: [String: Any] = [
            "type": "workout",
            "title": title,
            "duration": duration,
            "exerciseCount": exerciseCount,
            "timestamp": Date().timeIntervalSince1970,
        ]

        session.sendMessage(message, replyHandler: { _ in
            logger.info("Workout data sent to Watch")
        }, errorHandler: { error in
            logger.error("Failed to send workout to Watch: \(error.localizedDescription)")
        })
    }

    /// Send timer update to Watch
    func sendTimerUpdate(elapsed: TimeInterval, remaining: TimeInterval, phase: String) {
        guard let session = session, session.isReachable else { return }

        let message: [String: Any] = [
            "type": "timer-update",
            "elapsed": elapsed,
            "remaining": remaining,
            "phase": phase,
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            logger.error("Failed to send timer update to Watch: \(error.localizedDescription)")
        }
    }

    /// Send body metrics to Watch
    func sendBodyMetrics(_ metrics: [String: Double]) {
        guard let session = session else { return }

        var message: [String: Any] = ["type": "metrics"]
        message.merge(metrics) { _, new in new }

        session.sendMessage(message, replyHandler: nil) { error in
            logger.error("Failed to send metrics to Watch: \(error.localizedDescription)")
        }
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isWatchPaired = activationState == .activated
            if let error = error {
                logger.error("Watch activation error: \(error.localizedDescription)")
            } else {
                logger.info("Watch session activated: \(activationState == .activated)")
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchPaired = false
            logger.info("Watch session became inactive")
        }
    }

    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchPaired = false
            logger.info("Watch session deactivated")
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        logger.debug("Received message from Watch: \(message)")

        // Handle incoming messages from Watch
        if let type = message["type"] as? String {
            switch type {
            case "start-workout":
                logger.info("Watch requested workout start")
            case "pause-workout":
                logger.info("Watch requested workout pause")
            case "log-metric":
                logger.info("Watch requested metric logging")
            default:
                logger.debug("Unknown Watch message type: \(type)")
            }
        }
    }

    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        logger.debug("Received application context from Watch: \(applicationContext)")
    }

    #if os(iOS)
    func sessionDidInstallValueStore(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchAppInstalled = true
            logger.info("Watch app installed")
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchPaired = session.isPaired
            logger.info("Watch paired state changed: \(session.isPaired)")
        }
    }
    #endif
}
