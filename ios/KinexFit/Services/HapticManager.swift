import Foundation
import UIKit
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "Haptics")

/// Manages haptic feedback for user interactions
@MainActor
final class HapticManager {
    static let shared = HapticManager()

    private init() {}

    // MARK: - Impact Feedback

    /// Light impact feedback
    func lightImpact() {
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()
        logger.debug("Light haptic feedback triggered")
    }

    /// Medium impact feedback
    func mediumImpact() {
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
        logger.debug("Medium haptic feedback triggered")
    }

    /// Heavy impact feedback
    func heavyImpact() {
        let feedback = UIImpactFeedbackGenerator(style: .heavy)
        feedback.impactOccurred()
        logger.debug("Heavy haptic feedback triggered")
    }

    /// Rigid impact feedback
    func rigidImpact() {
        let feedback = UIImpactFeedbackGenerator(style: .rigid)
        feedback.impactOccurred()
        logger.debug("Rigid haptic feedback triggered")
    }

    /// Soft impact feedback
    func softImpact() {
        let feedback = UIImpactFeedbackGenerator(style: .soft)
        feedback.impactOccurred()
        logger.debug("Soft haptic feedback triggered")
    }

    // MARK: - Notification Feedback

    /// Success notification feedback
    func success() {
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
        logger.debug("Success haptic feedback triggered")
    }

    /// Warning notification feedback
    func warning() {
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.warning)
        logger.debug("Warning haptic feedback triggered")
    }

    /// Error notification feedback
    func error() {
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.error)
        logger.debug("Error haptic feedback triggered")
    }

    // MARK: - Selection Feedback

    /// Selection changed feedback
    func selection() {
        let feedback = UISelectionFeedbackGenerator()
        feedback.selectionChanged()
        logger.debug("Selection haptic feedback triggered")
    }

    // MARK: - Conditional Feedback

    /// Trigger haptic feedback based on user preference
    func triggerIf(enabled: Bool, style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard enabled else { return }
        let feedback = UIImpactFeedbackGenerator(style: style)
        feedback.impactOccurred()
    }

    /// Trigger notification feedback based on user preference
    func notificationIf(enabled: Bool, type: UINotificationFeedbackGenerator.FeedbackType = .success) {
        guard enabled else { return }
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(type)
    }
}
