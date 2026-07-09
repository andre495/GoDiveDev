import Foundation
import SwiftData
import SwiftUI

/// Tag detail — tagged dives, hero media, row display.
enum ActivityTagDetailPresentation: Sendable {

    nonisolated static let headerSystemImage = "tag.fill"
    nonisolated static let headerTypeAccessibilityLabel = "Activity tag"
    nonisolated static var pinnedHeaderIconFont: Font { .title3.weight(.semibold) }

    nonisolated static func pinnedHeaderAccessibilityLabel(tagName: String, diveCount: Int) -> String {
        "\(headerTypeAccessibilityLabel), \(tagName), \(diveCountLabel(count: diveCount))"
    }

    @MainActor
    static func taggedDives(on tag: ActivityTag) -> [DiveActivity] {
        tag.dives.sorted { lhs, rhs in
            if lhs.startTime != rhs.startTime {
                return lhs.startTime > rhs.startTime
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    nonisolated static func diveCountLabel(count: Int) -> String {
        count == 1 ? "1 dive" : "\(count) dives"
    }

    nonisolated static let heroModeToggleBottomPadding: CGFloat =
        DiveBuddyDetailPresentation.heroModeToggleBottomPadding

    nonisolated static func shouldAutoPlaySelectedVideo(for media: DiveMediaPhoto?) -> Bool {
        DiveBuddyDetailPresentation.shouldAutoPlaySelectedVideo(for: media)
    }

    @MainActor
    static func initialHeroMediaPhotoID(
        tagID: UUID,
        photos: [DiveMediaPhoto]
    ) -> UUID? {
        DetailHeroMediaPresentation.resolvedHeroMediaPhotoID(
            in: photos,
            explicitFeaturedID: nil,
            sessionRandomID: TagHeroMediaSession.resolvedRandomHeroMediaID(
                tagID: tagID,
                in: photos
            )
        )
    }

    @MainActor
    static func diveRowDisplayData(
        dives: [DiveActivity],
        unitSystem: DiveDisplayUnitSystem,
        useChronologicalNumbers: Bool,
        ownerProfileID: UUID?,
        numberingActivities: [DiveActivity]? = nil
    ) -> [DiveLogbookRowDisplayData] {
        let numberingRows = ownerProfileID.flatMap {
            OwnerDiveIndexSessionCache.resolve(ownerProfileID: $0)?.numberingRows
        }
        return DiveLogbookDisplay.rowData(
            activities: dives,
            unitSystem: unitSystem,
            duplicateIds: [],
            useChronologicalNumbers: useChronologicalNumbers,
            numberingActivities: numberingActivities,
            numberingRows: numberingRows
        )
    }
}

/// Per-tag random hero media — stable for the app session.
@MainActor
enum TagHeroMediaSession {
    private static var randomHeroMediaIDByTagID: [UUID: UUID] = [:]

    static func resolvedRandomHeroMediaID(tagID: UUID, in photos: [DiveMediaPhoto]) -> UUID? {
        if let existing = randomHeroMediaIDByTagID[tagID],
           photos.contains(where: { $0.id == existing }) {
            return existing
        }
        let picked = DiveBuddyDetailPresentation.randomHeroTaggedMedia(from: photos)?.id
        if let picked {
            randomHeroMediaIDByTagID[tagID] = picked
        } else {
            randomHeroMediaIDByTagID.removeValue(forKey: tagID)
        }
        return picked
    }
}
