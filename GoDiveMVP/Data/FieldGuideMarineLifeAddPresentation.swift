import Foundation
import SwiftData

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

        /// Prefills the edit sheet from an existing catalog species.
        nonisolated init(from species: MarineLife) {
            let snapshot = species.fieldGuideCatalogSnapshot
            self.commonName = species.commonName
            self.scientificName = species.scientificName
            self.categoryID = FieldGuideTaxonomy.resolvedCategoryID(for: snapshot)
            self.subcategoryID = FieldGuideTaxonomy.resolvedSubcategoryID(for: snapshot)
            self.familyName = species.familyName
            self.aboutText = species.aboutText
        }

        nonisolated init(from species: UserMarineLife) {
            let snapshot = species.fieldGuideCatalogSnapshot
            self.commonName = species.commonName
            self.scientificName = species.scientificName
            self.categoryID = FieldGuideTaxonomy.resolvedCategoryID(for: snapshot)
            self.subcategoryID = FieldGuideTaxonomy.resolvedSubcategoryID(for: snapshot)
            self.familyName = species.familyName
            self.aboutText = species.aboutText
        }

        nonisolated init(
            commonName: String = "",
            scientificName: String = "",
            categoryID: String = FieldGuideTaxonomy.categories.first?.id ?? "",
            subcategoryID: String = "",
            familyName: String = "",
            aboutText: String = ""
        ) {
            self.commonName = commonName
            self.scientificName = scientificName
            self.categoryID = categoryID
            self.subcategoryID = subcategoryID
            self.familyName = familyName
            self.aboutText = aboutText
        }
    }

    nonisolated static func isUserCreated(uuid: String) -> Bool {
        uuid.hasPrefix(userCreatedUUIDPrefix)
    }

    nonisolated static func isUserEditable(_ species: UserMarineLife) -> Bool {
        isUserCreated(uuid: species.uuid)
    }

    nonisolated static func isUserEditable(_ species: MarineLife) -> Bool {
        isUserCreated(uuid: species.uuid)
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

    nonisolated static func makeUserMarineLife(
        from form: FormValues,
        owner: UserProfile? = nil
    ) -> UserMarineLife {
        let categoryID = form.categoryID.trimmingCharacters(in: .whitespacesAndNewlines)
        return UserMarineLife(
            uuid: makeUserCreatedUUID(),
            commonName: trimmedCommonName(form.commonName),
            scientificName: form.scientificName.trimmingCharacters(in: .whitespacesAndNewlines),
            category: categoryID,
            subcategory: normalizedSubcategoryID(
                categoryID: categoryID,
                subcategoryID: form.subcategoryID
            ),
            familyName: form.familyName.trimmingCharacters(in: .whitespacesAndNewlines),
            aboutText: form.aboutText.trimmingCharacters(in: .whitespacesAndNewlines),
            owner: owner
        )
    }

    /// Legacy alias — prefer **`makeUserMarineLife`**.
    nonisolated static func makeMarineLife(from form: FormValues) -> UserMarineLife {
        makeUserMarineLife(from: form)
    }

    /// Updates identity / taxonomy / about fields on a **user-created** species only.
    static func applyEdits(
        to species: UserMarineLife,
        form: FormValues,
        modelContext: ModelContext,
        persistImmediately: Bool = true
    ) throws {
        guard isUserEditable(species) else {
            throw FieldGuideMarineLifeEditError.notUserCreated
        }
        guard canSave(form) else {
            throw FieldGuideMarineLifeEditError.invalidForm
        }

        let categoryID = form.categoryID.trimmingCharacters(in: .whitespacesAndNewlines)
        species.commonName = MarineLifeCommonNameFormatting.normalized(trimmedCommonName(form.commonName))
        species.scientificName = form.scientificName.trimmingCharacters(in: .whitespacesAndNewlines)
        species.category = categoryID
        species.subcategory = normalizedSubcategoryID(
            categoryID: categoryID,
            subcategoryID: form.subcategoryID
        )
        species.familyName = form.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        species.aboutText = form.aboutText.trimmingCharacters(in: .whitespacesAndNewlines)
        species.updatedAt = Date()

        if persistImmediately {
            try modelContext.save()
        }
    }

    /// Legacy catalog-row edit path (only valid for leftover pre-migration user rows).
    static func applyEdits(
        to species: MarineLife,
        form: FormValues,
        modelContext: ModelContext,
        persistImmediately: Bool = true
    ) throws {
        guard isUserEditable(species) else {
            throw FieldGuideMarineLifeEditError.notUserCreated
        }
        guard canSave(form) else {
            throw FieldGuideMarineLifeEditError.invalidForm
        }

        let categoryID = form.categoryID.trimmingCharacters(in: .whitespacesAndNewlines)
        species.commonName = MarineLifeCommonNameFormatting.normalized(trimmedCommonName(form.commonName))
        species.scientificName = form.scientificName.trimmingCharacters(in: .whitespacesAndNewlines)
        species.category = categoryID
        species.subcategory = normalizedSubcategoryID(
            categoryID: categoryID,
            subcategoryID: form.subcategoryID
        )
        species.familyName = form.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        species.aboutText = form.aboutText.trimmingCharacters(in: .whitespacesAndNewlines)

        if persistImmediately {
            try modelContext.save()
        }
    }

    nonisolated static func shouldPreserveOnCatalogReseed(uuid: String) -> Bool {
        isUserCreated(uuid: uuid)
    }
}

enum FieldGuideMarineLifeEditError: Error, Equatable {
    case notUserCreated
    case invalidForm
}

enum FieldGuideMarineLifeEditPresentation: Sendable {
    nonisolated static let cancelAccessibilityIdentifier = "FieldGuide.EditSpeciesSheet.Cancel"
    nonisolated static let doneAccessibilityIdentifier = "FieldGuide.EditSpeciesSheet.Done"
    nonisolated static let rootAccessibilityIdentifier = "FieldGuide.EditSpeciesSheet.Root"
}
