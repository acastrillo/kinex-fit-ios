import SwiftUI

/// Reusable stat card for displaying metrics in a 2x2 grid
/// Used on the Home tab to show workout statistics
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let iconColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)

            Spacer()

            // Value and Title
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.primaryText)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
    }
}

// MARK: - Preview

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
        StatCard(
            title: "Workouts This Week",
            value: "3",
            icon: "target",
            iconColor: AppTheme.statTarget
        )

        StatCard(
            title: "Total Workouts",
            value: "47",
            icon: "dumbbell.fill",
            iconColor: AppTheme.statDumbbell
        )

        StatCard(
            title: "Hours Trained",
            value: "35",
            icon: "clock.fill",
            iconColor: AppTheme.statClock
        )

        StatCard(
            title: "Streak",
            value: "5 days",
            icon: "flame.fill",
            iconColor: AppTheme.statStreak
        )
    }
    .padding()
    .background(AppTheme.background)
    .preferredColorScheme(.dark)
}
