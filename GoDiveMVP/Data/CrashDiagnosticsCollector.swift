import Foundation
import MetricKit
import SwiftData
import SwiftUI
import os

/// Lightweight on-device crash collection — no third-party SDK.
///
/// Two capture paths feed `CrashReportRecord` rows in the app's SwiftData container
/// (viewable in **Settings → Crash Reports**):
/// 1. **MetricKit** — the system delivers `MXCrashDiagnostic` payloads (signal, Mach exception,
///    symbolicatable call-stack JSON) on the launch after a crash. Not delivered while a
///    debugger is attached, so device runs outside Xcode are the real test.
/// 2. **Session marker heuristic** — a `UserDefaults` marker tracks whether the app was
///    foregrounded. If a new launch finds the marker still set to *foreground*, the previous
///    session died without backgrounding (crash, watchdog kill, or force-quit while active)
///    and an *abnormal exit* report is recorded even when MetricKit has nothing.
///
/// Reports include a **breadcrumb trail** (last root tab / dive overview tab+detent / sheets)
/// frozen from the dying session. When **Settings → Share crash reports** is on, stored reports
/// also upload to the developer's CloudKit public database (`CrashReportCloudUploader`).
enum CrashReportingService {

    /// Call once when the production scene appears (container attached): records any abnormal
    /// exit from the previous session, arms the marker, subscribes to MetricKit, and uploads
    /// any share backlog.
    @MainActor
    static func startAtLaunch(container: ModelContainer) {
        let previousState = CrashSessionMarker.readState()
        let previousDetails = CrashSessionMarker.readDetails()
        // Freeze dying-session breadcrumbs before this launch adds its own trail.
        CrashBreadcrumbTrail.freezePreviousSessionAndBeginNew()
        let previousBreadcrumbs = CrashBreadcrumbTrail.previousSessionExportPlainText()
            ?? "(no breadcrumb snapshot)"

        CrashSessionMarker.write(state: .foreground)
        CrashBreadcrumbTrail.record("appLaunch")

        CrashDiagnosticsCollector.shared.startIfNeeded(container: container)

        Task.detached(priority: .utility) {
            let store = CrashReportStore(container: container)
            if CrashSessionMarker.indicatesAbnormalExit(previousState: previousState) {
                // Prefer the frozen trail (full context) over `previousDetails`, which used to go
                // stale when scene phase didn't change. Keep a thin lifecycle preface only.
                recordAbnormalExit(
                    previousLifecycleState: previousState,
                    previousDetailsPreface: CrashSessionMarker.lifecyclePreface(from: previousDetails),
                    previousBreadcrumbs: previousBreadcrumbs,
                    store: store
                )
            }
            await uploadPendingIfSharingEnabled(store: store)
        }
    }

    /// Keep the session marker in sync with scene lifecycle so only foreground deaths flag.
    @MainActor
    static func updateSessionPhase(_ phase: ScenePhase) {
        switch phase {
        case .active, .inactive:
            CrashSessionMarker.write(state: .foreground)
        case .background:
            CrashSessionMarker.write(state: .background)
        @unknown default:
            break
        }
    }

    /// Settings toggle enable → push the stored backlog to CloudKit immediately.
    @MainActor
    static func uploadBacklogNow(container: ModelContainer) {
        Task.detached(priority: .utility) {
            await uploadPendingIfSharingEnabled(store: CrashReportStore(container: container))
        }
    }

    nonisolated static func uploadPendingIfSharingEnabled(store: CrashReportStore) async {
        guard AppUserSettings.shareCrashReports() else { return }
        await CrashReportCloudUploader.uploadPendingReports(store: store)
    }

    private nonisolated static func recordAbnormalExit(
        previousLifecycleState: CrashSessionMarker.State?,
        previousDetailsPreface: String,
        previousBreadcrumbs: String,
        store: CrashReportStore
    ) {
        let stateLabel = previousLifecycleState?.rawValue ?? "unknown"
        let details = """
        Abnormal exit — previous lifecycle: \(stateLabel)
        \(previousDetailsPreface)

        \(previousBreadcrumbs)
        """
        let report = CrashReport(
            kind: .abnormalExit,
            reason: "Previous session ended while the app was in the foreground",
            appVersion: currentAppVersion,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            details: details
        )
        try? store.save(report)
    }

    nonisolated static var currentAppVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(short) (\(build))"
    }
}

