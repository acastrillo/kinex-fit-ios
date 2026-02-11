import SwiftUI

struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var confirmationText = ""
    @State private var isDeleting = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var canDelete: Bool {
        confirmationText.uppercased() == "DELETE"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Warning Icon
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.red)
                        .padding(.top, 32)

                    // Warning Text
                    VStack(spacing: 12) {
                        Text("Delete Account")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("This action cannot be undone")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // What Will Be Deleted
                    VStack(alignment: .leading, spacing: 16) {
                        Text("The following data will be permanently deleted:")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            Label("All your workouts", systemImage: "list.bullet")
                            Label("Body metrics and progress", systemImage: "chart.line.uptrend.xyaxis")
                            Label("Personal records", systemImage: "trophy")
                            Label("Account information", systemImage: "person")
                            Label("Subscription data", systemImage: "creditcard")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Confirmation Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type 'DELETE' to confirm")
                            .font(.headline)

                        TextField("DELETE", text: $confirmationText)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
                    }

                    // Delete Button
                    Button(role: .destructive) {
                        deleteAccount()
                    } label: {
                        if isDeleting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Delete My Account")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canDelete || isDeleting)

                    // Cancel Button
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func deleteAccount() {
        isDeleting = true

        Task {
            do {
                // Call UserRepository to delete account
                // This will:
                // 1. Call backend API to delete user data
                // 2. Clear local database (workouts, metrics, user data)
                // 3. Clear auth tokens
                try await appState.environment.userRepository.deleteAccount()

                // Account deleted successfully - user is now signed out
                // The auth state will automatically update and show sign-in screen
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isDeleting = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    DeleteAccountView()
        .environmentObject(AppState(environment: .preview))
}
