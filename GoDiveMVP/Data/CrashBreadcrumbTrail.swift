import Darwin
import Foundation

/// Ring-buffer of recent navigation / UI context for crash reports.
///
/// Persisted in **`UserDefaults`** so abnormal-exit capture on the *next* launch still has
/// the last screens/actions from the dying session. Attach via
/// **`CrashBreadcrumbTrail.exportPlainText()`** (no dive log / photo / PII — IDs and route names only).
nonisolated enum CrashBreadcrumbTrail {

    nonisolated static let maxEntries = 24

    private nonisolated static let entriesKey = "CrashBreadcrumbTrail.entries"
    private nonisolated static let contextKey = "CrashBreadcrumbTrail.context"
    /// Snapshot of the trail at process start — the dying session's breadcrumbs for MetricKit / abnormal-exit.
    private nonisolated static let previousSessionExportKey = "CrashBreadcrumbTrail.previousSessionExport"
    /// Serializes trail reads/writes across MetricKit + UI threads (`UserDefaults` is not `Sendable`).
    private nonisolated static let lock = NSLock()

    private nonisolated static func withTrailLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    /// Current coarse UI context — overwritten in place; included in every diagnostic snapshot.
    nonisolated struct Context: Codable, Equatable, Sendable {
        var rootTab: String?
        var screen: String?
        var diveActivityID: String?
        var diveNumber: Int?
        var diveActivityTab: String?
        var overviewDetent: String?
        var presentedSheet: String?
        var mediaCount: Int?
        var selectedMediaID: String?
        var featuredMediaID: String?
        var selectedMediaKind: String?
        var overviewPanelPresented: Bool?
        var orientation: String?
        var lastAction: String?
    }

    /// Dive-overview fields captured together for crash context.
    nonisolated struct DiveOverviewSnapshot: Equatable, Sendable {
        var activityID: UUID
        var diveNumber: Int?
        var activityTab: DiveActivityTab
        var detent: DiveActivityOverviewDetent
        var mediaCount: Int
        var selectedMediaID: UUID?
        var featuredMediaID: UUID?
        var selectedMediaKind: String?
        var overviewPanelPresented: Bool
        var orientation: String
    }

    nonisolated struct Entry: Codable, Equatable, Sendable {
        var at: Date
        var message: String
    }

    // MARK: - Record

    /// Append a breadcrumb and keep only the newest `maxEntries`.
    static func record(_ message: String, userDefaults: UserDefaults = .standard) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withTrailLock {
            var entries = loadEntries(userDefaults: userDefaults)
            entries.append(Entry(at: Date(), message: trimmed))
            if entries.count > maxEntries {
                entries.removeFirst(entries.count - maxEntries)
            }
            saveEntries(entries, userDefaults: userDefaults)
        }
        CrashSessionMarker.refreshDetailsPreservingState(userDefaults: userDefaults)
    }

    /// Update durable UI context (last-known tab / screen / dive / detent).
    static func updateContext(
        _ mutate: (inout Context) -> Void,
        userDefaults: UserDefaults = .standard,
        refreshSessionMarker: Bool = true
    ) {
        withTrailLock {
            var context = loadContext(userDefaults: userDefaults) ?? Context()
            mutate(&context)
            if let data = try? JSONEncoder().encode(context) {
                userDefaults.set(data, forKey: contextKey)
            }
        }
        if refreshSessionMarker {
            CrashSessionMarker.refreshDetailsPreservingState(userDefaults: userDefaults)
        }
    }

    /// Convenience: set root tab + append a breadcrumb.
    static func noteRootTab(_ tab: RootTab, userDefaults: UserDefaults = .standard) {
        let label = rootTabLabel(tab)
        updateContext({ $0.rootTab = label }, userDefaults: userDefaults, refreshSessionMarker: false)
        record("rootTab → \(label)", userDefaults: userDefaults)
    }

    /// Dive overview identity + media selection / detent / orientation.
    static func noteDiveOverview(
        _ snapshot: DiveOverviewSnapshot,
        userDefaults: UserDefaults = .standard
    ) {
        let tabLabel = diveActivityTabLabel(snapshot.activityTab)
        let detentLabel = String(describing: snapshot.detent)
        let selectedShort = snapshot.selectedMediaID.map { String($0.uuidString.prefix(8)) }
        let featuredShort = snapshot.featuredMediaID.map { String($0.uuidString.prefix(8)) }
        updateContext({
            $0.screen = "diveOverview"
            $0.diveActivityID = snapshot.activityID.uuidString
            $0.diveNumber = snapshot.diveNumber
            $0.diveActivityTab = tabLabel
            $0.overviewDetent = detentLabel
            $0.presentedSheet = nil
            $0.mediaCount = snapshot.mediaCount
            $0.selectedMediaID = snapshot.selectedMediaID?.uuidString
            $0.featuredMediaID = snapshot.featuredMediaID?.uuidString
            $0.selectedMediaKind = snapshot.selectedMediaKind
            $0.overviewPanelPresented = snapshot.overviewPanelPresented
            $0.orientation = snapshot.orientation
        }, userDefaults: userDefaults, refreshSessionMarker: false)

        var line =
            "diveOverview #\(snapshot.diveNumber.map(String.init) ?? "-") \(snapshot.activityID.uuidString.prefix(8)) tab=\(tabLabel) detent=\(detentLabel) media=\(snapshot.mediaCount)"
        if let selectedShort {
            line += " selected=\(selectedShort)"
        }
        if let kind = snapshot.selectedMediaKind {
            line += " kind=\(kind)"
        }
        if let featuredShort {
            line += " featured=\(featuredShort)"
        }
        line += " panel=\(snapshot.overviewPanelPresented ? "on" : "off") \(snapshot.orientation)"
        record(line, userDefaults: userDefaults)
    }

    static func noteScreen(_ screen: String, userDefaults: UserDefaults = .standard) {
        updateContext({
            $0.screen = screen
            $0.diveActivityID = nil
            $0.diveNumber = nil
            $0.diveActivityTab = nil
            $0.overviewDetent = nil
            $0.presentedSheet = nil
            $0.mediaCount = nil
            $0.selectedMediaID = nil
            $0.featuredMediaID = nil
            $0.selectedMediaKind = nil
            $0.overviewPanelPresented = nil
            $0.orientation = nil
            $0.lastAction = nil
        }, userDefaults: userDefaults, refreshSessionMarker: false)
        record("screen → \(screen)", userDefaults: userDefaults)
    }

    static func noteSheet(_ sheet: String?, userDefaults: UserDefaults = .standard) {
        updateContext({ $0.presentedSheet = sheet }, userDefaults: userDefaults, refreshSessionMarker: false)
        if let sheet {
            record("sheet → \(sheet)", userDefaults: userDefaults)
        } else {
            record("sheet dismissed", userDefaults: userDefaults)
        }
    }

    /// Discrete user action (star toggle, upload, etc.) for abnormal-exit debugging.
    static func noteAction(_ action: String, userDefaults: UserDefaults = .standard) {
        let trimmed = action.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        updateContext({ $0.lastAction = trimmed }, userDefaults: userDefaults, refreshSessionMarker: false)
        record("action → \(trimmed)", userDefaults: userDefaults)
    }

    // MARK: - Export

    /// Plain-text block for crash / abnormal-exit report bodies (current in-session trail).
    static func exportPlainText(userDefaults: UserDefaults = .standard) -> String {
        withTrailLock {
            let context = loadContext(userDefaults: userDefaults)
            let entries = loadEntries(userDefaults: userDefaults)
            return formatExport(context: context, entries: entries, processSnapshot: processSnapshot())
        }
    }

    /// Call once at process launch *before* recording new breadcrumbs: freeze the dying session's
    /// trail, then clear the live ring so this session starts fresh.
    static func freezePreviousSessionAndBeginNew(userDefaults: UserDefaults = .standard) {
        withTrailLock {
            let context = loadContext(userDefaults: userDefaults)
            let entries = loadEntries(userDefaults: userDefaults)
            let snapshot = formatExport(
                context: context,
                entries: entries,
                processSnapshot: processSnapshot()
            )
            userDefaults.set(snapshot, forKey: previousSessionExportKey)
            userDefaults.removeObject(forKey: entriesKey)
            // Keep last UI context across the freeze — useful if MetricKit arrives before new notes.
        }
    }

    /// Breadcrumbs frozen at the start of this process (previous session). Prefer this in reports.
    static func previousSessionExportPlainText(userDefaults: UserDefaults = .standard) -> String? {
        userDefaults.string(forKey: previousSessionExportKey)
    }

    /// Testable formatter — no `UserDefaults` / device calls.
    nonisolated static func formatExport(
        context: Context?,
        entries: [Entry],
        processSnapshot: String
    ) -> String {
        var lines: [String] = ["## Session context", processSnapshot, ""]

        if let context {
            lines.append("## Last UI context")
            if let rootTab = context.rootTab { lines.append("rootTab: \(rootTab)") }
            if let screen = context.screen { lines.append("screen: \(screen)") }
            if let diveID = context.diveActivityID { lines.append("diveActivityID: \(diveID)") }
            if let diveNumber = context.diveNumber { lines.append("diveNumber: \(diveNumber)") }
            if let diveTab = context.diveActivityTab { lines.append("diveActivityTab: \(diveTab)") }
            if let detent = context.overviewDetent { lines.append("overviewDetent: \(detent)") }
            if let sheet = context.presentedSheet { lines.append("presentedSheet: \(sheet)") }
            if let mediaCount = context.mediaCount { lines.append("mediaCount: \(mediaCount)") }
            if let selected = context.selectedMediaID { lines.append("selectedMediaID: \(selected)") }
            if let featured = context.featuredMediaID { lines.append("featuredMediaID: \(featured)") }
            if let kind = context.selectedMediaKind { lines.append("selectedMediaKind: \(kind)") }
            if let panel = context.overviewPanelPresented {
                lines.append("overviewPanelPresented: \(panel)")
            }
            if let orientation = context.orientation { lines.append("orientation: \(orientation)") }
            if let lastAction = context.lastAction { lines.append("lastAction: \(lastAction)") }
            lines.append("")
        }

        lines.append("## Breadcrumbs (newest last, max \(maxEntries))")
        if entries.isEmpty {
            lines.append("(none)")
        } else {
            let formatter = ISO8601DateFormatter()
            for entry in entries {
                lines.append("\(formatter.string(from: entry.at))  \(entry.message)")
            }
        }
        return lines.joined(separator: "\n")
    }

    nonisolated static func processSnapshot() -> String {
        let info = ProcessInfo.processInfo
        var parts: [String] = [
            "uptimeSeconds: \(Int(info.systemUptime))",
            "activeProcessorCount: \(info.activeProcessorCount)",
            "processorCount: \(info.processorCount)",
            "physicalMemoryMB: \(info.physicalMemory / 1_048_576)",
            "hwMachine: \(hardwareMachineIdentifier())",
            "thermalState: \(thermalStateLabel(info.thermalState))",
        ]
        if let footprint = memoryFootprintHintMB() {
            parts.append("appMemoryFootprintMB: \(footprint)")
        }
        return parts.joined(separator: "\n")
    }

    // MARK: - Persistence helpers

    /// Clears trail — tests only.
    static func resetForTests(userDefaults: UserDefaults = .standard) {
        withTrailLock {
            userDefaults.removeObject(forKey: entriesKey)
            userDefaults.removeObject(forKey: contextKey)
            userDefaults.removeObject(forKey: previousSessionExportKey)
        }
    }

    static func loadEntriesForTests(userDefaults: UserDefaults = .standard) -> [Entry] {
        withTrailLock { loadEntries(userDefaults: userDefaults) }
    }

    private nonisolated static func loadEntries(userDefaults: UserDefaults) -> [Entry] {
        guard let data = userDefaults.data(forKey: entriesKey),
              let decoded = try? JSONDecoder().decode([Entry].self, from: data) else {
            return []
        }
        return decoded
    }

    private nonisolated static func saveEntries(_ entries: [Entry], userDefaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(entries) {
            userDefaults.set(data, forKey: entriesKey)
        }
    }

    private nonisolated static func loadContext(userDefaults: UserDefaults) -> Context? {
        guard let data = userDefaults.data(forKey: contextKey) else { return nil }
        return try? JSONDecoder().decode(Context.self, from: data)
    }

    nonisolated static func rootTabLabel(_ tab: RootTab) -> String {
        switch tab {
        case .home: "home"
        case .logbook: "logbook"
        case .fieldGuide: "fieldGuide"
        case .explore: "explore"
        case .search: "search"
        }
    }

    nonisolated static func diveActivityTabLabel(_ tab: DiveActivityTab) -> String {
        switch tab {
        case .map: "map"
        case .tank: "tank"
        case .camera: "media"
        }
    }

    nonisolated static func thermalStateLabel(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        @unknown default: "unknown"
        }
    }

    private nonisolated static func hardwareMachineIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }

    /// Rough resident size via `task_info` — diagnostic only.
    private nonisolated static func memoryFootprintHintMB() -> Int? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return Int(info.phys_footprint / 1_048_576)
    }
}
