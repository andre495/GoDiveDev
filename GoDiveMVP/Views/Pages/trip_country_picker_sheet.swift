import SwiftUI

/// Multi-select ISO countries with flag emojis for trip planning (blue overview-panel modal).
struct TripCountryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedCountries: [String]

    @State private var draftCountries: [String] = []
    @State private var searchQuery = ""

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
            List {
                if filteredOptions.isEmpty {
                    Section {
                        Text(TripPlannerPresentation.countriesPickerEmptySearchMessage)
                            .font(.body)
                            .foregroundStyle(AppTheme.Colors.tabUnselected)
                            .listRowBackground(Color.clear)
                            .accessibilityIdentifier("TripCountryPicker.EmptySearch")
                    }
                } else {
                    Section {
                        ForEach(filteredOptions) { country in
                            Button {
                                toggle(country)
                            } label: {
                                TripCountryPickerRow(
                                    country: country,
                                    isSelected: isSelected(country)
                                )
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(
                                top: 0,
                                leading: AppTheme.Spacing.md,
                                bottom: 0,
                                trailing: AppTheme.Spacing.md
                            ))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .accessibilityIdentifier("TripCountryPicker.Row.\(country.isoRegionCode.isEmpty ? country.name : country.isoRegionCode)")
                        }
                    } footer: {
                        Text(TripPlannerPresentation.countriesPickerFooter)
                    }
                }
            }
            .listStyle(.plain)
            .listRowSpacing(6)
            .scrollContentBackground(.hidden)
            .searchable(text: $searchQuery, prompt: TripPlannerPresentation.countriesPickerSearchPrompt)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppGlassToolbarCancelButton(
                        action: { dismiss() },
                        accessibilityIdentifier: TripPlannerPresentation.countryPickerCancelAccessibilityIdentifier
                    )
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppGlassProminentDoneButton(
                        action: {
                            selectedCountries = DiveTripFormValues.normalizeCountryList(draftCountries)
                            dismiss()
                        },
                        accessibilityIdentifier: TripPlannerPresentation.countryPickerDoneAccessibilityIdentifier
                    )
                }
            }
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

private struct TripCountryPickerRow: View {
    let country: DiveSiteSelectableCountry
    let isSelected: Bool

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            if let flag = country.flagEmoji, !flag.isEmpty {
                Text(flag)
                    .font(.title3)
                    .accessibilityHidden(true)
            }

            Text(country.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.tabSelected)
                    .accessibilityHidden(true)
            }
        }
        .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
        .background(rowBackground)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityLabel(country.labeledDisplayName)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                isSelected
                    ? AppTheme.Colors.tabSelected.opacity(0.14)
                    : AppTheme.Colors.surfaceElevated
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isSelected ? AppTheme.Colors.tabSelected.opacity(0.55) : Color.clear,
                        lineWidth: 1.5
                    )
            }
    }
}
