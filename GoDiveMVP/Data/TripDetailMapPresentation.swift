import CoreGraphics
import Foundation
import MapKit

/// Map hero layout inputs for framing planned + completed pins above the overlapping trip sheet.
struct TripDetailMapFitLayout: Equatable, Sendable {
    let mapHeight: CGFloat
    let topObstructionHeight: CGFloat
    let panelOverlap: CGFloat

    nonisolated init(
        mapHeight: CGFloat,
        topObstructionHeight: CGFloat,
        panelOverlap: CGFloat = HomeOverviewLayout.panelOverlap
    ) {
        self.mapHeight = mapHeight
        self.topObstructionHeight = topObstructionHeight
        self.panelOverlap = panelOverlap
    }

    nonisolated var layoutSignature: String {
        String(
            format: "%.1f|%.1f|%.1f",
            mapHeight,
            topObstructionHeight,
            panelOverlap
        )
    }
}

enum TripDetailMapPinKind: String, Sendable, Equatable {
    case planned
    case completed
}

struct TripDetailMapPin: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let coordinate: DiveCoordinate
    let kind: TripDetailMapPinKind
    /// Catalog **`DiveSite`** id when the pin can open **`ExploreDiveSiteDetailView`**.
    let siteID: UUID?
}

/// Planned (blue) and completed (red) pins for **`TripDetailView`**.
enum TripDetailMapPresentation: Sendable {

    /// Hero/sheet seam — same default band as **`HomeOverviewLayout.heroLayoutStatsPanelContentHeight`**.
    nonisolated static let heroLayoutStatsPanelContentHeight: CGFloat =
        HomeOverviewLayout.heroLayoutStatsPanelContentHeight

    /// Deprecated alias — use **`heroLayoutStatsPanelContentHeight`**.
    nonisolated static let minimumPanelContentHeight: CGFloat = heroLayoutStatsPanelContentHeight

    /// Pin-only markers; site name appears in a callout on pin tap (Explore all-sites pattern).
    nonisolated static let usesPinCalloutLabeling = true

    /// Map hero height aligned with Home featured media (**`HomeOverviewLayout.pushedHeroLayoutMetrics`**).
    nonisolated static func mapHeroHeight(
        viewportHeight: CGFloat,
        screenWidth: CGFloat,
        topSafeAreaInset: CGFloat,
        statsPanelContentHeight: CGFloat = heroLayoutStatsPanelContentHeight,
        showsBuddyLeaderboard: Bool = false,
        transitionViewportFloor: CGFloat = 0
    ) -> CGFloat {
        HomeOverviewLayout.pushedHeroLayoutMetrics(
            geometryHeight: viewportHeight,
            screenWidth: screenWidth,
            topSafeAreaInset: topSafeAreaInset,
            statsPanelContentHeight: statsPanelContentHeight,
            showsBuddyLeaderboard: showsBuddyLeaderboard,
            transitionViewportFloor: transitionViewportFloor
        ).heroHeight
    }

    /// Wider than Explore catalog maps so every planned + completed pin stays visible.
    nonisolated static let boundingRegionPaddingMultiplier: Double = 2.25
    /// Modest padding around pin bounds before hero edge insets — used for MapKit / Google camera fit.
    nonisolated static let fittingRegionPaddingMultiplier: Double = 1.15
    nonisolated static let boundingRegionMinimumSpanDegrees: Double = 0.08
    nonisolated static let singlePinRegionSpanDegrees: Double = 0.12

    /// Minimum top inset when the header has not measured yet.
    nonisolated static let mapFitEdgeInsetMinimumTop: CGFloat = 56
    nonisolated static let mapFitEdgeInsetHorizontal: CGFloat = 32
    /// Marker pins anchor at the tip; reserve space above the overlapping sheet.
    nonisolated static let mapMarkerGroundClearance: CGFloat = 32
    nonisolated static let mapFitEdgeInsetMinimumBottom: CGFloat = 56

