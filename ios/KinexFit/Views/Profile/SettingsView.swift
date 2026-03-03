import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var user: User?
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var isSavingProfile = false
    @State private var showingDeleteAccount = false
    @State private var showPaywall = false
    @State private var showingTrainingProfile = false
    @State private var showingOnboarding = false

    let onAccountDeleted: () async -> Void

    init(onAccountDeleted: @escaping () async -> Void = {}) {
        self.onAccountDeleted = onAccountDeleted
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                profileCard

                settingsSection(title: "Subscription") {
                    SettingsRow(
                        icon: "crown",
                        title: "Manage Subscription",
                        subtitle: "Current plan: \(user?.subscriptionTier.displayName ?? "Free")",
                        action: { showPaywall = true }
                    )
                }

                if user?.role?.isAdmin == true {
                    settingsSection(title: "Administration") {
                        SettingsRow(
                            icon: "shield",
                            title: "Admin Panel",
                            subtitle: "Manage users, settings, and system logs",
                            action: { }
                        )
                    }
                }

                settingsSection(title: "Stats & Progress") {
                    SettingsRow(
                        icon: "arrow.up.right",
                        title: "Personal Records",
                        subtitle: "View your PRs and strength progression",
                        action: {
                            appState.navigateToTab(.stats)
                            dismiss()
                        }
                    )

                    SettingsRow(
                        icon: "waveform.path.ecg",
                        title: "Body Metrics",
                        subtitle: "Track weight, measurements, and body composition",
                        action: {
                            appState.navigateToTab(.stats)
                            dismiss()
                        }
                    )

                    SettingsRow(
                        icon: "target",
                        title: "Training Profile",
                        subtitle: "Set goals and preferences for AI-powered workouts",
                        action: { showingTrainingProfile = true }
                    )

                    if user?.skipOnboardingAt != nil && !user?.onboardingCompleted ?? false {
                        SettingsRow(
                            icon: "checkmark.circle",
                            title: "Complete Your Profile",
                            subtitle: "Finish setting up your training profile",
                            action: { showingOnboarding = true }
                        )
                    }
                }

                settingsSection(title: "Appearance") {
                    Menu {
                        ForEach(AppThemeMode.allCases, id: \.self) { mode in
                            Button(mode.displayName) {
                                if var user = user {
                                    user.preferredTheme = mode
                                    Task {
                                        try? await appState.environment.userRepository.updateUser(user)
                                        await loadUser()
                                    }
                                }
                            }
                        }
                    } label: {
                        SettingsRow(
                            icon: "moon.stars",
                            title: "Theme",
                            subtitle: user?.preferredTheme.displayName ?? "System",
                            action: {}
                        )
                    }
                }

                settingsSection(title: "Notifications") {
                    Toggle(isOn: Binding(
                        get: { user?.enableNotificationSound ?? true },
                        set: { enabled in
                            if var user = user {
                                user.enableNotificationSound = enabled
                                Task {
                                    try? await appState.environment.userRepository.updateUser(user)
                                    await loadUser()
                                }
                            }
                        }
                    )) {
                        HStack(spacing: 12) {
                            Image(systemName: "speaker.wave.2")
                                .foregroundStyle(AppTheme.secondaryText)
                                .frame(width: 34, height: 34)
                                .background(AppTheme.cardBackgroundElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Notification Sounds")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(AppTheme.primaryText)
                                Text("Play sounds for alerts and reminders")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            Spacer()
                        }
                        .padding(12)
                    }
                    .toggleStyle(.switch)

                    Toggle(isOn: Binding(
                        get: { user?.enableNotificationHaptics ?? true },
                        set: { enabled in
                            if var user = user {
                                user.enableNotificationHaptics = enabled
                                Task {
                                    try? await appState.environment.userRepository.updateUser(user)
                                    await loadUser()
                                }
                            }
                        }
                    )) {
                        HStack(spacing: 12) {
                            Image(systemName: "iphone.radiowaves.left.and.right")
                                .foregroundStyle(AppTheme.secondaryText)
                                .frame(width: 34, height: 34)
                                .background(AppTheme.cardBackgroundElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Haptic Feedback")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(AppTheme.primaryText)
                                Text("Vibration for interactions")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            Spacer()
                        }
                        .padding(12)
                    }
                    .toggleStyle(.switch)
                }

                settingsSection(title: "Data") {
                    SettingsRow(
                        icon: "trash",
                        title: "Delete Account",
                        subtitle: "Permanently remove your account",
                        titleColor: AppTheme.error,
                        action: { showingDeleteAccount = true }
                    )
                }

                settingsSection(title: "Support") {
                    NavigationLink {
                        HelpView()
                    } label: {
                        HStack(spacing: 12) {
                            SettingsRowIcon(icon: "questionmark.circle")
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Help & FAQ")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(AppTheme.primaryText)

                                Text("Get help and find answers")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.tertiaryText)
                        }
                        .padding(12)
                    }
                    .buttonStyle(.plain)
                }

                footer
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 34)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await loadUser()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showingDeleteAccount) {
            DeleteAccountView(onAccountDeleted: onAccountDeleted)
        }
        .sheet(isPresented: $showingTrainingProfile) {
            TrainingProfileSettingsView()
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingCoordinator(onComplete: {
                showingOnboarding = false
                Task {
                    await loadUser()
                }
            })
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Settings")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            Text("Manage your account and app preferences")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profile")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            Text("Your personal information")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)

            profileField(title: "First Name", text: $firstName)
            profileField(title: "Last Name", text: $lastName)
            profileField(title: "Email", text: $email, editable: false)

            Text("Contact support to change your email address")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)

            HStack {
                Spacer()

                Button {
                    Task {
                        await saveProfile()
                    }
                } label: {
                    Text(isSavingProfile ? "Saving..." : "Save Changes")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(AppTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: AppTheme.accent.opacity(0.32), radius: 12, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(isSavingProfile)
            }
        }
        .padding(16)
        .kinexCard(cornerRadius: 18)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Text("Spotter")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)

            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)

            Text("Made with ❤️ for fitness enthusiasts")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            VStack(spacing: 0) {
                content()
            }
            .kinexCard(cornerRadius: 18)
        }
    }

    private func profileField(title: String, text: Binding<String>, editable: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.primaryText)

            TextField("", text: text)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(editable ? AppTheme.primaryText : AppTheme.secondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(AppTheme.cardBackgroundElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                }
                .disabled(!editable)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
        }
    }

    private func loadUser() async {
        guard let currentUser = try? await appState.environment.userRepository.getCurrentUser() else { return }
        user = currentUser
        firstName = currentUser.firstName ?? ""
        lastName = currentUser.lastName ?? ""
        email = currentUser.email
    }

    private func saveProfile() async {
        guard var existingUser = user else { return }

        isSavingProfile = true
        defer { isSavingProfile = false }

        existingUser.firstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        existingUser.lastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        existingUser.updatedAt = Date()

        do {
            try await appState.environment.userRepository.save(existingUser)
            try await appState.environment.userRepository.syncUserSettings(existingUser)
            user = existingUser
        } catch {
            // No-op fallback for now. Keeping UX stable during visual redesign.
        }
    }
}

private struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var titleColor: Color = AppTheme.primaryText
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SettingsRowIcon(icon: icon)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(titleColor)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.tertiaryText)
            }
            .padding(12)
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsRowIcon: View {
    let icon: String

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(AppTheme.secondaryText)
            .frame(width: 34, height: 34)
            .background(AppTheme.cardBackgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppState(environment: .preview))
    }
}
