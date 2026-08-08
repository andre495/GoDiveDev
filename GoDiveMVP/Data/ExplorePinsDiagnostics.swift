import Foundation
import os

/// Short-lived Explore pin pipeline breadcrumbs for device triage.
/// Written under Application Support so **`devicectl`** can pull them without root `log collect`.
enum ExplorePinsDiagnostics: Sendable {
    nonisolated private static let log = Logger(
        subsystem: "PrimoSoftware.GoDiveMVP",
        category: "ExplorePins"
    )
    nonisolated private static let fileName = "explore-pins-diagnostics.txt"
    nonisolated private static let lock = NSLock()
    nonisolated(unsafe) private static var lines: [String] = []
    nonisolated private static let maxLines = 80

    nonisolated static func resetSession() {
        lock.lock()
        lines = ["\(ISO8601DateFormatter().string(from: Date())) session-reset"]
        let snapshot = lines.joined(separator: "\n") + "\n"
        lock.unlock()
        write(snapshot)
    }

    nonisolated static func note(_ message: String) {
        log.info("\(message, privacy: .public)")
        #if DEBUG
        print("[ExplorePins] \(message)")
        #endif
        let stamped = "\(ISO8601DateFormatter().string(from: Date())) \(message)"
        lock.lock()
        lines.append(stamped)
        if lines.count > maxLines {
            lines.removeFirst(lines.count - maxLines)
        }
        let snapshot = lines.joined(separator: "\n") + "\n"
        lock.unlock()
        write(snapshot)
    }

    nonisolated static var fileURL: URL? {
        guard let root = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }
        let dir = root.appendingPathComponent("GoDiveDiagnostics", isDirectory: true)
        return dir.appendingPathComponent(fileName)
    }

    nonisolated private static func write(_ contents: String) {
        guard let url = fileURL else { return }
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? contents.write(to: url, atomically: true, encoding: .utf8)
    }
}
