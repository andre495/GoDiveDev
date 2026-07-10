import Foundation

/// Self-contained fixture data for the logged-out **Log every dive** onboarding micro-demo.
enum OnboardingLogEveryDiveDemoFixtures: Sendable {
  nonisolated static let focusedDiveID = UUID(uuidString: "A1000001-0000-4000-8000-000000000045")!
  nonisolated static let focusedDiveNumberLabel = "#45"
  nonisolated static let focusedDiveName = "Blue Hole"
  nonisolated static let focusedDiveLocation = "Belize"

  /// Lighthouse Reef — matches the **Explore sites** onboarding demo pin.
  nonisolated static let diveCoordinate = DiveCoordinate(latitude: 17.3158, longitude: -87.5348)

  nonisolated static var mapRegion: DiveLocationMapRegionSpec {
    DiveLocationMapRegionSpec(
      centerLatitude: diveCoordinate.latitude,
      centerLongitude: diveCoordinate.longitude,
      latitudeDelta: DiveLocationMapPresentation.diveSiteLatitudeDelta,
      longitudeDelta: DiveLocationMapPresentation.diveSiteLongitudeDelta
    )
  }

  nonisolated static let tankPressureStartPSI: Double = 3000
  nonisolated static let tankPressureEndPSI: Double = 1200

  nonisolated static let demoMediaPhotoID = UUID(uuidString: "A1000001-0000-4000-8000-00000000DE00")!

  /// Bundled **Photos** tab hero for the log-every-dive onboarding micro-demo.
  nonisolated static let mediaHeroVideoResourceName = "onboarding-log-every-dive-demo"
  nonisolated static let mediaHeroVideoResourceExtension = "mov"

  /// Bundled Field Guide JPEGs for onboarding micro-demo media thumbnails.
  nonisolated static let logbookThumbnailSpeciesResourceName = "marine-life-french-angelfish"
  nonisolated static let mediaHeroPrimarySpeciesResourceName = "marine-life-stoplight-parrotfish"
  nonisolated static let mediaHeroSecondarySpeciesResourceName = "marine-life-green-sea-turtle"

  /// Species tagged on the **Photos** tab hero video in the dive-detail panel.
  nonisolated static let taggedMediaSpeciesResourceName = "marine-life-red-lionfish"
  nonisolated static let taggedMediaSpeciesCommonName = "Red lionfish"
  nonisolated static let taggedMediaSpeciesScientificName = "Pterois volitans"
  nonisolated static let taggedMediaSpeciesDescription =
    "Red bars on head and body. Large pectoral arrays. Long dorsal and anal spines. Fleshy appendages around mouth."

  nonisolated static let demoMarineLifeSpeciesResourceNames: [String] = [
    logbookThumbnailSpeciesResourceName,
    mediaHeroPrimarySpeciesResourceName,
    mediaHeroSecondarySpeciesResourceName,
    taggedMediaSpeciesResourceName,
  ]

  nonisolated static var logbookRows: [DiveLogbookRowDisplayData] {
    [
      DiveLogbookRowDisplayData(
        id: UUID(uuidString: "A1000001-0000-4000-8000-000000000047")!,
        displayName: "Wreck Alley",
        diveNumberLabel: "#47",
        detailLine: "Jul 6, 2026 · 52 min · 82 ft",
        showsDuplicateHint: false,
        previewMediaPhotoID: nil,
        startTime: fixtureDate(day: 6)
      ),
      DiveLogbookRowDisplayData(
        id: UUID(uuidString: "A1000001-0000-4000-8000-000000000046")!,
        displayName: "The Ledges",
        diveNumberLabel: "#46",
        detailLine: "Jul 4, 2026 · 48 min · 68 ft",
        showsDuplicateHint: false,
        previewMediaPhotoID: nil,
        startTime: fixtureDate(day: 4)
      ),
      DiveLogbookRowDisplayData(
        id: focusedDiveID,
        displayName: focusedDiveName,
        diveNumberLabel: focusedDiveNumberLabel,
        detailLine: "Jul 2, 2026 · 42 min · 60 ft",
        showsDuplicateHint: false,
        previewMediaPhotoID: demoMediaPhotoID,
        startTime: fixtureDate(day: 2)
      ),
      DiveLogbookRowDisplayData(
        id: UUID(uuidString: "A1000001-0000-4000-8000-000000000044")!,
        displayName: "Salt Pier",
        diveNumberLabel: "#44",
        detailLine: "Jun 28, 2026 · 55 min · 72 ft",
        showsDuplicateHint: false,
        previewMediaPhotoID: nil,
        startTime: fixtureDate(day: -2)
      ),
      DiveLogbookRowDisplayData(
        id: UUID(uuidString: "A1000001-0000-4000-8000-000000000043")!,
        displayName: "Turtle Bay",
        diveNumberLabel: "#43",
        detailLine: "Jun 25, 2026 · 38 min · 54 ft",
        showsDuplicateHint: false,
        previewMediaPhotoID: nil,
        startTime: fixtureDate(day: -5)
      ),
    ]
  }

  nonisolated static var depthSamples: [DiveDepthProfileSample] {
    let depthsMeters: [Double] = [1, 6, 12, 16.5, 18.3, 17, 12, 6, 2]
    return depthsMeters.enumerated().map { index, depth in
      DiveDepthProfileSample(elapsedSeconds: Double(index * 4 * 60), depthMeters: depth)
    }
  }

  nonisolated static var mapOverviewStatsLayout: DiveActivityOverviewPresentation.MapOverviewStatsLayout {
    DiveActivityOverviewPresentation.MapOverviewStatsLayout(
      leadingStats: [
        DiveActivityOverviewPresentation.statCell(
          id: "bottom",
          titleLine1: "Bottom",
          titleLine2: "Time",
          displayValue: "35 min",
          icon: .clock
        ),
        DiveActivityOverviewPresentation.statCell(
          id: "surface",
          titleLine1: "Surface",
          titleLine2: "Interval",
          displayValue: "1 hr",
          icon: .palmTree
        ),
      ],
      depthStats: [
        DiveActivityOverviewPresentation.statCell(
          id: "max",
          titleLine1: "Max",
          titleLine2: "Depth",
          displayValue: "60 ft",
          icon: nil
        ),
        DiveActivityOverviewPresentation.statCell(
          id: "avg",
          titleLine1: "Avg",
          titleLine2: "Depth",
          displayValue: "39 ft",
          icon: nil
        ),
      ],
      depthGauge: .init(maxFillFraction: 0.55, avgLineFraction: 0.35, showsAverageLine: true)
    )
  }

  nonisolated private static func fixtureDate(day: Int) -> Date {
    var components = DateComponents()
    components.year = 2026
    components.month = 7
    components.day = 8 + day
    components.hour = 10
    components.minute = 30
    return Calendar(identifier: .gregorian).date(from: components) ?? .now
  }
}
