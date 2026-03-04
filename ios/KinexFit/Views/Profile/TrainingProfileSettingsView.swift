import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "TrainingProfileSettings")

/// View for editing user's training profile (experience, split, goals, equipment, etc.)
struct TrainingProfileSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var profile: TrainingProfile = TrainingProfile()
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var validationErrors: [String: String] = [:]
    @State private var showValidationFeedback = false
    @State private var saveProgress: String = ""
    @State private var showSaveSuccess = false

    private var userRepository: UserRepository {
        appState.environment.userRepository
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                formSection

                saveButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await loadProfile()
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Training Profile")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                Spacer()

                // Invisible spacer to center title
                Button {} label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)
                .hidden()
            }

            Text("Set your experience level, training preferences, goals, and constraints")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    // MARK: - Form Section

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Experience Level
            VStack(alignment: .leading, spacing: 8) {
                Text("Experience Level")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                Picker("Experience", selection: $profile.experience) {
                    Text("Beginner").tag(Optional(ExperienceLevel.beginner))
                    Text("Intermediate").tag(Optional(ExperienceLevel.intermediate))
                    Text("Advanced").tag(Optional(ExperienceLevel.advanced))
                }
                .pickerStyle(.segmented)
                .tint(AppTheme.accent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(AppTheme.cardBackgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Training Split
            if profile.preferredSplit != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Training Split")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)

                    Picker("Split", selection: $profile.preferredSplit) {
                        Text("Full Body").tag(Optional(PreferredSplit.fullBody))
                        Text("Upper/Lower").tag(Optional(PreferredSplit.upperLower))
                        Text("Push/Pull/Legs").tag(Optional(PreferredSplit.pushPullLegs))
                        Text("Bro Split").tag(Optional(PreferredSplit.broSplit))
                    }
                    .pickerStyle(.menu)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(AppTheme.cardBackgroundElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            // Days Per Week
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Days Per Week")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    Spacer()
                    Text("\(profile.trainingDays ?? 4)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                }

                Stepper(
                    "Training days",
                    value: Binding(
                        get: { profile.trainingDays ?? 4 },
                        set: { profile.trainingDays = $0 }
                    ),
                    in: 1...7
                )
                .labelsHidden()
                .tint(AppTheme.accent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(AppTheme.cardBackgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Session Duration
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Session Duration (minutes)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    Spacer()
                    Text("\(profile.sessionDuration ?? 60)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                }

                Stepper(
                    "Session duration",
                    value: Binding(
                        get: { profile.sessionDuration ?? 60 },
                        set: { profile.sessionDuration = $0 }
                    ),
                    in: 15...180,
                    step: 5
                )
                .labelsHidden()
                .tint(AppTheme.accent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(AppTheme.cardBackgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Equipment
            VStack(alignment: .leading, spacing: 10) {
                Text("Available Equipment")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Equipment.allCases, id: \.self) { equipment in
                        HStack(spacing: 10) {
                            Image(systemName: profile.equipment.contains(equipment) ? "checkmark.square.fill" : "square")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(profile.equipment.contains(equipment) ? AppTheme.accent : AppTheme.tertiaryText)

                            Text(equipment.displayName)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(AppTheme.primaryText)

                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if profile.equipment.contains(equipment) {
                                profile.equipment.remove(equipment)
                            } else {
                                profile.equipment.insert(equipment)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(AppTheme.cardBackgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Goals
            VStack(alignment: .leading, spacing: 10) {
                Text("Training Goals")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(TrainingGoal.allCases, id: \.self) { goal in
                        HStack(spacing: 10) {
                            Image(systemName: profile.goals.contains(goal) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(profile.goals.contains(goal) ? AppTheme.accent : AppTheme.tertiaryText)

                            Text(goal.displayName)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(AppTheme.primaryText)

                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if profile.goals.contains(goal) {
                                profile.goals.remove(goal)
                            } else {
                                profile.goals.insert(goal)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(AppTheme.cardBackgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .redacted(reason: isLoading ? .placeholder : [])
        .disabled(isLoading || isSaving)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            Task {
                await saveProfile()
            }
        } label: {
            HStack(spacing: 8) {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                }

                Text(isSaving ? "Saving..." : "Save Changes")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isSaving || isLoading)
    }

    // MARK: - Methods

    private func loadProfile() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let request = APIRequest.getTrainingProfile()
            let fetchedProfile: TrainingProfile = try await appState.environment.apiClient.send(request)
            await MainActor.run {
                self.profile = fetchedProfile
            }
        } catch {
            logger.error("Failed to load training profile: \(error)")
            await MainActor.run {
                errorMessage = "Failed to load your profile. Please try again."
                showErrorAlert = true
            }
        }
    }

    private func validateProfile() -> Bool {
        validationErrors.removeAll()
        
        // Validate experience level
        if profile.experience == nil {
            validationErrors["experience"] = "Please select your experience level"
        }
        
        // Validate training split
        if profile.preferredSplit == nil {
            validationErrors["split"] = "Please select your training split"
        }
        
        // Validate training days
        if let days = profile.trainingDays, (days < 1 || days > 7) {
            validationErrors["days"] = "Training days must be between 1 and 7"
        }
        
        // Validate session duration
        if let duration = profile.sessionDuration, (duration < 15 || duration > 180) {
            validationErrors["duration"] = "Session duration must be between 15 and 180 minutes"
        }
        
        // Validate goals selected
        if profile.goals.isEmpty {
            validationErrors["goals"] = "Please select at least one training goal"
        }
        
        // Validate equipment selected
        if profile.equipment.isEmpty {
            validationErrors["equipment"] = "Please select at least one equipment option"
        }
        
        showValidationFeedback = !validationErrors.isEmpty
        return validationErrors.isEmpty
    }

    private func saveProfile() async {
        // Validate before attempting save
        if !validateProfile() {
            await MainActor.run {
                logger.info("Profile validation failed: \(validationErrors)")
            }
            return
        }
        
        isSaving = true
        defer { isSaving = false }

        do {
            await MainActor.run { saveProgress = "Saving profile..." }
            
            if let user = try await userRepository.getCurrentUser() {
                await MainActor.run { saveProgress = "Syncing with backend..." }
                try await userRepository.syncUserSettings(user, trainingProfile: profile)

                await MainActor.run {
                    saveProgress = "Profile saved successfully!"
                    showSaveSuccess = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            }
        } catch {
            logger.error("Failed to save training profile: \(error)")
            await MainActor.run {
                errorMessage = "Failed to save your profile. Please try again."
                showErrorAlert = true
                saveProgress = ""
            }
        }
    }
}

#Preview {
    TrainingProfileSettingsView()
        .environmentObject(AppState(environment: .preview))
}
