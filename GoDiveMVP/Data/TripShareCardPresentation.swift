import CoreGraphics
import Foundation

struct TripShareCardMember: Sendable, Equatable, Identifiable {
    let id: UUID
    let displayName: String
    let profilePhoto: Data?
    let subtitle: String
    let usesAccentSubtitle: Bool
}

enum TripShareCardPresentation: Sendable {

    nonisolated static let cardWidth: CGFloat = 600
    nonisolated static let cardMinHeight: CGFloat = 1040
    nonisolated static let renderScale: CGFloat = 3
    nonisolated static let avatarDiameter: CGFloat = 72
    nonisolated static let avatarGridMinimum: CGFloat = 96
    nonisolated static let contentPadding: CGFloat = 24
    nonisolated static let logoImageName = GoDiveLogoPinPresentation.assetName
    nonisolated static let logoHeight: CGFloat = 72

    nonisolated static func members(
        hasStarted: Bool,
        owner: UserProfile?,
        ownerLinkedDiveCount: Int,
        plannedBuddies: [DiveBuddy],
        taggedBuddies: [DiveTripBuddySummary],
        rosterBuddiesByID: [UUID: DiveBuddy]
    ) -> [TripShareCardMember] {
        if hasStarted {
            return taggedShareMembers(
                owner: owner,
                ownerLinkedDiveCount: ownerLinkedDiveCount,
                taggedBuddies: taggedBuddies,
                rosterBuddiesByID: rosterBuddiesByID
            )
        }
        return plannedShareMembers(
            owner: owner,
            ownerLinkedDiveCount: ownerLinkedDiveCount,
            plannedBuddies: plannedBuddies
        )
    }

    nonisolated static func ownerShareSubtitle(
        hasStarted: Bool,
        ownerLinkedDiveCount: Int
    ) -> (subtitle: String, usesAccentSubtitle: Bool) {
        if hasStarted || ownerLinkedDiveCount > 0 {
            return (
                DiveTripPresentation.tripBuddyTaggedDiveCountLabel(count: ownerLinkedDiveCount),
                true
            )
        }
        return (TripDetailPlannedBuddyPresentation.ownerSubtitle, false)
    }

    nonisolated static func marineLifeCalloutLabel(uniqueSpeciesCount: Int) -> String? {
        guard uniqueSpeciesCount > 0 else { return nil }
        switch uniqueSpeciesCount {
        case 1:
            return "1 species spotted"
        default:
            return "\(uniqueSpeciesCount) species spotted"
        }
    }

    nonisolated static func plannedShareMembers(
        owner: UserProfile?,
        ownerLinkedDiveCount: Int,
        plannedBuddies: [DiveBuddy]
    ) -> [TripShareCardMember] {
        let ownerSubtitle = ownerShareSubtitle(
            hasStarted: false,
            ownerLinkedDiveCount: ownerLinkedDiveCount
        )
        var members: [TripShareCardMember] = []
        if let owner {
            members.append(
                TripShareCardMember(
                    id: owner.id,
                    displayName: owner.displayName,
                    profilePhoto: owner.profilePhoto,
                    subtitle: ownerSubtitle.subtitle,
                    usesAccentSubtitle: ownerSubtitle.usesAccentSubtitle
                )
            )
        }
        members.append(contentsOf: plannedBuddies.map {
            TripShareCardMember(
                id: $0.id,
                displayName: $0.displayName,
                profilePhoto: $0.profilePhoto,
                subtitle: TripDetailPlannedBuddyPresentation.buddySubtitle,
                usesAccentSubtitle: false
            )
        })
        return members
    }

    nonisolated static func taggedShareMembers(
        owner: UserProfile?,
        ownerLinkedDiveCount: Int,
        taggedBuddies: [DiveTripBuddySummary],
        rosterBuddiesByID: [UUID: DiveBuddy]
    ) -> [TripShareCardMember] {
        var members: [TripShareCardMember] = []
        if let owner {
            let ownerSubtitle = ownerShareSubtitle(
                hasStarted: true,
                ownerLinkedDiveCount: ownerLinkedDiveCount
            )
            members.append(
                TripShareCardMember(
                    id: owner.id,
                    displayName: owner.displayName,
                    profilePhoto: owner.profilePhoto,
                    subtitle: ownerSubtitle.subtitle,
                    usesAccentSubtitle: ownerSubtitle.usesAccentSubtitle
                )
            )
        }

        let ownerID = owner?.id
        members.append(contentsOf: taggedBuddies.compactMap { summary in
            guard summary.buddyID != ownerID else { return nil }
            return TripShareCardMember(
                id: summary.buddyID,
                displayName: summary.displayName,
                profilePhoto: rosterBuddiesByID[summary.buddyID]?.profilePhoto,
                subtitle: DiveTripPresentation.tripBuddyTaggedDiveCountLabel(count: summary.diveCount),
                usesAccentSubtitle: true
            )
        })
        return members
    }

    nonisolated static func temporaryPNGURL(tripTitle: String) -> URL {
        let sanitized = tripTitle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let base = sanitized.isEmpty ? "GoDive-Trip" : "GoDive-Trip-\(sanitized)"
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("\(base)-\(UUID().uuidString).png")
    }
}

#if canImport(UIKit)
import SwiftUI
import UIKit

enum TripShareCardRenderer {

    @MainActor
    static func renderPNG(
        tripTitle: String,
        dateRange: String,
        members: [TripShareCardMember],
        uniqueMarineLifeCount: Int,
        mapPins: [TripDetailMapPin]
    ) async -> URL? {
        let mapImage = await TripShareMapSnapshotRenderer.snapshotImage(pins: mapPins)
        let card = TripShareCardView(
            tripTitle: tripTitle,
            dateRange: dateRange,
            members: members,
            marineLifeCallout: TripShareCardPresentation.marineLifeCalloutLabel(
                uniqueSpeciesCount: uniqueMarineLifeCount
            ),
            mapImage: mapImage
        )
        .frame(width: TripShareCardPresentation.cardWidth)
        .background(AppOverviewSheetPanelBackground())

        guard
            let image = AppSwiftUIImageRenderer.opaqueUIImage(
                content: card,
                scale: TripShareCardPresentation.renderScale
            ),
            let data = AppSwiftUIImageRenderer.opaquePNGData(from: image)
        else { return nil }

        let url = TripShareCardPresentation.temporaryPNGURL(tripTitle: tripTitle)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
#endif
