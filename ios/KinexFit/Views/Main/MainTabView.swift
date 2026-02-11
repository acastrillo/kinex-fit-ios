import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var authViewModel: AuthViewModel

    @State private var selectedTab: Tab = .home

    enum Tab: String, CaseIterable {
        case home
        case library
        case add
        case stats
        case profile

        var title: String {
            switch self {
            case .home: return "Home"
            case .library: return "Library"
            case .add: return "Add"
            case .stats: return "Stats"
            case .profile: return "Profile"
            }
        }

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .library: return "books.vertical.fill"
            case .add: return "plus.circle.fill"
            case .stats: return "chart.bar.fill"
            case .profile: return "person.circle"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeTab()
                .tabItem {
                    Label(Tab.home.title, systemImage: Tab.home.icon)
                }
                .tag(Tab.home)

            WorkoutsTab()
                .tabItem {
                    Label(Tab.library.title, systemImage: Tab.library.icon)
                }
                .tag(Tab.library)

            AddWorkoutTab()
                .tabItem {
                    Label(Tab.add.title, systemImage: Tab.add.icon)
                }
                .tag(Tab.add)

            MetricsTab()
                .tabItem {
                    Label(Tab.stats.title, systemImage: Tab.stats.icon)
                }
                .tag(Tab.stats)

            ProfileTab(authViewModel: authViewModel)
                .tabItem {
                    Label(Tab.profile.title, systemImage: Tab.profile.icon)
                }
                .tag(Tab.profile)
        }
        .tint(AppTheme.accent)
        .preferredColorScheme(.dark)
        .environmentObject(appState.environment.storeManager)
    }
}

// MARK: - Preview

#Preview {
    MainTabView(authViewModel: .previewSignedIn)
        .environmentObject(AppState(environment: .preview))
}
