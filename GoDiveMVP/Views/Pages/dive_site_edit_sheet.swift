import SwiftData
import SwiftUI

/// Blue modal form to edit an existing dive site (catalog or user-owned).
struct DiveSiteEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private enum BoundSite {
        case catalog(DiveSite)
        case user(UserDiveSite)
    }

    private let boundSite: BoundSite
    var onSaved: () -> Void = {}

    @State private var draft: DiveSiteFormDraft
    @State private var saveErrorMessage: String?

    init(site: DiveSite, onSaved: @escaping () -> Void = {}) {
        self.boundSite = .catalog(site)
        self.onSaved = onSaved
        _draft = State(initialValue: DiveSiteFormDraft(from: site))
    }

    init(site: UserDiveSite, onSaved: @escaping () -> Void = {}) {
        self.boundSite = .user(site)
        self.onSaved = onSaved
        _draft = State(initialValue: DiveSiteFormDraft(from: site))
    }

    private var canSave: Bool {
        DiveSiteFormValidation.canSave(draft: draft)
    }

    private var fallbackCoordinate: DiveCoordinate? {
        switch boundSite {
        case .catalog(let site):
            DiveMapCoordinateResolver.coordinate(from: site)
        case .user(let site):
            DiveMapCoordinateResolver.coordinate(from: site)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                DiveSiteFormContent(
                    draft: $draft,
                    fallbackCoordinate: fallbackCoordinate,
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

        Task { @MainActor in
            do {
                switch boundSite {
                case .catalog(let site):
                    let previousLat = site.latCoords
                    let previousLon = site.longCoords
                    let parsed = DiveSiteFormValidation.parsedCoordinate(
                        latitudeText: draft.latitudeText,
                        longitudeText: draft.longitudeText
                    )
                    let coordsChanged = parsed?.latitude != previousLat || parsed?.longitude != previousLon
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
                case .user(let site):
                    let previousLat = site.latCoords
                    let previousLon = site.longCoords
                    let parsed = DiveSiteFormValidation.parsedCoordinate(
                        latitudeText: draft.latitudeText,
                        longitudeText: draft.longitudeText
                    )
                    let coordsChanged = parsed?.latitude != previousLat || parsed?.longitude != previousLon
                    try DiveActivitySiteAssociation.applyUserSiteEdits(
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
