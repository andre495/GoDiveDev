import Foundation

/// UDDF import pipeline: normalize dive-local **`startTime`** / profile timestamps, then resolve display offsets.
enum UddfImportedDiveNormalization: Sendable {

    /// Run before insert/save/media attach so PhotoKit windows use corrected UTC instants.
    @MainActor
    static func normalizeBeforePersist(
        _ activities: [DiveActivity],
        catalogSites: [DiveSite] = [],
        resolver: (any GeocodingTimeZoneResolving)? = nil
    ) async {
        let resolvedResolver = resolver ?? MapKitGeocodingTimeZoneResolver.shared
        await UddfImportGeocodeBatch.prefetchForActivities(
            activities,
            catalogSites: catalogSites,
            resolver: resolvedResolver
        )
        await UddfMacDiveImportDatetimeNetworkNormalization.apply(
            activities,
            catalogSites: catalogSites,
            resolver: resolvedResolver
        )
        await UddfNaiveDatetimeStartTimeCorrection.reconcile(
            activities,
            catalogSites: catalogSites,
            resolver: resolvedResolver
        )
        for activity in activities where activity.source == .macDive {
            await DiveActivityTimeZoneResolution.resolveMissingOffset(
                for: activity,
                catalogSites: catalogSites,
                resolver: resolvedResolver
            )
            activity.uddfImportDatetimeRaw = nil
            activity.uddfWatchNaiveDatetimeSemantics = nil
        }
    }
}
