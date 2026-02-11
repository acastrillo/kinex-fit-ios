import SwiftUI

struct GoalsStep: View {
    @Binding var selection: Set<TrainingGoal>
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "target")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)

                    Text("What are your goals?")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("Select all that apply")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)
                .padding(.horizontal)

                // Options
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(TrainingGoal.allCases, id: \.self) { goal in
                        GoalCard(
                            goal: goal,
                            isSelected: selection.contains(goal),
                            onToggle: {
                                if selection.contains(goal) {
                                    selection.remove(goal)
                                } else {
                                    selection.insert(goal)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)

                Spacer()
                    .frame(height: 100)
            }
        }
        .safeAreaInset(edge: .bottom) {
            // Continue button
            Button {
                onContinue()
            } label: {
                HStack {
                    Text("Continue")
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(!selection.isEmpty ? Color.blue : Color.gray)
                .foregroundStyle(.white)
                .fontWeight(.semibold)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(selection.isEmpty)
            .padding(.horizontal)
            .padding(.vertical, 16)
            .background(Color(.systemBackground).opacity(0.95))
        }
    }
}

struct GoalCard: View {
    let goal: TrainingGoal
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 12) {
                // Icon
                Image(systemName: goal.icon)
                    .font(.largeTitle)
                    .foregroundStyle(isSelected ? .blue : .secondary)

                // Title
                Text(goal.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                // Description
                Text(goal.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .blue : .secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 160)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground).opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    GoalsStep(selection: .constant([.strength, .muscleGain]), onContinue: {})
}
