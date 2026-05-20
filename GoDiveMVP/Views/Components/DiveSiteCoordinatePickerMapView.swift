import SwiftUI

/// Mini map for **`DiveSiteAddSheet`** — drag to position the site under the center pin.
struct DiveSiteCoordinatePickerMapView: View {
    @Binding var latitudeText: String
    @Binding var longitudeText: String
    var fallbackCoordinate: DiveCoordinate?

    @State private var mapCenter: DiveCoordinate
    @State private var isSyncingFromTextFields = false

    init(
        latitudeText: Binding<String>,
        longitudeText: Binding<String>,
        fallbackCoordinate: DiveCoordinate? = nil
    ) {
        _latitudeText = latitudeText
        _longitudeText = longitudeText
        self.fallbackCoordinate = fallbackCoordinate
        let initial = DiveSiteCoordinatePickerPresentation.initialCenter(
            latitudeText: latitudeText.wrappedValue,
            longitudeText: longitudeText.wrappedValue,
            fallback: fallbackCoordinate
        )
        _mapCenter = State(initialValue: initial)
    }

    var body: some View {
        Group {
            if GoDiveUITestConfiguration.isActive {
                pickerPlaceholder
            } else {
                livePicker
            }
        }
        .frame(height: Layout.mapHeight)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                .strokeBorder(AppTheme.Colors.tabUnselected.opacity(0.35), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Site location map")
        .accessibilityHint("Drag the map to set latitude and longitude")
        .accessibilityIdentifier("DiveSiteAddSheet.CoordinatePickerMap")
        .onAppear {
            let center = DiveSiteCoordinatePickerPresentation.initialCenter(
                latitudeText: latitudeText,
                longitudeText: longitudeText,
                fallback: fallbackCoordinate
            )
            mapCenter = center
            seedTextsIfEmpty(from: center)
        }
        .onChange(of: latitudeText) { _, _ in
            syncMapCenterFromTextFields()
        }
        .onChange(of: longitudeText) { _, _ in
            syncMapCenterFromTextFields()
        }
    }

    @ViewBuilder
    private var livePicker: some View {
        ZStack {
            #if canImport(UIKit)
            DiveSiteCoordinatePickerMapRepresentable(
                centerCoordinate: mapCenter,
                onCenterCoordinateChanged: applyCoordinateFromMap
            )
            #else
            Color.clear
            #endif

            DiveSiteMapPickerPinOverlay()
                .allowsHitTesting(false)
        }
    }

    private var pickerPlaceholder: some View {
        AppTheme.Colors.surfaceMuted
            .overlay {
                Image(systemName: "map")
                    .font(.title2)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
            }
    }

    private func applyCoordinateFromMap(_ coordinate: DiveCoordinate) {
        guard !isSyncingFromTextFields else { return }
        mapCenter = coordinate
        let formatted = DiveSiteCoordinatePickerPresentation.formattedTexts(for: coordinate)
        latitudeText = formatted.latitude
        longitudeText = formatted.longitude
    }

    private func syncMapCenterFromTextFields() {
        guard let parsed = DiveSiteFormValidation.parsedCoordinate(
            latitudeText: latitudeText,
            longitudeText: longitudeText
        ) else { return }
        guard parsed != mapCenter else { return }
        isSyncingFromTextFields = true
        mapCenter = parsed
        isSyncingFromTextFields = false
    }

    private func seedTextsIfEmpty(from coordinate: DiveCoordinate) {
        let latEmpty = latitudeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let lonEmpty = longitudeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard latEmpty || lonEmpty else { return }
        let formatted = DiveSiteCoordinatePickerPresentation.formattedTexts(for: coordinate)
        if latEmpty { latitudeText = formatted.latitude }
        if lonEmpty { longitudeText = formatted.longitude }
    }

    private enum Layout {
        static let mapHeight: CGFloat = 240
        static let cornerRadius: CGFloat = 12
    }
}

/// Center pin shown while the map moves underneath.
private struct DiveSiteMapPickerPinOverlay: View {
    var body: some View {
        VStack(spacing: 0) {
            DiveSiteMapPinView()
                .scaleEffect(1.12)
            Ellipse()
                .fill(AppTheme.Colors.accentDeep.opacity(0.28))
                .frame(width: 12, height: 5)
                .offset(y: -5)
        }
        .accessibilityHidden(true)
    }
}
