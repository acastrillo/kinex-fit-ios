import SwiftUI

/// Divider component for separating AI generator from import options
struct WorkoutDivider: View {
    var body: some View {
        HStack(spacing: 16) {
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 1)

            Text("OR IMPORT EXISTING WORKOUT")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .fixedSize()

            Rectangle()
                .fill(Color(.systemGray5))
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
