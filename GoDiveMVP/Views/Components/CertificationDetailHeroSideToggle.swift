import SwiftUI

/// Compact front / back toggle on certification card heroes (mirrors **`PushedDetailHeroModeToggle`** chrome).
struct CertificationDetailHeroSideToggle: View {
    @Binding var selectedSide: CertificationDetailHeroSide
    var accessibilityIdentifierPrefix: String = "CertificationDetails.Hero.SideToggle"

    var body: some View {
        HStack(spacing: PushedDetailHeroModeTogglePresentation.segmentSpacing) {
            ForEach(CertificationDetailHeroSide.allCases) { side in
                segmentButton(for: side)
            }
        }
        .padding(PushedDetailHeroModeTogglePresentation.shellPadding)
        .glassEffect(
            .regular.interactive(),
            in: .rect(cornerRadius: PushedDetailHeroModeTogglePresentation.shellCornerRadius)
        )
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityIdentifierPrefix)
    }

    private func segmentButton(for side: CertificationDetailHeroSide) -> some View {
        let isSelected = selectedSide == side

        return Button {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selectedSide = side
            }
        } label: {
            Image(systemName: side.systemImage)
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
        .accessibilityLabel(side.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("\(accessibilityIdentifierPrefix).\(side.rawValue)")
    }
}
