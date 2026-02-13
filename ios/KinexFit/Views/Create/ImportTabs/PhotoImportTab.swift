import SwiftUI
import PhotosUI

/// Photo import tab with camera and library options
struct PhotoImportTab: View {
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false

    var body: some View {
        VStack(spacing: 24) {
            // Instructions
            VStack(spacing: 8) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                Text("Scan Workout")
                    .font(.headline)

                Text("Take a photo or choose from your library to extract workout text")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)

            // Action buttons
            VStack(spacing: 12) {
                Button(action: { showingCamera = true }) {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Take Photo")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }

                Button(action: { showingPhotoPicker = true }) {
                    HStack {
                        Image(systemName: "photo.fill")
                        Text("Choose from Library")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .foregroundStyle(.primary)
                    .cornerRadius(12)
                }
            }

            Spacer()

            // Info note
            Text("OCR processing will extract text from your image")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .fullScreenCover(isPresented: $showingCamera) {
            ScanTab()
        }
        .fullScreenCover(isPresented: $showingPhotoPicker) {
            ScanTab()
        }
    }
}

#Preview {
    PhotoImportTab()
        .preferredColorScheme(.dark)
}
