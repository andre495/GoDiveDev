import SwiftData
import SwiftUI

/// Resolves a dive by id for navigation — no root-tab full-log `@Query` required.
struct OwnerDiveActivityDestinationView: View {
    let activityID: UUID
    var initialMediaFocusID: UUID? = nil
    var opensCommentsOnAppear: Bool = false
    let onMissing: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var activity: DiveActivity?
    @State private var didResolve = false

    var body: some View {
        Group {
            if let activity {
                ViewSingleActivity(
                    activity: activity,
                    initialMediaFocusID: initialMediaFocusID,
                    opensCommentsOnAppear: opensCommentsOnAppear
                )
            } else if didResolve {
                ActivityMissingDestinationPopView(onAppearPop: onMissing)
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityHidden(true)
            }
        }
        .task(id: activityID) {
            activity = OwnerDiveActivityLookup.dive(id: activityID, modelContext: modelContext)
            didResolve = true
        }
    }
}

/// Resolves a snorkel by id for navigation — no root-tab full-log `@Query` required.
struct OwnerSnorkelActivityDestinationView: View {
    let activityID: UUID
    var initialMediaFocusID: UUID? = nil
    var opensCommentsOnAppear: Bool = false
    let onMissing: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var activity: SnorkelActivity?
    @State private var didResolve = false

    var body: some View {
        Group {
            if let activity {
                ViewSingleSnorkelActivity(
                    activity: activity,
                    initialMediaFocusID: initialMediaFocusID,
                    opensCommentsOnAppear: opensCommentsOnAppear
                )
            } else if didResolve {
                ActivityMissingDestinationPopView(onAppearPop: onMissing)
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityHidden(true)
            }
        }
        .task(id: activityID) {
            activity = OwnerDiveActivityLookup.snorkel(id: activityID, modelContext: modelContext)
            didResolve = true
        }
    }
}
