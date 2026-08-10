import SwiftUI

/// Multi-select ISO countries with flag emojis for trip planning (blue overview-panel modal).
struct TripCountryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedCountries: [String]

    @State private var draftCountries: [String] = []
    @State private var searchQuery = ""
    @FocusState private var isSearchFocused: Bool

    private var allOptions: [DiveSiteSelectableCountry] {
        DiveSiteCountryPresentation.selectableCountries(includingSelected: draftCountries)
    }

    private var filteredOptions: [DiveSiteSelectableCountry] {
        allOptions.filter {
            DiveSiteCountryPresentation.matchesSelectableCountry($0, query: searchQuery)
        }
    }

    private var selectedNormalizedKeys: Set<String> {
        Set(draftCountries.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if filteredOptions.isEmpty {
                    Text(TripPlannerPresentation.countriesPickerEmptySearchMessage)
                        .font(.body)
                        .foregroundStyle(AppTheme.Colors.tabUnselected)
                        .multilineTextAlignment(.center)
                        .padding(AppTheme.Spacing.lg)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityIdentifier("TripCountryPicker.EmptySearch")
                } else {
                    TaggingSheetListChrome {
                        ForEach(Array(filteredOptions.enumerated()), id: \.element.id) { index, country in
                            TaggingSheetListRowContainer(showsDivider: index < filteredOptions.count - 1) {
                                TaggingSheetSelectionRow(
                                    title: country.name,
                                    isSelected: isSelected(country),
                                    accessibilityValueSelected: "Selected",
                                    accessibilityValueUnselected: "Not selected",
                                    onTap: { toggle(country) },
                                    leading: {
                                        TaggingSheetFlagLeadingArt(flagEmoji: country.flagEmoji)
                                    }
                                )
                                .accessibilityLabel(country.labeledDisplayName)
                                .accessibilityIdentifier(
                                    "TripCountryPicker.Row.\(country.isoRegionCode.isEmpty ? country.name : country.isoRegionCode)"
                                )
                            }
                        }
                    }
                }

                TaggingSheetBottomSearchChrome(
                    searchText: $searchQuery,
                    isSearchFocused: $isSearchFocused,
                    placeholder: TripPlannerPresentation.countriesPickerSearchPrompt,
                    searchFieldAccessibilityIdentifier: "TripCountryPicker.SearchField",
                    cancelAccessibilityIdentifier: "TripCountryPicker.SearchCancel"
                )
            }
            .taggingSheetToolbar(
                cancelAccessibilityIdentifier: TripPlannerPresentation.countryPickerCancelAccessibilityIdentifier,
                doneAccessibilityIdentifier: TripPlannerPresentation.countryPickerDoneAccessibilityIdentifier,
                onCancel: { dismiss() },
                onDone: {
                    selectedCountries = DiveTripFormValues.normalizeCountryList(draftCountries)
                    dismiss()
                }
            )
        }
        .diveActivityOverviewPanelModalSheetPresentation()
        .onAppear {
            draftCountries = DiveTripFormValues.normalizeCountryList(selectedCountries)
        }
        .accessibilityIdentifier("TripCountryPicker.Root")
    }

    private func isSelected(_ country: DiveSiteSelectableCountry) -> Bool {
        selectedNormalizedKeys.contains(country.name.lowercased())
    }

    private func toggle(_ country: DiveSiteSelectableCountry) {
        DiveTripFormValues.toggleCountry(country.name, in: &draftCountries)
    }
}
