import SwiftUI

struct EquipmentStep: View {
    @Binding var selection: Set<Equipment>
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("What equipment do you have?")
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
            VStack(spacing: 16) {
                ForEach(Equipment.allCases, id: \.self) { equipment in
                    EquipmentCard(
                        equipment: equipment,
                        isSelected: selection.contains(equipment),
                        onToggle: {
                            if selection.contains(equipment) {
                                selection.remove(equipment)
                            } else {
                                selection.insert(equipment)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)

            Spacer()

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
            .padding(.bottom, 32)
        }
    }
}

struct EquipmentCard: View {
    let equipment: Equipment
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: equipment.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .frame(width: 32)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(equipment.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(equipment.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Checkbox
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundStyle(isSelected ? .blue : .secondary)
            }
            .padding()
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
    EquipmentStep(selection: .constant([.fullGym, .homeGym]), onContinue: {})
}
