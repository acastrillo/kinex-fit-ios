import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var authViewModel: AuthViewModel
    @State private var showingQuickMenu = false
    @State private var showingSettings = false
    @State private var showingTimer = false

    var body: some View {
        VStack(spacing: 0) {
            KinexTopBar(
                onAccountTap: appState.isGuestMode ? nil : { showingSettings = true },
                onSignInTap: appState.isGuestMode ? { appState.exitGuestMode() } : nil,
                onMenuTap: { showingQuickMenu = true }
            )

            if appState.isGuestMode {
                TabView(selection: $appState.selectedMainTab) {
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
                }
            } else {
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

                    CalendarTab()
                        .tabItem {
                            Label(AppState.MainTab.calendar.title, systemImage: AppState.MainTab.calendar.icon)
                        }
                        .tag(AppState.MainTab.calendar)

                    MetricsTab()
                        .tabItem {
                            Label(AppState.MainTab.stats.title, systemImage: AppState.MainTab.stats.icon)
                        }
                        .tag(AppState.MainTab.stats)
                }
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .tint(AppTheme.accent)
        .environmentObject(appState.environment.storeManager)
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView {
                    await authViewModel.signOut()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            showingSettings = false
                        }
                        .foregroundStyle(AppTheme.accent)
                    }
                }
                .toolbarBackground(.hidden, for: .navigationBar)
            }
            .presentationBackground(AppTheme.background)
        }
        .sheet(isPresented: $showingQuickMenu) {
            KinexQuickMenuSheet { action in
                showingQuickMenu = false
                switch action {
                case .timer:
                    showingTimer = true
                case .bodyMetrics:
                    appState.navigateToTab(.stats)
                case .settings:
                    showingSettings = true
                }
            }
            .presentationDetents([PresentationDetent.height(320)])
            .presentationBackground(AppTheme.background)
        }
        .sheet(isPresented: $showingTimer) {
            WorkoutTimersView()
                .presentationBackground(AppTheme.background)
        }
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
        case .home: return "house"
        case .library: return "books.vertical"
        case .add: return "plus.circle.fill"
        case .stats: return "chart.bar"
        case .calendar: return "calendar"
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabView(authViewModel: .previewSignedIn)
        .environmentObject(AppState(environment: .preview))
}

enum KinexQuickMenuAction {
    case timer
    case bodyMetrics
    case settings
}

struct KinexTopBar: View {
    @EnvironmentObject private var appState: AppState
    /// Tap handler for the account icon. Pass `nil` in guest mode.
    let onAccountTap: (() -> Void)?
    /// Tap handler shown as "Sign In" button in guest mode. Pass `nil` for authenticated users.
    let onSignInTap: (() -> Void)?
    let onMenuTap: () -> Void

    @State private var scanLabel = "120 scans"
    @State private var hasLoadedQuota = false

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.accent)

                Text("Kinex Fit")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
            }

            Spacer(minLength: 8)

            HStack(spacing: 16) {
                if let onSignInTap {
                    Button(action: onSignInTap) {
                        Text("Sign In")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .buttonStyle(.plain)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)

                        Text("(\(scanLabel))")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    if let onAccountTap {
                        Button(action: onAccountTap) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppTheme.primaryText)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button(action: onMenuTap) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppTheme.background)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.separator)
                .frame(height: 1)
        }
        .task {
            await loadScanLabelIfNeeded()
        }
    }

    private func loadScanLabelIfNeeded() async {
        guard !hasLoadedQuota, !appState.isGuestMode else { return }
        hasLoadedQuota = true

        guard let user = try? await appState.environment.userRepository.getCurrentUser() else {
            return
        }

        await MainActor.run {
            if user.scanQuotaLimit == .max {
                scanLabel = "∞ scans"
            } else {
                scanLabel = "\(user.scanQuotaLimit) scans"
            }
        }
    }
}

struct KinexQuickMenuSheet: View {
    let onSelect: (KinexQuickMenuAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Capsule()
                .fill(AppTheme.tertiaryText.opacity(0.45))
                .frame(width: 42, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 8)

            Text("Quick Menu")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)

            KinexQuickMenuRow(
                icon: "timer",
                title: "Timer",
                action: { onSelect(.timer) }
            )

