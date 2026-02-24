import SwiftUI

/// Promotional card for AI workout generation feature
/// Displayed on the Home tab to encourage users to try AI-generated workouts
struct AIFeatureCard: View {
    let onGenerateTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Workout of the Week")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)

                    Text("Your free AI-generated weekly workout plan")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.top, 8)

                Text("Get Your AI Workout")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                Text("AI workout tailored to your training profile.\nFresh every week!")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)

            Button(action: onGenerateTapped) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Generate This Week's Workout")
                }
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: AppTheme.accent.opacity(0.38), radius: 16, y: 7)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .kinexCard(cornerRadius: 18)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        AIFeatureCard {
            print("Generate tapped")
        }
    }
    .padding()
    .background(AppTheme.background)
    .preferredColorScheme(.dark)
}
