import SwiftData
import SwiftUI

struct ExploreView: View {
    @Query(sort: \DiveSite.siteName) private var diveSites: [DiveSite]
    @State private var selectedSite: DiveSite?

    private var plottableSites: [ExploreCatalogMapPresentation.PlottedSite] {
        ExploreCatalogMapPresentation.plottableSites(from: diveSites)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                ExploreCatalogMapView(sites: plottableSites) { siteID in
                    selectedSite = diveSites.first(where: { $0.id == siteID })
                }
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
            .sheet(item: $selectedSite) { site in
                ExploreDiveSiteDetailSheet(site: site)
            }
        }
        .navigationInteractivePopGestureForHiddenNavBar()
    }
}

#Preview {
    ExploreView()
        .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
