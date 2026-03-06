import SwiftUI

/// Banner shown when there are pending social imports (Instagram or TikTok)
struct PendingImportsBanner: View {
    @EnvironmentObject private var appState: AppState
    @Binding var selectedImport: InstagramImport?
    @Binding var showingImportReview: Bool

    private var instagramService: InstagramImportService { appState.instagramImportService }
    private var tiktokService: TikTokImportService { appState.tiktokImportService }

    private var totalPendingCount: Int {
        instagramService.pendingCount + tiktokService.pendingCount
    }

    private var hasPendingImports: Bool { totalPendingCount > 0 }

    /// First pending import from whichever service has one
    private var firstPendingImport: InstagramImport? {
        tiktokService.pendingImports.first ?? instagramService.pendingImports.first
    }

    private var bannerLabel: String {
        if tiktokService.hasPendingImports && instagramService.hasPendingImports {
            return "Social Import"
        }
        return tiktokService.hasPendingImports ? "TikTok Import" : "Instagram Import"
    }

    private var bannerIcon: String {
        if tiktokService.hasPendingImports && !instagramService.hasPendingImports {
            return "play.rectangle.fill"
        }
        return tiktokService.hasPendingImports ? "square.and.arrow.down.fill" : "camera.on.rectangle.fill"
    }

    private var bannerGradient: LinearGradient {
        if tiktokService.hasPendingImports && !instagramService.hasPendingImports {
            return LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing)
        }
        return LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing)
    }

    var body: some View {
        if hasPendingImports {
            Button {
                if let first = firstPendingImport {
                    selectedImport = first
                    showingImportReview = true
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: bannerIcon)
                        .font(.title3)
                        .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(bannerLabel)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)

                        Text("\(totalPendingCount) workout\(totalPendingCount == 1 ? "" : "s") ready to import")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding()
                .background(bannerGradient)
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
