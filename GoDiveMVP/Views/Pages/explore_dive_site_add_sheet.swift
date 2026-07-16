import SwiftData
import SwiftUI

/// Creates a catalog **`DiveSite`** from **Explore** without linking a dive.
struct ExploreCatalogDiveSiteAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var onSaved: (UUID) -> Void

    @State private var draft = DiveSiteFormDraft(
        siteName: "",
        country: "",
        region: "",
        bodyOfWater: "",
        latitudeText: "",
        longitudeText: ""
    )
    @State private var saveErrorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                DiveSiteFormContent(
                    draft: $draft,
                    fallbackCoordinate: nil,
                    clearsListRowBackgrounds: true
                )
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppGlassToolbarCancelButton(
                        action: { dismiss() },
                        accessibilityIdentifier: ExploreDiveSiteAddPresentation.cancelAccessibilityIdentifier
                    )
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppGlassProminentDoneButton(
                        action: saveSite,
                        accessibilityIdentifier: ExploreDiveSiteAddPresentation.doneAccessibilityIdentifier,
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
        .accessibilityIdentifier("Explore.AddDiveSiteSheet.Root")
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

        Task { @MainActor in
            do {
                let site = try DiveActivitySiteAssociation.createCatalogSite(
                    siteName: siteName,
                    country: DiveSiteFormValidation.sanitizedPlaceField(draft.country),
                    region: DiveSiteFormValidation.sanitizedPlaceField(draft.region),
                    bodyOfWater: DiveSiteFormValidation.sanitizedPlaceField(draft.bodyOfWater),
                    latCoords: parsed?.latitude,
                    longCoords: parsed?.longitude,
                    waterType: draft.waterType,
                    modelContext: modelContext
                )
                if parsed != nil {
                    await DiveSiteTimeZoneResolution.ensureResolved(
                        for: site,
                        at: Date(),
                        resolver: MapKitGeocodingTimeZoneResolver.shared
                    )
                    try modelContext.save()
                }
                onSaved(site.id)
                dismiss()
            } catch {
                saveErrorMessage = error.localizedDescription
            }
        }
    }
}
