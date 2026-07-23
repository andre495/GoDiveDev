import Foundation
import FITSwiftSDK

/// Maps Garmin **snorkeling** or **open-water swim** `.fit` files into **`SnorkelActivity`** + **`SnorkelProfilePoint`** rows.
enum FitSnorkelFileDecoder {

    private static let fitImportVersion = "FITSwiftSDK-snorkel-21.202.0"

    static func buildSnorkelActivity(from data: Data) throws -> SnorkelActivity {
        guard !data.isEmpty else {
            throw FitSnorkelDecodeError.emptyFile
        }
        try DiveFileImportLimits.enforceFileSize(byteCount: data.count)
        try DiveFileImportLimits.validateContent(data, kind: .fit)

        let parseStartedAt = Date()
        let stream = FITSwiftSDK.InputStream(data: data)
        guard try Decoder.isFIT(stream: stream) else {
            throw FitSnorkelDecodeError.notAFitFile
        }

        let listener = FitListener()
        let decoder = Decoder(stream: FITSwiftSDK.InputStream(data: data))
        decoder.addMesgListener(listener)

        do {
            try decoder.read()
        } catch {
            throw FitSnorkelDecodeError.readFailed(underlying: error)
        }
        try DiveFileImportLimits.enforceParseDeadline(startedAt: parseStartedAt)

        let messages = listener.fitMessages
        let session = try FitActivitySessionValidation.snorkelSessionForImport(from: messages)

        guard let start = session.getStartTime()?.date else {
            throw FitSnorkelDecodeError.missingStartTime
        }

        let elapsedSeconds = session.getTotalElapsedTime() ?? session.getTotalTimerTime() ?? 0
        let durationMinutes = max(1, Int((elapsedSeconds / 60.0).rounded(.towardZero)))

        let records = messages.recordMesgs
        let isSnorkelingSport = session.getSport() == .snorkeling
        let recordDepths: [Double] = isSnorkelingSport
            ? records.compactMap { record -> Double? in
                guard let depth = record.getDepth() else { return nil }
                return Double(depth)
            }
            : []
        let maxDepthMeters: Double? = recordDepths.isEmpty ? nil : recordDepths.max()

        let sourceActivityId = makeSourceActivityId(fileId: messages.fileIdMesgs.first)

        let swimDistanceMeters = session.getTotalDistance().map { Double($0) }
        let totalCalories = session.getTotalCalories().map { Int($0) }
        let avgHeartRateBPM = session.getAvgHeartRate().map { Int($0) }
        let maxHeartRateBPM = session.getMaxHeartRate().map { Int($0) }
        let avgTemperatureCelsius = session.getAvgTemperature().map { Double($0) }
        let avgMovingSpeedMetersPerSecond = session.getEnhancedAvgSpeed().map { Double($0) }

        let activity = SnorkelActivity(
            source: .garminMK3,
            sourceActivityId: sourceActivityId,
            startTime: start,
            durationMinutes: durationMinutes,
            swimDistanceMeters: swimDistanceMeters,
            totalCalories: totalCalories,
            avgHeartRateBPM: avgHeartRateBPM,
            maxHeartRateBPM: maxHeartRateBPM,
            avgTemperatureCelsius: avgTemperatureCelsius,
            avgMovingSpeedMetersPerSecond: avgMovingSpeedMetersPerSecond,
            maxDepthMeters: maxDepthMeters,
            rawImportVersion: fitImportVersion
        )
        activity.entryCoordinate = sessionEntryCoordinate(session: session, records: records)
        activity.timeZoneOffsetSeconds = FitImportTimeZone.activityOffsetSeconds(from: messages)

        let points: [SnorkelProfilePoint] = records.compactMap { record in
            guard let ts = record.getTimestamp()?.date else { return nil }
            guard let latS = record.getPositionLat(),
                  let lonS = record.getPositionLong(),
                  latS != invalidPositionSemicircle,
                  lonS != invalidPositionSemicircle,
                  let coordinate = coordinateFromSemicircles(latS: latS, lonS: lonS)
            else { return nil }
            let heartBPM = record.getHeartRate().map { Int($0) }
            return SnorkelProfilePoint(
                timestamp: ts,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                heartRateBPM: heartBPM
            )
        }
        activity.profilePoints = points
        try DiveFileImportLimits.enforceProfileSampleCount(points.count)

        return activity
    }

    nonisolated static func isAllowedSnorkelSession(_ session: SessionMesg) -> Bool {
        guard let sport = session.getSport() else { return false }
        if sport == .snorkeling { return true }
        if sport == .swimming, session.getSubSport() == .openWater { return true }
        return false
    }

    private static func makeSourceActivityId(fileId: FileIdMesg?) -> String? {
        guard let fileId else { return nil }
        let serial = fileId.getSerialNumber().map(String.init) ?? "0"
        let number = fileId.getNumber().map(String.init) ?? "0"
        let created = fileId.getTimeCreated().map { String($0.timestamp) } ?? "0"
        return "fit-\(serial)-\(number)-\(created)"
    }

    private static let invalidPositionSemicircle: Int32 = Int32(bitPattern: 0x7FFF_FFFF)

    private static func semicircleToDegrees(_ semicircles: Int32) -> Double {
        Double(Int64(semicircles)) * (180.0 / 2_147_483_648.0)
    }

    private static func coordinateFromSemicircles(latS: Int32, lonS: Int32) -> DiveCoordinate? {
        let lat = semicircleToDegrees(latS)
        let lon = semicircleToDegrees(lonS)
        guard lat >= -90, lat <= 90, lon >= -180, lon <= 180 else { return nil }
        return DiveCoordinate(latitude: lat, longitude: lon)
    }

    private static func sessionEntryCoordinate(session: SessionMesg, records: [RecordMesg]) -> DiveCoordinate? {
        if let latS = session.getStartPositionLat(),
           let lonS = session.getStartPositionLong(),
           latS != invalidPositionSemicircle,
           lonS != invalidPositionSemicircle,
           let coordinate = coordinateFromSemicircles(latS: latS, lonS: lonS) {
            return coordinate
        }
        for record in records {
            if let latS = record.getPositionLat(),
               let lonS = record.getPositionLong(),
               latS != invalidPositionSemicircle,
               lonS != invalidPositionSemicircle,
               let coordinate = coordinateFromSemicircles(latS: latS, lonS: lonS) {
                return coordinate
            }
        }
        return nil
    }
}

enum FitSnorkelDecodeError: LocalizedError {
    case emptyFile
    case notAFitFile
    case readFailed(underlying: Error)
    case noSnorkelSession
    case wrongActivityKindForSnorkelImport
    case missingStartTime
    case multipleSnorkelSessionsInOneFile(sessionCount: Int)

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "The file is empty."
        case .notAFitFile:
            return "This file is not a valid FIT file."
        case .readFailed(let underlying):
            return "Could not read FIT data: \(underlying.localizedDescription)"
        case .noSnorkelSession:
            return "No snorkel or open-water swim session was found in this FIT file. GoDive imports Garmin Snorkel or Open Water swim activities only."
        case .wrongActivityKindForSnorkelImport:
            return "This FIT file is a scuba dive, not a snorkel or open-water swim. Supported dive modes are \(FitActivitySessionValidation.allowedDiveSubSportUserLabels). Import it from Logbook → New Dive Activity instead."
        case .missingStartTime:
            return "The session is missing a start time."
        case .multipleSnorkelSessionsInOneFile(let count):
            return "This FIT file contains \(count) snorkel or open-water sessions. GoDive imports one session per file. Export or split the file, then try again."
        }
    }
}
