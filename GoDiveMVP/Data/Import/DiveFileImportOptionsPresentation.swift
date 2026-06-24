import Foundation

enum DiveFileImportOptionsPresentation {
    nonisolated static func pageTitle(for mode: DiveFileImporterPresentation.PickerMode) -> String {
        switch mode {
        case .uddf: "UDDF import"
        case .fit: "Garmin FIT import"
        }
    }

    nonisolated static func intro(for mode: DiveFileImporterPresentation.PickerMode) -> String {
        switch mode {
        case .uddf:
            "Import one or all of your UDDF dive records at once."
        case .fit:
            "Import a single dive from a Garmin .fit file exported from your dive computer."
        }
    }

    nonisolated static func chooseFileTitle(for mode: DiveFileImporterPresentation.PickerMode) -> String {
        switch mode {
        case .uddf: "Choose UDDF file"
        case .fit: "Choose FIT file"
        }
    }

    nonisolated static func accessibilityPrefix(for mode: DiveFileImporterPresentation.PickerMode) -> String {
        switch mode {
        case .uddf: "ActivityUpload.BulkUddf"
        case .fit: "ActivityUpload.FitImport"
        }
    }
}
