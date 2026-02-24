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
            VStack(spacing: 8) {
                Image(systemName: "pencil.line")
                    .font(.system(size: 34))
                    .foregroundStyle(AppTheme.statStreak)

                Text("Manual Entry")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                Text("Type in your workout details directly")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)

            VStack(alignment: .leading, spacing: 12) {
                Text("Example Format:")
                    .font(.system(size: 15, weight: .semibold))
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.secondaryText)

                VStack(alignment: .leading, spacing: 4) {
                    ExampleText("Push Day")
                    ExampleText("Bench Press 4x8 @ 185 lb")
                    ExampleText("Overhead Press 3x10 @ 95 lb")
                    ExampleText("Tricep Dips 3x12")
                }
                .padding()
                .kinexCard(cornerRadius: 8, fill: AppTheme.cardBackgroundElevated)
            }

            Button(action: { showingManualEntry = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Workout")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.statStreak)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(AppTheme.secondaryText)
            .fontDesign(.monospaced)
    }
}

#Preview {
    ManualImportTab()
        .environmentObject(AppState(environment: .preview))
        .preferredColorScheme(.dark)
}
