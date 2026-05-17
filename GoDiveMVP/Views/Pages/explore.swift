import SwiftUI

struct ExploreView: View {
    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                DiveLocationMapView(coordinate: nil)
                    .ignoresSafeArea()

                NavigationLink {
                    TripPlannerView()
                } label: {
                    Image(systemName: "calendar")
                        .font(.title3.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.Colors.iconPrimary)
                .padding(.trailing, AppTheme.Spacing.lg)
                .padding(.top, AppTheme.Spacing.sm)
                .accessibilityLabel("Trip Planner")
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .navigationInteractivePopGestureForHiddenNavBar()
    }
}

#Preview {
    ExploreView()
}