    /// Pin Y target in the hero (fraction from top) — midpoint of the band between top chrome and panel overlap.
    nonisolated static func targetPinScreenYFraction(for layout: TripDetailMapFitLayout) -> CGFloat {
        let height = max(layout.mapHeight, 1)
        let panelFraction = min(max(layout.panelOverlap / height, 0), 0.92)
        return DiveLocationMapPresentation.targetPinScreenYFraction(
            layoutHeight: height,
            topObstructionHeight: mapFitEdgeInsetTop(for: layout),
            sheetHeightFraction: panelFraction
                + mapMarkerGroundClearance / height
        )
    }

    nonisolated static func mapFitEdgeInsetTop(for layout: TripDetailMapFitLayout) -> CGFloat {
        let height = max(layout.mapHeight, 1)
        return min(max(layout.topObstructionHeight, mapFitEdgeInsetMinimumTop), height * 0.4)
    }

    nonisolated static func mapFitEdgeInsetBottom(for layout: TripDetailMapFitLayout) -> CGFloat {
        let height = max(layout.mapHeight, 1)
        let bottom = layout.panelOverlap + mapMarkerGroundClearance
        return min(max(bottom, mapFitEdgeInsetMinimumBottom), height * 0.65)
    }

    nonisolated static func mapFitEdgeInsetValues(for layout: TripDetailMapFitLayout) -> (
        top: CGFloat,
        bottom: CGFloat
    ) {
        (
            top: mapFitEdgeInsetTop(for: layout),
            bottom: mapFitEdgeInsetBottom(for: layout)
        )
    }

    /// **`MKMapView`** / **`GMSMapView`** bounds are often zero on first **`makeUIView`**; use the SwiftUI hero height until UIKit lays out.
    nonisolated static func effectiveMapHeight(
        measuredBoundsHeight: CGFloat,
        fitLayout: TripDetailMapFitLayout
    ) -> CGFloat {
        measuredBoundsHeight > 1 ? measuredBoundsHeight : fitLayout.mapHeight
    }

    nonisolated static func hasMeasuredMapBounds(width: CGFloat, height: CGFloat) -> Bool {
        width > 1 && height > 1
    }

    @MainActor
    static func pins(
        plannedSites: [DiveSite],
        linkedActivities: [DiveActivity],
        catalogSites: [DiveSite]
    ) -> [TripDetailMapPin] {
        var completedSiteIDs = Set<UUID>()
        var usedCoordinateKeys = Set<String>()
        var completedPins: [TripDetailMapPin] = []

        for activity in linkedActivities {
            guard let coordinate = activity.resolvedMapCoordinate(catalogSites: catalogSites),
                  DiveMapCoordinateResolver.isUsable(coordinate)
            else { continue }

            let coordinateKey = Self.coordinateKey(for: coordinate)
            guard usedCoordinateKeys.insert(coordinateKey).inserted else { continue }

            if let siteID = activity.diveSiteID {
                completedSiteIDs.insert(siteID)
            }

            let title = activity.resolvedSiteName?.trimmingCharacters(in: .whitespacesAndNewlines)
            completedPins.append(
                TripDetailMapPin(
                    id: "completed-\(activity.id.uuidString)",
                    title: (title?.isEmpty == false) ? title! : "Dive",
                    coordinate: coordinate,
                    kind: .completed,
                    siteID: activity.diveSiteID
                )
            )
        }

        var plannedPins: [TripDetailMapPin] = []
        for site in plannedSites {
            guard !completedSiteIDs.contains(site.id) else { continue }
            guard let coordinate = DiveMapCoordinateResolver.coordinate(from: site),
                  DiveMapCoordinateResolver.isUsable(coordinate)
            else { continue }

            let coordinateKey = Self.coordinateKey(for: coordinate)
            guard usedCoordinateKeys.insert(coordinateKey).inserted else { continue }

            plannedPins.append(
                TripDetailMapPin(
                    id: "planned-\(site.id.uuidString)",
                    title: site.siteName,
                    coordinate: coordinate,
                    kind: .planned,
                    siteID: site.id
                )
            )
        }

        return completedPins + plannedPins
    }

