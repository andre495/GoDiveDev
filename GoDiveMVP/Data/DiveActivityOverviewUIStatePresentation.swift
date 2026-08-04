import Foundation

/// Clears dive/snorkel overview chrome snapshots when an activity leaves a tab **`NavigationStack`**.
/// Nested pushes (tags / species / buddies / sites) keep the activity route on the path so restore still works.
enum DiveActivityOverviewUIStatePresentation: Sendable {

    nonisolated static func diveActivityIDs(inLogbookPath path: [LogbookRoute]) -> Set<UUID> {
        Set(path.compactMap { route in
            switch route {
            case .diveDetail(let id), .diveMedia(let id, _):
                return id
            default:
                return nil
            }
        })
    }

    nonisolated static func snorkelActivityIDs(inLogbookPath path: [LogbookRoute]) -> Set<UUID> {
        Set(path.compactMap { route in
            switch route {
            case .snorkelDetail(let id), .snorkelMedia(let id, _):
                return id
            default:
                return nil
            }
        })
    }

    nonisolated static func diveActivityIDs(inHomePath path: [HomeRoute]) -> Set<UUID> {
        Set(path.compactMap { route in
            switch route {
            case .diveDetail(let id), .diveMedia(diveID: let id, mediaID: _):
                return id
            default:
                return nil
            }
        })
    }

    nonisolated static func diveActivityIDs(inExplorePath path: [ExploreRoute]) -> Set<UUID> {
        Set(path.compactMap { route in
            if case .diveDetail(let id) = route { return id }
            return nil
        })
    }

    nonisolated static func diveActivityIDs(
        inSearchPath path: [GlobalSearchPresentation.Destination]
    ) -> Set<UUID> {
        Set(path.compactMap { destination in
            if case .dive(let id) = destination { return id }
            return nil
        })
    }

    nonisolated static func snorkelActivityIDs(
        inSearchPath path: [GlobalSearchPresentation.Destination]
    ) -> Set<UUID> {
        Set(path.compactMap { destination in
            if case .snorkel(let id) = destination { return id }
            return nil
        })
    }

    nonisolated static func activityIDsLeavingStack(
        previous: Set<UUID>,
        current: Set<UUID>
    ) -> Set<UUID> {
        previous.subtracting(current)
    }

    nonisolated static func discardSessionsLeavingStack(
        previousDiveIDs: Set<UUID>,
        currentDiveIDs: Set<UUID>,
        previousSnorkelIDs: Set<UUID> = [],
        currentSnorkelIDs: Set<UUID> = []
    ) {
        for activityID in activityIDsLeavingStack(previous: previousDiveIDs, current: currentDiveIDs) {
            DiveActivityOverviewUIStateStore.discardDiveSession(activityID: activityID)
        }
        for activityID in activityIDsLeavingStack(previous: previousSnorkelIDs, current: currentSnorkelIDs) {
            DiveActivityOverviewUIStateStore.discardSnorkelSession(activityID: activityID)
        }
    }
}
