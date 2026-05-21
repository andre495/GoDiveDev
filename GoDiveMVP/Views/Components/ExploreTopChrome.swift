import SwiftUI

/// Explore top bar — map/list toggle (**leading**) and Trip Planner (**trailing**), aligned like **`AppHeader`** / Logbook **+**.
struct ExploreTopChrome: View {
    @Binding var viewMode: ExploreViewMode
    let statusBarSafeAreaTop: CGFloat

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            HStack(spacing: AppTheme.Spacing.sm) {
                ExploreViewModeToggle(selection: $viewMode)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Color.clear
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            HStack(spacing: AppTheme.Spacing.sm) {
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
                .accessibilityLabel("Trip Planner")
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.md)
        .fixedSize(horizontal: false, vertical: true)
        .background(alignment: .top) {
            if statusBarSafeAreaTop > 0.5 {
                AppStatusBarEdgeScrim(safeAreaTop: statusBarSafeAreaTop)
                    .ignoresSafeArea(edges: .top)
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: AppHeaderMetrics.HeightKey.self, value: proxy.size.height)
            }
        }
    }
}
