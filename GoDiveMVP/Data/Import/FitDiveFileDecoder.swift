import Foundation
import FITSwiftSDK

/// Maps a Garmin **diving** `.fit` activity file into a canonical `DiveActivity` + `DiveProfilePoint` rows.
enum FitDiveFileDecoder {

    private static let fitImportVersion = "FITSwiftSDK-21.202.0"

    /// Builds a `DiveActivity` with `profilePoints` populated (not yet inserted into SwiftData).
    static func buildDiveActivity(from data: Data) throws -> DiveActivity {
        guard !data.isEmpty else {
            throw FitDecodeError.emptyFile
        }

        let stream = FITSwiftSDK.InputStream(data: data)
        guard try Decoder.isFIT(stream: stream) else {
            throw FitDecodeError.notAFitFile
        }

        let listener = FitListener()
        let decoder = Decoder(stream: FITSwiftSDK.InputStream(data: data))
        decoder.addMesgListener(listener)

        do {
            try decoder.read()
        } catch {
            throw FitDecodeError.readFailed(underlying: error)
        }

        let messages = listener.fitMessages

        let divingSessions = messages.sessionMesgs.filter { $0.getSport() == .diving }
        guard !divingSessions.isEmpty else {
            throw FitDecodeError.noDivingSession
        }
        guard divingSessions.count == 1 else {
            throw FitDecodeError.multipleDivingSessionsInOneFile(sessionCount: divingSessions.count)
        }
        let session = divingSessions[0]

        let tankUpdates = messages.tankUpdateMesgs
        let tankSummaries = messages.tankSummaryMesgs
        let distinctTankSensors = FitTankFieldImport.distinctTankSensorIds(
            tankUpdates: tankUpdates,
            tankSummaries: tankSummaries
        )
        try FitTankFieldImport.validateDistinctTankSensorCount(distinctTankSensors.count)

        let primaryTankSensor = FitTankFieldImport.primaryTankSensorId(
            tankUpdates: tankUpdates,
            tankSummaries: tankSummaries
        )
        let sortedTankSamples: [(Date, Double)] = primaryTankSensor.map {
            FitTankFieldImport.sortedTankPressureSamples(tankUpdates: tankUpdates, sensor: $0)
        } ?? []

        guard let start = session.getStartTime()?.date else {
            throw FitDecodeError.missingStartTime
        }

        let elapsedSeconds = session.getTotalElapsedTime() ?? session.getTotalTimerTime() ?? 0
        let durationMinutes = max(1, Int((elapsedSeconds / 60.0).rounded(.towardZero)))

        let records = messages.recordMesgs
        let recordDepths = records.compactMap { $0.getDepth() }
        let maxFromRecords = recordDepths.max()
        let maxDepthMeters = session.getMaxDepth() ?? maxFromRecords ?? 0

        let avgDepthMeters: Double? = session.getAvgDepth() ?? mean(recordDepths)

        let sourceDiveId = makeSourceDiveId(fileId: messages.fileIdMesgs.first)

        let recordTempsC = records.compactMap { $0.getTemperature() }.map(Double.init)
        let mergedWater = DiveImportWaterTemperatureSummary.mergedAvgMaxMinCelsius(
            sessionAvg: session.getAvgTemperature(),
            sessionMax: session.getMaxTemperature(),
            sessionMin: session.getMinTemperature(),
            recordTemps: recordTempsC
        )

        let diveSummary = diveSummaryForSession(session: session, summaries: messages.diveSummaryMesgs)
        let bottomTimeSeconds = diveSummary?.getBottomTime().map { Int($0.rounded(.towardZero)) }
        let surfaceIntervalSeconds = diveSummary?.getSurfaceInterval().map { Int($0) }
            ?? session.getSurfaceInterval().map { Int($0) }

        let (tankStartPSI, tankEndPSI) = primaryTankSensor.map { sensor in
            FitTankFieldImport.diveLevelTankPressuresPSI(
                sensor: sensor,
                tankSummaries: tankSummaries,
                tankUpdates: tankUpdates
            )
        } ?? (nil, nil)

        var volumeUsedSurfaceLiters: Double?
        if let sensor = primaryTankSensor,
           let summary = FitTankFieldImport.tankSummary(forSensor: sensor, in: tankSummaries),
           let used = summary.getVolumeUsed(), used > 0 {
            volumeUsedSurfaceLiters = used
        }

        let gasFromFit = diveGasMix(from: messages.diveGasMesgs)
        let defaultTank = DiveActivityTankDefaults.resolvedSpecification()

        let activity = DiveActivity(
            deviceSource: .garminMK3,
            sourceDiveId: sourceDiveId,
            startTime: start,
            durationMinutes: durationMinutes,
            maxDepthMeters: maxDepthMeters,
            averageDepthMeters: avgDepthMeters,
            bottomTimeSeconds: bottomTimeSeconds,
            surfaceIntervalSeconds: surfaceIntervalSeconds,
            waterTempAvgCelsius: mergedWater.avg,
            waterTempMaxCelsius: mergedWater.max,
            waterTempMinCelsius: mergedWater.min,
            tankMaterial: defaultTank.materialLabel,
            tankVolumeDescription: defaultTank.storedDescription,
            tankPressureStartPSI: tankStartPSI,
            tankPressureEndPSI: tankEndPSI,
            gasType: gasFromFit?.gasType,
            oxygenMix: gasFromFit?.oxygenMix,
            rawImportVersion: fitImportVersion
        )

        activity.coordinate = diveEntryCoordinate(session: session, records: records)

        let points: [DiveProfilePoint] = records.compactMap { record in
            guard let ts = record.getTimestamp()?.date, let depth = record.getDepth() else {
                return nil
            }
            let temp: Double? = record.getTemperature().map { Double($0) }
            let ndl = DiveImportFitUInt32Seconds.toOptionalInt(record.getNdlTime())
            let tts = DiveImportFitUInt32Seconds.toOptionalInt(record.getTimeToSurface())
            let ascent = record.getAscentRate().map { $0 }
            let heartBPM = record.getHeartRate().map { Int($0) }
            let po2 = record.getPo2().map { Double($0) }
            let n2 = record.getN2Load().map { Int($0) }
            let cns = record.getCnsLoad().map { Int($0) }
            let tankPSI: Double? = primaryTankSensor.map { _ in
                FitTankFieldImport.nearestTankPressurePSI(
                    recordTime: ts,
                    sortedSamples: sortedTankSamples,
                    maxTimeDelta: 12.0
                )
            } ?? nil
            return DiveProfilePoint(
                timestamp: ts,
                depthMeters: depth,
                temperatureCelsius: temp,
                ascentRateMetersPerSecond: ascent,
                ndlSeconds: ndl,
                timeToSurfaceSeconds: tts,
                tankPressurePSI: tankPSI,
                heartRateBPM: heartBPM,
                po2Bars: po2,
                n2Load: n2,
                cnsLoad: cns,
                dive: activity
            )
        }
        activity.profilePoints = points
        activity.applyImportedGasConsumptionMetrics(volumeUsedSurfaceLiters: volumeUsedSurfaceLiters)

        return activity
    }

