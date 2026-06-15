import SwiftUI

/// Push **`TripDetailView`** (and trip planner) on a tab-root **`NavigationStack`** so map → site → back lands on trip overview.
private struct OpenTripDetailKey: EnvironmentKey {
    static let defaultValue: ((UUID) -> Void)? = nil
}

private struct OpenTripDetailMediaKey: EnvironmentKey {
    static let defaultValue: ((TripDetailTripMediaLaunch) -> Void)? = nil
}

private struct OpenTripPlannerKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// Append a trip-overview route on the tab stack (required before map pin → site detail).
    var openTripDetail: ((UUID) -> Void)? {
        get { self[OpenTripDetailKey.self] }
        set { self[OpenTripDetailKey.self] = newValue }
    }

    var openTripDetailMedia: ((TripDetailTripMediaLaunch) -> Void)? {
        get { self[OpenTripDetailMediaKey.self] }
        set { self[OpenTripDetailMediaKey.self] = newValue }
    }

    var openTripPlanner: (() -> Void)? {
        get { self[OpenTripPlannerKey.self] }
        set { self[OpenTripPlannerKey.self] = newValue }
    }
}

enum TripDetailStackNavigationPresentation {
    @ViewBuilder
    static func tripDetailDestination(
        tripID: UUID,
        initialContentPage: TripDetailContentPage? = nil,
        initialSelectedMediaID: UUID? = nil
    ) -> some View {
        TripDetailView(
            tripID: tripID,
            initialContentPage: initialContentPage,
            initialSelectedMediaID: initialSelectedMediaID
        )
        .hidesBottomTabBarWhenPushed()
    }
}
