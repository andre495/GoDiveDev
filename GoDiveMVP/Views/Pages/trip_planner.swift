import SwiftUI

struct TripPlannerView: View {
    var body: some View {
        AppPage(title: "Trip Planner", showsBackButton: true) {
            Spacer()
        }
        .hidesBottomTabBarWhenPushed()
    }
}

#Preview {
    TripPlannerView()
}
