import SwiftUI

/// Promotional card for AI workout generation feature
/// Displayed on the Home tab to encourage users to try AI-generated workouts
struct AIFeatureCard: View {
    let onGenerateTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(AppTheme.accent)

                Text("Workout of the Week")
                    .font(.headline)
                    .foregroundStyle(AppTheme.primaryText)
            }

            // Description
            Text("Let AI create a personalized workout based on your goals and available equipment.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            // Generate button
            Button(action: onGenerateTapped) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Generate This Week's Workout")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.accent)
                .foregroundStyle(.black)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
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
