import SwiftData
import SwiftUI

/// Pushed catalog dive-site detail from **Explore** (replaces sheet presentation).
struct ExploreDiveSiteDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountSession.self) private var accountSession

    @Query(sort: \MarineLife.commonName) private var marineLifeCatalog: [MarineLife]
    @Query private var ownerDiveActivities: [DiveActivity]
    @Query private var siteSightings: [SightingInstance]

    let site: DiveSite

    init(site: DiveSite, ownerProfileID: UUID?) {
        self.site = site
        let diveSiteID = site.id
        let ownerFilterID = ownerProfileID ?? Self.noOwnerQueryToken
        _ownerDiveActivities = Query(
            filter: #Predicate<DiveActivity> { $0.ownerProfileID == ownerFilterID },
            sort: [
                SortDescriptor(\DiveActivity.startTime, order: .reverse),
                SortDescriptor(\DiveActivity.id, order: .forward),
            ]
        )
        _siteSightings = Query(
            filter: #Predicate<SightingInstance> { $0.diveSiteID == diveSiteID },
            sort: [SortDescriptor(\.sightingDateTime, order: .reverse)]
        )
    }

    private var catalogByUUID: [String: MarineLifeCatalogSnapshot] {
        Dictionary(uniqueKeysWithValues: marineLifeCatalog.map {
            ($0.uuid, $0.fieldGuideCatalogSnapshot)
        })
    }

    private var ownerDiveActivityIDs: Set<UUID> {
        Set(ownerDiveActivities.map(\.id))
    }

    private var taggedMediaItems: [DiveMediaPhoto] {
        FieldGuideTaggedMediaPresentation.resolvedTaggedMediaPhotos(
            sightings: siteSightings,
            ownerDiveActivityIDs: ownerDiveActivityIDs,
            modelContext: modelContext
        )
    }

    private var taggedMediaTimeZoneOffsetByID: [UUID: Int?] {
        let offsetByActivityID = Dictionary(
            uniqueKeysWithValues: ownerDiveActivities.map { ($0.id, $0.timeZoneOffsetSeconds) }
        )
        return FieldGuideTaggedMediaPresentation.timeZoneOffsetByMediaID(
            sightings: siteSightings,
            ownerDiveActivityIDs: ownerDiveActivityIDs,
            timeZoneOffsetByActivityID: offsetByActivityID
        )
    }

    private var sightedSpeciesLinks: [DiveSiteMarineLifePresentation.SightedSpeciesLinkData] {
        DiveSiteMarineLifePresentation.sightedSpeciesLinks(
            diveSiteID: site.id,
            ownerProfileID: accountSession.currentProfile?.id,
            sightings: siteSightings,
            ownerDiveActivityIDs: ownerDiveActivityIDs,
            catalogByUUID: catalogByUUID
        )
    }

    private var siteActivityLinks: [FieldGuidePresentation.SightedActivityLinkData] {
        let snapshots = ownerDiveActivities.map {
            DiveActivitySightingLinkSnapshot(
                id: $0.id,
                diveSiteID: $0.diveSiteID,
                resolvedSiteName: $0.resolvedSiteName,
                startTime: $0.startTime,
                timeZoneOffsetSeconds: $0.timeZoneOffsetSeconds
            )
        }
        return DiveSiteMarineLifePresentation.siteActivityLinks(
            diveSiteID: site.id,
            ownerProfileID: accountSession.currentProfile?.id,
            activities: snapshots
        )
    }

    var body: some View {
        AppPage(
            title: site.siteName,
            showsBackButton: true,
            trailingContent: { EmptyView() }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    if let coordinate = siteCoordinate {
                        detailSection(title: "Location") {
                            detailRow(
                                title: "Coordinates",
                                value: DiveLocationMapPresentation.coordinateLabel(for: coordinate)
                            )
                        }
                    }

                    if !placeRows.isEmpty {
                        detailSection(title: "Place") {
                            ForEach(placeRows, id: \.label) { row in
                                detailRow(title: row.label, value: row.value)
                            }
                        }
                    }

                    detailSection(title: "Details") {
                        if let rating = site.siteRating {
                            detailRow(title: "Rating", value: "\(rating) / 5")
                        } else {
                            detailRow(title: "Rating", value: "Not rated")
                        }

                        if site.siteTags.isEmpty {
                            detailRow(title: "Tags", value: "None")
                        } else {
                            detailRow(title: "Tags", value: site.siteTags.joined(separator: ", "))
                        }

                        detailRow(
                            title: "Dives logged here",
                            value: "\(site.diveActivities.count)"
                        )
                    }

                    if !taggedMediaItems.isEmpty {
                        FieldGuideTaggedMediaGalleryView(
                            mediaItems: taggedMediaItems,
                            timeZoneOffsetByMediaID: taggedMediaTimeZoneOffsetByID,
                            previewAccessibilityIdentifier: "Explore.DiveSiteDetail.TaggedMediaPreview",
                            carouselAccessibilityIdentifier: "Explore.DiveSiteDetail.TaggedMediaCarousel"
                        )
                    }

                    activitiesAtSiteSection
                    marineLifeSightedSection
                }
                .padding(AppTheme.Spacing.md)
            }
        }
        .hidesBottomTabBarWhenPushed()
        .accessibilityIdentifier("Explore.DiveSiteDetail.Root")
    }

    private var marineLifeSightedSection: some View {
        detailSection(title: "Marine life sighted here") {
            if sightedSpeciesLinks.isEmpty {
                Text("None logged yet")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(sightedSpeciesLinks) { link in
                        NavigationLink(value: ExploreRoute.speciesDetail(link.marineLifeUUID)) {
                            marineLifeLinkRow(link)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(
                            "Explore.DiveSiteDetail.MarineLife.\(link.marineLifeUUID)"
                        )
                    }
                }
            }
        }
    }

    private var activitiesAtSiteSection: some View {
        ExpandableDetailSection(
            title: "Activities at this site",
            itemCount: siteActivityLinks.count,
            accessibilityIdentifier: "Explore.DiveSiteDetail.ActivitiesAtSite"
        ) {
            Text("None logged yet")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        } content: {
            VStack(spacing: AppTheme.Spacing.sm) {
                ForEach(siteActivityLinks) { link in
                    NavigationLink(value: ExploreRoute.diveDetail(link.id)) {
                        activityLinkRow(link)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("Explore.DiveSiteDetail.DiveLink.\(link.id.uuidString)")
                }
            }
        }
    }

    private func marineLifeLinkRow(
        _ link: DiveSiteMarineLifePresentation.SightedSpeciesLinkData
    ) -> some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            Text(link.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.leading)

            Spacer(minLength: AppTheme.Spacing.sm)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabUnselected)
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.surfaceElevated)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.Colors.tabUnselected.opacity(0.12), lineWidth: 1)
        }
    }

    private func activityLinkRow(_ link: FieldGuidePresentation.SightedActivityLinkData) -> some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(link.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)

                Text(link.dateText)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }

            Spacer(minLength: AppTheme.Spacing.sm)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabUnselected)
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.surfaceElevated)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.Colors.tabUnselected.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(link.title), \(link.dateText)")
        .accessibilityHint("Opens this dive")
    }

    private func detailSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            content()
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Spacer(minLength: AppTheme.Spacing.sm)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.trailing)
        }
    }

    private var siteCoordinate: DiveCoordinate? {
        DiveMapCoordinateResolver.coordinate(from: site)
    }

    private var placeRows: [(label: String, value: String)] {
        var rows: [(label: String, value: String)] = []
        let country = site.country.trimmingCharacters(in: .whitespacesAndNewlines)
        let region = site.region.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = site.bodyOfWater.trimmingCharacters(in: .whitespacesAndNewlines)
        if !country.isEmpty { rows.append((label: "Country", value: country)) }
        if !region.isEmpty { rows.append((label: "Region", value: region)) }
        if !body.isEmpty { rows.append((label: "Body of water", value: body)) }
        return rows
    }

    /// Sentinel **`ownerProfileID`** so **`@Query`** returns no dives when signed out.
    private static let noOwnerQueryToken = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
}

/// Explore stack routes (shared with **`ExploreView`**).
enum ExploreRoute: Hashable {
    case tripPlanner
    case siteDetail(UUID)
    case speciesDetail(String)
    case diveDetail(UUID)
}
