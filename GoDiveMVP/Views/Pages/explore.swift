import SwiftData
import SwiftUI

struct ExploreView: View {
    @Query(sort: \DiveSite.siteName) private var diveSites: [DiveSite]
    @State private var selectedSite: DiveSite?
    @State private var viewMode: ExploreViewMode = .map
    @State private var exploreTopChromeHeight: CGFloat = AppTheme.Layout.appHeaderClearanceFallback

    private var plottableSites: [ExploreCatalogMapPresentation.PlottedSite] {
        ExploreCatalogMapPresentation.plottableSites(from: diveSites)
    }

    private var siteListRows: [ExploreDiveSiteRowDisplayData] {
        ExploreDiveSiteListDisplay.rowData(for: diveSites)
    }

    private var diveSiteListSignature: String {
        diveSites.map(\.id.uuidString).joined(separator: "|")
    }

    var body: some View {
        NavigationStack {
            AppHeaderlessPage {
                GeometryReader { proxy in
                    let topInset = proxy.safeAreaInsets.top + exploreTopChromeHeight
                    let bottomInset = proxy.safeAreaInsets.bottom + AppTheme.Spacing.md

                    ZStack(alignment: .top) {
                        Group {
                            switch viewMode {
                            case .map:
                                ExploreCatalogMapView(sites: plottableSites) { siteID in
                                    selectedSite = diveSites.first(where: { $0.id == siteID })
                                }
                                .ignoresSafeArea()
                            case .list:
                                exploreSiteList(topInset: topInset, bottomInset: bottomInset)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        if viewMode == .list, !diveSites.isEmpty {
                            LogbookTopChromeScrim(topObstructionHeight: topInset)
                                .padding(.top, -proxy.safeAreaInsets.top)
                                .ignoresSafeArea(edges: .top)
                                .allowsHitTesting(false)
                                .zIndex(0.5)
                        }

                        ExploreTopChrome(
                            viewMode: $viewMode,
                            statusBarSafeAreaTop: proxy.safeAreaInsets.top
                        )
                        .frame(maxWidth: .infinity, alignment: .top)
                        .zIndex(1)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .ignoresSafeArea(edges: .bottom)
                }
                .onPreferenceChange(AppHeaderMetrics.HeightKey.self) { height in
                    if height > 0 { exploreTopChromeHeight = height }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(item: $selectedSite) { site in
                ExploreDiveSiteDetailSheet(site: site)
            }
        }
        .navigationInteractivePopGestureForHiddenNavBar()
        .onChange(of: diveSiteListSignature) { _, _ in
            guard let selectedSite else { return }
            if !diveSites.contains(where: { $0.id == selectedSite.id }) {
                self.selectedSite = nil
            }
        }
    }

    @ViewBuilder
    private func exploreSiteList(topInset: CGFloat, bottomInset: CGFloat) -> some View {
        if diveSites.isEmpty {
            exploreSiteListEmptyState
                .padding(.top, topInset)
                .padding(.horizontal, AppTheme.Spacing.lg)
        } else {
            List {
                Color.clear
                    .frame(height: topInset)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityHidden(true)

                ForEach(siteListRows) { row in
                    Button {
                        selectedSite = diveSites.first(where: { $0.id == row.id })
                    } label: {
                        ExploreDiveSiteRow(data: row)
                            .equatable()
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(
                        EdgeInsets(
                            top: 0,
                            leading: AppTheme.Spacing.lg,
                            bottom: 0,
                            trailing: AppTheme.Spacing.lg
                        )
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("Explore.SiteRow.\(row.id.uuidString)")
                }

                Color.clear
                    .frame(height: bottomInset)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityHidden(true)
            }
            .listStyle(.plain)
            .listRowSpacing(AppTheme.Spacing.md)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea(edges: [.top, .bottom])
        }
    }

    private var exploreSiteListEmptyState: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer(minLength: AppTheme.Spacing.lg)

            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.Colors.accent.opacity(0.85))

            Text("No dive sites yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text("Sites appear here when you add them to the catalog or import dives with site names.")
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

#Preview {
    ExploreView()
        .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
