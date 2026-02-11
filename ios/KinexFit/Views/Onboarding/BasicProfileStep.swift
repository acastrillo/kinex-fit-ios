import SwiftUI

struct BasicProfileStep: View {
    let onContinue: () -> Void

    @State private var firstName = ""
    @State private var lastName = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)

                    Text("Tell us about yourself")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("We've pre-filled your name from Sign in with Apple. Feel free to update it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)

                // Form
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("First Name")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextField("John", text: $firstName)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.givenName)
                            .autocapitalization(.words)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last Name")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextField("Doe", text: $lastName)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.familyName)
                            .autocapitalization(.words)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground).opacity(0.8))
                )
                .padding(.horizontal)

                Spacer()

                // Continue button
                Button {
                    onContinue()
                } label: {
                    HStack {
                        Text("Continue")
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
        .task {
            // Load current user name
            if let user = try? await AppState.shared?.environment.userRepository.getCurrentUser() {
                firstName = user.firstName ?? ""
                lastName = user.lastName ?? ""
            }
        }
    }
}

// MARK: - Preview

#Preview {
    BasicProfileStep(onContinue: {})
}
