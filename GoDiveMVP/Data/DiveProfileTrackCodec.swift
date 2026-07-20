import Compression
import Foundation

/// One depth-profile sample for encode/decode (CloudKit track blob — not a SwiftData model).
struct DiveProfileTrackSample: Sendable, Equatable {
    var timestamp: Date
    var depthMeters: Double
    var temperatureCelsius: Double?
    var ascentRateMetersPerSecond: Double?
    var ndlSeconds: Int?
    var timeToSurfaceSeconds: Int?
    var tankPressurePSI: Double?
    var heartRateBPM: Int?
    var po2Bars: Double?
    var n2Load: Int?
    var cnsLoad: Int?

    nonisolated init(
        timestamp: Date,
        depthMeters: Double,
        temperatureCelsius: Double? = nil,
        ascentRateMetersPerSecond: Double? = nil,
        ndlSeconds: Int? = nil,
        timeToSurfaceSeconds: Int? = nil,
        tankPressurePSI: Double? = nil,
        heartRateBPM: Int? = nil,
        po2Bars: Double? = nil,
        n2Load: Int? = nil,
        cnsLoad: Int? = nil
    ) {
        self.timestamp = timestamp
        self.depthMeters = depthMeters
        self.temperatureCelsius = temperatureCelsius
        self.ascentRateMetersPerSecond = ascentRateMetersPerSecond
        self.ndlSeconds = ndlSeconds
        self.timeToSurfaceSeconds = timeToSurfaceSeconds
        self.tankPressurePSI = tankPressurePSI
        self.heartRateBPM = heartRateBPM
        self.po2Bars = po2Bars
        self.n2Load = n2Load
        self.cnsLoad = cnsLoad
    }

    nonisolated init(_ point: DiveProfilePoint) {
        self.init(
            timestamp: point.timestamp,
            depthMeters: point.depthMeters,
            temperatureCelsius: point.temperatureCelsius,
            ascentRateMetersPerSecond: point.ascentRateMetersPerSecond,
            ndlSeconds: point.ndlSeconds,
            timeToSurfaceSeconds: point.timeToSurfaceSeconds,
            tankPressurePSI: point.tankPressurePSI,
            heartRateBPM: point.heartRateBPM,
            po2Bars: point.po2Bars,
            n2Load: point.n2Load,
            cnsLoad: point.cnsLoad
        )
    }

    nonisolated func makeProfilePoint(diveActivityID: UUID) -> DiveProfilePoint {
        let point = DiveProfilePoint(
            timestamp: timestamp,
            depthMeters: depthMeters,
            temperatureCelsius: temperatureCelsius,
            ascentRateMetersPerSecond: ascentRateMetersPerSecond,
            ndlSeconds: ndlSeconds,
            timeToSurfaceSeconds: timeToSurfaceSeconds,
            tankPressurePSI: tankPressurePSI,
            heartRateBPM: heartRateBPM,
            po2Bars: po2Bars,
            n2Load: n2Load,
            cnsLoad: cnsLoad
        )
        point.diveActivityID = diveActivityID
        return point
    }
}

enum DiveProfileTrackCodecError: Error, Equatable {
    case emptyInput
    case unsupportedVersion(UInt8)
    case truncated
    case decompressionFailed
    case compressionFailed
}

/// Versioned binary + LZFSE codec for **`DiveActivity.profileTrackData`**.
///
/// Wire format (outer):
/// - `UInt8` codec version (**1**)
/// - `UInt8` compression (**0** none, **1** LZFSE)
/// - `UInt32` BE uncompressed payload length
/// - payload bytes
///
/// Payload (version 1):
/// - `UInt32` BE sample count
/// - for each sample (sorted by time): `UInt16` BE presence mask, `UInt32` BE ms from dive start,
///   `Float32` BE depth, then optional fields in mask order.
enum DiveProfileTrackCodec: Sendable {

    nonisolated static let codecVersion: UInt8 = 1
    nonisolated static let compressionNone: UInt8 = 0
    nonisolated static let compressionLZFSE: UInt8 = 1

    private nonisolated static let maskTemperature: UInt16 = 1 << 0
    private nonisolated static let maskAscent: UInt16 = 1 << 1
    private nonisolated static let maskNDL: UInt16 = 1 << 2
    private nonisolated static let maskTTS: UInt16 = 1 << 3
    private nonisolated static let maskTankPSI: UInt16 = 1 << 4
    private nonisolated static let maskHeartRate: UInt16 = 1 << 5
    private nonisolated static let maskPO2: UInt16 = 1 << 6
    private nonisolated static let maskN2: UInt16 = 1 << 7
    private nonisolated static let maskCNS: UInt16 = 1 << 8

