import SwiftUI

struct DiveDepthProfileScrubCalloutLabel: View {
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem

    let callout: DiveDepthProfileScrubCallout

    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(DiveDepthProfileChartAxisPresentation.scrubTimeLabel(
                elapsedSeconds: callout.elapsedSeconds
            ))
            Text(DiveDepthProfileChartAxisPresentation.scrubDepthLabel(
                depthMeters: callout.depthMeters,
                system: diveDisplayUnitSystem
            ))
            if let pressurePSI = callout.pressurePSI {
                Text("Pressure \(formattedPressure(pressurePSI))")
                    .foregroundStyle(AppTheme.Colors.tankGasAccent)
            }
        }
        .font(.caption.weight(.semibold).monospacedDigit())
        .foregroundStyle(AppTheme.Colors.textPrimary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.Colors.tabUnselected.opacity(0.25), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = [
            DiveDepthProfileChartAxisPresentation.scrubTimeLabel(
                elapsedSeconds: callout.elapsedSeconds
            ),
            DiveDepthProfileChartAxisPresentation.scrubDepthLabel(
                depthMeters: callout.depthMeters,
                system: diveDisplayUnitSystem
            ),
        ]
        if let pressurePSI = callout.pressurePSI {
            parts.append("Pressure \(formattedPressure(pressurePSI))")
        }
        return parts.joined(separator: ", ")
    }

    private func formattedPressure(_ psi: Double) -> String {
        DiveQuantityFormatting.cylinderPressure(fromPSI: psi, system: diveDisplayUnitSystem)
    }
}
