import Foundation

/// Maps friend-visible dive projections into logbook rows for the friend-profile blue sheet.
enum FriendProfileSharedDiveListPresentation: Sendable {
    nonisolated static let sectionTitle = FriendProfileContentPagerPresentation.sharedActivitiesPageTitle
    nonisolated static let sectionSubtitleAccessibilityIdentifier = "FriendProfile.SharedActivities.Subtitle"
    nonisolated static let listAccessibilityIdentifier = "FriendProfile.SharedActivities.List"
    nonisolated static let emptyAccessibilityIdentifier = "FriendProfile.SharedActivities.Empty"
    nonisolated static let panelAccessibilityIdentifier = "FriendProfile.SharedActivities"
    nonisolated static let emptyTogetherMessage = "No activities together yet."

    nonisolated static func logbookRows(
        from dives: [GoDiveSharedDiveProjectionMapping.FriendVisibleDive],
        unitSystem: DiveDisplayUnitSystem
    ) -> [DiveLogbookRowDisplayData] {
        let ordered = dives.sorted { lhs, rhs in
            let left = lhs.startTime ?? lhs.sharedAt ?? .distantPast
            let right = rhs.startTime ?? rhs.sharedAt ?? .distantPast
            if left != right { return left > right }
            return lhs.id > rhs.id
        }
        return ordered.compactMap { logbookRow(from: $0, unitSystem: unitSystem) }
    }

    nonisolated static func filteredDives(
        _ dives: [GoDiveSharedDiveProjectionMapping.FriendVisibleDive],
        filter: FriendProfileActivityListFilter,
        togetherActivityIDs: Set<UUID>,
        currentFirebaseUID: String?
    ) -> [GoDiveSharedDiveProjectionMapping.FriendVisibleDive] {
        switch filter {
        case .all:
            return dives
        case .together:
            return dives.filter {
                FriendProfileSharedDiveMapPresentation.isTogetherSharedDive(
                    $0,
                    togetherActivityIDs: togetherActivityIDs,
                    currentFirebaseUID: currentFirebaseUID
                )
            }
        }
    }

    nonisolated static func logbookRow(
        from dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive,
        unitSystem: DiveDisplayUnitSystem
    ) -> DiveLogbookRowDisplayData? {
        guard let id = UUID(uuidString: dive.id) else { return nil }
        let kind: LogbookActivitySnapshotKind =
            dive.resolvedActivityKind == .snorkel ? .snorkel : .scubaDive
        let startTime = dive.startTime ?? dive.sharedAt ?? .distantPast
        switch kind {
        case .scubaDive:
            return DiveLogbookRowDisplayData(
                id: id,
                activityKind: .scubaDive,
                displayName: GoDiveSharedDiveProjectionMapping.displayTitle(for: dive),
                diveNumberLabel: scubaDiveNumberLabel(dive.diveNumber),
                diveNumberLeadingSymbolName: LogbookActivityRowPresentation.scubaDiveLeadingSymbolName,
                detailLine: scubaDetailLine(for: dive, unitSystem: unitSystem),
                showsDuplicateHint: false,
                previewMediaPhotoID: nil,
                previewMediaIsSnorkel: false,
                startTime: startTime
            )
        case .snorkel:
            return DiveLogbookRowDisplayData(
                id: id,
                activityKind: .snorkel,
                displayName: GoDiveSharedDiveProjectionMapping.displayTitle(for: dive),
                diveNumberLabel: LogbookActivityRowPresentation.snorkelChipTitle,
                diveNumberLeadingSymbolName: LogbookActivityRowPresentation.snorkelLeadingSymbolName,
                detailLine: snorkelDetailLine(for: dive, unitSystem: unitSystem),
                showsDuplicateHint: false,
                previewMediaPhotoID: nil,
                previewMediaIsSnorkel: true,
                startTime: startTime
            )
        }
    }

    nonisolated static func dive(
        matching rowID: UUID,
        in dives: [GoDiveSharedDiveProjectionMapping.FriendVisibleDive]
    ) -> GoDiveSharedDiveProjectionMapping.FriendVisibleDive? {
        let key = rowID.uuidString
        return dives.first { $0.id.caseInsensitiveCompare(key) == .orderedSame }
    }

    nonisolated private static func scubaDiveNumberLabel(_ number: Int?) -> String {
        guard let number else { return "#" }
        return "#\(number)"
    }

    nonisolated static func scubaDetailLine(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive,
        unitSystem: DiveDisplayUnitSystem
    ) -> String {
        var parts: [String] = []
        if let start = dive.startTime {
            parts.append(start.formatted(date: .abbreviated, time: .omitted))
        }
        if let max = dive.maxDepthMeters {
            parts.append(DiveQuantityFormatting.depth(meters: max, system: unitSystem))
        }
        if let minutes = dive.durationMinutes {
            parts.append("\(minutes) min")
        }
        return parts.joined(separator: " · ")
    }

    nonisolated static func snorkelDetailLine(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive,
        unitSystem: DiveDisplayUnitSystem
    ) -> String {
        var parts: [String] = []
        if let start = dive.startTime {
            parts.append(start.formatted(date: .abbreviated, time: .omitted))
        }
        if let minutes = dive.durationMinutes {
            parts.append("\(minutes) min")
        }
        if let distance = dive.swimDistanceMeters {
            parts.append(DiveQuantityFormatting.swimDistance(meters: distance, system: unitSystem))
        }
        return parts.joined(separator: " · ")
    }
}
