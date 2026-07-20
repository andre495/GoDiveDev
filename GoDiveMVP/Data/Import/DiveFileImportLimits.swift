import Foundation

/// Resource caps for FIT / UDDF import (OWASP Phase 2 — fail closed on oversized / hostile files).
enum DiveFileImportLimits: Sendable {
    /// ~100 MiB — large multi-dive MacDive UDDF exports; still bounded for memory.
    nonisolated static let maxFileBytes = 100 * 1024 * 1024
    /// Per-dive profile samples (FIT records / UDDF waypoints).
    nonisolated static let maxProfileSamplesPerDive = 50_000
    /// Wall-clock budget for a single decode pass (XML + dive build). Large MacDive UDDFs need headroom past file-size raise.
    nonisolated static let parseTimeoutSeconds: TimeInterval = 600

    enum Kind: Equatable, Sendable {
        case fit
        case uddf

        nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.fit, .fit), (.uddf, .uddf): return true
            default: return false
            }
        }
    }

    enum Error: LocalizedError, Equatable, Sendable {
        case fileTooLarge(maxBytes: Int)
        case contentTypeMismatch(Kind)
        case tooManyProfileSamples(max: Int)
        case parseTimeout

        nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.fileTooLarge(let a), .fileTooLarge(let b)): return a == b
            case (.contentTypeMismatch(let a), .contentTypeMismatch(let b)): return a == b
            case (.tooManyProfileSamples(let a), .tooManyProfileSamples(let b)): return a == b
            case (.parseTimeout, .parseTimeout): return true
            default: return false
            }
        }

        var errorDescription: String? {
            switch self {
            case .fileTooLarge(let maxBytes):
                let mb = maxBytes / (1024 * 1024)
                return "This file is too large to import (max \(mb) MB)."
            case .contentTypeMismatch(.fit):
                return "The selected file does not look like a Garmin FIT dive file."
            case .contentTypeMismatch(.uddf):
                return "The selected file does not look like a UDDF dive log."
            case .tooManyProfileSamples(let max):
                return "A dive in this file has too many profile samples (max \(max))."
            case .parseTimeout:
                return "Import timed out while reading the file. Try a smaller export."
            }
        }

        /// Coarse token for **`GoDiveSecurityEvent`** (no file names / paths).
        nonisolated var securityEventDetail: String {
            switch self {
            case .fileTooLarge: return "fileTooLarge"
            case .contentTypeMismatch(.fit): return "fit.contentTypeMismatch"
            case .contentTypeMismatch(.uddf): return "uddf.contentTypeMismatch"
            case .tooManyProfileSamples: return "tooManyProfileSamples"
            case .parseTimeout: return "parseTimeout"
            }
        }
    }

    nonisolated static func enforceFileSize(byteCount: Int) throws {
        guard byteCount <= maxFileBytes else {
            throw Error.fileTooLarge(maxBytes: maxFileBytes)
        }
    }

    /// Prefer **`fileSize`** resource value when available, then re-check after load.
    nonisolated static func readCappedFileData(from url: URL, kind: Kind) throws -> Data {
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
            try enforceFileSize(byteCount: size)
        }
        let data = try Data(contentsOf: url)
        try enforceFileSize(byteCount: data.count)
        try validateContent(data, kind: kind)
        return data
    }

    /// Do not trust filename / UTI alone — cheap magic / root checks before decode.
    nonisolated static func validateContent(_ data: Data, kind: Kind) throws {
        switch kind {
        case .fit:
            // FIT files begin with a header size byte then `.FIT` signature at offset 8 (Garmin FIT).
            guard data.count >= 12 else { throw Error.contentTypeMismatch(.fit) }
            let signature = data.subdata(in: 8..<12)
            guard String(data: signature, encoding: .ascii) == ".FIT" else {
                throw Error.contentTypeMismatch(.fit)
            }
        case .uddf:
            guard !data.isEmpty else { throw Error.contentTypeMismatch(.uddf) }
            // Avoid full UTF-8 scan of huge files: check a prefix for the root token.
            let prefixLen = min(data.count, 64 * 1024)
            let prefix = data.prefix(prefixLen)
            let ascii = String(decoding: prefix, as: UTF8.self).lowercased()
            guard ascii.contains("<uddf") || ascii.contains(":uddf") else {
                throw Error.contentTypeMismatch(.uddf)
            }
            if ascii.contains("<!doctype") || ascii.contains("<!entity") {
                // Disallow DTD / entity declarations up front (XXE / expansion hardening).
                throw Error.contentTypeMismatch(.uddf)
            }
        }
    }

    nonisolated static func enforceProfileSampleCount(_ count: Int) throws {
        guard count <= maxProfileSamplesPerDive else {
            throw Error.tooManyProfileSamples(max: maxProfileSamplesPerDive)
        }
    }

    nonisolated static func enforceParseDeadline(startedAt: Date, now: Date = Date()) throws {
        guard now.timeIntervalSince(startedAt) <= parseTimeoutSeconds else {
            throw Error.parseTimeout
        }
    }
}
