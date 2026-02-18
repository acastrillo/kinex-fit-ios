import SwiftUI

/// Centralized theme definitions for Kinex Fit app
/// Dark theme with orange accent matching web app design
enum AppTheme {
    // MARK: - Primary Colors

    /// Primary accent color (orange) - used for buttons, selected tabs, highlights
    static let accent = Color(red: 1.0, green: 0.6, blue: 0.0) // Orange #FF9900

    /// Main background color (pure black)
    static let background = Color.black

    /// Card background color (dark gray)
    static let cardBackground = Color(red: 0.11, green: 0.11, blue: 0.118) // #1C1C1E

    /// Elevated card/surface (slightly lighter)
    static let cardBackgroundElevated = Color(red: 0.17, green: 0.17, blue: 0.18) // #2C2C2E

    // MARK: - Text Colors

    /// Primary text color (white)
    static let primaryText = Color.white

    /// Secondary text color (gray)
    static let secondaryText = Color(white: 0.6)

    /// Tertiary text color (darker gray)
    static let tertiaryText = Color(white: 0.4)

    // MARK: - Stat Icon Colors

    /// Target/goal icon color (orange)
    static let statTarget = accent

    /// Dumbbell/workout icon color (soft blue)
    static let statDumbbell = Color(red: 0.4, green: 0.6, blue: 0.8) // Faded blue

    /// Clock/time icon color (teal/cyan)
    static let statClock = Color(red: 0.0, green: 0.8, blue: 0.8) // Teal

    /// Streak/flame icon color (green)
    static let statStreak = Color(red: 0.3, green: 0.85, blue: 0.4) // Green

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
}
