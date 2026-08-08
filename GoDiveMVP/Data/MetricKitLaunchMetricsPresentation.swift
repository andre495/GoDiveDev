import Foundation
import MetricKit

/// Pure formatting for MetricKit launch histograms (Organizer Launch Time source).
enum MetricKitLaunchMetricsPresentation: Sendable {

    struct Bucket: Equatable, Sendable {
        let startMilliseconds: Double
        let endMilliseconds: Double
        let count: Int
    }

    nonisolated static let summaryFileName = "metrickit-launch-summary.txt"

    nonisolated static func milliseconds(from measurement: Measurement<UnitDuration>) -> Double {
        measurement.converted(to: .milliseconds).value
    }

    nonisolated static func buckets(
        from histogram: MXHistogram<UnitDuration>
    ) -> [Bucket] {
        var result: [Bucket] = []
        let enumerator = histogram.bucketEnumerator
        while let next = enumerator.nextObject() {
            guard let bucket = next as? MXHistogramBucket<UnitDuration> else { continue }
            result.append(
                Bucket(
                    startMilliseconds: milliseconds(from: bucket.bucketStart),
                    endMilliseconds: milliseconds(from: bucket.bucketEnd),
                    count: bucket.bucketCount
                )
            )
        }
        return result
    }

    nonisolated static func formatBucketLine(_ bucket: Bucket) -> String {
        let start = Int(bucket.startMilliseconds.rounded())
        let end = Int(bucket.endMilliseconds.rounded())
        return "\(start)-\(end)ms x\(bucket.count)"
    }

    nonisolated static func formatHistogramSummary(name: String, buckets: [Bucket]) -> String {
        guard !buckets.isEmpty else {
            return "\(name): (empty)"
        }
        let total = buckets.reduce(0) { $0 + $1.count }
        let lines = buckets.map(formatBucketLine).joined(separator: ", ")
        return "\(name): samples=\(total) [\(lines)]"
    }

    /// Plain-text summary for console + Application Support (no UIDs / GPS).
    nonisolated static func summaryText(
        timeStampEnd: Date,
        appBuildVersion: String?,
        osVersion: String?,
        timeToFirstDraw: [Bucket],
        optimizedTimeToFirstDraw: [Bucket],
        applicationResumeTime: [Bucket],
        extendedLaunch: [Bucket]
    ) -> String {
        let stamp = ISO8601DateFormatter().string(from: timeStampEnd)
        let lines = [
            "MetricKit launch summary",
            "capturedAt=\(stamp)",
            "appBuild=\(appBuildVersion ?? "?")",
            "osVersion=\(osVersion ?? "?")",
            formatHistogramSummary(name: "timeToFirstDraw", buckets: timeToFirstDraw),
            formatHistogramSummary(name: "optimizedTimeToFirstDraw", buckets: optimizedTimeToFirstDraw),
            formatHistogramSummary(name: "applicationResumeTime", buckets: applicationResumeTime),
            formatHistogramSummary(name: "extendedLaunch", buckets: extendedLaunch),
        ]
        return lines.joined(separator: "\n") + "\n"
    }

    nonisolated static func summaryText(from payload: MXMetricPayload) -> String? {
        guard let launch = payload.applicationLaunchMetrics else { return nil }
        let optimized: [Bucket]
        let extended: [Bucket]
        if #available(iOS 15.2, *) {
            optimized = buckets(from: launch.histogrammedOptimizedTimeToFirstDraw)
        } else {
            optimized = []
        }
        if #available(iOS 16.0, *) {
            extended = buckets(from: launch.histogrammedExtendedLaunch)
        } else {
            extended = []
        }
        let meta = payload.metaData
        return summaryText(
            timeStampEnd: payload.timeStampEnd,
            appBuildVersion: meta?.applicationBuildVersion,
            osVersion: meta?.osVersion,
            timeToFirstDraw: buckets(from: launch.histogrammedTimeToFirstDraw),
            optimizedTimeToFirstDraw: optimized,
            applicationResumeTime: buckets(from: launch.histogrammedApplicationResumeTime),
            extendedLaunch: extended
        )
    }
}

/// Persists the latest MetricKit launch summary under Application Support / GoDiveDiagnostics.
enum MetricKitLaunchMetricsStore: Sendable {

    nonisolated static var fileURL: URL? {
        guard let root = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }
        let dir = root.appendingPathComponent("GoDiveDiagnostics", isDirectory: true)
        return dir.appendingPathComponent(MetricKitLaunchMetricsPresentation.summaryFileName)
    }

    nonisolated static func record(summary: String) {
        #if DEBUG
        for line in summary.split(separator: "\n", omittingEmptySubsequences: false) {
            print("[MetricKit.Launch] \(line)")
        }
        #endif
        guard let url = fileURL else { return }
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? summary.write(to: url, atomically: true, encoding: .utf8)
        GoDiveFileBackupPolicy.excludeFromBackup(url)
        GoDiveFileBackupPolicy.excludeFromBackup(dir)
    }
}
