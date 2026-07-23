import Foundation

/// Canonical WeatherKit fields frozen at import — display strings are rebuilt for the current unit system.
nonisolated struct ActivityWeatherPersistedSnapshot: Codable, Sendable, Equatable {
    static let codecVersion: UInt8 = 1

    var conditionDescription: String
    var symbolName: String
    var temperatureCelsius: Double
    var humidityFraction: Double?
    var windMetersPerSecond: Double?
    var dailyHighCelsius: Double?
    var dailyLowCelsius: Double?
    var referenceHour: Date?
    var usesDailyFallback: Bool
    var capturedAt: Date
}

enum ActivityWeatherPersistedSnapshotCodec: Sendable {
    enum Error: Swift.Error, Equatable {
        case unsupportedVersion(UInt8)
        case invalidPayload
    }

    nonisolated static func encode(_ snapshot: ActivityWeatherPersistedSnapshot) throws -> Data {
        var envelope = Data([ActivityWeatherPersistedSnapshot.codecVersion])
        let payload = try JSONEncoder().encode(snapshot)
        envelope.append(payload)
        return envelope
    }

    nonisolated static func decode(_ data: Data) throws -> ActivityWeatherPersistedSnapshot {
        guard let version = data.first else { throw Error.invalidPayload }
        guard version == ActivityWeatherPersistedSnapshot.codecVersion else {
            throw Error.unsupportedVersion(version)
        }
        let payload = data.dropFirst()
        return try JSONDecoder().decode(ActivityWeatherPersistedSnapshot.self, from: payload)
    }
}
