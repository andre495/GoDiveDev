import SwiftUI

/// Buddy-style species chip for the map-tab **Marine Life** section.
struct DiveActivityMarineLifeAvatarChip: View {
    let chip: DiveActivityMarineLifeOverviewPresentation.SpeciesChip
    var avatarDiameter: CGFloat = DiveActivityMarineLifeOverviewPresentation.avatarDiameter

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            avatar
                .frame(width: avatarDiameter, height: avatarDiameter)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .strokeBorder(AppTheme.Colors.accent.opacity(0.18), lineWidth: 1)
                }

            Text(chip.commonName)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.75)
        }
        .frame(width: max(avatarDiameter, 64))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(chip.commonName)
    }

    @ViewBuilder
    private var avatar: some View {
        switch chip.avatarKind {
        case .model3D(let resourceName):
            FieldGuideMarineLifeRealityHeroView(
                configuration: DiveActivityMarineLifeOverviewPresentation.compactModelSceneConfiguration(
                    resourceName: resourceName,
                    minSizeMeters: chip.minSizeMeters,
                    maxSizeMeters: chip.maxSizeMeters
                )
            )
            .allowsHitTesting(false)
            .background(AppTheme.Colors.surfaceElevated)

        case .photo(let resourceName, let imageURL):
            FieldGuideMarineLifeCatalogImage(
                imageURLString: imageURL,
                bundleResourceName: resourceName,
                placement: .mediaSheetHero(
                    height: avatarDiameter,
                    cornerRadius: avatarDiameter / 2
                )
            )

        case .fishIcon:
            Image(systemName: "fish.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.Colors.surfaceElevated)
        }
    }
}
