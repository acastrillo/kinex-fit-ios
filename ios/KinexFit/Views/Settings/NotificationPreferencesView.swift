import SwiftUI

/// Notification preferences and settings
struct NotificationPreferencesView: View {
    @EnvironmentObject private var appState: AppState
    @State private var user: User?
    @State private var enableReminders = true
    @State private var enableMilestones = true
    @State private var enableAchievements = true
    @State private var reminderTime = Date(timeIntervalSince1970: 0)
    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                Text("Notification Preferences")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.bottom, 10)

                // Workout Reminders
                Section {
                    VStack(spacing: 12) {
                        Toggle(isOn: $enableReminders) {
                            HStack(spacing: 12) {
                                Image(systemName: "bell.fill")
                                    .foregroundStyle(AppTheme.accent)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Workout Reminders")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Get reminded about your scheduled workouts")
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                                Spacer()
                            }
                            .padding(12)
                            .contentShape(Rectangle())
                        }
                        .toggleStyle(.switch)

                        if enableReminders {
                            DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                                .padding(.horizontal, 12)
                        }
                    }
                    .padding(12)
                    .background(AppTheme.cardBackgroundElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } header: {
                    Text("WORKOUTS").font(.system(size: 12, weight: .semibold)).foregroundStyle(AppTheme.secondaryText)
                }

                // Achievements
                Section {
                    Toggle(isOn: $enableMilestones) {
                        HStack(spacing: 12) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Milestone Notifications")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Celebrate achievements (50 workouts, etc)")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .contentShape(Rectangle())
                    }
                    .toggleStyle(.switch)

                    Toggle(isOn: $enableAchievements) {
                        HStack(spacing: 12) {
                            Image(systemName: "medal.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Achievement Badges")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Earn badges for consistency and PRs")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .contentShape(Rectangle())
                    }
                    .toggleStyle(.switch)
                } header: {
                    Text("ACHIEVEMENTS").font(.system(size: 12, weight: .semibold)).foregroundStyle(AppTheme.secondaryText)
                }

                // System
                Section {
                    Toggle(isOn: Binding(
                        get: { user?.enableNotificationSound ?? true },
                        set: { _ in }
                    )) {
                        HStack(spacing: 12) {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundStyle(AppTheme.accent)
                            Text("Notification Sounds")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                        .padding(12)
                        .contentShape(Rectangle())
                    }
                    .toggleStyle(.switch)

                    Toggle(isOn: Binding(
                        get: { user?.enableNotificationHaptics ?? true },
                        set: { _ in }
                    )) {
                        HStack(spacing: 12) {
                            Image(systemName: "iphone.radiowaves.left.and.right")
                                .foregroundStyle(AppTheme.accent)
                            Text("Haptic Feedback")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                        .padding(12)
                        .contentShape(Rectangle())
                    }
                    .toggleStyle(.switch)
                } header: {
                    Text("FEEDBACK").font(.system(size: 12, weight: .semibold)).foregroundStyle(AppTheme.secondaryText)
                }

                // Save Button
                Button {
                    Task {
                        await savePreferences()
                    }
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Save Preferences")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Spacer()
            }
            .padding(16)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .task {
            await loadUser()
        }
    }

    private func loadUser() async {
        user = try? await appState.environment.userRepository.getCurrentUser()
    }

    private func savePreferences() async {
        isSaving = true

        guard var user = user else {
            isSaving = false
            return
        }

        user.enableNotificationSound = true
        user.enableNotificationHaptics = true

        do {
            try await appState.environment.userRepository.updateUser(user)
            isSaving = false
        } catch {
            isSaving = false
        }
    }
}

#Preview {
    NotificationPreferencesView()
        .environmentObject(AppState(environment: .preview))
}