    /// Returns **`nil`** when there are no samples (caller should clear **`profileTrackData`**).
    nonisolated static func encode(
        samples: [DiveProfileTrackSample],
        diveStartTime: Date
    ) throws -> Data? {
        guard !samples.isEmpty else { return nil }
        let sorted = samples.sorted { $0.timestamp < $1.timestamp }
        var payload = Data()
        payload.reserveCapacity(16 + sorted.count * 24)
        appendUInt32(UInt32(sorted.count), to: &payload)
        let start = diveStartTime.timeIntervalSinceReferenceDate
        for sample in sorted {
            var mask: UInt16 = 0
            if sample.temperatureCelsius != nil { mask |= maskTemperature }
            if sample.ascentRateMetersPerSecond != nil { mask |= maskAscent }
            if sample.ndlSeconds != nil { mask |= maskNDL }
            if sample.timeToSurfaceSeconds != nil { mask |= maskTTS }
            if sample.tankPressurePSI != nil { mask |= maskTankPSI }
            if sample.heartRateBPM != nil { mask |= maskHeartRate }
            if sample.po2Bars != nil { mask |= maskPO2 }
            if sample.n2Load != nil { mask |= maskN2 }
            if sample.cnsLoad != nil { mask |= maskCNS }

            appendUInt16(mask, to: &payload)
            let ms = max(0, (sample.timestamp.timeIntervalSinceReferenceDate - start) * 1000)
            appendUInt32(UInt32(min(ms, Double(UInt32.max))), to: &payload)
            appendFloat32(Float(sample.depthMeters), to: &payload)

            if let temperatureCelsius = sample.temperatureCelsius {
                appendFloat32(Float(temperatureCelsius), to: &payload)
            }
            if let ascentRateMetersPerSecond = sample.ascentRateMetersPerSecond {
                appendFloat32(Float(ascentRateMetersPerSecond), to: &payload)
            }
            if let ndlSeconds = sample.ndlSeconds {
                appendInt32(Int32(ndlSeconds), to: &payload)
            }
            if let timeToSurfaceSeconds = sample.timeToSurfaceSeconds {
                appendInt32(Int32(timeToSurfaceSeconds), to: &payload)
            }
            if let tankPressurePSI = sample.tankPressurePSI {
                appendFloat32(Float(tankPressurePSI), to: &payload)
            }
            if let heartRateBPM = sample.heartRateBPM {
                appendInt32(Int32(heartRateBPM), to: &payload)
            }
            if let po2Bars = sample.po2Bars {
                appendFloat32(Float(po2Bars), to: &payload)
            }
            if let n2Load = sample.n2Load {
                appendInt32(Int32(n2Load), to: &payload)
            }
            if let cnsLoad = sample.cnsLoad {
                appendInt32(Int32(cnsLoad), to: &payload)
            }
        }

        let compressed = try compressLZFSE(payload)
        var envelope = Data()
        envelope.reserveCapacity(6 + compressed.count)
        envelope.append(codecVersion)
        envelope.append(compressionLZFSE)
        appendUInt32(UInt32(payload.count), to: &envelope)
        envelope.append(compressed)
        return envelope
    }

    nonisolated static func encode(
        points: [DiveProfilePoint],
        diveStartTime: Date
    ) throws -> Data? {
        try encode(samples: points.map(DiveProfileTrackSample.init), diveStartTime: diveStartTime)
    }

    nonisolated static func decode(
        _ data: Data,
        diveStartTime: Date
    ) throws -> [DiveProfileTrackSample] {
        guard !data.isEmpty else { throw DiveProfileTrackCodecError.emptyInput }
        var cursor = 0
        let version = try readUInt8(data, cursor: &cursor)
        guard version == codecVersion else {
            throw DiveProfileTrackCodecError.unsupportedVersion(version)
        }
        let compression = try readUInt8(data, cursor: &cursor)
        let uncompressedLength = Int(try readUInt32(data, cursor: &cursor))
        let body = data.subdata(in: cursor ..< data.count)

        let payload: Data
        switch compression {
        case compressionNone:
            payload = body
        case compressionLZFSE:
            payload = try decompressLZFSE(body, uncompressedLength: uncompressedLength)
        default:
            throw DiveProfileTrackCodecError.unsupportedVersion(compression)
        }
        guard payload.count == uncompressedLength else {
            throw DiveProfileTrackCodecError.truncated
        }

        var p = 0
        let count = Int(try readUInt32(payload, cursor: &p))
        var samples: [DiveProfileTrackSample] = []
        samples.reserveCapacity(count)
        let start = diveStartTime.timeIntervalSinceReferenceDate
        for _ in 0 ..< count {
            let mask = try readUInt16(payload, cursor: &p)
            let ms = try readUInt32(payload, cursor: &p)
            let depth = Double(try readFloat32(payload, cursor: &p))
            let timestamp = Date(timeIntervalSinceReferenceDate: start + Double(ms) / 1000)

            var temperatureCelsius: Double?
            var ascentRateMetersPerSecond: Double?
            var ndlSeconds: Int?
            var timeToSurfaceSeconds: Int?
            var tankPressurePSI: Double?
            var heartRateBPM: Int?
            var po2Bars: Double?
            var n2Load: Int?
            var cnsLoad: Int?

            if mask & maskTemperature != 0 {
                temperatureCelsius = Double(try readFloat32(payload, cursor: &p))
            }
            if mask & maskAscent != 0 {
                ascentRateMetersPerSecond = Double(try readFloat32(payload, cursor: &p))
            }
            if mask & maskNDL != 0 {
                ndlSeconds = Int(try readInt32(payload, cursor: &p))
            }
            if mask & maskTTS != 0 {
                timeToSurfaceSeconds = Int(try readInt32(payload, cursor: &p))
            }
            if mask & maskTankPSI != 0 {
                tankPressurePSI = Double(try readFloat32(payload, cursor: &p))
            }
            if mask & maskHeartRate != 0 {
                heartRateBPM = Int(try readInt32(payload, cursor: &p))
            }
            if mask & maskPO2 != 0 {
                po2Bars = Double(try readFloat32(payload, cursor: &p))
            }
            if mask & maskN2 != 0 {
                n2Load = Int(try readInt32(payload, cursor: &p))
            }
            if mask & maskCNS != 0 {
                cnsLoad = Int(try readInt32(payload, cursor: &p))
            }

            samples.append(
                DiveProfileTrackSample(
                    timestamp: timestamp,
                    depthMeters: depth,
                    temperatureCelsius: temperatureCelsius,
                    ascentRateMetersPerSecond: ascentRateMetersPerSecond,
                    ndlSeconds: ndlSeconds,
                    timeToSurfaceSeconds: timeToSurfaceSeconds,
                    tankPressurePSI: tankPressurePSI,
                    heartRateBPM: heartRateBPM,
                    po2Bars: po2Bars,
                    n2Load: n2Load,
                    cnsLoad: cnsLoad
                )
            )
        }
        guard p == payload.count else { throw DiveProfileTrackCodecError.truncated }
        return samples
    }

