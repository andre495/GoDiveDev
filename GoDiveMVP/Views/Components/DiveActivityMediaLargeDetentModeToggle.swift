import SwiftUI

/// Fish / buddy mode toggle on dive Media **large** detent — same chrome as pushed hero map/media toggle.
struct DiveActivityMediaLargeDetentModeToggle: View {
    @Binding var selectedMode: DiveActivityMediaLargeDetentMode

    var body: some View {
        HStack(spacing: PushedDetailHeroModeTogglePresentation.segmentSpacing) {
            ForEach(DiveActivityMediaLargeDetentMode.allCases) { mode in
                segmentButton(for: mode)
            }
        }
        .padding(PushedDetailHeroModeTogglePresentation.shellPadding)
        .glassEffect(
            .regular.interactive(),
            in: .rect(cornerRadius: PushedDetailHeroModeTogglePresentation.shellCornerRadius)
        )
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("DiveOverview.MediaLargeModeToggle")
    }

    private func segmentButton(for mode: DiveActivityMediaLargeDetentMode) -> some View {
        let isSelected = selectedMode == mode

        return Button {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selectedMode = mode
            }
        } label: {
            Image(systemName: mode.systemImage)
                .font(.body.weight(.semibold))
                .frame(
                    width: PushedDetailHeroModeTogglePresentation.segmentSize,
                    height: PushedDetailHeroModeTogglePresentation.segmentSize
                )
                .contentShape(Rectangle())
                .foregroundStyle(isSelected ? AppTheme.Colors.tabSelected : AppTheme.Colors.tabUnselected)
                .background {
                    if isSelected {
                        RoundedRectangle(
                            cornerRadius: PushedDetailHeroModeTogglePresentation.segmentCornerRadius,
                            style: .continuous
                        )
                        .fill(AppTheme.Colors.surfaceElevated.opacity(0.92))
                    }
                }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel(mode.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("DiveOverview.MediaLargeModeToggle.\(mode.rawValue)")
    }
}
