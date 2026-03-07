import SwiftUI

struct QuickProfileStep: View {
    let onComplete: (TrainingGoal?) -> Void

    @State private var selectedGoal: TrainingGoal?

    private let goals: [(goal: TrainingGoal, label: String, icon: String)] = [
        (.buildMuscleHypertrophy, "Build Muscle", "figure.strengthtraining.traditional"),
        (.increaseStrengthPowerlifting, "Get Stronger", "bolt.fill"),
        (.loseFatWeightLoss, "Lose Fat", "flame.fill"),
        (.improveCardiovascularEndurance, "Improve Cardio", "heart.fill"),
        (.generalFitnessHealthMaintenance, "General Fitness", "star.fill"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 8) {
                Text("One quick thing...")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.primaryText)

                Text("What's your main goal?")
                    .font(.body)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)

            Spacer().frame(height: 32)

            VStack(spacing: 12) {
                ForEach(goals, id: \.goal) { item in
                    GoalRow(
                        icon: item.icon,
                        label: item.label,
                        isSelected: selectedGoal == item.goal
                    ) {
                        selectedGoal = item.goal
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 14) {
                Button(action: {
                    saveAndContinue()
                }) {
                    Text(selectedGoal == nil ? "Skip" : "Continue")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(selectedGoal == nil ? AppTheme.secondaryText : AppTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .animation(.easeInOut(duration: 0.15), value: selectedGoal)
                }
                .accessibilityLabel(selectedGoal == nil ? "Skip goal selection" : "Continue with selected goal")

                if selectedGoal != nil {
                    Button(action: { onComplete(nil) }) {
                        Text("Skip")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    private func saveAndContinue() {
        if let goal = selectedGoal {
            // Persist locally — will be synced on sign-up
            UserDefaults.standard.set(goal.rawValue, forKey: "guest_primaryGoal")
        }
        onComplete(selectedGoal)
    }
}

private struct GoalRow: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? .white : AppTheme.accent)
                    .frame(width: 32)

                Text(label)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : AppTheme.primaryText)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AppTheme.accent : AppTheme.accent.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppTheme.accent : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label)\(isSelected ? ", selected" : "")")
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
