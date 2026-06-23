import SwiftUI

/// 3-column linked media grid; tap opens **`LinkedMediaFullscreenView`**.
struct LinkedMediaGridSection: View {
    let mediaItems: [DiveMediaPhoto]
    let timeZoneOffsetByMediaID: [UUID: Int?]
    let linkedMediaItems: [TripDetailLinkedMediaItem]
    @Binding var gallerySelectedMediaID: UUID?
    let featuredMediaPhotoID: UUID?
    let onToggleFeaturedTaggedMedia: (() -> Void)?
    let sightings: [SightingInstance]
    let marineLifeCatalog: [MarineLife]
    let ownerProfileID: UUID?
    let fullscreenConfiguration: LinkedMediaFullscreenView.Configuration
    let gridAccessibilityIdentifier: String
    let gridItemAccessibilityPrefix: String
    let sectionAccessibilityIdentifier: String
    let emptyMessage: String?
    let emptyAccessibilityIdentifier: String?
    var initialFullscreenMediaID: UUID?
    let onOpenDive: (UUID) -> Void

    @State private var fullscreenMediaSelection: FullscreenMediaSelection?
    @State private var didApplyInitialFullscreenSelection = false

    private struct FullscreenMediaSelection: Identifiable {
        let id: UUID
    }

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: LinkedMediaGridPresentation.spacing),
            count: LinkedMediaGridPresentation.columnCount
        )
    }

    var body: some View {
        Group {
            if mediaItems.isEmpty, let emptyMessage {
                Text(emptyMessage)
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier(emptyAccessibilityIdentifier ?? "LinkedMedia.Grid.Empty")
            } else {
                LazyVGrid(
                    columns: gridColumns,
                    spacing: LinkedMediaGridPresentation.spacing
                ) {
                    ForEach(mediaItems, id: \.id) { media in
                        gridCellButton(for: media)
                    }
                }
                .accessibilityIdentifier(gridAccessibilityIdentifier)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier(sectionAccessibilityIdentifier)
        .fullScreenCover(item: $fullscreenMediaSelection) { selection in
            LinkedMediaFullscreenView(
                mediaItems: mediaItems,
                timeZoneOffsetByMediaID: timeZoneOffsetByMediaID,
                linkedMediaItems: linkedMediaItems,
                selectedMediaID: $gallerySelectedMediaID,
                configuration: fullscreenConfiguration,
                featuredMediaPhotoID: featuredMediaPhotoID,
                onToggleFeatured: onToggleFeaturedTaggedMedia,
                sightings: sightings,
                marineLifeCatalog: marineLifeCatalog,
                ownerProfileID: ownerProfileID,
                onOpenDive: onOpenDive
            )
            .onAppear {
                gallerySelectedMediaID = selection.id
            }
        }
        .onAppear(perform: applyInitialFullscreenSelectionIfNeeded)
        .onChange(of: initialFullscreenMediaID) { _, _ in
            didApplyInitialFullscreenSelection = false
            applyInitialFullscreenSelectionIfNeeded()
        }
        .onChange(of: mediaItems.count) { _, _ in
            didApplyInitialFullscreenSelection = false
            applyInitialFullscreenSelectionIfNeeded()
        }
    }

    private func applyInitialFullscreenSelectionIfNeeded() {
        guard !didApplyInitialFullscreenSelection,
              let initialFullscreenMediaID,
              mediaItems.contains(where: { $0.id == initialFullscreenMediaID })
        else { return }

        gallerySelectedMediaID = initialFullscreenMediaID
        fullscreenMediaSelection = FullscreenMediaSelection(id: initialFullscreenMediaID)
        didApplyInitialFullscreenSelection = true
    }

    private func gridCellButton(for media: DiveMediaPhoto) -> some View {
        Button {
            gallerySelectedMediaID = media.id
            fullscreenMediaSelection = FullscreenMediaSelection(id: media.id)
        } label: {
            gridCell(for: media)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(gridCellAccessibilityLabel(for: media))
        .accessibilityIdentifier("\(gridItemAccessibilityPrefix).\(media.id.uuidString)")
    }

    private func gridCell(for media: DiveMediaPhoto) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GeometryReader { proxy in
                    let side = min(proxy.size.width, proxy.size.height)
                    DiveActivityMediaThumbnailView(
                        media: media,
                        size: side,
                        cornerRadius: LinkedMediaGridPresentation.cornerRadius
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: LinkedMediaGridPresentation.cornerRadius,
                    style: .continuous
                )
            )
            .overlay(alignment: .topTrailing) {
                if media.id == featuredMediaPhotoID {
                    featuredBadge
                        .padding(6)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if showsMarineLifeIndicator(for: media.id) {
                    marineLifeBadge
                        .padding(6)
                }
            }
    }

    private var featuredBadge: some View {
        Image(systemName: "star.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(4)
            .background {
                Circle()
                    .fill(AppTheme.Colors.accent)
            }
            .accessibilityHidden(true)
    }

    private var marineLifeBadge: some View {
        Image(systemName: "fish.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(4)
            .background {
                Circle()
                    .fill(AppTheme.Colors.accent)
            }
            .accessibilityHidden(true)
    }

    private func showsMarineLifeIndicator(for mediaID: UUID) -> Bool {
        fullscreenConfiguration.showsMarineLifeTagButton
            && TripDetailMediaGalleryPresentation.showsMarineLifeTagIndicator(
                mediaID: mediaID,
                sightings: sightings
            )
    }

    private func gridCellAccessibilityLabel(for media: DiveMediaPhoto) -> String {
        let kind = media.resolvedMediaKind == .video ? "Video" : "Photo"
        if media.id == featuredMediaPhotoID {
            return "Featured \(kind.lowercased())"
        }
        if showsMarineLifeIndicator(for: media.id) {
            return "\(kind), marine life tagged"
        }
        return kind
    }
}
