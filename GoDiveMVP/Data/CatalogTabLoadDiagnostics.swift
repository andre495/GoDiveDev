import Foundation
import os

/// DEBUG console triage for Field Guide / Explore catalog binds vs loading UI.
///
/// Filter Xcode console by **`[CatalogTabLoad]`** or category **`CatalogTabLoad`**.
///
/// How to read:
/// - **No `task.bind` / `reload.start` when you open the tab** → selection / `.task` UI bug
/// - **`reload.start` then silence / `cancelled`** → cancel storm (UI lifecycle)
/// - **`ids>0` but `bound=0`** → SwiftData bind bug (IDs don't resolve on UI context)
/// - **`storeCount=0` after seed window** → data/seed bug (catalog store empty)
/// - **`hasLoaded=true` + hub** but you still see loading chrome → pure UI bug
enum CatalogTabLoadDiagnostics: Sendable {
    private nonisolated static let logger = Logger(
        subsystem: "PrimoSoftware.GoDiveMVP",
        category: "CatalogTabLoad"
    )

    nonisolated static var isEnabled: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    nonisolated static func note(_ message: String) {
        guard isEnabled else { return }
        let line = message
        logger.notice("\(line, privacy: .public)")
        print("[CatalogTabLoad] \(line)")
    }
}
