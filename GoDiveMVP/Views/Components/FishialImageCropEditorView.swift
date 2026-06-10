import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
/// Pinch/drag crop used before sending a still to Fishial.
struct FishialImageCropEditorView: View {
    let sourceImage: UIImage
    let instruction: String
    @Binding var gestureScale: CGFloat
    @Binding var lastGestureScale: CGFloat
    @Binding var offset: CGSize
    @Binding var lastOffset: CGSize
    @Binding var viewportSize: CGSize

    private enum Layout {
        static let cropCornerRadius: CGFloat = 12
        static let cropStrokeWidth: CGFloat = 2
        static let dimmedOpacity: CGFloat = 0.55
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text(instruction)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, AppTheme.Spacing.lg)

            cropCanvas
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityIdentifier("DiveMediaFishialIdentify.CropEditor")
    }

    private var cropSize: CGSize {
        guard viewportSize.width > 0, viewportSize.height > 0 else {
            return CGSize(width: 1, height: 1)
        }
        return viewportSize
    }

    private func drawSize(for gestureScale: CGFloat) -> CGSize {
        FishialImageCropRenderer.scaledDrawSize(
            imageSize: sourceImage.size,
            cropSize: cropSize,
            gestureScale: gestureScale
        )
    }

    private var drawSize: CGSize {
        drawSize(for: gestureScale)
    }

    private func clamped(_ offset: CGSize, for gestureScale: CGFloat) -> CGSize {
        FishialImageCropRenderer.clampedOffset(
            offset,
            drawSize: drawSize(for: gestureScale),
            cropSize: cropSize
        )
    }

    private var cropCanvas: some View {
        GeometryReader { proxy in
            let resolvedCropSize = FishialImageCropPresentation.squareCropViewportSize(
                in: proxy.size,
                horizontalPadding: AppTheme.Spacing.lg,
                verticalPadding: AppTheme.Spacing.sm
            )

            ZStack {
                Color.black.opacity(Layout.dimmedOpacity)

                Image(uiImage: sourceImage)
                    .resizable()
                    .frame(width: drawSize.width, height: drawSize.height)
                    .offset(offset)

                cropOverlay(size: resolvedCropSize)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .gesture(magnificationGesture)
            .onAppear {
                viewportSize = resolvedCropSize
            }
            .onChange(of: proxy.size) { _, newSize in
                let updated = FishialImageCropPresentation.squareCropViewportSize(
                    in: newSize,
                    horizontalPadding: AppTheme.Spacing.lg,
                    verticalPadding: AppTheme.Spacing.sm
                )
                viewportSize = updated
                offset = clamped(offset, for: gestureScale)
                lastOffset = offset
            }
        }
    }

    private func cropOverlay(size: CGSize) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(Layout.dimmedOpacity))
                .mask {
                    Rectangle()
                        .overlay(alignment: .center) {
                            RoundedRectangle(cornerRadius: Layout.cropCornerRadius, style: .continuous)
                                .frame(width: size.width, height: size.height)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                }
                .allowsHitTesting(false)

            RoundedRectangle(cornerRadius: Layout.cropCornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.95), lineWidth: Layout.cropStrokeWidth)
                .frame(width: size.width, height: size.height)
                .allowsHitTesting(false)

            RoundedRectangle(cornerRadius: Layout.cropCornerRadius + 2, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                .frame(width: size.width + 4, height: size.height + 4)
                .allowsHitTesting(false)
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
                gestureScale = max(proposed, FishialImageCropRenderer.minimumGestureScale)
                offset = clamped(offset, for: gestureScale)
            }
            .onEnded { _ in
                lastGestureScale = gestureScale
                lastOffset = clamped(offset, for: gestureScale)
                offset = lastOffset
            }
    }
}
#endif
