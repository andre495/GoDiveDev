import CoreGraphics
import Foundation
import os

/// DEBUG tracing for rising-bubble motion. Filter Xcode console by category **`WaterBubbles`**
/// or subsystem **`PrimoSoftware.GoDiveMVP`**.
///
/// Look for: `mode` / `link_start` / `link_stop` / `heartbeat` / `draw` / `zero_bounds`.
/// If a site stays on `staticFrame` after tab select, the pause flag never cleared.
/// If you see `link_start` + `heartbeat` but no motion, the draw path is the bug.
/// If you never see `link_start`, the UIKit host never entered `.animating`.
enum WaterBubbleDiagnostics: Sendable {
    private nonisolated static let logger = Logger(
        subsystem: "PrimoSoftware.GoDiveMVP",
        category: "WaterBubbles"
    )

    /// Master switch — off in Release; on in DEBUG unless overridden.
    nonisolated static var isEnabled: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    nonisolated static func mode(
        label: String,
        mode: String,
        animationPaused: Bool,
        reduceMotion: Bool
    ) {
        guard isEnabled else { return }
        let line =
            "mode site=\(label) mode=\(mode) paused=\(animationPaused) reduceMotion=\(reduceMotion)"
        logger.notice("\(line, privacy: .public)")
        print("[WaterBubbles] \(line)")
    }

    nonisolated static func linkStart(label: String, bounds: CGSize) {
        guard isEnabled else { return }
        let line = "link_start site=\(label) bounds=\(fmt(bounds))"
        logger.notice("\(line, privacy: .public)")
        print("[WaterBubbles] \(line)")
    }

    nonisolated static func linkStop(label: String) {
        guard isEnabled else { return }
        let line = "link_stop site=\(label)"
        logger.notice("\(line, privacy: .public)")
        print("[WaterBubbles] \(line)")
    }

    nonisolated static func heartbeat(label: String, ticks: UInt64, time: TimeInterval, bounds: CGSize) {
        guard isEnabled else { return }
        let line =
            "heartbeat site=\(label) ticks=\(ticks) t=\(String(format: "%.2f", time)) bounds=\(fmt(bounds))"
        logger.debug("\(line, privacy: .public)")
        print("[WaterBubbles] \(line)")
    }

    nonisolated static func draw(label: String, size: CGSize, time: TimeInterval, animating: Bool) {
        guard isEnabled else { return }
        if size.width <= 1 || size.height <= 1 {
            let line = "zero_bounds site=\(label) size=\(fmt(size)) animating=\(animating)"
            logger.warning("\(line, privacy: .public)")
            print("[WaterBubbles] \(line)")
            return
        }
        // Throttled: only log first draws + occasional samples via heartbeat.
    }

    nonisolated static func hostUpdate(label: String, isAnimating: Bool, size: CGSize) {
        guard isEnabled else { return }
        let line = "host_update site=\(label) animating=\(isAnimating) size=\(fmt(size))"
        logger.debug("\(line, privacy: .public)")
        print("[WaterBubbles] \(line)")
    }

    private nonisolated static func fmt(_ size: CGSize) -> String {
        "\(Int(size.width))x\(Int(size.height))"
    }
}
