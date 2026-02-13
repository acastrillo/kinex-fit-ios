import SwiftUI

/// Manual workout entry tab
struct ManualImportTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var showingManualEntry = false

    private var workoutRepository: WorkoutRepository {
        appState.environment.workoutRepository
    }

    var body: some View {
        VStack(spacing: 24) {
            // Instructions
            VStack(spacing: 8) {
                Image(systemName: "pencil.line")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)

                Text("Manual Entry")
                    .font(.headline)

                Text("Type in your workout details directly")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)

            // Example format
            VStack(alignment: .leading, spacing: 12) {
                Text("Example Format:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    ExampleText("Push Day")
                    ExampleText("Bench Press 4x8 @ 185 lb")
                    ExampleText("Overhead Press 3x10 @ 95 lb")
                    ExampleText("Tricep Dips 3x12")
                }
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
            }

            // Create button
            Button(action: { showingManualEntry = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Workout")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }

            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingManualEntry) {
            WorkoutFormView(mode: .create, onSave: createWorkout)
        }
    }

    // MARK: - Actions

    private func createWorkout(title: String, content: String?) async throws {
        let workout = Workout(
            title: title,
            content: content?.isEmpty == true ? nil : content,
            source: .manual
        )
        try await workoutRepository.create(workout)
    }
}

/// Example text row
private struct ExampleText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fontDesign(.monospaced)
    }
}

#Preview {
    ManualImportTab()
        .environmentObject(AppState(environment: .preview))
        .preferredColorScheme(.dark)
}
