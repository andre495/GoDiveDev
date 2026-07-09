import SwiftUI

/// Title + body copy for the upload-media empty state (Home carousel + dive **Media** sheet).
struct MediaUploadEmptyPromptTextBlock: View {
    let title: String
    let message: String
    var horizontalAlignment: HorizontalAlignment = .center

    var body: some View {
        VStack(alignment: horizontalAlignment, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(horizontalAlignment == .center ? .center : .leading)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(horizontalAlignment == .center ? .center : .leading)
                .lineSpacing(2)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: horizontalAlignment, vertical: .center))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

/// Bouncing ghost photo/video frames (Home carousel + dive **Media** hero).
struct MediaUploadEmptyGhostFramesAnimation: View {
    let containerWidth: CGFloat
    var verticalOffset: CGFloat = 0
    var contentScale: CGFloat = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ghostFrames
            .scaleEffect(contentScale)
            .offset(y: verticalOffset)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var ghostFrames: some View {
        if reduceMotion {
            staticGhostFrames
        } else {
            animatedGhostFrames
        }
    }

    private var staticGhostFrames: some View {
        ZStack {
            ForEach(0 ..< HomeMediaCarouselEmptyPresentation.frameCount, id: \.self) { index in
                ghostFrame(index: index, verticalOffset: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var animatedGhostFrames: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0 ..< HomeMediaCarouselEmptyPresentation.frameCount, id: \.self) { index in
                    let phase = HomeMediaCarouselEmptyPresentation.framePhaseOffset(index: index)
                    let cycle = HomeMediaCarouselEmptyPresentation.animationCycleSeconds
                    let wave = sin((elapsed / cycle + phase) * 2 * .pi)
                    ghostFrame(
                        index: index,
                        verticalOffset: HomeMediaCarouselEmptyPresentation.frameOffsetAmplitude(index: index) * wave
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func ghostFrame(index: Int, verticalOffset: CGFloat) -> some View {
        let frameSize = ghostFrameSize(index: index)
        return RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(AppTheme.Colors.surfaceElevated.opacity(0.55))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(AppTheme.Colors.accent.opacity(0.22), lineWidth: 1)
            }
            .overlay {
                Image(systemName: index == 1 ? "video.fill" : "photo.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.Colors.accent.opacity(0.45))
            }
            .frame(width: frameSize.width, height: frameSize.height)
            .rotationEffect(.degrees(HomeMediaCarouselEmptyPresentation.frameRotationDegrees(index: index)))
            .offset(
                x: ghostFrameHorizontalOffset(index: index),
                y: verticalOffset + ghostFrameVerticalOffset(index: index)
            )
            .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
    }

    private func ghostFrameSize(index: Int) -> CGSize {
        switch index {
        case 0: CGSize(width: 108, height: 132)
        case 1: CGSize(width: 118, height: 142)
        default: CGSize(width: 104, height: 126)
        }
    }

    private func ghostFrameHorizontalOffset(index: Int) -> CGFloat {
        switch index {
        case 0: -containerWidth * 0.22
        case 1: 0
        default: containerWidth * 0.22
        }
    }

    private func ghostFrameVerticalOffset(index: Int) -> CGFloat {
        switch index {
        case 0: -12
        case 1: -28
        default: -8
        }
    }
}

/// Bouncing ghost photo/video frames + upload encouragement copy (Home carousel).
struct AnimatedMediaUploadEmptyPrompt: View {
    let containerWidth: CGFloat
    var title: String
    var message: String
    var ghostFramesBottomPadding: CGFloat = 0
    var verticalOffset: CGFloat = 0
    var contentScale: CGFloat = 1

    var body: some View {
        Group {
            MediaUploadEmptyGhostFramesAnimation(
                containerWidth: containerWidth,
                verticalOffset: verticalOffset,
                contentScale: contentScale
            )
            .padding(.bottom, ghostFramesBottomPadding)

            MediaUploadEmptyPromptTextBlock(title: title, message: message)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

/// Shared **Log Your First Dive** Liquid Glass capsule — Home empty hero + Logbook empty state.
struct LogYourFirstDiveGlassButtonLabel: View {
    var body: some View {
        Text(HomeMediaCarouselEmptyPresentation.headline(for: .noLoggedActivities))
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, AppTheme.Spacing.md)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
    }
}

extension View {
    /// Compact glass capsule — text-width, same **44 pt** height as toolbar / search glass controls.
    func logYourFirstDiveGlassButtonChrome() -> some View {
        buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .controlSize(.regular)
            .frame(height: AppTheme.Layout.glassChromeControlHeight)
            .fixedSize(horizontal: true, vertical: false)
    }
}
