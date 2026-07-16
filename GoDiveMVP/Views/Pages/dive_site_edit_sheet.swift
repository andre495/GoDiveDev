import SwiftData
import SwiftUI

/// Blue modal form to edit an existing catalog **`DiveSite`** (name, place, water, depth, coordinates).
struct DiveSiteEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var site: DiveSite
    var onSaved: () -> Void = {}

    @State private var draft: DiveSiteFormDraft
    @State private var saveErrorMessage: String?

    init(site: DiveSite, onSaved: @escaping () -> Void = {}) {
        self.site = site
        self.onSaved = onSaved
        _draft = State(initialValue: DiveSiteFormDraft(from: site))
    }

    private var canSave: Bool {
        DiveSiteFormValidation.canSave(draft: draft)
    }

    var body: some View {
        NavigationStack {
            Form {
                DiveSiteFormContent(
                    draft: $draft,
                    fallbackCoordinate: DiveMapCoordinateResolver.coordinate(from: site),
                    clearsListRowBackgrounds: true
                )
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppGlassToolbarCancelButton(
                        action: { dismiss() },
                        accessibilityIdentifier: DiveSiteEditPresentation.cancelAccessibilityIdentifier
                    )
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppGlassProminentDoneButton(
                        action: saveChanges,
                        accessibilityIdentifier: DiveSiteEditPresentation.doneAccessibilityIdentifier,
                        isEnabled: canSave
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
        .accessibilityIdentifier(DiveSiteEditPresentation.rootAccessibilityIdentifier)
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )
    }

    private func saveChanges() {
        guard canSave else { return }

        let previousLat = site.latCoords
        let previousLon = site.longCoords
        let parsed = DiveSiteFormValidation.parsedCoordinate(
            latitudeText: draft.latitudeText,
            longitudeText: draft.longitudeText
        )
        let coordsChanged = parsed?.latitude != previousLat || parsed?.longitude != previousLon

        Task { @MainActor in
            do {
                try DiveActivitySiteAssociation.applyCatalogSiteEdits(
                    to: site,
                    draft: draft,
                    modelContext: modelContext,
                    persistImmediately: false
                )
                if coordsChanged, parsed != nil {
                    await DiveSiteTimeZoneResolution.ensureResolved(
                        for: site,
                        at: Date(),
                        resolver: MapKitGeocodingTimeZoneResolver.shared
                    )
                }
                try modelContext.save()
                onSaved()
                dismiss()
            } catch {
                saveErrorMessage = error.localizedDescription
            }
        }
    }
}
