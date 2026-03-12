import SwiftUI
import PhotosUI

struct ScanTab: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showingCamera = false
    @State private var showingOCRResult = false
    @State private var isProcessing = false
    @State private var ocrResult: OCRResponse?
    @State private var error: OCRError?
    @State private var showingError = false

    private var ocrService: OCRService {
        OCRService(apiClient: appState.environment.apiClient)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Icon
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)

                // Title and description
                VStack(spacing: 8) {
                    Text("Scan Workout")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Take a photo of your workout to automatically extract exercises")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                // Action buttons
                VStack(spacing: 16) {
                    Button {
                        showingCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .disabled(isProcessing)
            }
            .navigationTitle("Scan")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Back", systemImage: "chevron.backward")
                            .labelStyle(.titleAndIcon)
                    }
                    .disabled(isProcessing)
                }
            }
            .overlay {
                if isProcessing {
                    ProcessingOverlay()
                }
            }
            .onChange(of: selectedPhotoItem) { oldValue, newValue in
                Task {
                    await loadSelectedPhoto()
                }
            }
            .onChange(of: selectedImage) { oldValue, newValue in
                if newValue != nil {
                    Task {
                        await processImage()
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView(image: $selectedImage)
            }
            .sheet(isPresented: $showingOCRResult, onDismiss: discardResult) {
                if let result = ocrResult {
                    WorkoutFormView(
                        mode: .create,
                        initialTitle: WorkoutTextParser.parse(result.text).title,
                        initialRawContent: result.text,
                        initialSource: .ocr
                    ) { title, content, enhancementSourceText in
                        try await saveWorkout(
                            title: title,
                            content: content,
                            enhancementSourceText: enhancementSourceText ?? result.text
                        )
                    }
                }
            }
            .alert("Scan Failed", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(error?.localizedDescription ?? "Unknown error occurred")
            }
        }
    }

    // MARK: - Photo Loading

    private func loadSelectedPhoto() async {
        guard let item = selectedPhotoItem else { return }

        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    selectedImage = image
                }
            }
        } catch {
            await MainActor.run {
                self.error = .invalidImage
                showingError = true
            }
        }

        // Reset picker selection
        await MainActor.run {
            selectedPhotoItem = nil
        }
    }

    // MARK: - OCR Processing

    private func processImage() async {
        guard let image = selectedImage else { return }

        await MainActor.run {
            isProcessing = true
        }

        do {
            let result = try await ocrService.processImage(image)
            await MainActor.run {
                ocrResult = result
                showingOCRResult = true
                isProcessing = false
            }
        } catch let ocrError as OCRError {
            await MainActor.run {
                error = ocrError
                showingError = true
                isProcessing = false
                selectedImage = nil
            }
        } catch {
            await MainActor.run {
                self.error = .networkError(error)
                showingError = true
                isProcessing = false
                selectedImage = nil
            }
        }
    }

    // MARK: - Actions

    private func saveWorkout(title: String, content: String?, enhancementSourceText: String?) async throws {
        let normalizedSourceText = enhancementSourceText?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedContent = content?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let workout = Workout(
            title: title,
            content: content,
            enhancementSourceText: (normalizedSourceText?.isEmpty == false ? normalizedSourceText : normalizedContent),
            source: .ocr
        )
        let savedWorkout = try await appState.environment.workoutRepository.create(workout)

        await MainActor.run {
            ocrResult = nil
            selectedImage = nil
            showingOCRResult = false
            appState.navigateToWorkoutCard(workoutID: savedWorkout.id)
        }
    }

    private func discardResult() {
        ocrResult = nil
        selectedImage = nil
        showingOCRResult = false
    }
}

// MARK: - Processing Overlay

private struct ProcessingOverlay: View {
    @State private var currentStep = 0

    private let steps: [(String, String)] = [
        ("photo", "Loading image"),
        ("text.viewfinder", "Extracting text"),
        ("list.bullet.clipboard", "Parsing workout"),
    ]

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .opacity(0.92)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: steps[currentStep].0)
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                    .symbolEffect(.pulse, options: .repeating)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)

                VStack(spacing: 6) {
                    Text("Processing Image")
                        .font(.headline)

                    Text("Extracting text from your workout...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(spacing: 10) {
                            Group {
                                if index < currentStep {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else if index == currentStep {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .tint(.blue)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .frame(width: 20)

                            Text(step.1)
                                .font(.system(size: 15))
                                .foregroundStyle(index <= currentStep ? Color(.label) : .secondary)

                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 48)
            }
        }
        .task {
            for i in 1..<steps.count {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                withAnimation(.easeInOut(duration: 0.4)) {
                    currentStep = i
                }
            }
        }
    }
}

// MARK: - Camera View

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    ScanTab()
        .environmentObject(AppState(environment: .preview))
}
