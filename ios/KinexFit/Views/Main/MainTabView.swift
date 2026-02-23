import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var authViewModel: AuthViewModel

    var body: some View {
        TabView(selection: $appState.selectedMainTab) {
            HomeTab()
                .tabItem {
                    Label(AppState.MainTab.home.title, systemImage: AppState.MainTab.home.icon)
                }
                .tag(AppState.MainTab.home)

            WorkoutsTab()
                .tabItem {
                    Label(AppState.MainTab.library.title, systemImage: AppState.MainTab.library.icon)
                }
                .tag(AppState.MainTab.library)

            CreateWorkoutView()
                .tabItem {
                    Label(AppState.MainTab.add.title, systemImage: AppState.MainTab.add.icon)
                }
                .tag(AppState.MainTab.add)

            MetricsTab()
                .tabItem {
                    Label(AppState.MainTab.stats.title, systemImage: AppState.MainTab.stats.icon)
                }
                .tag(AppState.MainTab.stats)

            CalendarTab()
                .tabItem {
                    Label(AppState.MainTab.calendar.title, systemImage: AppState.MainTab.calendar.icon)
                }
                .tag(AppState.MainTab.calendar)
        }
        .tint(AppTheme.accent)
        .environmentObject(appState.environment.storeManager)
    }
}

private extension AppState.MainTab {
    var title: String {
        switch self {
        case .home: return "Home"
        case .library: return "Library"
        case .add: return "Add"
        case .stats: return "Stats"
        case .calendar: return "Calendar"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .library: return "books.vertical.fill"
        case .add: return "plus.circle.fill"
        case .stats: return "chart.bar.fill"
        case .calendar: return "calendar"
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabView(authViewModel: .previewSignedIn)
        .environmentObject(AppState(environment: .preview))
}
