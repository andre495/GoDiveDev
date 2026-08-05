import SwiftUI

/// Swipable species detail pages — about → stats → similar → tagged dives → tagged media.
struct FieldGuideSpeciesDetailContentPager: View {
    let aboutText: String
    let typicalSizeLine: String
    let depthLine: String
    let depthRowTitle: String
    let distinctiveFeatures: String
    let similarSpecies: [MarineLifeCatalogSnapshot]
    let taggedDiveRows: [DiveLogbookRowDisplayData]
    let taggedMediaItems: [DiveMediaPhoto]
    let taggedMediaTimeZoneOffsetByID: [UUID: Int?]
    let linkedMediaItems: [TripDetailLinkedMediaItem]
    let mediaSightings: [SightingInstance]
    let marineLifeCatalog: [MarineLife]
    let ownerProfileID: UUID?
    let bottomScrollInset: CGFloat
    let onOpenDive: (UUID) -> Void
    let onOpenSpecies: ((String) -> Void)?

    @State private var selectedPage: FieldGuideSpeciesDetailContentPage =
        FieldGuideSpeciesDetailContentPagerPresentation.defaultPage
    @State private var gallerySelectedMediaID: UUID?

    var body: some View {
        BlueSheetDetailPager(
            pagerAccessibilityIdentifier: "FieldGuide.SpeciesDetail.ContentPager",
            pages: FieldGuideSpeciesDetailContentPagerPresentation.pages,
            selection: $selectedPage,
            bottomScrollInset: bottomScrollInset,
            pageLayout: FieldGuideSpeciesDetailContentPagerPresentation.pagerPageLayout(for:),
            pageContent: pageContent(for:)
        )
    }

    @ViewBuilder
    private func pageContent(for page: FieldGuideSpeciesDetailContentPage) -> some View {
        switch page {
        case .about:
            aboutContent
        case .stats:
            statsContent
        case .similarSpecies:
            similarSpeciesContent
        case .taggedDives:
            taggedDivesContent
        case .taggedMedia:
            taggedMediaContent
        }
    }

    @ViewBuilder
    private var aboutContent: some View {
        let trimmed = aboutText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            emptyState(for: .about)
        } else {
            Text(trimmed)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("FieldGuide.SpeciesDetail.AboutBody")
        }
    }

    @ViewBuilder
    private var statsContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            detailRow(title: "Typical size", value: typicalSizeLine)
            detailRow(title: depthRowTitle, value: depthLine)

            if !distinctiveFeatures.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Distinctive features")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(distinctiveFeatures)
                        .font(.body)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityIdentifier("FieldGuide.SpeciesDetail.DistinctiveFeatures")
            }
        }
        .accessibilityIdentifier("FieldGuide.SpeciesDetail.Stats")
    }

    @ViewBuilder
    private var similarSpeciesContent: some View {
        if similarSpecies.isEmpty {
            emptyState(for: .similarSpecies)
        } else {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                ForEach(similarSpecies, id: \.uuid) { snapshot in
                    similarSpeciesRow(for: snapshot)
                    if snapshot.uuid != similarSpecies.last?.uuid {
                        Divider()
                            .opacity(0.35)
                    }
                }
            }
            .accessibilityIdentifier("FieldGuide.SpeciesDetail.SimilarSpecies")
        }
    }

    @ViewBuilder
    private func similarSpeciesRow(for snapshot: MarineLifeCatalogSnapshot) -> some View {
        let row = FieldGuideSimilarSpeciesRow(snapshot: snapshot)
        if let onOpenSpecies {
            Button {
                onOpenSpecies(snapshot.uuid)
            } label: {
                row
            }
            .buttonStyle(.plain)
        } else if let species = marineLifeCatalog.first(where: { $0.uuid == snapshot.uuid }) {
            NavigationLink {
                FieldGuideMarineLifeDetailView(
                    species: species,
                    ownerProfileID: ownerProfileID,
                    onOpenDive: onOpenDive
                )
                .hidesBottomTabBarWhenPushed()
            } label: {
                row
            }
            .buttonStyle(.plain)
            .navigationLinkIndicatorVisibility(.hidden)
        } else {
            row
        }
    }

    @ViewBuilder
    private var taggedDivesContent: some View {
        if taggedDiveRows.isEmpty {
            emptyState(for: .taggedDives)
        } else {
            LinkedDiveLogbookListRows(
                rows: taggedDiveRows,
                listAccessibilityIdentifier: "FieldGuide.SpeciesDetail.TaggedDives.List",
                onOpenDive: onOpenDive
            )
            .accessibilityIdentifier("FieldGuide.SpeciesDetail.TaggedDives")
        }
    }

    @ViewBuilder
    private var taggedMediaContent: some View {
        if taggedMediaItems.isEmpty {
            emptyState(for: .taggedMedia)
        } else {
            TripDetailMediaGallerySection(
                mediaItems: taggedMediaItems,
                timeZoneOffsetByMediaID: taggedMediaTimeZoneOffsetByID,
                linkedMediaItems: linkedMediaItems,
                sightings: mediaSightings,
                marineLifeCatalog: marineLifeCatalog,
                ownerProfileID: ownerProfileID,
                featuredMediaPhotoID: nil,
                selectedMediaID: $gallerySelectedMediaID,
                onToggleFeaturedTripMedia: nil,
                onOpenDive: onOpenDive
            )
            .accessibilityIdentifier("FieldGuide.SpeciesDetail.TaggedMedia")
        }
    }

    private func emptyState(for page: FieldGuideSpeciesDetailContentPage) -> some View {
        Text(FieldGuideSpeciesDetailContentPagerPresentation.emptyStateMessage(for: page))
            .font(.body)
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier(emptyStateAccessibilityIdentifier(for: page))
    }

    private func emptyStateAccessibilityIdentifier(for page: FieldGuideSpeciesDetailContentPage) -> String {
        switch page {
        case .about:
            return "FieldGuide.SpeciesDetail.About.Empty"
        case .stats:
            return "FieldGuide.SpeciesDetail.Stats.Empty"
        case .similarSpecies:
            return "FieldGuide.SpeciesDetail.SimilarSpecies.Empty"
        case .taggedDives:
            return "FieldGuide.SpeciesDetail.TaggedDives.Empty"
        case .taggedMedia:
            return "FieldGuide.SpeciesDetail.TaggedMedia.Empty"
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Spacer(minLength: AppTheme.Spacing.sm)
            Text(value.isEmpty ? "—" : value)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.trailing)
        }
    }
}
