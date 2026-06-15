import Foundation
import os

/// Trace trip map pin taps through site resolution and tab-root navigation.
///
/// Filter in **Console.app** or Xcode: subsystem **`GoDiveMVP`** (bundle id), category **`TripMapNavigation`**.
enum TripDetailMapNavigationDebug: Sendable {

    /// Flip to **`false`** to silence once navigation is verified.
    nonisolated(unsafe) static var isEnabled = true

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "GoDiveMVP",
        category: "TripMapNavigation"
    )

    enum MapEngine: String, Sendable {
        case mapKit
        case googleMaps
    }

    static func tripMapAppeared(
        pinCount: Int,
        openablePinCount: Int,
        hasOpenCatalogDiveSiteDetail: Bool,
        tripID: UUID
    ) {
        guard isEnabled else { return }
        logger.info("""
        trip map appeared trip=\(tripID.uuidString, privacy: .public) \
        pins=\(pinCount, privacy: .public) openable=\(openablePinCount, privacy: .public) \
        envOpenCatalogDiveSiteDetail=\(hasOpenCatalogDiveSiteDetail, privacy: .public)
        """)
    }

    static func pinSelected(
        engine: MapEngine,
        pinID: String,
        kind: TripDetailMapPinKind,
        siteID: UUID?,
        title: String
    ) {
        guard isEnabled else { return }
        let site = siteID?.uuidString ?? "nil"
        logger.info("""
        pin tap engine=\(engine.rawValue, privacy: .public) pin=\(pinID, privacy: .public) \
        kind=\(kind.rawValue, privacy: .public) siteID=\(site, privacy: .public) \
        title=\(title, privacy: .public)
        """)
    }

    static func pinIgnoredMissingSiteID(engine: MapEngine, pinID: String, kind: TripDetailMapPinKind) {
        guard isEnabled else { return }
        logger.warning("""
        pin tap ignored (no catalog siteID) engine=\(engine.rawValue, privacy: .public) \
        pin=\(pinID, privacy: .public) kind=\(kind.rawValue, privacy: .public)
        """)
    }

    static func openDiveSiteFromMapCalled(siteID: UUID, tripID: UUID?) {
        guard isEnabled else { return }
        let trip = tripID?.uuidString ?? "nil"
        logger.info("""
        openDiveSiteFromMap siteID=\(siteID.uuidString, privacy: .public) trip=\(trip, privacy: .public)
        """)
    }

    static func siteResolutionFailed(siteID: UUID) {
        guard isEnabled else { return }
        logger.error("site resolution failed siteID=\(siteID.uuidString, privacy: .public)")
    }

    static func siteResolutionSucceeded(siteID: UUID, siteName: String) {
        guard isEnabled else { return }
        logger.info("""
        site resolved siteID=\(siteID.uuidString, privacy: .public) name=\(siteName, privacy: .public)
        """)
    }

    static func openCatalogDiveSiteDetailMissing(siteID: UUID) {
        guard isEnabled else { return }
        logger.error("""
        openCatalogDiveSiteDetail is nil — parent NavigationStack did not inject environment \
        siteID=\(siteID.uuidString, privacy: .public)
        """)
    }

    enum ParentStack: String, Sendable {
        case explore
        case logbook
        case home
    }

    static func parentStackAppendedRoute(stack: ParentStack, siteID: UUID, pathCountAfterAppend: Int) {
        guard isEnabled else { return }
        logger.info("""
        parent stack append stack=\(stack.rawValue, privacy: .public) \
        siteID=\(siteID.uuidString, privacy: .public) pathCount=\(pathCountAfterAppend, privacy: .public)
        """)
    }
}
