import SwiftUI

struct FieldGuideMarineLifeFormContent: View {
    @Binding var form: FieldGuideMarineLifeAddPresentation.FormValues

    private var selectedCategory: FieldGuideTaxonomy.Category? {
        FieldGuideTaxonomy.category(id: form.categoryID)
    }

    var body: some View {
        Section {
            TextField("Common name", text: $form.commonName)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("FieldGuide.AddSpecies.CommonName")
                .listRowBackground(Color.clear)

            TextField("Scientific name", text: $form.scientificName)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("FieldGuide.AddSpecies.ScientificName")
                .listRowBackground(Color.clear)
        } header: {
            Text("Identity")
        }

        Section {
            Picker("Category", selection: $form.categoryID) {
                ForEach(FieldGuideTaxonomy.categories) { category in
                    Text(category.title).tag(category.id)
                }
            }
            .accessibilityIdentifier("FieldGuide.AddSpecies.Category")
            .listRowBackground(Color.clear)

            if let selectedCategory {
                Picker("Group", selection: $form.subcategoryID) {
                    Text("None").tag("")
                    ForEach(selectedCategory.subcategories) { subcategory in
                        Text(subcategory.title).tag(subcategory.id)
                    }
                }
                .accessibilityIdentifier("FieldGuide.AddSpecies.Subcategory")
                .listRowBackground(Color.clear)
            }

            TextField("Family", text: $form.familyName)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("FieldGuide.AddSpecies.Family")
                .listRowBackground(Color.clear)
        } header: {
            Text("Taxonomy")
        }

        Section {
            TextField(
                "Description",
                text: $form.aboutText,
                axis: .vertical
            )
            .lineLimit(3...8)
            .accessibilityIdentifier("FieldGuide.AddSpecies.About")
            .listRowBackground(Color.clear)
        } header: {
            Text("About")
        }
        .onChange(of: form.categoryID) { _, newCategoryID in
            if FieldGuideMarineLifeAddPresentation.normalizedSubcategoryID(
                categoryID: newCategoryID,
                subcategoryID: form.subcategoryID
            ).isEmpty {
                form.subcategoryID = ""
            }
        }
    }
}
