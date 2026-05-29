import SwiftData
import SwiftUI

/// Creates a catalog **`DiveSite`** from map-tab prepopulated import fields and links **`activity`**.
struct DiveSiteAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var activity: DiveActivity
    let initialDraft: DiveSiteFormDraft
    var onSaved: () -> Void = {}

    @State private var draft: DiveSiteFormDraft
    @State private var saveErrorMessage: String?

    init(
        activity: DiveActivity,
        initialDraft: DiveSiteFormDraft,
        onSaved: @escaping () -> Void = {}
    ) {
        self.activity = activity
        self.initialDraft = initialDraft
        self.onSaved = onSaved
        _draft = State(initialValue: initialDraft)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Site name", text: $draft.siteName)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("DiveSiteAddSheet.SiteName")
                } header: {
                    Text("Dive site")
                }

                Section {
                    TextField("Country", text: $draft.country)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("DiveSiteAddSheet.Country")

                    TextField("Region", text: $draft.region)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("DiveSiteAddSheet.Region")

                    TextField("Body of water", text: $draft.bodyOfWater)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("DiveSiteAddSheet.BodyOfWater")
                } header: {
                    Text("Place")
                } footer: {
                    Text("Optional. Country is the broadest level; region is a state, province, or survey area; body of water is the sea, reef, or bay.")
                }

                Section {
                    DiveSiteCoordinatePickerMapView(
                        latitudeText: $draft.latitudeText,
                        longitudeText: $draft.longitudeText,
                        fallbackCoordinate: activity.entryCoordinate
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                    TextField("Latitude", text: $draft.latitudeText)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("DiveSiteAddSheet.Latitude")

                    TextField("Longitude", text: $draft.longitudeText)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("DiveSiteAddSheet.Longitude")
                } header: {
                    Text("Location")
                } footer: {
                    Text("Drag the map to place the pin, or edit the coordinates directly. Location helps match future dives to this site.")
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("New dive site")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("DiveSiteAddSheet.Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSite()
                    }
                    .fontWeight(.semibold)
                    .disabled(!DiveSiteFormValidation.canSave(draft: draft))
                    .accessibilityIdentifier("DiveSiteAddSheet.Save")
                }
            }
            .alert("Could not save", isPresented: saveErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "Try again.")
            }
        }
        .diveSiteAddSheetPresentation()
        .accessibilityIdentifier("DiveSiteAddSheet.Root")
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )
    }

    private func saveSite() {
        guard let siteName = DiveSiteFormValidation.sanitizedSiteName(draft.siteName) else { return }

        let parsed = DiveSiteFormValidation.parsedCoordinate(
            latitudeText: draft.latitudeText,
            longitudeText: draft.longitudeText
        )
        let lat = parsed?.latitude
        let lon = parsed?.longitude

        Task { @MainActor in
            do {
                let site = try DiveActivitySiteAssociation.createSiteAndLink(
                    to: activity,
                    siteName: siteName,
                    country: DiveSiteFormValidation.sanitizedPlaceField(draft.country),
                    region: DiveSiteFormValidation.sanitizedPlaceField(draft.region),
                    bodyOfWater: DiveSiteFormValidation.sanitizedPlaceField(draft.bodyOfWater),
                    latCoords: lat,
                    longCoords: lon,
                    modelContext: modelContext
                )
                await DiveSiteTimeZoneResolution.ensureResolved(
                    for: site,
                    at: activity.startTime,
                    resolver: MapKitGeocodingTimeZoneResolver.shared
                )
                try modelContext.save()
                DiveActivityMapSitePromptStorage.setDeclined(activityID: activity.id, declined: false)
                onSaved()
                dismiss()
            } catch {
                saveErrorMessage = error.localizedDescription
            }
        }
    }
}
