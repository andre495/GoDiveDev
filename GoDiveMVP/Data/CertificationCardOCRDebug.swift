import Foundation
import os

/// Certification card OCR diagnostics. Filter Xcode / device console by category **`CertOCR`**.
enum CertificationCardOCRDebug: Sendable {
    #if DEBUG
    nonisolated(unsafe) static var isEnabled = true
    #else
    nonisolated(unsafe) static var isEnabled = false
    #endif

    nonisolated private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "PrimoSoftware.GoDiveMVP",
        category: "CertOCR"
    )

    nonisolated static func beganScan(photoLabel: String, imagePixelSize: String) {
        guard isEnabled else { return }
        logger.info("scan began photo=\(photoLabel, privacy: .public) pixels=\(imagePixelSize, privacy: .public)")
    }

    nonisolated static func recognizedLines(_ lines: [String], photoLabel: String) {
        guard isEnabled else { return }
        if lines.isEmpty {
            logger.warning("ocr empty photo=\(photoLabel, privacy: .public)")
            return
        }
        for (index, line) in lines.enumerated() {
            logger.info("ocr[\(index, privacy: .public)] photo=\(photoLabel, privacy: .public) \(line, privacy: .public)")
        }
    }

    nonisolated static func parseResult(_ result: PADICertificationCardParseResult?, photoLabel: String) {
        guard isEnabled else { return }
        guard let result else {
            logger.warning("parse nil photo=\(photoLabel, privacy: .public)")
            return
        }
        logger.info(
            """
            parse photo=\(photoLabel, privacy: .public) \
            agency=\(result.agency, privacy: .public) \
            agencyDetected=\(result.agencyDetectedFromCard, privacy: .public) \
            certName=\(result.certName ?? "—", privacy: .public) \
            certNumber=\(result.certNumber ?? "—", privacy: .public) \
            instructor=\(result.instructor ?? "—", privacy: .public) \
            instructorNumber=\(result.instructorNumber ?? "—", privacy: .public) \
            diveShop=\(result.diveShop ?? "—", privacy: .public) \
            diveShopNumber=\(result.diveShopNumber ?? "—", privacy: .public)
            """
        )
    }

    nonisolated static func skippedApply(field: String, existingValue: String) {
        guard isEnabled else { return }
        logger.warning(
            "apply skipped field=\(field, privacy: .public) existing=\(existingValue, privacy: .public)"
        )
    }

    nonisolated static func unchangedApply(field: String, value: String) {
        guard isEnabled else { return }
        logger.info(
            "apply unchanged field=\(field, privacy: .public) value=\(value, privacy: .public)"
        )
    }
}
