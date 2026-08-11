import Foundation

/// Copy and accessibility ids for shared dive-site add/edit form chrome.
enum DiveSiteFormPresentation: Sendable {
    nonisolated static let countryPlaceholder = "Select country"
    nonisolated static let countryPickerSearchPrompt = "Search countries"
    nonisolated static let countryPickerEmptySearchMessage = "No countries match your search."
    nonisolated static let countryPickerCancelAccessibilityIdentifier = "DiveSiteForm.CountryPicker.Cancel"
    nonisolated static let countryPickerDoneAccessibilityIdentifier = "DiveSiteForm.CountryPicker.Done"
    nonisolated static let countryPickerRootAccessibilityIdentifier = "DiveSiteForm.CountryPicker.Root"
    nonisolated static let countryFieldAccessibilityIdentifier = "DiveSiteForm.Country"
}