    nonisolated static func boundingRegion(for pins: [TripDetailMapPin]) -> DiveLocationMapRegionSpec? {
        regionSpec(
            for: pins,
            paddingMultiplier: boundingRegionPaddingMultiplier
        )
    }

    /// Tight geographic bounds for hero map camera fit — edge insets frame pins in the visible band.
    nonisolated static func fittingRegion(for pins: [TripDetailMapPin]) -> DiveLocationMapRegionSpec? {
        regionSpec(
            for: pins,
            paddingMultiplier: fittingRegionPaddingMultiplier
        )
    }

    nonisolated static func mkMapRect(for pins: [TripDetailMapPin]) -> MKMapRect? {
        fittingRegion(for: pins)?.mkMapRect
    }

    private nonisolated static func regionSpec(
        for pins: [TripDetailMapPin],
        paddingMultiplier: Double
    ) -> DiveLocationMapRegionSpec? {
        guard let bounds = coordinateBounds(for: pins) else { return nil }
        if pins.count == 1
            || (bounds.latitudeSpan < 1e-9 && bounds.longitudeSpan < 1e-9) {
            return DiveLocationMapRegionSpec(
                centerLatitude: bounds.centerLatitude,
                centerLongitude: bounds.centerLongitude,
                latitudeDelta: singlePinRegionSpanDegrees,
                longitudeDelta: singlePinRegionSpanDegrees
            )
        }

        let latSpan = bounds.latitudeSpan
        let lonSpan = bounds.longitudeSpan
        let latDelta = max(latSpan * paddingMultiplier, boundingRegionMinimumSpanDegrees)
        let lonDelta = max(lonSpan * paddingMultiplier, boundingRegionMinimumSpanDegrees)
        return DiveLocationMapRegionSpec(
            centerLatitude: bounds.centerLatitude,
            centerLongitude: bounds.centerLongitude,
            latitudeDelta: latDelta,
            longitudeDelta: lonDelta
        )
    }

    nonisolated static func coordinateBounds(for pins: [TripDetailMapPin]) -> TripDetailMapCoordinateBounds? {
        guard let first = pins.first else { return nil }
        var minLat = first.coordinate.latitude
        var maxLat = first.coordinate.latitude
        var minLon = first.coordinate.longitude
        var maxLon = first.coordinate.longitude
        for pin in pins.dropFirst() {
            minLat = min(minLat, pin.coordinate.latitude)
            maxLat = max(maxLat, pin.coordinate.latitude)
            minLon = min(minLon, pin.coordinate.longitude)
            maxLon = max(maxLon, pin.coordinate.longitude)
        }
        return TripDetailMapCoordinateBounds(
            minLatitude: minLat,
            maxLatitude: maxLat,
            minLongitude: minLon,
            maxLongitude: maxLon
        )
    }

    nonisolated static func region(for pins: [TripDetailMapPin]) -> MKCoordinateRegion? {
        boundingRegion(for: pins)?.mkCoordinateRegion
    }

    private nonisolated static func coordinateKey(for coordinate: DiveCoordinate) -> String {
        String(format: "%.5f,%.5f", coordinate.latitude, coordinate.longitude)
    }
}

struct TripDetailMapCoordinateBounds: Equatable, Sendable {
    let minLatitude: Double
    let maxLatitude: Double
    let minLongitude: Double
    let maxLongitude: Double

    nonisolated var centerLatitude: Double { (minLatitude + maxLatitude) / 2 }
    nonisolated var centerLongitude: Double { (minLongitude + maxLongitude) / 2 }
    nonisolated var latitudeSpan: Double { maxLatitude - minLatitude }
    nonisolated var longitudeSpan: Double { maxLongitude - minLongitude }
}

#if canImport(UIKit)
import UIKit

extension TripDetailMapPresentation {
    static func uiMapFitEdgeInsets(for layout: TripDetailMapFitLayout) -> UIEdgeInsets {
        let insets = mapFitEdgeInsetValues(for: layout)
        return UIEdgeInsets(
            top: insets.top,
            left: mapFitEdgeInsetHorizontal,
            bottom: insets.bottom,
            right: mapFitEdgeInsetHorizontal
        )
    }
}
#endif
