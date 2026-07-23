import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Profile sheet pager — diver stats → DAN & certification → tagged media.
struct ProfileDetailContentPager: View {
    let lifetimeStats: HomeLifetimeStats
    let myActivitiesSummary: LogbookMyActivitiesSummary
    let buddyLeaderboard: [HomeBuddyLeaderboardEntry]
    let lifetimeStatsContentFingerprint: Int
    let unitSystem: DiveDisplayUnitSystem
    let onOpenLeaderboard: (HomeLifetimeStatsLeaderboardKind) -> Void
    let onOpenBuddy: (UUID) -> Void

    let danInsuranceNumber: String?
    let featuredCertification: Certification?
    let featuredCertificationDisplay: CertificationPresentation.ProfileFeaturedCertificationDisplay?
    let certificationCount: Int
    let onViewAllCertifications: () -> Void

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
        case .details:
            ProfileDetailDetailsMetadataView(
                danInsuranceNumber: danInsuranceNumber,
                featuredCertification: featuredCertification,
                featuredCertificationDisplay: featuredCertificationDisplay,
                certificationCount: certificationCount,
                onViewAllCertifications: onViewAllCertifications
            )
        case .taggedMedia:
            taggedMediaContent
        }
    }

    private var diverStatsContent: some View {
        HomeLifetimeStatsSection(
            stats: lifetimeStats,
            myActivitiesSummary: myActivitiesSummary,
            buddyLeaderboard: buddyLeaderboard,
            unitSystem: unitSystem,
            onOpenLeaderboard: onOpenLeaderboard,
            onOpenBuddy: onOpenBuddy
        )
        .id(lifetimeStatsContentFingerprint)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("Profile.DiverStats")
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

/// Profile sheet — DAN insurance + featured certification rows.
struct ProfileDetailDetailsMetadataView: View {
    let danInsuranceNumber: String?
    let featuredCertification: Certification?
    let featuredCertificationDisplay: CertificationPresentation.ProfileFeaturedCertificationDisplay?
    let certificationCount: Int
    let onViewAllCertifications: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            danSection
            certificationSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, AppTheme.Spacing.sm)
        .accessibilityIdentifier("Profile.Details")
    }

    private var danSection: some View {
        detailSection(title: ProfileDetailContentPagerPresentation.danSectionTitle) {
            danMemberNumberLinkRow
        }
    }

    private var danMemberNumberLinkRow: some View {
        let displayNumber = ProfileDetailContentPagerPresentation.formattedDanMemberNumberForDisplay(
            danInsuranceNumber
        )
        return VStack(alignment: .leading, spacing: 4) {
            Text(ProfileDetailContentPagerPresentation.danMemberNumberLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.secondaryText)

            Link(destination: ProfileDetailContentPagerPresentation.danWebsiteURL) {
                Text(displayNumber)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.tabSelected)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityLabel(
                "\(ProfileDetailContentPagerPresentation.danMemberNumberLabel), \(displayNumber)"
            )
            .accessibilityHint(ProfileDetailContentPagerPresentation.danWebsiteLinkAccessibilityHint)
            .accessibilityIdentifier("Profile.DanInsuranceNumber")
        }
    }

    @ViewBuilder
    private var certificationSection: some View {
        detailSection(title: ProfileDetailContentPagerPresentation.certificationSectionTitle) {
            if let featuredCertification, let display = featuredCertificationDisplay {
                NavigationLink {
                    ViewCertificationDetails(certification: featuredCertification)
                } label: {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                        ProfileFeaturedCertificationFrontPreview(
                            imageData: featuredCertification.certFrontPicture
                        )

                        detailRow(
                            label: ProfileDetailContentPagerPresentation.certificationNameLabel,
                            value: display.title
                        )
                        if let number = display.certNumber {
                            detailRow(
                                label: ProfileDetailContentPagerPresentation.certificationNumberLabel,
                                value: number
                            )
                        }
                        detailRow(
                            label: ProfileDetailContentPagerPresentation.certificationDateAttainedLabel,
                            value: CertificationPresentation.listDateLine(for: featuredCertification)
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View certification, \(display.title)")
                .accessibilityIdentifier("Profile.FeaturedCertificationLink")

                if certificationCount > 1 {
                    Button(action: onViewAllCertifications) {
                        Text(ProfileDetailContentPagerPresentation.viewAllCertificationsTitle)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.tabSelected)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("Profile.ViewAllCertifications")
                }
            } else {
                emptyMessage(ProfileDetailContentPagerPresentation.emptyCertificationMessage)
            }
        }
    }

    private func detailSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                content()
            }
            .padding(AppTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.Colors.surfaceElevated)
            )
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
            Text(value)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func emptyMessage(_ message: String) -> some View {
        Text(message)
            .font(.body)
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Featured certification card front — profile Details sheet.
private struct ProfileFeaturedCertificationFrontPreview: View {
    let imageData: Data?

    private let cornerRadius: CGFloat = 10
    private let maxPreviewHeight: CGFloat = 148

    var body: some View {
        Group {
            #if canImport(UIKit)
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: maxPreviewHeight)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(AppTheme.Colors.tabUnselected.opacity(0.2), lineWidth: 1)
                    }
                    .accessibilityLabel("Certification card front")
                    .accessibilityIdentifier("Profile.FeaturedCertification.FrontImage")
            } else {
                frontPlaceholder
            }
            #else
            frontPlaceholder
            #endif
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var frontPlaceholder: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title)
                .foregroundStyle(AppTheme.Colors.accent)
            Text("No card photo")
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .frame(height: maxPreviewHeight * 0.65)
        .background(AppTheme.Colors.surfaceMuted.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityIdentifier("Profile.FeaturedCertification.FrontImagePlaceholder")
    }
}
