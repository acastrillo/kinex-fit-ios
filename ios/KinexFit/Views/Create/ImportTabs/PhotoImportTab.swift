import SwiftUI
import PhotosUI

/// Photo import tab with camera and library options
struct PhotoImportTab: View {
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 34))
                    .foregroundStyle(AppTheme.statClock)

                Text("Scan Workout")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                Text("Take a photo or choose from your library to extract workout text")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)

            VStack(spacing: 12) {
                Button(action: { showingCamera = true }) {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Take Photo")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Button(action: { showingPhotoPicker = true }) {
                    HStack {
                        Image(systemName: "photo.fill")
                        Text("Choose from Library")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.cardBackgroundElevated)
                    .foregroundStyle(AppTheme.primaryText)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppTheme.cardBorder, lineWidth: 1)
                    }
                }
            }

            Spacer()

            Text("OCR processing will extract text from your image")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
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
