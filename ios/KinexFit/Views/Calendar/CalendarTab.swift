import SwiftUI

struct CalendarTab: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Training Calendar")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.primaryText)

                    Text("Calendar planning is coming soon. For now, keep building your library and use Stats to track consistency.")
                        .font(.body)
                        .foregroundStyle(AppTheme.secondaryText)

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Saved workouts remain available offline", systemImage: "checkmark.circle.fill")
                        Label("Workout sync continues in the background", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                        Label("Stats update automatically from your library", systemImage: "chart.bar.fill")
                    }
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    CalendarTab()
        .appDarkTheme()
}
