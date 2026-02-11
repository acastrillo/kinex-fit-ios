import SwiftUI

struct ProfileTab: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var authViewModel: AuthViewModel
    @State private var showingSignOutConfirmation = false

    private var user: User? {
        authViewModel.authState.user
    }

    var body: some View {
        NavigationStack {
            List {
                // User Info Section
                if let user {
                    Section {
                        HStack(spacing: 16) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.blue)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.displayName)
                                    .font(.headline)

                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    // Subscription Section
                    Section("Subscription") {
                        HStack {
                            Label("Plan", systemImage: "crown")
                            Spacer()
                            Text(user.subscriptionTier.displayName)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Label("Scans Used", systemImage: "doc.text.viewfinder")
                            Spacer()
                            Text("\(user.scanQuotaUsed) / \(user.subscriptionTier.scanLimit == .max ? "∞" : String(user.subscriptionTier.scanLimit))")
                                .foregroundStyle(.secondary)
                        }

                        if user.subscriptionTier == .free {
                            Button {
                                // TODO: Show paywall
                            } label: {
                                HStack {
                                    Text("Upgrade to Pro")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                            }
                        }
                    }
                }

                // App Section
                Section("App") {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }

                    NavigationLink {
                        HelpView()
                    } label: {
                        Label("Help & Support", systemImage: "questionmark.circle")
                    }
                }

                // Account Section
                Section {
                    Button(role: .destructive) {
                        showingSignOutConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                            Spacer()
                        }
                    }
                }

                // Version Info
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.appVersion)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Profile")
            .confirmationDialog(
                "Sign Out",
                isPresented: $showingSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    Task {
                        await authViewModel.signOut()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
}

// MARK: - Bundle Extension

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Preview

#Preview {
    ProfileTab(authViewModel: .previewSignedIn)
        .environmentObject(AppState(environment: .preview))
}