    // MARK: - Compression

    nonisolated private static func compressLZFSE(_ data: Data) throws -> Data {
        let dstCapacity = data.count + data.count / 16 + 64
        let destination = UnsafeMutablePointer<UInt8>.allocate(capacity: dstCapacity)
        defer { destination.deallocate() }
        let written = data.withUnsafeBytes { src -> Int in
            guard let base = src.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return compression_encode_buffer(
                destination,
                dstCapacity,
                base,
                data.count,
                nil,
                COMPRESSION_LZFSE
            )
        }
        guard written > 0 else { throw DiveProfileTrackCodecError.compressionFailed }
        return Data(bytes: destination, count: written)
    }

    nonisolated private static func decompressLZFSE(_ data: Data, uncompressedLength: Int) throws -> Data {
        guard uncompressedLength > 0 else { return Data() }
        let destination = UnsafeMutablePointer<UInt8>.allocate(capacity: uncompressedLength)
        defer { destination.deallocate() }
        let written = data.withUnsafeBytes { src -> Int in
            guard let base = src.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return compression_decode_buffer(
                destination,
                uncompressedLength,
                base,
                data.count,
                nil,
                COMPRESSION_LZFSE
            )
        }
        guard written == uncompressedLength else {
            throw DiveProfileTrackCodecError.decompressionFailed
        }
        return Data(bytes: destination, count: written)
    }

    // MARK: - Binary helpers (big-endian)

    nonisolated private static func appendUInt16(_ value: UInt16, to data: inout Data) {
        var be = value.bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
    }

    nonisolated private static func appendUInt32(_ value: UInt32, to data: inout Data) {
        var be = value.bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
    }

    nonisolated private static func appendInt32(_ value: Int32, to data: inout Data) {
        var be = value.bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
    }

    nonisolated private static func appendFloat32(_ value: Float, to data: inout Data) {
        var be = value.bitPattern.bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
    }

    nonisolated private static func readUInt8(_ data: Data, cursor: inout Int) throws -> UInt8 {
        guard cursor < data.count else { throw DiveProfileTrackCodecError.truncated }
        defer { cursor += 1 }
        return data[cursor]
    }

    nonisolated private static func readUInt16(_ data: Data, cursor: inout Int) throws -> UInt16 {
        guard cursor + 2 <= data.count else { throw DiveProfileTrackCodecError.truncated }
        let value = data.subdata(in: cursor ..< (cursor + 2)).withUnsafeBytes {
            $0.load(as: UInt16.self).bigEndian
        }
        cursor += 2
        return value
    }

    nonisolated private static func readUInt32(_ data: Data, cursor: inout Int) throws -> UInt32 {
        guard cursor + 4 <= data.count else { throw DiveProfileTrackCodecError.truncated }
        let value = data.subdata(in: cursor ..< (cursor + 4)).withUnsafeBytes {
            $0.load(as: UInt32.self).bigEndian
        }
        cursor += 4
        return value
    }

    nonisolated private static func readInt32(_ data: Data, cursor: inout Int) throws -> Int32 {
        Int32(bitPattern: try readUInt32(data, cursor: &cursor))
    }

    nonisolated private static func readFloat32(_ data: Data, cursor: inout Int) throws -> Float {
        Float(bitPattern: try readUInt32(data, cursor: &cursor))
    }
}
