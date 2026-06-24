import Foundation
import UniformTypeIdentifiers

/// Helpers for SwiftUI **`.fileImporter`** results and presentation timing.
enum DiveFileImporterPresentation {
    /// Single **`.fileImporter`** per view — use this mode to choose allowed UTTypes (two modifiers break the first).
    ///
    /// **`.fit`** is the Garmin single-dive path; **`.uddf`** is the consolidated UDDF path (one or many dives).
    enum PickerMode {
        case fit
        case uddf

        /// Restrict the document picker to the matching extension only (no broad **`.data`** / **`.xml`**, which
        /// previously left every file selectable). **`UTType(filenameExtension:)`** matches files by extension.
        var allowedContentTypes: [UTType] {
            switch self {
            case .fit:
                [.goDiveFit]
            case .uddf:
                [.goDiveUddf]
            }
        }

        var isUddf: Bool { self == .uddf }
    }

    static let fitAllowedTypes: [UTType] = PickerMode.fit.allowedContentTypes
    static let uddfAllowedTypes: [UTType] = PickerMode.uddf.allowedContentTypes

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

    /// Yields past an in-flight sheet dismiss or navigation pop before **`.fileImporter`** is shown.
    @MainActor
    static func awaitPresentationSurfaceReady() async {
        await Task.yield()
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(320))
    }
}
