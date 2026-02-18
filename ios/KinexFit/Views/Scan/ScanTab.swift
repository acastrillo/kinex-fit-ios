import SwiftUI
import PhotosUI

struct ScanTab: View {
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
            .sheet(isPresented: $showingOCRResult) {
                if let result = ocrResult, let image = selectedImage {
                    OCRResultView(
                        image: image,
                        ocrResponse: result,
                        onSave: saveWorkout,
                        onDiscard: discardResult
                    )
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

    private func saveWorkout(title: String, content: String?) async throws {
        let workout = Workout(
            title: title,
            content: content,
            source: .ocr
        )
        try await appState.environment.workoutRepository.create(workout)

        await MainActor.run {
            ocrResult = nil
            selectedImage = nil
            showingOCRResult = false
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
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)

                VStack(spacing: 8) {
                    Text("Processing Image")
                        .font(.headline)

                    Text("Extracting text from your workout...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
