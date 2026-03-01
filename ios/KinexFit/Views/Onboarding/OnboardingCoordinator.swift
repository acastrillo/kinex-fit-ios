import SwiftUI
import OSLog

private let onboardingLogger = Logger(subsystem: "com.kinex.fit", category: "Onboarding")

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

        // Attempt to send profile to backend. A network or server failure is
        // non-fatal — we still complete onboarding locally so the user isn't
        // blocked. The data will sync the next time the app is online.
        do {
            try await submitOnboardingData()
        } catch {
            onboardingLogger.error("Failed to submit onboarding data to backend: \(error.localizedDescription, privacy: .public)")
        }

        do {
            try await markOnboardingComplete()
            onComplete()
        } catch {
            errorMessage = "Failed to save onboarding data: \(error.localizedDescription)"
            isSubmitting = false
        }
    }

    // MARK: - Backend Submission

    private func submitOnboardingData() async throws {
        struct OnboardingRequest: Encodable {
            // Canonical web schema
            let experience: String?
            let preferredSplit: String?
            let trainingDays: Int?
            let sessionDuration: Int?
            let equipment: [String]
            let trainingLocation: String?
            let goals: [String]
            let primaryGoal: String?
            let constraints: [ConstraintData]
            let preferences: PreferencesData?
            let personalRecordsByExercise: [String: PRData]
            let updatedAt: String?
            let createdAt: String?

            // Legacy mobile onboarding payload keys (still used by backend route)
            let experienceLevel: String?
            let trainingDaysPerWeek: Int?
            let personalRecords: [PRData]

            struct PRData: Encodable {
                let exerciseName: String
                let weight: Double
                let unit: String
                let reps: Int?
                let date: String
                let notes: String?
            }

            struct ConstraintData: Encodable {
                let id: String
                let description: String
                let affectedExercises: [String]?
                let createdAt: String
            }

            struct PreferencesData: Encodable {
                let favoriteExercises: [String]?
                let dislikedExercises: [String]?
                let warmupRequired: Bool?
                let cooldownRequired: Bool?
            }
        }

        let personalRecords = trainingProfile.personalRecords.map { pr in
            OnboardingRequest.PRData(
                exerciseName: pr.exerciseName,
                weight: pr.weight,
                unit: pr.unit.rawValue,
                reps: pr.reps,
                date: pr.date,
                notes: pr.notes
            )
        }
        let personalRecordsMap = Dictionary(uniqueKeysWithValues: personalRecords.map { ($0.exerciseName, $0) })

        let request = try APIRequest.json(
            path: "/api/mobile/user/onboarding",
            method: .post,
            body: OnboardingRequest(
                experience: trainingProfile.experience?.rawValue,
                preferredSplit: trainingProfile.preferredSplit?.rawValue,
                trainingDays: trainingProfile.trainingDays,
                sessionDuration: trainingProfile.sessionDuration,
                equipment: trainingProfile.equipment.map(\.rawValue).sorted(),
                trainingLocation: trainingProfile.trainingLocation?.rawValue,
                goals: trainingProfile.goals.map(\.rawValue).sorted(),
                primaryGoal: trainingProfile.primaryGoal?.rawValue,
                constraints: trainingProfile.constraints.map { constraint in
                    OnboardingRequest.ConstraintData(
                        id: constraint.id,
                        description: constraint.description,
                        affectedExercises: constraint.affectedExercises,
                        createdAt: constraint.createdAt
                    )
                },
                preferences: trainingProfile.preferences.map { preferences in
                    OnboardingRequest.PreferencesData(
                        favoriteExercises: preferences.favoriteExercises,
                        dislikedExercises: preferences.dislikedExercises,
                        warmupRequired: preferences.warmupRequired,
                        cooldownRequired: preferences.cooldownRequired
                    )
                },
                personalRecordsByExercise: personalRecordsMap,
                updatedAt: trainingProfile.updatedAt,
                createdAt: trainingProfile.createdAt,
                experienceLevel: trainingProfile.experience?.rawValue,
                trainingDaysPerWeek: trainingProfile.trainingDays,
                personalRecords: personalRecords
            )
        )

        _ = try await apiClient.send(request)

        if let currentUser = try await userRepository.getCurrentUser() {
            try await userRepository.syncUserSettings(currentUser, trainingProfile: trainingProfile)
        }
    }

    private func markOnboardingComplete() async throws {
        try await userRepository.markOnboardingComplete()
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
                            selection: $viewModel.trainingProfile.experience,
                            onContinue: viewModel.goToNext
                        )
                    case .schedule:
                        ScheduleStep(
                            daysPerWeek: $viewModel.trainingProfile.trainingDays,
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
