import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showEmailSignIn = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo and welcome text
            VStack(spacing: 16) {
                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(AppTheme.accent)

                Text("Kinex Fit")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.primaryText)

                Text("AI-powered workout tracking")
                    .font(.title3)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()

            // Features list
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "doc.text.viewfinder",
                    title: "Scan Workouts",
                    description: "Use OCR to capture workouts from photos"
                )

                FeatureRow(
                    icon: "icloud.and.arrow.up",
                    title: "Sync Everywhere",
                    description: "Your data syncs across all devices"
                )

                FeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Track Progress",
                    description: "Monitor your fitness journey"
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            // Sign in buttons
            VStack(spacing: 16) {
                SignInWithAppleButton(
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        Task {
                            await viewModel.handleAppleSignIn(result)
                        }
                    }
                )
                .signInWithAppleButtonStyle(
                    colorScheme == .dark ? .white : .black
                )
                .frame(height: 50)
                .cornerRadius(8)

                // Google Sign In
                Button {
                    Task {
                        await viewModel.handleGoogleSignIn()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.system(size: 20))
                        Text("Continue with Google")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white)
                    .foregroundStyle(Color.black)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Facebook Sign In
                Button {
                    Task {
                        await viewModel.handleFacebookSignIn()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "f.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 24/255, green: 119/255, blue: 242/255))
                        Text("Continue with Facebook")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white)
                    .foregroundStyle(Color.black)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Email/Password Sign In
                Button {
                    showEmailSignIn = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 20))
                        Text("Continue with Email")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white)
                    .foregroundStyle(Color.black)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                #if DEBUG
                // Development bypass button (DEBUG builds only)
                Button {
                    viewModel.bypassAuthForDevelopment()
                } label: {
                    HStack {
                        Image(systemName: "hammer.fill")
                        Text("Continue as Dev User")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.orange)
                    .foregroundStyle(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                #endif

                Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .disabled(viewModel.isLoading)
        .overlay {
            if viewModel.isLoading {
                LoadingOverlay()
            }
        }
        .alert(
            "Sign In Failed",
            isPresented: .init(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.clearError() } }
            ),
            presenting: viewModel.error
        ) { _ in
            Button("OK") {
                viewModel.clearError()
            }
        } message: { error in
            Text(error.localizedDescription)
        }
        .sheet(isPresented: $showEmailSignIn) {
            EmailSignInSheet(viewModel: viewModel)
        }
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.primaryText)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }
}

// MARK: - Loading Overlay

private struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)

                Text("Signing in...")
                    .font(.headline)
            }
            .padding(32)
            .background(.regularMaterial)
            .cornerRadius(16)
        }
    }
}

// MARK: - Preview

#Preview {
    SignInView(viewModel: .preview)
}
