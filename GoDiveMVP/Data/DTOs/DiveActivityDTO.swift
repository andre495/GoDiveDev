import Foundation

/// JSON / seed shape matching **canonical** **`DiveActivity`** storage (meters, °C, psi, etc.).
struct DiveActivityDTO: Decodable {
    let id: UUID?
    let deviceSource: DeviceSource
    let sourceDiveId: String?
    let startTime: Date
    let durationMinutes: Int
    let maxDepthMeters: Double
    let averageDepthMeters: Double?
    let bottomTimeSeconds: Int?
    let surfaceIntervalSeconds: Int?
    let diveNumber: Int?
    let waterTempAvgCelsius: Double?
    let waterTempMaxCelsius: Double?
    let waterTempMinCelsius: Double?
    let avgAscentRateMetersPerSecond: Double?
    let siteName: String?
    let locationName: String?
    let coordinate: DiveCoordinateDTO?
    let notes: String?
    let tankMaterial: String?
    let tankVolumeDescription: String?
    let tankPressureStartPSI: Double?
    let tankPressureEndPSI: Double?
    let buddies: [DiveBuddyDTO]?
    let rawImportVersion: String?
    let profilePoints: [DiveProfilePointDTO]
}

struct DiveBuddyDTO: Decodable {
    let id: UUID?
    let displayName: String
}

struct DiveCoordinateDTO: Decodable {
    let latitude: Double
    let longitude: Double
}

struct DiveProfilePointDTO: Decodable {
    let timestamp: Date
    let depthMeters: Double
    let temperatureCelsius: Double?
    let ascentRateMetersPerSecond: Double?
    let ndlSeconds: Int?
    let timeToSurfaceSeconds: Int?
    let tankPressurePSI: Double?
    let heartRateBPM: Int?
    let po2Bars: Double?
    let n2Load: Int?
    let cnsLoad: Int?
}
