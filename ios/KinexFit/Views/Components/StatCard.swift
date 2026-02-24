import SwiftUI

/// Reusable stat card for displaying metrics in a 2x2 grid
/// Used on the Home tab to show workout statistics
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let iconColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(2)

                Spacer(minLength: 8)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 98)
        .padding(12)
        .kinexCard(cornerRadius: 14)
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
