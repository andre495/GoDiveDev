import Foundation
import os

/// Structured logging for auto-attach media matching. Toggle **`isEnabled`** to trace why an asset matched / was skipped.
///
/// View in **Console.app** (or Xcode console) filtered by subsystem **`GoDive.MediaAutoAttach`**.
enum DiveLibraryMediaAttachDebug: Sendable {

    /// Flip to **`false`** to silence per-asset logs once matching is verified.
    nonisolated(unsafe) static var isEnabled = true

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "GoDiveMVP",
        category: "MediaAutoAttach"
    )

    enum AssetDecision: String, Sendable {
        case matched
        case alreadyLinked
        case missingCreationDate
        case outsideWindow
        case loadFailed
    }

    static func diveStart(
        index: Int,
        total: Int,
        diveStartTime: Date,
        timeZone: TimeZone,
        window: DiveActivityMediaAttachWindow,
        fetchWindow: DiveActivityMediaAttachWindow,
        fetchedAssetCount: Int
    ) {
        guard isEnabled else { return }
        logger.info("""
        Dive \(index, privacy: .public)/\(total, privacy: .public) tz=\(timeZone.identifier, privacy: .public) \
        start=\(local(diveStartTime, timeZone), privacy: .public) \
        match=[\(local(window.inclusiveStart, timeZone), privacy: .public) … \(local(window.inclusiveEnd, timeZone), privacy: .public)] \
        fetch=[\(local(fetchWindow.inclusiveStart, timeZone), privacy: .public) … \(local(fetchWindow.inclusiveEnd, timeZone), privacy: .public)] \
        candidates=\(fetchedAssetCount, privacy: .public)
        """)
    }

    static func asset(
        localIdentifier: String,
        mediaTypeLabel: String,
        creationDate: Date?,
        capturedAt: Date?,
        timeZone: TimeZone,
        decision: AssetDecision,
        detail: String? = nil
    ) {
        guard isEnabled else { return }
        let creation = creationDate.map { local($0, timeZone) } ?? "nil"
        let captured = capturedAt.map { local($0, timeZone) } ?? "nil"
        let detailSuffix = detail.map { " (\($0))" } ?? ""
        logger.info("""
        asset \(localIdentifier, privacy: .public) [\(mediaTypeLabel, privacy: .public)] \
        creation=\(creation, privacy: .public) capturedAt=\(captured, privacy: .public) \
        -> \(decision.rawValue, privacy: .public)\(detailSuffix, privacy: .public)
        """)
    }

    static func diveSummary(
        index: Int,
        attached: Int,
        skippedAlreadyLinked: Int,
        skippedOutsideWindow: Int,
        skippedNoCreationDate: Int
    ) {
        guard isEnabled else { return }
        logger.info("""
        Dive \(index, privacy: .public) done: attached=\(attached, privacy: .public) \
        alreadyLinked=\(skippedAlreadyLinked, privacy: .public) \
        outsideWindow=\(skippedOutsideWindow, privacy: .public) \
        noCreationDate=\(skippedNoCreationDate, privacy: .public)
        """)
    }

    /// Local + UTC rendering so timezone problems are obvious in the log.
    private static func local(_ date: Date, _ timeZone: TimeZone) -> String {
        let local = formatter(timeZone).string(from: date)
        let utc = formatter(TimeZone(secondsFromGMT: 0) ?? .gmt).string(from: date)
        return "\(local) (\(utc)Z)"
    }

    private static func formatter(_ timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }
}
