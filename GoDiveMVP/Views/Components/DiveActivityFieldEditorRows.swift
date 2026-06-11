import SwiftUI

/// Form controls for one dive overview field (shared by single- and multi-field edit sheets).
struct DiveActivityFieldEditorRows: View {
    @Bindable var activity: DiveActivity
    let field: DiveActivityEditableFieldID
    @Binding var draft: DiveActivityFieldEditDraft
    let displayUnits: DiveDisplayUnitSystem

    var body: some View {
        switch DiveActivityFieldEditing.editorKind(for: field) {
        case .shortText:
            TextField("Value", text: $draft.text)
                .textInputAutocapitalization(.words)
        case .multilineText:
            TextEditor(text: $draft.text)
                .frame(minHeight: 160)
                .onChange(of: draft.text) { _, newValue in
                    if newValue.count > 2500 {
                        draft.text = String(newValue.prefix(2500))
                    }
                }
        case .integer, .decimal:
            TextField(unitHint, text: $draft.text)
                .keyboardType(.decimalPad)
        case .dateTime:
            DatePicker("Start", selection: Binding(
                get: { draft.dateValue ?? activity.startTime },
                set: { draft.dateValue = $0 }
            ), displayedComponents: [.date, .hourAndMinute])
        case .coordinate:
            TextField("Latitude", text: $draft.latitudeText)
                .keyboardType(.decimalPad)
            TextField("Longitude", text: $draft.longitudeText)
                .keyboardType(.decimalPad)
        case .diveNumber:
            Toggle("Hide dive number in logbook", isOn: $draft.hideDiveNumber)
            if !draft.hideDiveNumber {
                TextField("Dive number", text: $draft.text)
                    .keyboardType(.numberPad)
            }
        case .currentStrength:
            Picker("Current", selection: $draft.currentStrength) {
                ForEach(DiveCurrentStrength.allCases) { level in
                    Text(level.displayTitle).tag(level)
                }
            }
            .pickerStyle(.segmented)
        case .visibility:
            Picker("Visibility", selection: $draft.visibility) {
                Text("Not set").tag(DiveVisibilityRating?.none)
                ForEach(DiveVisibilityRating.allCases) { rating in
                    Text(rating.displayTitle).tag(Optional(rating))
                }
            }
            .pickerStyle(.segmented)
        case .source:
            Picker("Source", selection: $draft.source) {
                ForEach(DiveSource.allCases, id: \.self) { source in
                    Text(source.rawValue).tag(source)
                }
            }
        case .signature:
            DiveSignaturePadView(signatureData: $activity.diveSignatureData)
        case .readOnly:
            Text(DiveActivityFieldEditing.displayValue(
                for: field,
                activity: activity,
                displayUnits: displayUnits,
                profileGasStats: .init(sampleCount: 0, minPSI: nil, maxPSI: nil)
            ))
        case .buddies, .equipment, .linkedSite:
            EmptyView()
        }
    }

    private var unitHint: String {
        switch field {
        case .maxDepthMeters, .averageDepthMeters:
            return displayUnits == .metric ? "Meters" : "Feet"
        case .tankPressureStartPSI, .tankPressureEndPSI, .avgSAC:
            return displayUnits == .metric ? "Bar" : "PSI"
        case .waterTempAvgCelsius, .waterTempMaxCelsius, .waterTempMinCelsius:
            return displayUnits == .metric ? "°C" : "°F"
        case .avgAscentRateMetersPerSecond:
            return displayUnits == .metric ? "m/s" : "ft/min"
        case .avgRMV:
            return displayUnits == .metric ? "L/min" : "cu ft/min"
        case .oxygenMix:
            return "Percent O₂"
        default:
            return "Value"
        }
    }
}
