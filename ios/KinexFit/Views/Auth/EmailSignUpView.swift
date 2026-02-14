import SwiftUI

struct EmailSignUpView: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirmation = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var showPassword = false
    @State private var showPasswordConfirmation = false
    @FocusState private var focusedField: Field?

    enum Field {
        case email
        case password
        case passwordConfirmation
        case firstName
        case lastName
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("First Name (Optional)", text: $firstName)
                        .textContentType(.givenName)
                        .autocapitalization(.words)
                        .focused($focusedField, equals: .firstName)

                    TextField("Last Name (Optional)", text: $lastName)
                        .textContentType(.familyName)
                        .autocapitalization(.words)
                        .focused($focusedField, equals: .lastName)
                } header: {
                    Text("Personal Information")
                }

                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                } header: {
                    Text("Account")
                }

                Section {
                    HStack {
                        if showPassword {
                            TextField("Password", text: $password)
                                .textContentType(.newPassword)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .password)
                        } else {
                            SecureField("Password", text: $password)
                                .textContentType(.newPassword)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .password)
                        }

                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        if showPasswordConfirmation {
                            TextField("Confirm Password", text: $passwordConfirmation)
                                .textContentType(.newPassword)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .passwordConfirmation)
                        } else {
                            SecureField("Confirm Password", text: $passwordConfirmation)
                                .textContentType(.newPassword)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .passwordConfirmation)
                        }

                        Button {
                            showPasswordConfirmation.toggle()
                        } label: {
                            Image(systemName: showPasswordConfirmation ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    }

                    // Password match indicator
                    if !password.isEmpty && !passwordConfirmation.isEmpty {
                        HStack {
                            Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(passwordsMatch ? .green : .red)
                            Text(passwordsMatch ? "Passwords match" : "Passwords do not match")
                                .font(.caption)
                                .foregroundColor(passwordsMatch ? .green : .red)
                        }
                    }
                } header: {
                    Text("Password")
                } footer: {
                    if !password.isEmpty {
                        PasswordRequirementsView(password: password)
                            .padding(.top, 8)
                    }
                }

                Section {
                    Button {
                        focusedField = nil
                        Task {
                            await viewModel.handleEmailPasswordSignUp(
                                email: email,
                                password: password,
                                passwordConfirmation: passwordConfirmation,
                                firstName: firstName.isEmpty ? nil : firstName,
                                lastName: lastName.isEmpty ? nil : lastName
                            )
                            if viewModel.authState.isSignedIn {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            Text("Create Account")
                                .frame(maxWidth: .infinity)
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            }
                        }
                    }
                    .disabled(!canSignUp || viewModel.isLoading)
                }

                Section {
                    Button {
                        dismiss()
                    } label: {
                        Text("Already have an account? Sign In")
                            .frame(maxWidth: .infinity)
                    }
                    .foregroundColor(AppTheme.accent)
                }
            }
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var passwordsMatch: Bool {
        !password.isEmpty && !passwordConfirmation.isEmpty && password == passwordConfirmation
    }

    private var canSignUp: Bool {
        !email.isEmpty && !password.isEmpty && passwordsMatch
    }
}

// MARK: - Password Requirements View

struct PasswordRequirementsView: View {
    let password: String
    @EnvironmentObject var appState: AppState

    private var authService: EmailPasswordAuthService {
        appState.environment.emailPasswordAuthService
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Password must contain:")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(PasswordValidationError.allCases, id: \.self) { requirement in
                HStack(spacing: 8) {
                    Image(systemName: isMet(requirement) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isMet(requirement) ? .green : .secondary)
                        .font(.caption)

                    Text(requirement.rawValue)
                        .font(.caption)
                        .foregroundColor(isMet(requirement) ? .primary : .secondary)
                }
            }
        }
    }

    private func isMet(_ requirement: PasswordValidationError) -> Bool {
        authService.isRequirementMet(requirement, in: password)
    }
}

#Preview {
    EmailSignUpView(viewModel: .preview)
        .environmentObject(AppState(environment: .preview))
}
