import CoreGraphics
import Foundation

/// Read-only presentation helpers for friend-visible activity detail (dives + snorkels).
enum FriendSharedActivityDetailPresentation: Sendable {

    struct SnorkelDerivedSnapshot: Sendable, Equatable {
        var heartRateSamples: [SnorkelHeartRateProfileSample]
        var trackCoordinates: [DiveCoordinate]
        var heartRateStats: SnorkelHeartRatePanelSummary.ProfileHeartRateStats
        var avgHeartRateBPM: Int?
        var maxHeartRateBPM: Int?

        nonisolated static let empty = SnorkelDerivedSnapshot(
            heartRateSamples: [],
            trackCoordinates: [],
            heartRateStats: .init(sampleCount: 0, minBPM: nil, maxBPM: nil),
            avgHeartRateBPM: nil,
            maxHeartRateBPM: nil
        )

        nonisolated var hasHeartRateProfile: Bool {
            heartRateSamples.count >= 2
        }
    }

    nonisolated static func siteHeaderTitle(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> String {
        let title = GoDiveSharedDiveProjectionMapping.displayTitle(for: dive)
        switch dive.resolvedActivityKind {
        case .scubaDive:
            return title
        case .snorkel:
            return SnorkelActivityOverviewPresentation.siteHeaderTitle(siteName: dive.siteName)
        }
    }

    nonisolated static func mapCoordinate(
        from dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> DiveCoordinate? {
        guard let latitude = dive.entryLatitude,
              let longitude = dive.entryLongitude
        else { return nil }
        let coordinate = DiveCoordinate(latitude: latitude, longitude: longitude)
        return DiveMapCoordinateResolver.isUsable(coordinate) ? coordinate : nil
    }

    nonisolated static func regionCountryLine(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> String? {
        GoDiveSharedDiveProjectionMapping.regionCountryDisplayLine(for: dive)
    }

    nonisolated static func startDateText(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> String {
        guard let start = dive.startTime else { return "—" }
        return start.formatted(date: .abbreviated, time: .omitted)
    }

    nonisolated static func dateDashTimeLine(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> String {
        guard let start = dive.startTime else { return "—" }
        let date = start.formatted(date: .abbreviated, time: .omitted)
        let time = start.formatted(date: .omitted, time: .shortened)
        return "\(date) - \(time)"
    }

    nonisolated static func diveNumberChip(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> String? {
        guard dive.resolvedActivityKind == .scubaDive, let number = dive.diveNumber else { return nil }
        return "#\(number)"
    }

    nonisolated static func diveNumberPlainLabel(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> String {
        guard let number = dive.diveNumber else { return "—" }
        return "#\(number)"
    }

    nonisolated static func formattedMaxDepth(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive,
        unitSystem: DiveDisplayUnitSystem
    ) -> String {
        guard let max = dive.maxDepthMeters else { return "—" }
        return DiveQuantityFormatting.depth(meters: max, system: unitSystem)
    }

    nonisolated static func formattedDuration(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> String {
        guard let minutes = dive.durationMinutes else { return "—" }
        return "\(minutes) min"
    }

    nonisolated static func formattedSwimDistance(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive,
        unitSystem: DiveDisplayUnitSystem
    ) -> String? {
        guard let distance = dive.swimDistanceMeters else { return nil }
        return DiveQuantityFormatting.swimDistance(meters: distance, system: unitSystem)
    }

    nonisolated static func scubaMapStatsLayout(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive,
        unitSystem: DiveDisplayUnitSystem
    ) -> DiveActivityOverviewPresentation.MapOverviewStatsLayout {
        DiveActivityOverviewPresentation.mapOverviewStatsLayout(
            durationMinutes: dive.durationMinutes ?? 0,
            maxDepthMeters: dive.maxDepthMeters ?? 0,
            averageDepthMeters: dive.averageDepthMeters,
            surfaceIntervalSeconds: nil,
            displayUnits: unitSystem
        )
    }

    nonisolated static func snorkelMapStatsLayout(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive,
        unitSystem: DiveDisplayUnitSystem
    ) -> DiveActivityOverviewPresentation.MapOverviewStatsLayout {
        SnorkelActivityOverviewPresentation.mapOverviewStatsLayout(
            durationMinutes: dive.durationMinutes ?? 0,
            swimDistanceMeters: dive.swimDistanceMeters,
            maxDepthMeters: dive.maxDepthMeters,
            avgTemperatureCelsius: dive.waterTempMinCelsius,
            displayUnits: unitSystem
        )
    }

    nonisolated static func formattedPressure(
        psi: Double?,
        unitSystem: DiveDisplayUnitSystem
    ) -> String {
        guard let psi else { return "—" }
        let line = DiveQuantityFormatting.cylinderPressure(fromPSI: psi, system: unitSystem)
        return line == "—" ? "—" : line
    }

    nonisolated static func snorkelDerivedSnapshot(
        from dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> SnorkelDerivedSnapshot {
        guard dive.resolvedActivityKind == .snorkel,
              let base64 = dive.swimTrackBase64,
              let data = Data(base64Encoded: base64),
              let startTime = dive.startTime,
              let track = try? SnorkelSwimTrackCodec.decode(data, activityStartTime: startTime)
        else { return .empty }

        let snapshots = track.map {
            SnorkelDerivedProfilePointSnapshot(
                timestamp: $0.timestamp,
                latitude: $0.latitude,
                longitude: $0.longitude,
                heartRateBPM: $0.heartRateBPM
            )
        }
        let built = SnorkelDerivedDataBuilder.build(from: snapshots)
        let bpmValues = snapshots.compactMap(\.heartRateBPM)
        let avg = bpmValues.isEmpty
            ? nil
            : Int((Double(bpmValues.reduce(0, +)) / Double(bpmValues.count)).rounded())
        return SnorkelDerivedSnapshot(
            heartRateSamples: built.heartRateSamples,
            trackCoordinates: built.trackCoordinates,
            heartRateStats: built.heartRateStats,
            avgHeartRateBPM: avg,
            maxHeartRateBPM: built.heartRateStats.maxBPM
        )
    }

    nonisolated static func swimTrackCoordinates(
        from dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> [DiveCoordinate] {
        let decoded = snorkelDerivedSnapshot(from: dive).trackCoordinates
        if decoded.count >= 2 { return decoded }
        return GoDiveSharedDiveProjectionMapping.decodedSwimTrackCoordinates(from: dive)
    }

    /// Tank hero gas label — same rules as owned **`DiveActivity.tankHeroGasMixLabel`**.
    nonisolated static func tankHeroGasMixLabel(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> String {
        DiveGasMixImport.tankHeroLabel(gasType: dive.gasType, oxygenMix: dive.oxygenMix)
    }

    /// Cylinder fill for friend tank hero (**end / start** PSI).
    nonisolated static func tankHeroPressureFillFraction(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> CGFloat {
        let fraction = DiveActivityTankPanelSummary.remainingPressureFillFraction(
            startPSI: dive.tankPressureStartPSI,
            endPSI: dive.tankPressureEndPSI
        )
        return CGFloat(fraction ?? 1)
    }

    /// Minimized gas summary SAC line — same formula path as owned **`DiveActivity.tankHeroSACRateLine`**.
    nonisolated static func tankHeroSACRateLine(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive,
        displayUnits: DiveDisplayUnitSystem
    ) -> String? {
        guard dive.tankPressureStartPSI != nil, dive.tankPressureEndPSI != nil else { return nil }
        guard let sac = DiveSACRMVCalculation.sacPSIPerMinute(from: sacRMVCalculationInput(for: dive)) else {
            return nil
        }
        return DiveQuantityFormatting.surfaceAirConsumption(sacPSIPerMinute: sac, system: displayUnits)
    }

    /// Minimized gas summary RMV line — same formula path as owned **`DiveActivity.tankHeroRMVRateLine`**.
    nonisolated static func tankHeroRMVRateLine(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive,
        displayUnits: DiveDisplayUnitSystem
    ) -> String? {
        guard dive.tankPressureStartPSI != nil, dive.tankPressureEndPSI != nil else { return nil }
        let input = sacRMVCalculationInput(for: dive)
        guard let sac = DiveSACRMVCalculation.sacPSIPerMinute(from: input),
              let rmv = DiveSACRMVCalculation.rmvLitersPerMinute(from: input, sacPSIPerMinute: sac)
        else { return nil }
        return DiveQuantityFormatting.respiratoryMinuteVolume(litersPerMinute: rmv, system: displayUnits)
    }

    /// Landscape tank plot frame — identical inputs/outputs as owned dive **Tank** landscape.
    nonisolated static func landscapeTankProfileChartFrame(
        layoutSize: CGSize,
        layoutHeight: CGFloat,
        topObstructionHeight: CGFloat,
        bottomSafeInset: CGFloat
    ) -> CGRect {
        DiveTankOverviewHeroPresentation.minimizedProfileChartFrame(
            layoutSize: layoutSize,
            layoutHeight: layoutHeight,
            topObstructionHeight: topObstructionHeight,
            bottomContentMargin: bottomSafeInset,
            isLandscape: true
        )
    }

    /// Friend tank minimized entrance uses the same durations / gate as owned **`ViewSingleActivity`**.
    nonisolated static var tankMinimizedEntranceMatchesOwnedDive: Bool {
        DiveTankOverviewHeroPresentation.minimizedEntranceAnimationDuration == 2.4
            && DiveTankOverviewHeroPresentation.minimizedWaterTopFadeDuration == 0.35
            && DiveTankOverviewHeroPresentation.profileStrokeFadeCompleteCollapseProgress == 0.22
            && DiveTankOverviewHeroPresentation.shouldPlayMinimizedEntranceAnimation(
                from: .large,
                to: .minimized
            )
            && !DiveTankOverviewHeroPresentation.shouldPlayMinimizedEntranceAnimation(
                from: .minimized,
                to: .large
            )
    }

    private nonisolated static func sacRMVCalculationInput(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> DiveSACRMVCalculation.Input {
        DiveSACRMVCalculation.Input(
            tankPressureStartPSI: dive.tankPressureStartPSI,
            tankPressureEndPSI: dive.tankPressureEndPSI,
            bottomTimeSeconds: dive.bottomTimeSeconds,
            durationMinutes: dive.durationMinutes ?? 0,
            averageDepthMeters: dive.averageDepthMeters,
            maxDepthMeters: dive.maxDepthMeters ?? 0,
            tankVolumeDescription: dive.tankVolumeDescription
        )
    }
}
