import Foundation
import UniformTypeIdentifiers

/// Helpers for SwiftUI **`.fileImporter`** results and presentation timing.
enum DiveFileImporterPresentation {
    /// Single **`.fileImporter`** per view — use this mode to choose allowed UTTypes (two modifiers break the first).
    enum PickerMode {
        case singleDive
        case bulkUddf

        var allowedContentTypes: [UTType] {
            switch self {
            case .singleDive:
                [.goDiveFit, .goDiveUddf, .data, .xml]
            case .bulkUddf:
                [.goDiveUddf, .data, .xml]
            }
        }

        var isBulkUddf: Bool { self == .bulkUddf }
    }

    static let singleDiveAllowedTypes: [UTType] = PickerMode.singleDive.allowedContentTypes
    static let bulkUddfAllowedTypes: [UTType] = PickerMode.bulkUddf.allowedContentTypes

    /// **`true`** when the user cancelled the system document picker (not a read/decode failure).
    static func isUserCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain, ns.code == NSUserCancelledError {
            return true
        }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }
        return false
    }
}
