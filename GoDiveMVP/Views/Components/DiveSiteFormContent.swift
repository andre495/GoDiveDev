import SwiftUI

/// Shared add/edit fields for catalog **`DiveSite`** forms.
struct DiveSiteFormContent: View {
    @Binding var draft: DiveSiteFormDraft
    var fallbackCoordinate: DiveCoordinate?
    /// Blue overview-panel modals clear Form card fills so rows sit on the presentation background.
    var clearsListRowBackgrounds: Bool = false

    /// Owned by the host sheet, which presents the picker via `diveSiteCountryPickerSheet`
    /// at its root. A `.sheet` attached here (inside `Form` section content) anchors the
    /// presentation to recycled list cells and tears down the whole sheet stack on iOS 26.
    @Binding var showsCountryPicker: Bool

    private var selectedCountryOption: DiveSiteSelectableCountry? {
        let name = DiveSiteCountryPresentation.canonicalDisplayName(for: draft.country)
        guard !name.isEmpty else { return nil }
        let code = DiveSiteCountryPresentation.isoRegionCode(forCountryName: name) ?? ""
        return DiveSiteSelectableCountry(
            name: name,
            isoRegionCode: code,
            flagEmoji: DiveSiteCountryPresentation.flagEmoji(forCountryName: name)
        )
    }

    var body: some View {
        Group {
            Section {
            TextField("Site name", text: $draft.siteName)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("DiveSiteForm.SiteName")
                .modifier(DiveSiteFormListRowBackground(clears: clearsListRowBackgrounds))
        } header: {
            Text("Dive site")
        }

        Section {
            Button {
                showsCountryPicker = true
            } label: {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Text("Country")
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    Spacer(minLength: AppTheme.Spacing.sm)

                    if let country = selectedCountryOption {
                        if let flag = country.flagEmoji, !flag.isEmpty {
                            Text(flag)
                                .accessibilityHidden(true)
                        }
                        Text(country.name)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .lineLimit(1)
                    } else {
                        Text(DiveSiteFormPresentation.countryPlaceholder)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.tabUnselected)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityIdentifier(DiveSiteFormPresentation.countryFieldAccessibilityIdentifier)
            .modifier(DiveSiteFormListRowBackground(clears: clearsListRowBackgrounds))

            TextField("Region", text: $draft.region)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("DiveSiteForm.Region")
                .modifier(DiveSiteFormListRowBackground(clears: clearsListRowBackgrounds))

            TextField("Body of water", text: $draft.bodyOfWater)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("DiveSiteForm.BodyOfWater")
                .modifier(DiveSiteFormListRowBackground(clears: clearsListRowBackgrounds))
        } header: {
            Text("Place")
        }

        Section {
            Picker("Water type", selection: $draft.waterType) {
                ForEach(DiveWaterType.allCases) { type in
                    Text(type.displayTitle).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("DiveSiteForm.WaterType")
            .modifier(DiveSiteFormListRowBackground(clears: clearsListRowBackgrounds))

            TextField("Entry", text: $draft.entry, prompt: Text("e.g. shore, boat"))
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("DiveSiteForm.Entry")
                .modifier(DiveSiteFormListRowBackground(clears: clearsListRowBackgrounds))

            TextField("Environment", text: $draft.environment, prompt: Text("e.g. ocean, lake"))
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("DiveSiteForm.Environment")
                .modifier(DiveSiteFormListRowBackground(clears: clearsListRowBackgrounds))

            TextField("Max depth (m)", text: $draft.maxDepthMetersText)
                .keyboardType(.numberPad)
                .accessibilityIdentifier("DiveSiteForm.MaxDepth")
                .modifier(DiveSiteFormListRowBackground(clears: clearsListRowBackgrounds))
        } header: {
            Text("Water")
        } footer: {
            Text("Water type sets diver weight defaults on linked dives. Entry, environment, and max depth are optional catalog details.")
        }

        Section {
            DiveSiteCoordinatePickerMapView(
                latitudeText: $draft.latitudeText,
                longitudeText: $draft.longitudeText,
                fallbackCoordinate: fallbackCoordinate
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            TextField("Latitude", text: $draft.latitudeText)
                .keyboardType(.decimalPad)
                .accessibilityIdentifier("DiveSiteForm.Latitude")
                .modifier(DiveSiteFormListRowBackground(clears: clearsListRowBackgrounds))

            TextField("Longitude", text: $draft.longitudeText)
                .keyboardType(.decimalPad)
                .accessibilityIdentifier("DiveSiteForm.Longitude")
                .modifier(DiveSiteFormListRowBackground(clears: clearsListRowBackgrounds))
        } header: {
            Text("Location")
        } footer: {
            Text("Drag the map to place the pin, or edit the coordinates directly. Location helps match future dives to this site.")
        }
        }
    }
}

private struct DiveSiteFormListRowBackground: ViewModifier {
    let clears: Bool

    func body(content: Content) -> some View {
        if clears {
            content.listRowBackground(Color.clear)
        } else {
            content
        }
    }
}
