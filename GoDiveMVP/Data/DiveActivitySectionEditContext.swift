import Foundation

/// Identifies which overview section is being edited in a sheet.
struct DiveActivitySectionEditContext: Identifiable, Equatable, Sendable {
    let sectionID: String
    let tab: DiveActivityEditablePanelTab
    let panelDetent: DiveActivityOverviewDetent

    var id: String { "\(tab)-\(sectionID)" }

    func resolvedSection() -> DiveActivityEditableCatalog.Section? {
        DiveActivityEditableCatalog.section(id: sectionID, tab: tab, detent: panelDetent)
    }
}
