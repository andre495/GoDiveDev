import SwiftUI

/// Shared add/edit fields for catalog **`DiveSite`** forms.
struct DiveSiteFormContent: View {
    @Binding var draft: DiveSiteFormDraft
    var fallbackCoordinate: DiveCoordinate?

    var body: some View {
        Section {
            TextField("Site name", text: $draft.siteName)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("DiveSiteForm.SiteName")
        } header: {
            Text("Dive site")
        }

        Section {
            TextField("Country", text: $draft.country)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("DiveSiteForm.Country")

            TextField("Region", text: $draft.region)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("DiveSiteForm.Region")

            TextField("Body of water", text: $draft.bodyOfWater)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("DiveSiteForm.BodyOfWater")
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
        } header: {
            Text("Water")
        } footer: {
            Text("Used for diver weight defaults on dives linked to this site.")
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

            TextField("Longitude", text: $draft.longitudeText)
                .keyboardType(.decimalPad)
                .accessibilityIdentifier("DiveSiteForm.Longitude")
        } header: {
            Text("Location")
        } footer: {
            Text("Drag the map to place the pin, or edit the coordinates directly. Location helps match future dives to this site.")
        }
    }
}
