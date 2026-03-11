import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ImportPromptStep: View {
    @EnvironmentObject private var appState: AppState

    let onImportCompleted: (CaptionParsedWorkout) -> Void
    let onSkip: () -> Void

    @State private var showInstagramSheet = false
    @State private var showImageSourceOptions = false
    @State private var showPhotosPicker = false
    @State private var showDocumentPicker = false
    @State private var showManualInputSheet = false
    @State private var instagramURL = ""
    @State private var manualInputText = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var parsedWorkout: CaptionParsedWorkout?
    @State private var extractionProgress: Double = 0
    @State private var isProcessing = false
    @State private var showProgressSheet = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var processingStartTime: Date?

    private let textExtractor = TextExtractionService()

    private var parser: CaptionImportParsingService {
        CaptionImportParsingService(apiClient: appState.environment.apiClient)
    }

    private var instagramFetchService: InstagramFetchService {
        InstagramFetchService(apiClient: appState.environment.apiClient)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero
            VStack(spacing: 16) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 64))
                    .foregroundStyle(AppTheme.accent)

                Text("Bring Your Workouts to Life")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.primaryText)
                    .multilineTextAlignment(.center)

                Text("Import from Instagram, upload an image, or type it in and we'll do the rest.")
                    .font(.body)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 32)

            Spacer()

            // Actions
            VStack(spacing: 14) {
                importActionButton(
                    title: "Instagram",
                    systemImage: "camera.on.rectangle",
                    isPrimary: true,
                    accessibilityLabel: "Import workout from Instagram"
                ) {
                    OnboardingAnalytics.shared.track(.importAttemptStarted(source: "instagram_url"))
                    instagramURL = ""
                    showInstagramSheet = true
                }

                importActionButton(
                    title: "Upload Image",
                    systemImage: "photo.on.rectangle.angled",
                    accessibilityLabel: "Upload a workout image"
                ) {
                    showImageSourceOptions = true
                }

                importActionButton(
                    title: "Manual Input",
                    systemImage: "keyboard",
                    accessibilityLabel: "Type or paste workout text manually"
                ) {
                    OnboardingAnalytics.shared.track(.importAttemptStarted(source: "manual_input"))
                    manualInputText = ""
                    showManualInputSheet = true
                }

                // Skip
                Button(action: {
                    OnboardingAnalytics.shared.track(.importSkipped(reason: "not_now"))
                    onSkip()
                }) {
                    Text("Skip for now")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .accessibilityLabel("Skip import step")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        // Photos picker
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection: $selectedPhoto,
            matching: .images
        )
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            Task { await processPhoto(newItem) }
        }
        .confirmationDialog("Upload Image", isPresented: $showImageSourceOptions, titleVisibility: .visible) {
            Button("Photo Library") {
                OnboardingAnalytics.shared.track(.importAttemptStarted(source: "photo_picker"))
                showPhotosPicker = true
            }

            Button("Files") {
                OnboardingAnalytics.shared.track(.importAttemptStarted(source: "file_picker"))
                showDocumentPicker = true
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose where your workout image lives.")
        }
        // Document picker (images)
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView(allowedTypes: [.image, .jpeg, .png, .heic]) { url in
                Task { await processFile(url) }
            }
        }
        // Instagram URL sheet
        .sheet(isPresented: $showInstagramSheet) {
            InstagramURLSheet(urlText: $instagramURL) { url in
                showInstagramSheet = false
                guard !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                Task { await processInstagramURL(url) }
            }
            .presentationDetents([.medium])
        }
        // Manual input sheet
        .sheet(isPresented: $showManualInputSheet) {
            ManualInputSheet(text: $manualInputText) {
                showManualInputSheet = false
                guard !manualInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                Task { await processManualInput(manualInputText) }
            }
            .presentationDetents([.medium, .large])
        }
        // Progress sheet
        .sheet(isPresented: $showProgressSheet) {
            ImportProgressView(
                parsedWorkout: parsedWorkout,
                progress: extractionProgress,
                onCreateWorkout: {
                    if let workout = parsedWorkout {
                        let exerciseCount = workout.exercises.count
                        let ms = processingStartTime.map { Int(Date().timeIntervalSince($0) * 1000) } ?? 0
                        OnboardingAnalytics.shared.track(.importVideoAnalyzed(exerciseCount: exerciseCount, processingMs: ms))
                        OnboardingAnalytics.shared.track(.importSuccess(exerciseCount: exerciseCount))
                        showProgressSheet = false
                        onImportCompleted(workout)
                    }
                },
                onCancel: {
                    showProgressSheet = false
                    parsedWorkout = nil
                    extractionProgress = 0
                }
            )
            .presentationDetents([.large])
        }
        .alert("Import Error", isPresented: $showError, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(errorMessage ?? "Something went wrong. Please try again.")
        })
    }

    // MARK: - Processing

    private func processInstagramURL(_ url: String) async {
        processingStartTime = Date()
        isProcessing = true
        showProgressSheet = true
        parsedWorkout = nil
        extractionProgress = 0.15

        do {
            let fetchedWorkout = try await instagramFetchService.fetchAndParse(url: url)
            extractionProgress = 0.7

            var workout = fetchedWorkout.onboardingPreview
            let normalizedContent = fetchedWorkout.content.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedSourceURL = fetchedWorkout.sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if workout.exercises.isEmpty,
               !normalizedContent.isEmpty {
                workout = await parser.parseImportText(
                    normalizedContent,
                    sourceURL: normalizedSourceURL.isEmpty ? nil : normalizedSourceURL
                )
            }

            extractionProgress = 1.0
            parsedWorkout = workout
        } catch let error as InstagramFetchError {
            showProgressSheet = false
            errorMessage = error.localizedDescription
            showError = true
        } catch {
            showProgressSheet = false
            errorMessage = error.localizedDescription
            showError = true
        }
        isProcessing = false
    }

    private func processPhoto(_ item: PhotosPickerItem) async {
        processingStartTime = Date()
        isProcessing = true
        showProgressSheet = true
        parsedWorkout = nil
        extractionProgress = 0.1

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw TextExtractionService.ExtractionError.imageLoadFailed
            }
            extractionProgress = 0.3
            let text = try await textExtractor.extractText(from: data)
            extractionProgress = 0.6
            let workout = await parser.parseImportText(text, sourceURL: nil)
            extractionProgress = 1.0
            parsedWorkout = workout
        } catch TextExtractionService.ExtractionError.noTextFound {
            // Show empty state inside ImportProgressView rather than an error alert
            extractionProgress = 1.0
            parsedWorkout = nil
        } catch {
            showProgressSheet = false
            errorMessage = error.localizedDescription
            showError = true
        }
        isProcessing = false
    }

    private func processFile(_ url: URL) async {
        processingStartTime = Date()
        isProcessing = true
        showProgressSheet = true
        parsedWorkout = nil
        extractionProgress = 0.1

        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        do {
            extractionProgress = 0.3
            let text = try await textExtractor.extractText(from: url)
            extractionProgress = 0.6
            let workout = await parser.parseImportText(text, sourceURL: nil)
            extractionProgress = 1.0
            parsedWorkout = workout
        } catch TextExtractionService.ExtractionError.noTextFound {
            extractionProgress = 1.0
            parsedWorkout = nil
        } catch {
            showProgressSheet = false
            errorMessage = error.localizedDescription
            showError = true
        }
        isProcessing = false
    }

    private func processManualInput(_ text: String) async {
        processingStartTime = Date()
        isProcessing = true
        showProgressSheet = true
        parsedWorkout = nil
        extractionProgress = 0.3

        let workout = await parser.parseImportText(text, sourceURL: nil)
        extractionProgress = 1.0
        parsedWorkout = workout
        isProcessing = false
    }

    private func importActionButton(
        title: String,
        systemImage: String,
        isPrimary: Bool = false,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 18))
                Text(title)
                    .font(.headline)
            }
            .foregroundStyle(isPrimary ? .white : AppTheme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isPrimary ? AppTheme.accent : AppTheme.accent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Instagram URL sheet

private struct InstagramURLSheet: View {
    @Binding var urlText: String
    let onAnalyze: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Paste a public Instagram post or reel URL and Kinex Fit will turn it into a workout draft.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)

                TextField("instagram.com/p/... or instagram.com/reel/...", text: $urlText)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(AppTheme.accent.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(AppTheme.primaryText)

                Button {
                    onAnalyze(urlText.trimmingCharacters(in: .whitespacesAndNewlines))
                } label: {
                    Text("Analyze Instagram")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? AppTheme.secondaryText
                                : AppTheme.accent
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
            }
            .padding(20)
            .navigationTitle("Instagram")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Manual input sheet

private struct ManualInputSheet: View {
    @Binding var text: String
    let onAnalyze: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Type or paste your workout below — a screenshot caption, a program description, or any exercise list.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)

                TextEditor(text: $text)
                    .font(.body)
                    .foregroundStyle(AppTheme.primaryText)
                    .scrollContentBackground(.hidden)
                    .background(AppTheme.accent.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .frame(minHeight: 160)

                Button(action: onAnalyze) {
                    Text("Analyze Workout")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppTheme.secondaryText : AppTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
            }
            .padding(20)
            .navigationTitle("Manual Input")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Document picker wrapper

private struct DocumentPickerView: UIViewControllerRepresentable {
    let allowedTypes: [UTType]
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}
