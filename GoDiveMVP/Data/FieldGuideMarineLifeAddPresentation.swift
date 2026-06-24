import Foundation

/// Copy, validation, and persistence helpers for user-created catalog species.
enum FieldGuideMarineLifeAddPresentation: Sendable {

    nonisolated static let sheetTitle = "New species"
    nonisolated static let chromeAccessibilityLabel = "Add species"
    nonisolated static let chromeSystemImage = "plus"
    nonisolated static let chromeAccessibilityIdentifier = "FieldGuide.AddSpecies"
    nonisolated static let userCreatedUUIDPrefix = "user-marine-life-"

    struct FormValues: Equatable, Sendable {
        var commonName = ""
        var scientificName = ""
        var categoryID = FieldGuideTaxonomy.categories.first?.id ?? ""
        var subcategoryID = ""
        var familyName = ""
        var aboutText = ""
    }

    nonisolated static func isUserCreated(uuid: String) -> Bool {
        uuid.hasPrefix(userCreatedUUIDPrefix)
    }

    nonisolated static func makeUserCreatedUUID() -> String {
        "\(userCreatedUUIDPrefix)\(UUID().uuidString.lowercased())"
    }

    nonisolated static func trimmedCommonName(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func canSave(_ form: FormValues) -> Bool {
        !trimmedCommonName(form.commonName).isEmpty
            && FieldGuideTaxonomy.category(id: form.categoryID) != nil
    }

    nonisolated static func normalizedSubcategoryID(
        categoryID: String,
        subcategoryID: String
    ) -> String {
        let trimmed = subcategoryID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        guard let category = FieldGuideTaxonomy.category(id: categoryID) else { return "" }
        if category.subcategories.contains(where: { $0.id == trimmed }) {
            return trimmed
        }
        return ""
    }

    nonisolated static func makeMarineLife(from form: FormValues) -> MarineLife {
        let categoryID = form.categoryID.trimmingCharacters(in: .whitespacesAndNewlines)
        return MarineLife(
            uuid: makeUserCreatedUUID(),
            commonName: trimmedCommonName(form.commonName),
            scientificName: form.scientificName.trimmingCharacters(in: .whitespacesAndNewlines),
            category: categoryID,
            subcategory: normalizedSubcategoryID(
                categoryID: categoryID,
                subcategoryID: form.subcategoryID
            ),
            familyName: form.familyName.trimmingCharacters(in: .whitespacesAndNewlines),
            aboutText: form.aboutText.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    nonisolated static func shouldPreserveOnCatalogReseed(uuid: String) -> Bool {
        isUserCreated(uuid: uuid)
    }
}
