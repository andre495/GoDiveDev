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
                DiveSiteFormContent(
                    draft: $draft,
                    fallbackCoordinate: activity.entryCoordinate,
                    clearsListRowBackgrounds: true
                )
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppGlassToolbarCancelButton(
                        action: { dismiss() },
                        accessibilityIdentifier: "DiveSiteAddSheet.Cancel"
                    )
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppGlassProminentDoneButton(
                        action: saveSite,
                        accessibilityIdentifier: "DiveSiteAddSheet.Done",
                        isEnabled: DiveSiteFormValidation.canSave(draft: draft)
                    )
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
                    waterType: draft.waterType,
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
