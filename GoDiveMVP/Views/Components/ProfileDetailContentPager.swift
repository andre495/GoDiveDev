import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Profile sheet pager — diver stats (lifetime tiles + certifications) → tagged media.
struct ProfileDetailContentPager: View {
    let lifetimeStats: HomeLifetimeStats
    let myActivitiesSummary: LogbookMyActivitiesSummary
    let lifetimeStatsContentFingerprint: Int
    let unitSystem: DiveDisplayUnitSystem
    let onOpenLeaderboard: (HomeLifetimeStatsLeaderboardKind) -> Void

    let certifications: [Certification]

    let taggedMediaItems: [DiveMediaPhoto]
    let taggedMediaTimeZoneOffsetByID: [UUID: Int?]
    let linkedMediaItems: [TripDetailLinkedMediaItem]
    let mediaSightings: [SightingInstance]
    let marineLifeCatalog: [MarineLife]
    let ownerProfileID: UUID?
    let featuredTaggedMediaPhotoID: UUID?
    @Binding var gallerySelectedMediaID: UUID?
    let onToggleFeaturedTaggedMedia: (() -> Void)?
    let onOpenDive: (UUID) -> Void

    let bottomScrollInset: CGFloat
    var onPageFirstMounted: ((ProfileDetailContentPage) -> Void)? = nil

    @State private var selectedPage: ProfileDetailContentPage =
        ProfileDetailContentPagerPresentation.defaultPage

    var body: some View {
        BlueSheetDetailPager(
            pagerAccessibilityIdentifier: "Profile.ContentPager",
            pages: ProfileDetailContentPagerPresentation.pages,
            selection: $selectedPage,
            bottomScrollInset: bottomScrollInset,
            onPageFirstMounted: onPageFirstMounted,
            pageLayout: ProfileDetailContentPagerPresentation.pagerPageLayout(for:),
            pageContent: pageContent(for:)
        )
    }

    @ViewBuilder
    private func pageContent(for page: ProfileDetailContentPage) -> some View {
        switch page {
        case .diverStats:
            diverStatsContent
        case .taggedMedia:
            taggedMediaContent
        }
    }

    private var diverStatsContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            HomeLifetimeStatsSection(
                stats: lifetimeStats,
                myActivitiesSummary: myActivitiesSummary,
                buddyLeaderboard: [],
                unitSystem: unitSystem,
                onOpenLeaderboard: onOpenLeaderboard,
                onOpenBuddy: { _ in },
                includesBuddyLeaderboard: ProfileDetailContentPagerPresentation.showsBuddyLeaderboardOnDiverStats,
                includesLifetimeSummaryHeader: ProfileDetailContentPagerPresentation.showsLifetimeSummaryOnDiverStats
            )
            .id(lifetimeStatsContentFingerprint)
            .fixedSize(horizontal: false, vertical: true)

            profileCertificationsSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("Profile.DiverStats")
    }

    @ViewBuilder
    private var profileCertificationsSection: some View {
        let sorted = CertificationPresentation.sortedForList(certifications)
        if !sorted.isEmpty {
            VStack(spacing: AppTheme.Spacing.sm) {
                ForEach(sorted, id: \.id) { certification in
                    NavigationLink {
                        ViewCertificationDetails(certification: certification)
                    } label: {
                        ProfileCertificationStatTile(certification: certification)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("Profile.CertificationTile.\(certification.id.uuidString)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("Profile.Certifications")
        }
    }

    @ViewBuilder
    private var taggedMediaContent: some View {
        if taggedMediaItems.isEmpty {
            Text(ProfileDetailContentPagerPresentation.emptyStateMessage(for: .taggedMedia))
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("Profile.EmptyTaggedMedia")
        } else {
            ProfileTaggedMediaGridSection(
                mediaItems: taggedMediaItems,
                timeZoneOffsetByMediaID: taggedMediaTimeZoneOffsetByID,
                linkedMediaItems: linkedMediaItems,
                sightings: mediaSightings,
                marineLifeCatalog: marineLifeCatalog,
                ownerProfileID: ownerProfileID,
                featuredMediaPhotoID: featuredTaggedMediaPhotoID,
                gallerySelectedMediaID: $gallerySelectedMediaID,
                onToggleFeaturedTaggedMedia: onToggleFeaturedTaggedMedia,
                onOpenDive: onOpenDive
            )
            .accessibilityIdentifier("Profile.TaggedMedia")
        }
    }
}

/// Full-width certification tile on Profile **Diver stats** — logbook-style text + trailing cover.
struct ProfileCertificationStatTile: View {
    let certification: Certification

    /// Landscape cert-card thumbnail (trailing), sized like a compact logbook preview.
    private let coverWidth: CGFloat = 72
    private let coverHeight: CGFloat = 54
    private let coverCornerRadius: CGFloat = DiveActivityMediaPresentation.logbookRowMediaPreviewCornerRadius

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: LogbookActivityRowLayout.contentSpacing) {
                Text(CertificationPresentation.title(for: certification))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)

                Text(CertificationPresentation.listAgencyLine(for: certification))
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(1)

                Text(CertificationPresentation.listDateLine(for: certification))
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: LogbookActivityRowLayout.previewGap)

            coverPreview
        }
        .padding(LogbookActivityRowLayout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background {
            RoundedRectangle(cornerRadius: LogbookActivityRowLayout.cardCornerRadius, style: .continuous)
                .fill(AppListTileCardChrome.fill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: LogbookActivityRowLayout.cardCornerRadius, style: .continuous)
                .stroke(AppListTileCardChrome.stroke, lineWidth: AppListTileCardChrome.strokeWidth)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint("Opens certification details")
    }

    private var accessibilityLabelText: String {
        [
            CertificationPresentation.title(for: certification),
            CertificationPresentation.listAgencyLine(for: certification),
            CertificationPresentation.listDateLine(for: certification),
        ].joined(separator: ", ")
    }

    @ViewBuilder
    private var coverPreview: some View {
        Group {
            #if canImport(UIKit)
            if certification.certFrontPicture != nil {
                GoDiveCachedBlobImageView(
                    data: certification.certFrontPicture,
                    maxPixelEdge: 160,
                    contentMode: .fill
                ) {
                    coverPlaceholder
                }
            } else {
                coverPlaceholder
            }
            #else
            coverPlaceholder
            #endif
        }
        .frame(width: coverWidth, height: coverHeight)
        .clipShape(RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous))
        .accessibilityLabel("Certification card front")
        .accessibilityHidden(true)
    }

    private var coverPlaceholder: some View {
        Image(systemName: "checkmark.seal.fill")
            .font(.title3)
            .foregroundStyle(AppTheme.Colors.accent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.Colors.surfaceMuted.opacity(0.5))
    }
}
