import SwiftUI

extension View {
    /// Presents the country picker from a host sheet's stable root (`NavigationStack` level).
    /// Attaching this inside `DiveSiteFormContent`'s `Form` section content anchors the
    /// presentation to recycled list cells, which dismisses the picker *and* the host sheet.
    func diveSiteCountryPickerSheet(
        isPresented: Binding<Bool>,
        selectedCountry: Binding<String>
    ) -> some View {
        sheet(isPresented: isPresented) {
            DiveSiteCountryPickerSheet(selectedCountry: selectedCountry)
        }
    }
}

/// Single-select ISO country picker with flag emojis for dive-site forms.
struct DiveSiteCountryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedCountry: String

    @State private var searchQuery = ""
    @FocusState private var isSearchFocused: Bool

    private var allOptions: [DiveSiteSelectableCountry] {
        let selected = selectedCountry.trimmingCharacters(in: .whitespacesAndNewlines)
        return DiveSiteCountryPresentation.selectableCountries(
            includingSelected: selected.isEmpty ? [] : [selected]
        )
    }

    private var filteredOptions: [DiveSiteSelectableCountry] {
        allOptions.filter {
            DiveSiteCountryPresentation.matchesSelectableCountry($0, query: searchQuery)
        }
    }

    private var selectedNormalizedKey: String {
        DiveSiteCountryPresentation.canonicalDisplayName(for: selectedCountry)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if filteredOptions.isEmpty {
                    Text(DiveSiteFormPresentation.countryPickerEmptySearchMessage)
                        .font(.body)
                        .foregroundStyle(AppTheme.Colors.tabUnselected)
                        .multilineTextAlignment(.center)
                        .padding(AppTheme.Spacing.lg)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityIdentifier("DiveSiteForm.CountryPicker.EmptySearch")
                } else {
                    TaggingSheetListChrome {
                        ForEach(Array(filteredOptions.enumerated()), id: \.element.id) { index, country in
                            TaggingSheetListRowContainer(showsDivider: index < filteredOptions.count - 1) {
                                TaggingSheetSelectionRow(
                                    title: country.name,
                                    isSelected: isSelected(country),
                                    accessibilityValueSelected: "Selected",
                                    accessibilityValueUnselected: "Not selected",
                                    onTap: { select(country) },
                                    leading: {
                                        TaggingSheetFlagLeadingArt(flagEmoji: country.flagEmoji)
                                    }
                                )
                                .accessibilityLabel(country.labeledDisplayName)
                                .accessibilityIdentifier(
                                    "DiveSiteForm.CountryPicker.Row.\(country.isoRegionCode.isEmpty ? country.name : country.isoRegionCode)"
                                )
                            }
                        }
                    }
                }

                TaggingSheetBottomSearchChrome(
                    searchText: $searchQuery,
                    isSearchFocused: $isSearchFocused,
                    placeholder: DiveSiteFormPresentation.countryPickerSearchPrompt,
                    searchFieldAccessibilityIdentifier: "DiveSiteForm.CountryPicker.SearchField",
                    cancelAccessibilityIdentifier: "DiveSiteForm.CountryPicker.SearchCancel"
                )
            }
            .taggingSheetToolbar(
                cancelAccessibilityIdentifier: DiveSiteFormPresentation.countryPickerCancelAccessibilityIdentifier,
                doneAccessibilityIdentifier: DiveSiteFormPresentation.countryPickerDoneAccessibilityIdentifier,
                onCancel: { dismiss() },
                onDone: { dismiss() }
            )
        }
        .diveActivityOverviewPanelModalSheetPresentation()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(DiveSiteFormPresentation.countryPickerRootAccessibilityIdentifier)
    }

    private func isSelected(_ country: DiveSiteSelectableCountry) -> Bool {
        selectedNormalizedKey == country.name.lowercased()
    }

    private func select(_ country: DiveSiteSelectableCountry) {
        selectedCountry = country.name
        dismiss()
    }
}
