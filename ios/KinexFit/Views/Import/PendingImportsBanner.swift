import SwiftUI

/// Banner shown when there are pending Instagram imports
struct PendingImportsBanner: View {
    @EnvironmentObject private var appState: AppState
    @Binding var selectedImport: InstagramImport?
    @Binding var showingImportReview: Bool

    private var importService: InstagramImportService {
        appState.instagramImportService
    }

    var body: some View {
        if importService.hasPendingImports {
            Button {
                if let firstImport = importService.pendingImports.first {
                    selectedImport = firstImport
                    showingImportReview = true
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "camera.on.rectangle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Instagram Import")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)

                        Text("\(importService.pendingCount) workout\(importService.pendingCount == 1 ? "" : "s") ready to import")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [.pink, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }
}

/// Smaller badge for tab bar or navigation
struct PendingImportsBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.pink)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Preview

#Preview("Banner") {
    VStack {
        PendingImportsBanner(
            selectedImport: .constant(nil),
            showingImportReview: .constant(false)
        )
        .padding()

        Spacer()
    }
    .environmentObject(AppState(environment: .preview))
}

#Preview("Badge") {
    HStack {
        Text("Workouts")
        PendingImportsBadge(count: 3)
    }
}
