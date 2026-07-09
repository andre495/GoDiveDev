import Foundation

/// Self-contained fixture data for the logged-out **Explore sites** onboarding micro-demo.
enum OnboardingExploreSitesDemoFixtures: Sendable {
  nonisolated static let focusedSiteID = UUID(uuidString: "A1000002-0000-4000-8000-00000000B001")!
  nonisolated static let halfMoonCayeSiteID = UUID(uuidString: "A1000002-0000-4000-8000-00000000B002")!
  nonisolated static let longCayeSiteID = UUID(uuidString: "A1000002-0000-4000-8000-00000000B003")!
  nonisolated static let turneffeAtollSiteID = UUID(uuidString: "A1000002-0000-4000-8000-00000000B004")!
  nonisolated static let cozumelSiteID = UUID(uuidString: "A1000002-0000-4000-8000-00000000B005")!
  nonisolated static let grandCaymanSiteID = UUID(uuidString: "A1000002-0000-4000-8000-00000000B006")!
  nonisolated static let bonaireSiteID = UUID(uuidString: "A1000002-0000-4000-8000-00000000B007")!
  nonisolated static let focusedSiteName = "Blue Hole"
  nonisolated static let focusedSiteLocation = "Lighthouse Reef, Belize"
  nonisolated static let focusedSiteStarRating = 5
  nonisolated static let focusedSiteDiveCountLabel = "1 dive"

  nonisolated static var plottedSites: [ExploreCatalogMapPresentation.PlottedSite] {
    [
      PlottedSite(
        id: focusedSiteID,
        siteName: focusedSiteName,
        coordinate: DiveCoordinate(latitude: 17.3158, longitude: -87.5348),
        isVisited: true
      ),
      PlottedSite(
        id: halfMoonCayeSiteID,
        siteName: "Half Moon Caye",
        coordinate: DiveCoordinate(latitude: 17.192, longitude: -87.535),
        isVisited: false
      ),
      PlottedSite(
        id: longCayeSiteID,
        siteName: "Long Caye",
        coordinate: DiveCoordinate(latitude: 17.28, longitude: -87.59),
        isVisited: false
      ),
      PlottedSite(
        id: turneffeAtollSiteID,
        siteName: "Turneffe Atoll",
        coordinate: DiveCoordinate(latitude: 17.3, longitude: -87.8),
        isVisited: false
      ),
      PlottedSite(
        id: cozumelSiteID,
        siteName: "Cozumel",
        coordinate: DiveCoordinate(latitude: 20.423, longitude: -86.9223),
        isVisited: false
      ),
      PlottedSite(
        id: grandCaymanSiteID,
        siteName: "Grand Cayman",
        coordinate: DiveCoordinate(latitude: 19.2866, longitude: -81.3674),
        isVisited: false
      ),
      PlottedSite(
        id: bonaireSiteID,
        siteName: "Bonaire",
        coordinate: DiveCoordinate(latitude: 12.2019, longitude: -68.2624),
        isVisited: false
      ),
    ]
  }

  /// Wide Caribbean overview — starting frame for zoom-in.
  nonisolated static var worldOverviewRegion: DiveLocationMapRegionSpec {
    DiveLocationMapRegionSpec(
      centerLatitude: 16.5,
      centerLongitude: -78.5,
      latitudeDelta: 11.5,
      longitudeDelta: 17.5
    )
  }

  /// Belize reef cluster after first zoom.
  nonisolated static var belizeClusterRegion: DiveLocationMapRegionSpec {
    DiveLocationMapRegionSpec(
      centerLatitude: 17.24,
      centerLongitude: -87.62,
      latitudeDelta: 1.15,
      longitudeDelta: 1.35
    )
  }

  /// Slight pan east before pin selection.
  nonisolated static var belizePanRegion: DiveLocationMapRegionSpec {
    DiveLocationMapRegionSpec(
      centerLatitude: 17.28,
      centerLongitude: -87.48,
      latitudeDelta: 0.72,
      longitudeDelta: 0.88
    )
  }

  /// Tight frame on the focused site.
  nonisolated static var focusedSiteRegion: DiveLocationMapRegionSpec {
    DiveLocationMapRegionSpec(
      centerLatitude: 17.3158,
      centerLongitude: -87.5348,
      latitudeDelta: DiveLocationMapPresentation.diveSiteLatitudeDelta,
      longitudeDelta: DiveLocationMapPresentation.diveSiteLongitudeDelta
    )
  }

  nonisolated static var demoRegionSequence: [DiveLocationMapRegionSpec] {
    [
      worldOverviewRegion,
      belizeClusterRegion,
      belizePanRegion,
      focusedSiteRegion,
    ]
  }

  nonisolated static var siteDetailMaxDepthLabel: String { "124 ft max" }
  nonisolated static var siteDetailEnvironmentLabel: String { "Ocean · Reef" }

  private typealias PlottedSite = ExploreCatalogMapPresentation.PlottedSite
}
