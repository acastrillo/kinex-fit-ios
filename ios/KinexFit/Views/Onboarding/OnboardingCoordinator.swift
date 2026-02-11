import SwiftUI

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var trainingProfile = TrainingProfile()
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    private let userRepository: UserRepository
    private let apiClient: APIClient
    private let onComplete: () -> Void

    init(userRepository: UserRepository, apiClient: APIClient, onComplete: @escaping () -> Void) {
        self.userRepository = userRepository
        self.apiClient = apiClient
        self.onComplete = onComplete
    }

    enum OnboardingStep: Int, CaseIterable {
        case welcome = 0
        case basicProfile = 1
        case experience = 2
        case schedule = 3
        case equipment = 4
        case goals = 5
        case personalRecords = 6
        case complete = 7

        var title: String {
            switch self {
            case .welcome: return "Welcome"
            case .basicProfile: return "Profile"
            case .experience: return "Experience"
            case .schedule: return "Schedule"
            case .equipment: return "Equipment"
            case .goals: return "Goals"
            case .personalRecords: return "Records"
            case .complete: return "Ready!"
            }
        }

        var progress: Double {
            Double(rawValue + 1) / Double(OnboardingStep.allCases.count)
        }
    }

    // MARK: - Navigation

    func goToNext() {
        guard let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) else {
            return
        }
        withAnimation {
            currentStep = nextStep
        }
    }

    func goBack() {
        guard currentStep.rawValue > 0,
              let previousStep = OnboardingStep(rawValue: currentStep.rawValue - 1) else {
            return
        }
        withAnimation {
            currentStep = previousStep
        }
    }

    func skipToEnd() {
        withAnimation {
            currentStep = .complete
        }
    }

    // MARK: - Completion

    func completeOnboarding() async {
        isSubmitting = true
        errorMessage = nil

        do {
            // Send profile to backend
            try await submitOnboardingData()

            // Mark onboarding as complete in local storage
            try await markOnboardingComplete()

            // Notify completion
            onComplete()
        } catch {
            errorMessage = "Failed to save onboarding data: \(error.localizedDescription)"
            isSubmitting = false
        }
    }

    // MARK: - Backend Submission

    private func submitOnboardingData() async throws {
        struct OnboardingRequest: Encodable {
            let experienceLevel: String?
            let trainingDaysPerWeek: Int?
            let sessionDuration: Int?
            let equipment: [String]
            let goals: [String]
            let personalRecords: [PRData]

            struct PRData: Encodable {
                let exerciseName: String
                let weight: Double
                let unit: String
                let reps: Int?
            }
        }

        let request = try APIRequest.json(
            path: "/api/mobile/user/onboarding",
            method: .post,
            body: OnboardingRequest(
                experienceLevel: trainingProfile.experienceLevel?.rawValue,
                trainingDaysPerWeek: trainingProfile.trainingDaysPerWeek,
                sessionDuration: trainingProfile.sessionDuration,
                equipment: trainingProfile.equipment.map(\.rawValue),
                goals: trainingProfile.goals.map(\.rawValue),
                personalRecords: trainingProfile.personalRecords.map { pr in
                    OnboardingRequest.PRData(
                        exerciseName: pr.exerciseName,
                        weight: pr.weight,
                        unit: pr.unit.rawValue,
                        reps: pr.reps
                    )
                }
            )
        )

        struct EmptyResponse: Decodable {}
        let _: EmptyResponse = try await apiClient.send(request)
    }

    private func markOnboardingComplete() async throws {
        try await userRepository.database.dbQueue.write { db in
            try db.execute(
                sql: "UPDATE users SET onboardingCompleted = ?, updatedAt = ?",
                arguments: [true, Date()]
            )
        }
    }
}

// MARK: - Onboarding Container View

struct OnboardingCoordinator: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: OnboardingViewModel
    @State private var showSkipConfirmation = false

    init(onComplete: @escaping () -> Void) {
        let environment = AppState.shared?.environment ?? .preview
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(
            userRepository: environment.userRepository,
            apiClient: environment.apiClient,
            onComplete: onComplete
        ))
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with progress
                VStack(spacing: 12) {
                    HStack {
                        // Back button
                        if viewModel.currentStep.rawValue > 0 {
                            Button {
                                viewModel.goBack()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.title3)
                                    .foregroundStyle(.primary)
                            }
                        } else {
                            Spacer()
                                .frame(width: 44)
                        }

                        Spacer()

                        // Skip button
                        if viewModel.currentStep != .complete {
                            Button {
                                showSkipConfirmation = true
                            } label: {
                                Text("Skip")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Progress bar
                    ProgressView(value: viewModel.currentStep.progress)
                        .tint(.blue)
                        .padding(.horizontal)

                    // Step title
                    Text(viewModel.currentStep.title)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top)
                .padding(.bottom, 8)
                .background(Color(.systemBackground).opacity(0.95))

                // Current step content
                Group {
                    switch viewModel.currentStep {
                    case .welcome:
                        WelcomeStep(onContinue: viewModel.goToNext)
                    case .basicProfile:
                        BasicProfileStep(onContinue: viewModel.goToNext)
                    case .experience:
                        ExperienceStep(
                            selection: $viewModel.trainingProfile.experienceLevel,
                            onContinue: viewModel.goToNext
                        )
                    case .schedule:
                        ScheduleStep(
                            daysPerWeek: $viewModel.trainingProfile.trainingDaysPerWeek,
                            sessionDuration: $viewModel.trainingProfile.sessionDuration,
                            onContinue: viewModel.goToNext
                        )
                    case .equipment:
                        EquipmentStep(
                            selection: $viewModel.trainingProfile.equipment,
                            onContinue: viewModel.goToNext
                        )
                    case .goals:
                        GoalsStep(
                            selection: $viewModel.trainingProfile.goals,
                            onContinue: viewModel.goToNext
                        )
                    case .personalRecords:
                        PersonalRecordsStep(
                            records: $viewModel.trainingProfile.personalRecords,
                            onContinue: viewModel.goToNext,
                            onSkip: viewModel.goToNext
                        )
                    case .complete:
                        CompleteStep(
                            profile: viewModel.trainingProfile,
                            isSubmitting: viewModel.isSubmitting,
                            errorMessage: viewModel.errorMessage,
                            onComplete: {
                                Task {
                                    await viewModel.completeOnboarding()
                                }
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .confirmationDialog(
            "Skip Onboarding?",
            isPresented: $showSkipConfirmation,
            titleVisibility: .visible
        ) {
            Button("Skip All", role: .destructive) {
                viewModel.skipToEnd()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can always update your preferences in Settings later.")
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingCoordinator(onComplete: {})
        .environmentObject(AppState(environment: .preview))
}
