import Foundation

/// Copy, screenshots, and paging for the MacDive → UDDF export walkthrough.
///
/// Add each screenshot to **`Assets.xcassets`** using the **`screenshotAssetName`** on the matching step
/// (e.g. **`MacDiveImportStep01`**). Steps without an image yet show a placeholder frame.
enum MacDiveUddfImportPresentation {
    struct Step: Equatable, Sendable, Identifiable {
        let id: Int
        let title: String
        let detail: String
        /// Asset catalog name for the step screenshot (empty when none).
        let screenshotAssetName: String
        /// When **`true`**, the guide shows **Import MacDive Data** on this page.
        let showsImportButton: Bool

        var stepLabel: String {
            "Step \(id)"
        }
    }

    static let importButtonTitle = "Import MacDive Data"

    enum Layout {
        /// Keeps screenshot + copy on one non-scrolling step page.
        static let screenshotMaxHeight: CGFloat = 600
        static let screenshotCornerRadius: CGFloat = 12
    }

    /// Instruction pages — replace titles, details, and asset names as screenshots are added.
    static let steps: [Step] = [
        Step(
            id: 1,
            title: "Select your dive group",
            detail: "Open MacDive and tap the collection of dives you want to import — for example All Dives or a specific log.",
            screenshotAssetName: "MacDiveImportStep01",
            showsImportButton: false
        ),
        Step(
            id: 2,
            title: "Open dive list settings",
            detail: "Once you are on the list of dive activities, tap the settings button in the upper-right corner of the screen.",
            screenshotAssetName: "MacDiveImportStep02",
            showsImportButton: false
        ),
        Step(
            id: 3,
            title: "Export to UDDF",
            detail: "In Settings, tap Export these dives to UDDF. MacDive may take a minute to prepare your dives before the file is ready.",
            screenshotAssetName: "MacDiveImportStep03",
            showsImportButton: false
        ),
        Step(
            id: 4,
            title: "Save to iCloud",
            detail: "When export finishes, choose iCloud as the save location. That keeps the UDDF file where GoDive can find it when you are ready to import.",
            screenshotAssetName: "MacDiveImportStep04",
            showsImportButton: false
        ),
        Step(
            id: 5,
            title: "Save on your iPhone",
            detail: "In the Files browser, open On My iPhone and save the export — for example as MacDiveExport.",
            screenshotAssetName: "MacDiveImportStep05",
            showsImportButton: false
        ),
        Step(
            id: 6,
            title: "Import into GoDive",
            detail: "Tap Import MacDive Data below and choose the UDDF file you just created and saved.",
            screenshotAssetName: "",
            showsImportButton: true
        ),
    ]

    static var stepCount: Int { steps.count }

    static func step(at index: Int) -> Step? {
        guard steps.indices.contains(index) else { return nil }
        return steps[index]
    }

    static func isLastStep(index: Int) -> Bool {
        guard !steps.isEmpty else { return true }
        return index >= steps.count - 1
    }

    static func clampedStepIndex(_ index: Int) -> Int {
        min(max(0, index), max(0, steps.count - 1))
    }

    static func importButtonStepIndex() -> Int? {
        steps.firstIndex(where: \.showsImportButton)
    }
}
