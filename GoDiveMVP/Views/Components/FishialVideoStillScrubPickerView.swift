import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit) && canImport(AVFoundation)
/// Full-screen paused video + slider for choosing the still sent to Fishial.
struct FishialVideoStillScrubPickerView: View {
    let context: FishialVideoScrubContext
    @Binding var scrubFraction: Double

    @State private var isScrubbing = false

    var body: some View {
        ZStack(alignment: .bottom) {
            FishialVideoScrubPlayerView(
                avAsset: context.avAsset,
                durationSeconds: context.durationSeconds,
                scrubFraction: scrubFraction,
                isScrubbing: isScrubbing
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("DiveMediaFishialIdentify.ScrubPreview")

            scrubControls
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    private var scrubControls: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text(FishialImageCropPresentation.videoScrubInstruction)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Slider(
                value: $scrubFraction,
                in: 0...1
            ) {
                Text("Video position")
            } minimumValueLabel: {
                EmptyView()
            } maximumValueLabel: {
                EmptyView()
            } onEditingChanged: { editing in
                isScrubbing = editing
            }
            .tint(AppTheme.Colors.accent)
            .accessibilityIdentifier("DiveMediaFishialIdentify.ScrubSlider")

            HStack {
                Text(
                    FishialVideoScrubPresentation.formattedTimestamp(
                        durationSeconds: context.durationSeconds,
                        fraction: scrubFraction
                    )
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .monospacedDigit()

                Spacer(minLength: AppTheme.Spacing.sm)

                Text(
                    FishialVideoScrubPresentation.formattedDuration(
                        durationSeconds: context.durationSeconds
                    )
                )
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.tabUnselected)
                .monospacedDigit()
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.top, AppTheme.Spacing.md)
        .padding(.bottom, AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.92)
                .ignoresSafeArea(edges: .bottom)
        }
    }
}
#endif
