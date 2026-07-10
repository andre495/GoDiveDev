import SwiftData
import SwiftUI

/// Photos and videos where the signed-in diver tagged themself — pushed from **Profile**.
struct ProfileTaggedMediaView: View {
    @Environment(AccountSession.self) private var accountSession
    @Environment(\.modelContext) private var modelContext

    @Query private var ownerDiveActivities: [DiveActivity]

    @Query(sort: [SortDescriptor(\DiveMediaBuddyTag.id, order: .forward)])
    private var buddyMediaTags: [DiveMediaBuddyTag]

    @State private var selfBuddyID: UUID?

    private let ownerProfileID: UUID?

    init(ownerProfileID: UUID?) {
        self.ownerProfileID = ownerProfileID
        let filterOwnerID = ownerProfileID ?? Self.noOwnerQueryToken
        _ownerDiveActivities = Query(
            filter: #Predicate<DiveActivity> { $0.ownerProfileID == filterOwnerID },
            sort: [
                SortDescriptor(\DiveActivity.startTime, order: .reverse),
                SortDescriptor(\DiveActivity.id, order: .forward),
            ]
        )
    }

    private static let noOwnerQueryToken = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private var resolvedOwnerProfileID: UUID? {
        ownerProfileID ?? accountSession.currentProfile?.id
    }

    private var ownerDiveActivityIDs: Set<UUID> {
        Set(ownerDiveActivities.map(\.id))
    }

    private var selfBuddyTags: [DiveMediaBuddyTag] {
        guard let selfBuddyID else { return [] }
        return buddyMediaTags.filter { $0.buddyID == selfBuddyID }
    }

    private var taggedMediaItems: [DiveMediaPhoto] {
        DiveBuddyTaggedMediaPresentation.resolvedTaggedMediaPhotos(
            tags: selfBuddyTags,
            ownerDiveActivityIDs: ownerDiveActivityIDs,
            modelContext: modelContext
        )
    }

    private var taggedMediaTimeZoneOffsetByID: [UUID: Int?] {
        let offsetByActivityID = Dictionary(
            uniqueKeysWithValues: ownerDiveActivities.map { ($0.id, $0.timeZoneOffsetSeconds) }
        )
        return DiveBuddyTaggedMediaPresentation.timeZoneOffsetByMediaID(
            tags: selfBuddyTags,
            ownerDiveActivityIDs: ownerDiveActivityIDs,
            timeZoneOffsetByActivityID: offsetByActivityID
        )
    }

    var body: some View {
        AppPage(
            title: ProfileTaggedMediaPresentation.sectionTitle,
            showsBackButton: true,
            showsBrandWordmark: false,
            scrollContentUnderHeader: true,
            collapsibleInlineTitleHeader: true,
            showsWaterBubbleBackground: true
        ) {
            if taggedMediaItems.isEmpty {
                AppScrollUnderHeaderEmptyState {
                    emptyState
                }
            } else {
                AppScrollUnderHeaderList(listAccessibilityIdentifier: "Profile.TaggedMedia.Content") {
                    FieldGuideTaggedMediaGalleryView(
                        mediaItems: taggedMediaItems,
                        timeZoneOffsetByMediaID: taggedMediaTimeZoneOffsetByID,
                        sectionTitle: ProfileTaggedMediaPresentation.sectionTitle,
                        previewAccessibilityIdentifier: "Profile.TaggedMedia.Preview",
                        carouselAccessibilityIdentifier: "Profile.TaggedMedia.Carousel"
                    )
                    .listRowInsets(AppScrollUnderHeaderListLayout.horizontalRowInsets)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .hidesBottomTabBarWhenPushed()
        .task(id: resolvedOwnerProfileID) {
            resolveSelfBuddyIDIfNeeded()
        }
        .onAppear {
            activateMediaScopeIfNeeded()
        }
        .onDisappear {
            deactivateMediaScopeIfNeeded()
        }
        .accessibilityIdentifier("Profile.TaggedMedia.Root")
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.Colors.accent.opacity(0.85))

            Text(ProfileTaggedMediaPresentation.sectionTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text(ProfileTaggedMediaPresentation.emptyStateMessage)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.lg)
        .accessibilityIdentifier("Profile.TaggedMedia.Empty")
    }

    private func resolveSelfBuddyIDIfNeeded() {
        selfBuddyID = DiveBuddySelfRepresentation.resolveSelfBuddyID(
            owner: accountSession.currentProfile,
            modelContext: modelContext
        )
    }

    private func activateMediaScopeIfNeeded() {
        guard let selfBuddyID else { return }
        DiveMediaScopeCache.shared.activateScope(.buddyDetail(selfBuddyID))
    }

    private func deactivateMediaScopeIfNeeded() {
        guard let selfBuddyID else { return }
        DiveMediaScopeCache.shared.deactivateScope(.buddyDetail(selfBuddyID))
    }
}
