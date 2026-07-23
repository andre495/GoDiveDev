import SwiftUI

struct SnorkelActivityIconTabBar: View {
    @Binding var selection: SnorkelActivityTab
    let onSelect: (SnorkelActivityTab) -> Void

    var body: some View {
        HStack(spacing: DiveActivityTabBarPresentation.segmentSpacing) {
            ForEach(SnorkelActivityTab.allCases, id: \.self) { tab in
                segmentButton(for: tab)
            }
        }
        .padding(DiveActivityTabBarPresentation.shellPadding)
        .glassEffect(
            .regular.interactive(),
            in: .rect(cornerRadius: DiveActivityTabBarPresentation.shellCornerRadius)
        )
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("SnorkelActivity.IconTabs")
    }

    private func segmentButton(for tab: SnorkelActivityTab) -> some View {
        let isSelected = selection == tab

        return Button {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                onSelect(tab)
            }
        } label: {
            Image(systemName: tab.systemImageName)
                .font(.body.weight(.semibold))
                .frame(
                    width: DiveActivityTabBarPresentation.segmentSize,
                    height: DiveActivityTabBarPresentation.segmentSize
                )
                .contentShape(Rectangle())
                .foregroundStyle(isSelected ? AppTheme.Colors.tabSelected : AppTheme.Colors.tabUnselected)
                .background {
                    if isSelected {
                        RoundedRectangle(
                            cornerRadius: DiveActivityTabBarPresentation.segmentCornerRadius,
                            style: .continuous
                        )
                        .fill(AppTheme.Colors.surfaceElevated.opacity(0.92))
                    }
                }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel(tab.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("SnorkelActivity.IconTabs.\(tab.accessibilityIdentifierSuffix)")
    }
}
