import SwiftUI

struct SettingsView: View {
    @StateObject private var settingsManager = SettingsManager()
    @State private var showingDeleteAccount = false

    var body: some View {
        List {
            // Units Section
            Section("Units") {
                Picker("Preferred Units", selection: $settingsManager.settings.preferredUnits) {
                    ForEach(UnitSystem.allCases, id: \.self) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .onChange(of: settingsManager.settings.preferredUnits) { _, newValue in
                    settingsManager.updateUnits(newValue)
                }
            }

            // Appearance Section
            Section("Appearance") {
                Picker("Theme", selection: $settingsManager.settings.theme) {
                    ForEach(Theme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .onChange(of: settingsManager.settings.theme) { _, newValue in
                    settingsManager.updateTheme(newValue)
                }
            }

            // Notifications Section
            Section("Notifications") {
                Toggle("Workout Reminders", isOn: $settingsManager.settings.notificationsEnabled)
                    .onChange(of: settingsManager.settings.notificationsEnabled) { _, newValue in
                        settingsManager.updateNotifications(newValue)
                    }

                if settingsManager.settings.notificationsEnabled {
                    Text("Configure notification preferences for workout reminders and weekly updates.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Privacy & Legal Section
            Section("Privacy & Legal") {
                Link(destination: URL(string: "https://kinexfit.com/privacy")!) {
                    HStack {
                        Label("Privacy Policy", systemImage: "hand.raised")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Link(destination: URL(string: "https://kinexfit.com/terms")!) {
                    HStack {
                        Label("Terms of Service", systemImage: "doc.text")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Support Section
            Section("Support") {
                Link(destination: URL(string: "https://kinexfit.com/support")!) {
                    HStack {
                        Label("Support Center", systemImage: "lifepreserver")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Link(destination: URL(string: "mailto:support@kinexfit.com")!) {
                    HStack {
                        Label("Contact Support", systemImage: "envelope")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Account Section
            Section("Account") {
                Button(role: .destructive) {
                    showingDeleteAccount = true
                } label: {
                    Label("Delete Account", systemImage: "trash")
                }
            }

            // App Info Section
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.appVersion)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Build")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingDeleteAccount) {
            DeleteAccountView()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
    }
}
