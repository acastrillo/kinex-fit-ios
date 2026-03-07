import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ImportPromptStep: View {
    let onImportCompleted: (CaptionParsedWorkout) -> Void
    let onSkip: () -> Void

    @State private var showPhotosPicker = false
    @State private var showDocumentPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var parsedWorkout: CaptionParsedWorkout?
    @State private var extractionProgress: Double = 0
    @State private var isProcessing = false
    @State private var showProgressSheet = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var processingStartTime: Date?

    private let textExtractor = TextExtractionService()
    private let parser = CaptionImportParsingService()

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

                Text("Import a screenshot or photo of any workout plan and we'll do the rest.")
                    .font(.body)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 32)

            Spacer()

            // Actions
            VStack(spacing: 14) {
                // Primary: Import
                Button(action: {
                    OnboardingAnalytics.shared.track(.importAttemptStarted(source: "photo_picker"))
                    showPhotosPicker = true
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 18))
                        Text("Import from Photos")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .accessibilityLabel("Import workout from photos")

                // Secondary: Files
                Button(action: {
                    OnboardingAnalytics.shared.track(.importAttemptStarted(source: "file_picker"))
                    showDocumentPicker = true
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 18))
                        Text("Import from Files")
                            .font(.headline)
                    }
                    .foregroundStyle(AppTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .accessibilityLabel("Import workout from files")

                // Browse Gallery (future)
                Button(action: {}) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.stack")
                        Text("Browse Gallery")
                    }
                    .foregroundStyle(AppTheme.secondaryText.opacity(0.5))
                    .font(.subheadline)
                }
                .disabled(true)
                .accessibilityHidden(true)

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
        // Document picker (images)
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView(allowedTypes: [.image, .jpeg, .png, .heic]) { url in
                Task { await processFile(url) }
            }
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

    private func processPhoto(_ item: PhotosPickerItem) async {
        processingStartTime = Date()
        isProcessing = true
        showProgressSheet = true
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
        } catch {
            showProgressSheet = false
            errorMessage = error.localizedDescription
            showError = true
        }
        isProcessing = false
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
