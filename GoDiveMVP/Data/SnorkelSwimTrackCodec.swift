import Compression
import Foundation

/// One GPS + heart-rate sample for encode/decode (CloudKit swim track blob — not a SwiftData model).
struct SnorkelSwimTrackSample: Sendable, Equatable {
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    var heartRateBPM: Int?

    nonisolated init(
        timestamp: Date,
        latitude: Double,
        longitude: Double,
        heartRateBPM: Int? = nil
    ) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.heartRateBPM = heartRateBPM
    }

    nonisolated init(_ point: SnorkelProfilePoint) {
        self.init(
            timestamp: point.timestamp,
            latitude: point.latitude,
            longitude: point.longitude,
            heartRateBPM: point.heartRateBPM
        )
    }

    nonisolated func makeProfilePoint(snorkelActivityID: UUID) -> SnorkelProfilePoint {
        let point = SnorkelProfilePoint(
            timestamp: timestamp,
            latitude: latitude,
            longitude: longitude,
            heartRateBPM: heartRateBPM
        )
        point.snorkelActivityID = snorkelActivityID
        return point
    }
}

enum SnorkelSwimTrackCodecError: Error, Equatable {
    case emptyInput
    case unsupportedVersion(UInt8)
    case truncated
    case decompressionFailed
    case compressionFailed
}

/// Versioned binary + LZFSE codec for **`SnorkelActivity.swimTrackData`**.
enum SnorkelSwimTrackCodec: Sendable {

    nonisolated static let codecVersion: UInt8 = 1
    nonisolated static let compressionNone: UInt8 = 0
    nonisolated static let compressionLZFSE: UInt8 = 1

    private nonisolated static let maskHeartRate: UInt8 = 1 << 0

    nonisolated static func encode(
        samples: [SnorkelSwimTrackSample],
        activityStartTime: Date
    ) throws -> Data? {
        guard !samples.isEmpty else { return nil }
        let sorted = samples.sorted { $0.timestamp < $1.timestamp }
        var payload = Data()
        payload.reserveCapacity(16 + sorted.count * 16)
        appendUInt32(UInt32(sorted.count), to: &payload)
        let start = activityStartTime.timeIntervalSinceReferenceDate
        for sample in sorted {
            var mask: UInt8 = 0
            if sample.heartRateBPM != nil { mask |= maskHeartRate }

            payload.append(mask)
            let ms = max(0, (sample.timestamp.timeIntervalSinceReferenceDate - start) * 1000)
            appendUInt32(UInt32(min(ms, Double(UInt32.max))), to: &payload)
            appendFloat64(sample.latitude, to: &payload)
            appendFloat64(sample.longitude, to: &payload)
            if let heartRateBPM = sample.heartRateBPM {
                appendInt32(Int32(heartRateBPM), to: &payload)
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
        points: [SnorkelProfilePoint],
        activityStartTime: Date
    ) throws -> Data? {
        try encode(samples: points.map(SnorkelSwimTrackSample.init), activityStartTime: activityStartTime)
    }

    nonisolated static func decode(
        _ data: Data,
        activityStartTime: Date
    ) throws -> [SnorkelSwimTrackSample] {
        guard !data.isEmpty else { throw SnorkelSwimTrackCodecError.emptyInput }
        var cursor = 0
        let version = try readUInt8(data, cursor: &cursor)
        guard version == codecVersion else {
            throw SnorkelSwimTrackCodecError.unsupportedVersion(version)
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
            throw SnorkelSwimTrackCodecError.unsupportedVersion(compression)
        }
        guard payload.count == uncompressedLength else {
            throw SnorkelSwimTrackCodecError.truncated
        }

        var p = 0
        let count = Int(try readUInt32(payload, cursor: &p))
        var samples: [SnorkelSwimTrackSample] = []
        samples.reserveCapacity(count)
        let start = activityStartTime.timeIntervalSinceReferenceDate
        for _ in 0 ..< count {
            let mask = try readUInt8(payload, cursor: &p)
            let ms = try readUInt32(payload, cursor: &p)
            let latitude = try readFloat64(payload, cursor: &p)
            let longitude = try readFloat64(payload, cursor: &p)
            let timestamp = Date(timeIntervalSinceReferenceDate: start + Double(ms) / 1000)

            var heartRateBPM: Int?
            if mask & maskHeartRate != 0 {
                heartRateBPM = Int(try readInt32(payload, cursor: &p))
            }

            samples.append(
                SnorkelSwimTrackSample(
                    timestamp: timestamp,
                    latitude: latitude,
                    longitude: longitude,
                    heartRateBPM: heartRateBPM
                )
            )
        }
        guard p == payload.count else { throw SnorkelSwimTrackCodecError.truncated }
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
        guard written > 0 else { throw SnorkelSwimTrackCodecError.compressionFailed }
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
            throw SnorkelSwimTrackCodecError.decompressionFailed
        }
        return Data(bytes: destination, count: written)
    }

    // MARK: - Binary helpers (big-endian)

    nonisolated private static func appendUInt32(_ value: UInt32, to data: inout Data) {
        var be = value.bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
    }

    nonisolated private static func appendInt32(_ value: Int32, to data: inout Data) {
        var be = value.bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
    }

    nonisolated private static func appendFloat64(_ value: Double, to data: inout Data) {
        var be = value.bitPattern.bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
    }

    nonisolated private static func readUInt8(_ data: Data, cursor: inout Int) throws -> UInt8 {
        guard cursor < data.count else { throw SnorkelSwimTrackCodecError.truncated }
        defer { cursor += 1 }
        return data[cursor]
    }

    nonisolated private static func readUInt32(_ data: Data, cursor: inout Int) throws -> UInt32 {
        guard cursor + 4 <= data.count else { throw SnorkelSwimTrackCodecError.truncated }
        let value = data.subdata(in: cursor ..< (cursor + 4)).withUnsafeBytes {
            $0.load(as: UInt32.self).bigEndian
        }
        cursor += 4
        return value
    }

    nonisolated private static func readInt32(_ data: Data, cursor: inout Int) throws -> Int32 {
        Int32(bitPattern: try readUInt32(data, cursor: &cursor))
    }

    nonisolated private static func readFloat64(_ data: Data, cursor: inout Int) throws -> Double {
        guard cursor + 8 <= data.count else { throw SnorkelSwimTrackCodecError.truncated }
        let value = data.subdata(in: cursor ..< (cursor + 8)).withUnsafeBytes {
            $0.load(as: UInt64.self).bigEndian
        }
        cursor += 8
        return Double(bitPattern: value)
    }
}