            KinexQuickMenuRow(
                icon: "scalemass",
                title: "Body Metrics",
                action: { onSelect(.bodyMetrics) }
            )

            KinexQuickMenuRow(
                icon: "gearshape",
                title: "Settings",
                action: { onSelect(.settings) }
            )
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.background.ignoresSafeArea())
    }
}

private struct KinexQuickMenuRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.tertiaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .kinexCard()
        }
        .buttonStyle(.plain)
    }
}

struct WorkoutTimersView: View {
    enum TimerMode: String, CaseIterable, Identifiable {
        case interval = "Interval Timer"
        case hiit = "HIIT Timer"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .interval: return "timer"
            case .hiit: return "bolt"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var selectedMode: TimerMode = .interval
    @State private var durationMinutes: Double = 1
    @State private var remainingSeconds = 60
    @State private var isRunning = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var totalSeconds: Int {
        max(Int(durationMinutes * 60), 1)
    }

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(remainingSeconds) / Double(totalSeconds)
    }

    private var statusText: String {
        if isRunning { return "In Progress" }
        if remainingSeconds == 0 { return "Complete" }
        return "Ready"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Workout Timers")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)

                    Text("Track your rest periods and HIIT workouts")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)

                    modeSelector

                    timerCard

                    detailsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            .padding(11)
                            .background(AppTheme.cardBackgroundElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .onReceive(ticker) { _ in
                guard isRunning else { return }
                guard remainingSeconds > 0 else {
                    isRunning = false
                    return
                }
                remainingSeconds -= 1
            }
            .onChange(of: durationMinutes) { _, _ in
                guard !isRunning else { return }
                remainingSeconds = totalSeconds
            }
        }
    }

    private var modeSelector: some View {
        HStack(spacing: 12) {
            ForEach(TimerMode.allCases) { mode in
                Button {
                    selectedMode = mode
                    isRunning = false
                    remainingSeconds = totalSeconds
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: mode.icon)
                        Text(mode.rawValue)
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(mode == selectedMode ? .white : AppTheme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(mode == selectedMode ? AppTheme.accent : AppTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(mode == selectedMode ? Color.clear : AppTheme.cardBorder, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var timerCard: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(AppTheme.cardBorder, lineWidth: 10)
                    .frame(width: 240, height: 240)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(AppTheme.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 240, height: 240)

                VStack(spacing: 6) {
                    Text(formatTime(remainingSeconds))
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppTheme.primaryText)

                    Text(statusText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .padding(.top, 6)

            HStack(spacing: 16) {
                Button {
                    if remainingSeconds == 0 {
                        remainingSeconds = totalSeconds
                    }
                    isRunning.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isRunning ? "pause.fill" : "play.fill")
                        Text(isRunning ? "Pause" : "Start")
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 11)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    isRunning = false
                    remainingSeconds = totalSeconds
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset")
                    }
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)

            HStack(spacing: 14) {
                Text("Duration:")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)

                Button {
                    guard !isRunning else { return }
                    durationMinutes = max(durationMinutes - 1, 1)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(width: 30, height: 30)
                        .background(AppTheme.cardBackgroundElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)

                Text("\(Int(durationMinutes))")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 52, height: 40)
                    .background(AppTheme.cardBackgroundElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button {
                    guard !isRunning else { return }
                    durationMinutes = min(durationMinutes + 1, 60)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(width: 30, height: 30)
                        .background(AppTheme.cardBackgroundElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)

                Text("minutes")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
            }

            HStack(spacing: 24) {
                HStack(spacing: 8) {
                    Image(systemName: "speaker.wave.2")
                    Text("Sound")
                }

                HStack(spacing: 8) {
                    Image(systemName: "bell.slash")
                    Text("Notify")
                }
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(AppTheme.secondaryText)
            .padding(.top, 2)
        }
        .padding(16)
        .kinexCard(cornerRadius: 18)
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(selectedMode.rawValue)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            Text("• Perfect for rest periods between sets")
            Text("• Set custom durations up to 60 minutes")
            Text("• Runs in background with notifications")
            Text("• Audio alerts when time is up")
        }
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(AppTheme.secondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .kinexCard(cornerRadius: 18, fill: AppTheme.cardBackgroundElevated)
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%02d:%02d", minutes, remainder)
    }
}
