import SwiftUI

/// Centralized theme definitions for Kinex Fit app
/// Dark theme with orange accent matching web app design
enum AppTheme {
    // MARK: - Primary Colors

    /// Primary accent color used by CTA buttons and active navigation states.
    static let accent = Color(red: 1.0, green: 0.42, blue: 0.21) // #FF6B35

    /// Accent tint for soft fills/chips.
    static let accentMuted = Color(red: 0.52, green: 0.24, blue: 0.12)

    /// Main page background.
    static let background = Color(red: 0.02, green: 0.03, blue: 0.06) // #05080F

    /// Card background color.
    static let cardBackground = Color(red: 0.06, green: 0.07, blue: 0.10) // #10121A

    /// Elevated card/surface.
    static let cardBackgroundElevated = Color(red: 0.09, green: 0.10, blue: 0.14) // #171A24

    /// Default card border.
    static let cardBorder = Color.white.opacity(0.09)

    /// Subtle separator line color.
    static let separator = Color.white.opacity(0.08)

    // MARK: - Text Colors

    /// Primary text color (white)
    static let primaryText = Color.white

    /// Secondary text color
    static let secondaryText = Color(red: 0.64, green: 0.66, blue: 0.71)

    /// Tertiary text color
    static let tertiaryText = Color(red: 0.46, green: 0.48, blue: 0.54)

    // MARK: - Stat Icon Colors

    /// Target/goal icon color (orange)
    static let statTarget = accent

    /// Dumbbell/workout icon color
    static let statDumbbell = Color(red: 0.23, green: 0.27, blue: 0.34)

    /// Clock/time icon color
    static let statClock = Color(red: 0.20, green: 0.53, blue: 1.00)

    /// Streak/flame icon color (green)
    static let statStreak = Color(red: 0.11, green: 0.84, blue: 0.58)

    // MARK: - Semantic Colors

    /// Success/positive color
    static let success = Color.green

    /// Error/destructive color
    static let error = Color.red

    /// Warning color
    static let warning = Color.yellow

    // MARK: - AI Feature Colors

    /// AI sparkle/feature color
    static let aiAccent = accent
}

// MARK: - View Extension for Dark Theme

extension View {
    /// Apply the app's dark theme
    func appDarkTheme() -> some View {
        self
            .preferredColorScheme(.dark)
            .tint(AppTheme.accent)
    }

    /// Shared Kinex card treatment.
    func kinexCard(cornerRadius: CGFloat = 16, fill: Color = AppTheme.cardBackground) -> some View {
        self
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            }
    }
}
