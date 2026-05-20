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

        do {
            _ = try DiveActivitySiteAssociation.createSiteAndLink(
                to: activity,
                siteName: siteName,
                latCoords: lat,
                longCoords: lon,
                modelContext: modelContext
            )
            DiveActivityMapSitePromptStorage.setDeclined(activityID: activity.id, declined: false)
            onSaved()
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }
}