    /// First **`DiveGasMesg`** with **`oxygen_content`** (percent in FIT profile).
    private static func diveGasMix(from messages: [DiveGasMesg]) -> (oxygenMix: Double, gasType: String)? {
        for mesg in messages {
            guard let content = mesg.getOxygenContent() else { continue }
            return DiveGasMixImport.resolved(fromFitOxygenContent: Float(content))
        }
        return nil
    }

    /// Prefer **`DiveSummaryMesg`** linked to this **`SessionMesg`** (same **`reference_index`**); otherwise first summary.
    private static func diveSummaryForSession(session: SessionMesg, summaries: [DiveSummaryMesg]) -> DiveSummaryMesg? {
        guard let sessionIndex = session.getMessageIndex() else {
            return summaries.first
        }
        let linked = summaries.first { summary in
            summary.getReferenceMesg() == MesgNum.session && summary.getReferenceIndex() == sessionIndex
        }
        return linked ?? summaries.first
    }

    private static func mean(_ values: [Float64]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sum: Float64 = values.reduce(0, +)
        return Double(sum / Float64(values.count))
    }

    private static func makeSourceDiveId(fileId: FileIdMesg?) -> String? {
        guard let fileId else { return nil }
        let serial = fileId.getSerialNumber().map(String.init) ?? "0"
        let number = fileId.getNumber().map(String.init) ?? "0"
        let created = fileId.getTimeCreated().map { String($0.timestamp) } ?? "0"
        return "fit-\(serial)-\(number)-\(created)"
    }

