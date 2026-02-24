import SwiftUI

/// Divider component for separating AI generator from import options
struct WorkoutDivider: View {
    var body: some View {
        HStack(spacing: 16) {
            Rectangle()
                .fill(AppTheme.separator)
                .frame(height: 1)

            Text("OR GENERATE WITH AI")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize()

            Rectangle()
                .fill(AppTheme.separator)
                .frame(height: 1)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    WorkoutDivider()
        .padding()
        .preferredColorScheme(.dark)
}
