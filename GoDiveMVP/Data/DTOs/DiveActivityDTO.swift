import Foundation

/// JSON / seed shape matching **canonical** **`DiveActivity`** storage (meters, °C, psi, etc.).
struct DiveActivityDTO: Decodable, Sendable {
    let id: UUID?
    let source: DiveSource
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
    let gasType: String?
    let oxygenMix: Double?
    let buddies: [DiveBuddyDTO]?
    let rawImportVersion: String?
    let profilePoints: [DiveProfilePointDTO]

    private enum CodingKeys: String, CodingKey {
        case id
        case source
        case deviceSource
        case sourceDiveId
        case startTime
        case durationMinutes
        case maxDepthMeters
        case averageDepthMeters
        case bottomTimeSeconds
        case surfaceIntervalSeconds
        case diveNumber
        case waterTempAvgCelsius
        case waterTempMaxCelsius
        case waterTempMinCelsius
        case avgAscentRateMetersPerSecond
        case siteName
        case locationName
        case coordinate
        case notes
        case tankMaterial
        case tankVolumeDescription
        case tankPressureStartPSI
        case tankPressureEndPSI
        case gasType
        case oxygenMix
        case buddies
        case rawImportVersion
        case profilePoints
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
        if let decoded = try container.decodeIfPresent(DiveSource.self, forKey: .source) {
            source = decoded
        } else {
            source = try container.decode(DiveSource.self, forKey: .deviceSource)
        }
        sourceDiveId = try container.decodeIfPresent(String.self, forKey: .sourceDiveId)
        startTime = try container.decode(Date.self, forKey: .startTime)
        durationMinutes = try container.decode(Int.self, forKey: .durationMinutes)
        maxDepthMeters = try container.decode(Double.self, forKey: .maxDepthMeters)
        averageDepthMeters = try container.decodeIfPresent(Double.self, forKey: .averageDepthMeters)
        bottomTimeSeconds = try container.decodeIfPresent(Int.self, forKey: .bottomTimeSeconds)
        surfaceIntervalSeconds = try container.decodeIfPresent(Int.self, forKey: .surfaceIntervalSeconds)
        diveNumber = try container.decodeIfPresent(Int.self, forKey: .diveNumber)
        waterTempAvgCelsius = try container.decodeIfPresent(Double.self, forKey: .waterTempAvgCelsius)
        waterTempMaxCelsius = try container.decodeIfPresent(Double.self, forKey: .waterTempMaxCelsius)
        waterTempMinCelsius = try container.decodeIfPresent(Double.self, forKey: .waterTempMinCelsius)
        avgAscentRateMetersPerSecond = try container.decodeIfPresent(
            Double.self,
            forKey: .avgAscentRateMetersPerSecond
        )
        siteName = try container.decodeIfPresent(String.self, forKey: .siteName)
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName)
        coordinate = try container.decodeIfPresent(DiveCoordinateDTO.self, forKey: .coordinate)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        tankMaterial = try container.decodeIfPresent(String.self, forKey: .tankMaterial)
        tankVolumeDescription = try container.decodeIfPresent(String.self, forKey: .tankVolumeDescription)
        tankPressureStartPSI = try container.decodeIfPresent(Double.self, forKey: .tankPressureStartPSI)
        tankPressureEndPSI = try container.decodeIfPresent(Double.self, forKey: .tankPressureEndPSI)
        gasType = try container.decodeIfPresent(String.self, forKey: .gasType)
        oxygenMix = try container.decodeIfPresent(Double.self, forKey: .oxygenMix)
        buddies = try container.decodeIfPresent([DiveBuddyDTO].self, forKey: .buddies)
        rawImportVersion = try container.decodeIfPresent(String.self, forKey: .rawImportVersion)
        profilePoints = try container.decode([DiveProfilePointDTO].self, forKey: .profilePoints)
    }
}

struct DiveBuddyDTO: Decodable, Sendable {
    let id: UUID?
    let displayName: String
}

struct DiveCoordinateDTO: Decodable, Sendable {
    let latitude: Double
    let longitude: Double
}

struct DiveProfilePointDTO: Decodable, Sendable {
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