    /// FIT semicircles → WGS84 degrees (same scaling as FIT profile docs).
    private static func semicircleToDegrees(_ semicircles: Int32) -> Double {
        Double(Int64(semicircles)) * (180.0 / 2_147_483_648.0)
    }

    /// FIT **`SessionMesg`** **start_position_*** (dive entry / surface GPS). Falls back to first **`RecordMesg`** with a fix when the session has no start position.
    private static func diveEntryCoordinate(session: SessionMesg, records: [RecordMesg]) -> DiveCoordinate? {
        if let latS = session.getStartPositionLat(),
           let lonS = session.getStartPositionLong(),
           latS != invalidPositionSemicircle,
           lonS != invalidPositionSemicircle {
            if let c = coordinateFromSemicircles(latS: latS, lonS: lonS) {
                return c
            }
        }
        return firstRecordCoordinate(from: records)
    }

    /// FIT profile: invalid **semicircle** sentinel (**`0x7FFFFFFF`**).
    private static let invalidPositionSemicircle: Int32 = Int32(bitPattern: 0x7FFF_FFFF)

    private static func coordinateFromSemicircles(latS: Int32, lonS: Int32) -> DiveCoordinate? {
        let lat = semicircleToDegrees(latS)
        let lon = semicircleToDegrees(lonS)
        guard lat >= -90, lat <= 90, lon >= -180, lon <= 180 else { return nil }
        return DiveCoordinate(latitude: lat, longitude: lon)
    }

    private static func firstRecordCoordinate(from records: [RecordMesg]) -> DiveCoordinate? {
        for record in records {
            if let latS = record.getPositionLat(),
               let lonS = record.getPositionLong(),
               latS != invalidPositionSemicircle,
               lonS != invalidPositionSemicircle,
               let c = coordinateFromSemicircles(latS: latS, lonS: lonS) {
                return c
            }
        }
        return nil
    }
}

enum FitDecodeError: LocalizedError {
    case emptyFile
    case notAFitFile
    case readFailed(underlying: Error)
    case noDivingSession
    case missingStartTime
    /// More than one **diving** **`SessionMesg`** — likely multiple dives or divers in one file; import one dive per file for now.
    case multipleDivingSessionsInOneFile(sessionCount: Int)
    /// More than **two** distinct **tank sensor** ids (**`TankUpdate`** / **`TankSummary`**) — merged or multi-diver tank data; stop and split or narrow the source file.
    case multipleDistinctTankSensorsAmbiguous(sensorCount: Int)

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "The file is empty."
        case .notAFitFile:
            return "This file is not a valid FIT file."
        case .readFailed(let underlying):
            return "Could not read FIT data: \(underlying.localizedDescription)"
        case .noDivingSession:
            return "No diving session was found in this FIT file."
        case .missingStartTime:
            return "The dive session is missing a start time."
        case .multipleDivingSessionsInOneFile(let count):
            return "This FIT file contains \(count) diving sessions. GoDive MVP imports a single dive per file. Export or split so each file has one diving session, then try again."
        case .multipleDistinctTankSensorsAmbiguous(let count):
            return "This FIT file lists \(count) different tank transmitters. That usually means merged dives or multiple divers. GoDive MVP only supports up to two tanks (e.g. sidemount) on one diver. Use a single-diver export or a file with fewer tank streams."
        }
    }
}
