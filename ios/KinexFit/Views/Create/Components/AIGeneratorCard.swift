import SwiftUI

/// Featured AI Workout Generator card
struct AIGeneratorCard: View {
    let onGenerate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(.orange)

                Text("AI Workout Generator")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            // Description
            Text("Describe your workout in plain English. AI creates a complete plan with exercises, sets, and weights.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            // Feature chips
            HStack(spacing: 8) {
                FeatureChip(icon: "person.fill", text: "Personalized to your PRs")
                FeatureChip(icon: "dumbbell.fill", text: "Equipment-aware")
                FeatureChip(icon: "target", text: "Goal-optimized")
            }
            .font(.caption)

            // Generate button
            Button(action: onGenerate) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Generate Workout")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

/// Small feature chip for AI capabilities
private struct FeatureChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.15))
        .foregroundStyle(.orange)
        .cornerRadius(6)
    }
}

#Preview {
    AIGeneratorCard {
        print("Generate tapped")
    }
    .padding()
    .preferredColorScheme(.dark)
}
