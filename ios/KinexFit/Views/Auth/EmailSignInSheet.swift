import SwiftUI

struct EmailSignInSheet: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false
    @FocusState private var focusedField: Field?

    enum Field {
        case email
        case password
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                } header: {
                    Text("Sign In")
                }

                Section {
                    Button {
                        focusedField = nil
                        Task {
                            await viewModel.handleEmailPasswordSignIn(email: email, password: password)
                            if viewModel.authState.isSignedIn {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            Text("Sign In")
                                .frame(maxWidth: .infinity)
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            }
                        }
                    }
                    .disabled(email.isEmpty || password.isEmpty || viewModel.isLoading)
                }

                Section {
                    Button {
                        showSignUp = true
                    } label: {
                        Text("Don't have an account? Sign Up")
                            .frame(maxWidth: .infinity)
                    }
                    .foregroundColor(AppTheme.accent)
                }
            }
            .navigationTitle("Email Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showSignUp) {
                EmailSignUpView(viewModel: viewModel)
            }
            .onAppear {
                // Auto-focus email field when sheet appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    focusedField = .email
                }
            }
        }
    }
}

#Preview {
    EmailSignInSheet(viewModel: .preview)
}
