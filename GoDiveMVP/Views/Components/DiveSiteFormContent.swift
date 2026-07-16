import SwiftUI

/// Shared add/edit fields for catalog **`DiveSite`** forms.
struct DiveSiteFormContent: View {
    @Binding var draft: DiveSiteFormDraft
    var fallbackCoordinate: DiveCoordinate?
    /// Blue overview-panel modals clear Form card fills so rows sit on the presentation background.
    var clearsListRowBackgrounds: Bool = false

    var body: some View {
        Section {
            TextField("Site name", text: $draft.siteName)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("DiveSiteForm.SiteName")
                .modifier(DiveSiteFormListRowBackground(clears: clearsListRowBackgrounds))
        } header: {
            Text("Dive site")
        }

        Section {
            TextField("Country", text: $draft.country)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("DiveSiteForm.Country")
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
        } footer: {
            Text("Optional. Country is the broadest level; region is a state, province, or survey area; body of water is the sea, reef, or bay.")
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
