import UniformTypeIdentifiers

extension UTType {
    /// Garmin `.fit` activity files (UTI may be absent on some OS versions; falls back to generic data).
    static var goDiveFit: UTType {
        UTType(filenameExtension: "fit") ?? UTType.data
    }

    /// **UDDF** logbook export (e.g. **MacDive** `.uddf` — XML).
    static var goDiveUddf: UTType {
        UTType(filenameExtension: "uddf") ?? UTType.xml
    }
}
