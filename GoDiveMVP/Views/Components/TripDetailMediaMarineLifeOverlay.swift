import SwiftUI

/// Background treatment for **`TripDetailMediaMarineLifeOverlay`**.
enum MarineLifeMediaOverlayBackgroundStyle: Sendable {
    /// Opaque elevated card over the trip media preview (default on **Trips**).
    case tripPreviewCard
    /// Semi-transparent dimming panel so underlying photo/video remains visible.
    case overMediaDimming
}

/// Close control placement for **`TripDetailMediaMarineLifeOverlay`**.
enum MarineLifeMediaOverlayClosePlacement: Sendable {
    case leading
    case trailing
}

/// Full-bleed marine-life card over trip media — feature image, name, link to Field Guide overview.
struct TripDetailMediaMarineLifeOverlay: View {
    let taggedSpecies: [MarineLife]
    let previewSize: CGSize
    let cornerRadius: CGFloat
    let ownerProfileID: UUID?
    var featureImageHeight: CGFloat = TripDetailMediaGalleryPresentation.marineLifeOverlayFeatureImageHeight
    var featureImageMaxWidth: CGFloat = TripDetailMediaGalleryPresentation.marineLifeOverlayFeatureImageMaxWidth
    var backgroundStyle: MarineLifeMediaOverlayBackgroundStyle = .tripPreviewCard
    var closePlacement: MarineLifeMediaOverlayClosePlacement = .trailing
    /// Extra top inset for the close control (Home carousel — clears **`AppHeader`**).
    var closeTopInset: CGFloat?
    var accessibilityRoot: String = "TripDetail.Media.MarineLifeOverlay"
    @Binding var selectedSpeciesUUID: String?
    var onOpenDive: (UUID) -> Void
    var onClose: () -> Void

    private var resolvedSelectedSpecies: MarineLife? {
        guard let resolvedUUID = DiveActivityMediaPresentation.resolvedTaggedSpeciesUUID(
            selectedUUID: selectedSpeciesUUID,
            taggedSpeciesUUIDs: taggedSpecies.map(\.uuid)
        ) else { return nil }
        return taggedSpecies.first(where: { $0.uuid == resolvedUUID })
    }

    private var closeButtonAlignment: Alignment {
        switch closePlacement {
        case .leading: .topLeading
        case .trailing: .topTrailing
        }
    }

    private var resolvedCloseTopInset: CGFloat {
        closeTopInset ?? AppTheme.Spacing.md
    }

    var body: some View {
        ZStack(alignment: closeButtonAlignment) {
            overlayBackground

            VStack(spacing: AppTheme.Spacing.lg) {
                if taggedSpecies.count > 1 {
                    speciesSelector
                        .padding(.top, AppTheme.Spacing.lg + AppTheme.Spacing.md)
                        .padding(.leading, closePlacement == .leading ? 36 : 0)
                } else {
                    Spacer(minLength: AppTheme.Spacing.lg)
                }

                if let resolvedSelectedSpecies {
                    speciesCard(for: resolvedSelectedSpecies)
                }

                Spacer(minLength: AppTheme.Spacing.lg)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .frame(width: previewSize.width, height: previewSize.height, alignment: .top)

            closeButton
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, resolvedCloseTopInset)
        }
        .frame(width: previewSize.width, height: previewSize.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityRoot)
    }

    @ViewBuilder
    private var overlayBackground: some View {
        switch backgroundStyle {
        case .tripPreviewCard:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(AppTheme.Colors.tabUnselected.opacity(0.12), lineWidth: 1)
                }
        case .overMediaDimming:
            Color.black.opacity(TripDetailMediaGalleryPresentation.marineLifeOverlayMediaScrimOpacity)
                .ignoresSafeArea()
        }
    }

    private var speciesSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MarineLifeMediaTagPresentation.chipRowSpacing) {
                ForEach(taggedSpecies, id: \.uuid) { species in
                    Button {
                        selectedSpeciesUUID = species.uuid
                    } label: {
                        ActivityTagOvalChipLabel(
                            title: MarineLifeMediaTagPresentation.chipDisplayTitle(for: species.commonName),
                            isEmphasized: species.uuid == resolvedSelectedSpecies?.uuid
                        )
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("\(accessibilityRoot).Species.\(species.uuid)")
                }
            }
        }
    }

    @ViewBuilder
    private func speciesCard(for species: MarineLife) -> some View {
        VStack(spacing: AppTheme.Spacing.md) {
            featureImage(for: species)

            NavigationLink {
                FieldGuideMarineLifeDetailView(
                    species: species,
                    ownerProfileID: ownerProfileID,
                    onOpenDive: onOpenDive
                )
                .hidesBottomTabBarWhenPushed()
                .onAppear(perform: onClose)
            } label: {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Text(species.commonName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(speciesNameColor)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(speciesNameColor)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .navigationLinkIndicatorVisibility(.hidden)
            .accessibilityIdentifier("\(accessibilityRoot).ViewOverview")
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var speciesNameColor: Color {
        switch backgroundStyle {
        case .tripPreviewCard:
            AppTheme.Colors.accent
        case .overMediaDimming:
            .white
        }
    }

    @ViewBuilder
    private func featureImage(for species: MarineLife) -> some View {
        FieldGuideMarineLifeCatalogImage(
            imageURLString: species.featureImageURL,
            bundleResourceName: species.featureImageResourceName,
            placement: .mediaSheetHero(height: featureImageHeight)
        )
        .frame(maxWidth: featureImageMaxWidth)
        .frame(maxWidth: .infinity)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Group {
                switch backgroundStyle {
                case .tripPreviewCard:
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(AppTheme.Colors.tabUnselected)
                case .overMediaDimming:
                    Image(systemName: "xmark")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background {
                            Circle()
                                .fill(.black.opacity(0.48))
                                .background {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                }
                                .clipShape(Circle())
                        }
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close marine life overview")
        .accessibilityIdentifier("\(accessibilityRoot).Close")
        .zIndex(10)
    }
}
