import SwiftUI

/// Bottom-leading hero circle — previews the alternate media source (catalog vs owner tagged media).
struct FieldGuideSpeciesHeroSourceToggle: View {
    enum PreviewContent {
        case catalogReference(
            featureModelResourceName: String,
            featureImageResourceName: String,
            featureImageURL: String,
            minSizeMeters: Double,
            maxSizeMeters: Double
        )
        case taggedUserMedia(DiveMediaPhoto)
    }

    let diameter: CGFloat
    let previewContent: PreviewContent
    let accessibilityLabel: String
    let accessibilityIdentifier: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            preview
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .strokeBorder(AppTheme.Colors.accentDeep, lineWidth: ringLineWidth)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var ringLineWidth: CGFloat {
        max(2, diameter / 24)
    }

    @ViewBuilder
    private var preview: some View {
        switch previewContent {
        case .catalogReference(
            let featureModelResourceName,
            let featureImageResourceName,
            let featureImageURL,
            let minSizeMeters,
            let maxSizeMeters
        ):
            catalogPreview(
                featureModelResourceName: featureModelResourceName,
                featureImageResourceName: featureImageResourceName,
                featureImageURL: featureImageURL,
                minSizeMeters: minSizeMeters,
                maxSizeMeters: maxSizeMeters
            )
        case .taggedUserMedia(let media):
            taggedMediaPreview(media: media)
        }
    }

    @ViewBuilder
    private func catalogPreview(
        featureModelResourceName: String,
        featureImageResourceName: String,
        featureImageURL: String,
        minSizeMeters: Double,
        maxSizeMeters: Double
    ) -> some View {
        let availability = FieldGuideSpeciesHeroPresentation.catalogHeroAvailability(
            featureModelResourceName: featureModelResourceName,
            featureImageResourceName: featureImageResourceName,
            featureImageURL: featureImageURL
        )
        let display = FieldGuideSpeciesHeroPresentation.defaultCatalogHeroDisplay(
            availability: availability
        )

        switch display {
        case .model3D:
            FieldGuideMarineLifeRealityHeroView(
                configuration: FieldGuideSpeciesHeroPresentation.compactSceneConfiguration(
                    for: FieldGuideMarineLifeHeroPresentation.sceneConfiguration(
                        forModelResourceName: featureModelResourceName,
                        minSizeMeters: minSizeMeters,
                        maxSizeMeters: maxSizeMeters
                    )
                )
            )
            .frame(height: diameter)
            .allowsHitTesting(false)
        case .image:
            FieldGuideMarineLifeCatalogImage(
                imageURLString: featureImageURL,
                bundleResourceName: featureImageResourceName,
                placement: .mediaSheetHero(height: diameter, cornerRadius: diameter / 2)
            )
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func taggedMediaPreview(media: DiveMediaPhoto) -> some View {
        DiveActivityMediaItemView(
            media: media,
            showsCaptureDateOverlay: false,
            isVideoPlaybackActive: DiveBuddyDetailPresentation.shouldAutoPlaySelectedVideo(for: media),
            loopsVideoPlayback: true
        )
        .allowsHitTesting(false)
    }
}
