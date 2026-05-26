import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Pinch/drag crop inside a circle before saving **`UserProfile.profilePhoto`**.
struct ProfilePhotoCropSheet: View {
    #if canImport(UIKit)
    let sourceImage: UIImage
    #endif
    let onSave: (Data) -> Void
    let onCancel: () -> Void

    private enum Layout {
        static let cropDiameter: CGFloat = 280
    }

    @State private var gestureScale: CGFloat = 1
    @State private var lastGestureScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        #if canImport(UIKit)
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.lg) {
                cropCanvas
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Text("Pinch and drag to position your photo")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.lg)
            }
            .padding(.vertical, AppTheme.Spacing.md)
            .background(AppTheme.Colors.screenBackgroundGradient.ignoresSafeArea())
            .navigationTitle("Adjust photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier("ProfilePhotoCrop.Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCroppedPhoto()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("ProfilePhotoCrop.Save")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .appSheetContentTopSpacing()
        .onAppear {
            resetCropGestures()
        }
        #else
        EmptyView()
        #endif
    }

    #if canImport(UIKit)
    private func drawSize(for gestureScale: CGFloat) -> CGSize {
        ProfilePhotoCropRenderer.scaledDrawSize(
            imageSize: sourceImage.size,
            cropDiameter: Layout.cropDiameter,
            gestureScale: gestureScale
        )
    }

    private var drawSize: CGSize {
        drawSize(for: gestureScale)
    }

    private func clamped(_ offset: CGSize, for gestureScale: CGFloat) -> CGSize {
        ProfilePhotoCropRenderer.clampedOffset(
            offset,
            drawSize: drawSize(for: gestureScale),
            cropDiameter: Layout.cropDiameter
        )
    }

    private var cropCanvas: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.88)

                Image(uiImage: sourceImage)
                    .resizable()
                    .frame(width: drawSize.width, height: drawSize.height)
                    .offset(offset)

                Circle()
                    .strokeBorder(Color.white.opacity(0.95), lineWidth: 2)
                    .frame(width: Layout.cropDiameter, height: Layout.cropDiameter)
                    .allowsHitTesting(false)

                Circle()
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                    .frame(width: Layout.cropDiameter + 6, height: Layout.cropDiameter + 6)
                    .allowsHitTesting(false)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .gesture(magnificationGesture)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let proposed = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
                offset = clamped(proposed, for: gestureScale)
            }
            .onEnded { _ in
                lastOffset = clamped(offset, for: gestureScale)
                offset = lastOffset
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let proposed = lastGestureScale * value
                gestureScale = max(proposed, ProfilePhotoCropRenderer.minimumGestureScale)
                offset = clamped(offset, for: gestureScale)
            }
            .onEnded { _ in
                lastGestureScale = gestureScale
                lastOffset = clamped(offset, for: gestureScale)
                offset = lastOffset
            }
    }

    private func resetCropGestures() {
        gestureScale = 1
        lastGestureScale = 1
        offset = .zero
        lastOffset = .zero
    }

    private func saveCroppedPhoto() {
        let resolvedOffset = clamped(offset, for: gestureScale)
        guard let data = ProfilePhotoCropRenderer.croppedJPEGData(
            from: sourceImage,
            cropDiameter: Layout.cropDiameter,
            gestureScale: gestureScale,
            offset: resolvedOffset
        ) else {
            onCancel()
            return
        }
        onSave(data)
    }
    #endif
}

#if canImport(UIKit)
struct ProfilePhotoCropDraft: Identifiable {
    let id = UUID()
    let image: UIImage
}
#endif
