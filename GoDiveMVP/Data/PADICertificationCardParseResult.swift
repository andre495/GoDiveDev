import Foundation

/// Fields extracted from a PADI certification card via OCR (eCard, physical front, or physical back).
struct PADICertificationCardParseResult: Equatable, Sendable {
    var agency: String = "PADI"
    /// Set when OCR reads an agency token from the card (not just the parser default).
    var agencyDetectedFromCard: Bool = false
    var certName: String?
    var certNumber: String?
    var dateAttained: Date?
    var instructorNumber: String?
    var instructor: String?
    var diveShop: String?
    var diveShopNumber: String?

    nonisolated var hasAnyField: Bool {
        agencyDetectedFromCard
            || certName != nil
            || certNumber != nil
            || dateAttained != nil
            || instructorNumber != nil
            || instructor != nil
            || diveShop != nil
            || diveShopNumber != nil
    }

    nonisolated init() {
        agency = "PADI"
    }
}

extension CertificationFormValues {
    /// Applies OCR suggestions: fill empty fields, update when the new parse differs, leave unchanged when absent or matching.
    mutating func applyPADIParseResult(_ result: PADICertificationCardParseResult) {
        func normalized(_ value: String) -> String {
            value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        func stringsMatch(_ lhs: String, _ rhs: String) -> Bool {
            normalized(lhs).caseInsensitiveCompare(normalized(rhs)) == .orderedSame
        }

        func applyString(
            _ keyPath: WritableKeyPath<CertificationFormValues, String>,
            _ value: String?,
            fieldName: String
        ) {
            guard let value, !normalized(value).isEmpty else { return }

            let current = normalized(self[keyPath: keyPath])
            if current.isEmpty {
                self[keyPath: keyPath] = value
                return
            }

            if stringsMatch(current, value) {
                CertificationCardOCRDebug.unchangedApply(field: fieldName, value: current)
                return
            }

            self[keyPath: keyPath] = value
        }

        applyString(\.agency, result.hasAnyField ? result.agency : nil, fieldName: "agency")
        applyString(\.certName, result.certName, fieldName: "certName")
        applyString(\.certNumber, result.certNumber, fieldName: "certNumber")
        applyString(\.instructorNumber, result.instructorNumber, fieldName: "instructorNumber")
        applyString(\.instructor, result.instructor, fieldName: "instructor")
        applyString(\.diveShop, result.diveShop, fieldName: "diveShop")
        applyString(\.diveShopNumber, result.diveShopNumber, fieldName: "diveShopNumber")

        if let parsedDate = result.dateAttained {
            let currentComponents = PADICertificationCardParser.wallClockDateComponents(from: dateAttained)
            let parsedComponents = PADICertificationCardParser.wallClockDateComponents(from: parsedDate)

            if currentComponents.year == parsedComponents.year,
               currentComponents.month == parsedComponents.month,
               currentComponents.day == parsedComponents.day {
                if let year = currentComponents.year,
                   let month = currentComponents.month,
                   let day = currentComponents.day {
                    CertificationCardOCRDebug.unchangedApply(
                        field: "dateAttained",
                        value: "\(year)-\(month)-\(day)"
                    )
                }
            } else {
                dateAttained = parsedDate
            }
        }
    }
}