/// `UserDefaults` marker for the crash heuristic — which lifecycle state the last session was in.
nonisolated enum CrashSessionMarker {
    nonisolated enum State: String, Sendable {
        case foreground
        case background
    }

    private nonisolated static let stateKey = "CrashSessionMarker.state"
    private nonisolated static let detailsKey = "CrashSessionMarker.details"

    /// Abnormal exit means the last recorded state was *foreground* — a clean session always
    /// passes through `.background` before the process dies.
    nonisolated static func indicatesAbnormalExit(previousState: State?) -> Bool {
        previousState == .foreground
    }

    nonisolated static func write(state: State, userDefaults: UserDefaults = .standard) {
        userDefaults.set(state.rawValue, forKey: stateKey)
        userDefaults.set(sessionDetailsSnapshot(state: state, userDefaults: userDefaults), forKey: detailsKey)
    }

    /// Re-write the details payload without changing lifecycle state — keeps abnormal-exit
    /// reports current as the user navigates (breadcrumbs used to go stale until scenePhase).
    nonisolated static func refreshDetailsPreservingState(userDefaults: UserDefaults = .standard) {
        let state = readState(userDefaults: userDefaults) ?? .foreground
        userDefaults.set(sessionDetailsSnapshot(state: state, userDefaults: userDefaults), forKey: detailsKey)
    }

    /// First few lines of a prior details blob (marked-at / versions) without the stale trail.
    nonisolated static func lifecyclePreface(from details: String) -> String {
        let kept = details
            .split(separator: "\n", omittingEmptySubsequences: false)
            .prefix(while: { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { return false }
                if trimmed.hasPrefix("##") { return false }
                return true
            })
            .joined(separator: "\n")
        return kept.isEmpty ? details : kept
    }

    nonisolated static func readState(userDefaults: UserDefaults = .standard) -> State? {
        guard let raw = userDefaults.string(forKey: stateKey) else { return nil }
        return State(rawValue: raw)
    }

    nonisolated static func readDetails(userDefaults: UserDefaults = .standard) -> String {
        userDefaults.string(forKey: detailsKey)
            ?? "No details recorded for the previous session."
    }

    private nonisolated static func sessionDetailsSnapshot(
        state: State,
        userDefaults: UserDefaults
    ) -> String {
        """
        Last lifecycle state: \(state.rawValue)
        Marked at: \(Date().formatted(.iso8601))
        App version: \(CrashReportingService.currentAppVersion)
        OS version: \(ProcessInfo.processInfo.operatingSystemVersionString)

        \(CrashBreadcrumbTrail.exportPlainText(userDefaults: userDefaults))
        """
    }
}

/// MetricKit subscriber — converts delivered `MXCrashDiagnostic`s into stored `CrashReportRecord`s.
/// `nonisolated` because MetricKit delivers on a background queue; the only mutable state is the
/// lock-protected container slot, so `@unchecked Sendable` is safe.
nonisolated final class CrashDiagnosticsCollector: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    static let shared = CrashDiagnosticsCollector()

    private let containerSlot = OSAllocatedUnfairLock<ModelContainer?>(initialState: nil)

    func startIfNeeded(container: ModelContainer) {
        let alreadyStarted = containerSlot.withLock { slot in
            defer { slot = container }
            return slot != nil
        }
        guard !alreadyStarted else { return }
        MXMetricManager.shared.add(self)
    }

    /// MetricKit calls this on a background queue — SwiftData writes stay off the main actor.
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        guard let container = containerSlot.withLock({ $0 }) else { return }
        let store = CrashReportStore(container: container)
        var savedAny = false
        for payload in payloads {
            for crash in payload.crashDiagnostics ?? [] {
                try? store.save(Self.report(from: crash, payloadEnd: payload.timeStampEnd))
                savedAny = true
            }
        }
        guard savedAny else { return }
        Task.detached(priority: .utility) {
            await CrashReportingService.uploadPendingIfSharingEnabled(store: store)
        }
    }

    private nonisolated static func report(
        from crash: MXCrashDiagnostic,
        payloadEnd: Date
    ) -> CrashReport {
        let reason = CrashReportPresentation.metricKitReasonLine(
            exceptionType: crash.exceptionType?.intValue,
            signal: crash.signal?.intValue,
            terminationReason: crash.terminationReason
        )

        var details = ""
        if let exceptionReason = crash.exceptionReason {
            details += "Exception: \(exceptionReason.composedMessage)\n\n"
        }
        if let memoryRegion = crash.virtualMemoryRegionInfo {
            details += "Memory region: \(memoryRegion)\n\n"
        }
        let stackJSON = String(decoding: crash.callStackTree.jsonRepresentation(), as: UTF8.self)
        details += "Call stack (MetricKit JSON):\n\(stackJSON)\n\n"

        // Breadcrumbs frozen at this process's start = UI trail from the session that crashed.
        if let frozen = CrashBreadcrumbTrail.previousSessionExportPlainText() {
            details += "\(frozen)\n"
        }

        return CrashReport(
            capturedAt: payloadEnd,
            kind: .metricKitCrash,
            reason: reason,
            appVersion: crash.metaData.applicationBuildVersion,
            osVersion: crash.metaData.osVersion,
            details: details
        )
    }
}
