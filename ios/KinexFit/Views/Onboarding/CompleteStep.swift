import SwiftUI

struct CompleteStep: View {
    let profile: TrainingProfile
    let isSubmitting: Bool
    let errorMessage: String?
    let onComplete: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Celebration header
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.green)

                    Text("You're All Set!")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Here's what we learned about you")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)

                // Summary
                VStack(spacing: 16) {
                    if let experience = profile.experienceLevel {
                        SummaryRow(
                            icon: experience.icon,
                            title: "Experience",
                            value: experience.displayName
                        )
                    }

                    if let days = profile.trainingDaysPerWeek {
                        SummaryRow(
                            icon: "calendar",
                            title: "Training Days",
                            value: "\(days) days per week"
                        )
                    }

                    if let duration = profile.sessionDuration {
                        SummaryRow(
                            icon: "clock",
                            title: "Session Duration",
                            value: "\(duration) minutes"
                        )
                    }

                    if !profile.equipment.isEmpty {
                        SummaryRow(
                            icon: "dumbbell",
                            title: "Equipment",
                            value: profile.equipment.map(\.displayName).joined(separator: ", ")
                        )
                    }

                    if !profile.goals.isEmpty {
                        SummaryRow(
                            icon: "target",
                            title: "Goals",
                            value: profile.goals.map(\.displayName).joined(separator: ", ")
                        )
                    }

                    if !profile.personalRecords.isEmpty {
                        SummaryRow(
                            icon: "trophy",
                            title: "Personal Records",
                            value: "\(profile.personalRecords.count) recorded"
                        )
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground).opacity(0.8))
                )
                .padding(.horizontal)

                // Benefits reminder
                VStack(alignment: .leading, spacing: 12) {
                    Text("What's Next?")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        BenefitText(text: "Start tracking your workouts")
                        BenefitText(text: "Use OCR to scan workout photos")
                        BenefitText(text: "Get AI-powered recommendations")
                        BenefitText(text: "Track your progress over time")
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground).opacity(0.8))
                )
                .padding(.horizontal)

                // Error message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.1))
                        )
                        .padding(.horizontal)
                }

                Spacer()
                    .frame(height: 100)
            }
        }
        .safeAreaInset(edge: .bottom) {
            // Complete button
            Button {
                onComplete()
            } label: {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Start Tracking")
                        Image(systemName: "arrow.right")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .fontWeight(.semibold)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isSubmitting)
            .padding(.horizontal)
            .padding(.vertical, 16)
            .background(Color(.systemBackground).opacity(0.95))
        }
    }
}

struct SummaryRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
            }

            Spacer()
        }
    }
}

struct BenefitText: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.caption)
                .foregroundStyle(.green)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Preview

#Preview {
    CompleteStep(
        profile: {
            var p = TrainingProfile()
            p.experienceLevel = .intermediate
            p.trainingDaysPerWeek = 4
            p.sessionDuration = 60
            p.equipment = [.fullGym]
            p.goals = [.strength, .muscleGain]
            return p
        }(),
        isSubmitting: false,
        errorMessage: nil,
        onComplete: {}
    )
}
