import Foundation
#if canImport(PencilKit)
import PencilKit
#endif

enum DiveSignatureDataFormatting {
    /// **`true`** when **`data`** decodes to a non-empty **`PKDrawing`**.
    static func hasDisplayableContent(_ data: Data?) -> Bool {
        #if canImport(PencilKit)
        guard let data, let drawing = try? PKDrawing(data: data) else { return false }
        return !drawing.bounds.isEmpty
        #else
        return false
        #endif
    }
}
