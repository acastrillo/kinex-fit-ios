import SwiftUI

/// Featured AI Workout Generator card
struct AIGeneratorCard: View {
    let onGenerate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)

                Text("AI Workout Generator")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
            }

            Text("Describe your workout in plain English. AI creates a complete plan with exercises, sets, and weights.")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(3)

            ViewThatFits(in: .vertical) {
                HStack(spacing: 7) {
                    FeatureChip(icon: "person.fill", text: "Personalized to your PRs")
                    FeatureChip(icon: "dumbbell.fill", text: "Equipment-aware")
                    FeatureChip(icon: "target", text: "Goal-optimized")
                }

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 7) {
                        FeatureChip(icon: "person.fill", text: "Personalized to your PRs")
                        FeatureChip(icon: "dumbbell.fill", text: "Equipment-aware")
                    }

                    FeatureChip(icon: "target", text: "Goal-optimized")
                }
            }

            Button(action: onGenerate) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Generate Workout")
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 18, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppTheme.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: AppTheme.accent.opacity(0.35), radius: 14, y: 6)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .kinexCard(cornerRadius: 18)
    }
}

/// Small feature chip for AI capabilities
private struct FeatureChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(AppTheme.cardBackgroundElevated)
        .foregroundStyle(AppTheme.secondaryText)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

#Preview {
    AIGeneratorCard {
        print("Generate tapped")
    }
    .padding()
    .preferredColorScheme(.dark)
}
