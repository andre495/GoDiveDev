import SwiftUI

extension DiveActivityTab {
    @ViewBuilder
    var segmentedPickerLabel: some View {
        if let asset = assetImageName {
            DiveActivityTabAssetSegmentLabel(assetName: asset)
        } else if let system = systemImageName {
            Image(systemName: system)
                .font(.body.weight(.semibold))
        }
    }
}

/// Custom map / tank / media tab strip — avoids **`UISegmentedControl`** relayout glitches when the overview sheet detent animates.
struct DiveActivityIconTabBar: View {
    @Binding var selection: DiveActivityTab
    let onSelect: (DiveActivityTab) -> Void

    var body: some View {
        HStack(spacing: DiveActivityTabBarPresentation.segmentSpacing) {
            ForEach(DiveActivityTab.allCases, id: \.self) { tab in
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
        .accessibilityIdentifier("DiveActivity.IconTabs")
    }

    private func segmentButton(for tab: DiveActivityTab) -> some View {
        let isSelected = selection == tab

        return Button {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                onSelect(tab)
            }
        } label: {
            tab.segmentedPickerLabel
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
        .accessibilityIdentifier("DiveActivity.IconTabs.\(tab.accessibilityIdentifierSuffix)")
    }
}

enum DiveActivityTabBarPresentation {
    static let segmentSize: CGFloat = AppToolbarIconButtonMetrics.tapDimension
    static let segmentSpacing: CGFloat = 4
    static let shellPadding: CGFloat = 4
    static let shellCornerRadius: CGFloat = 12
    static let segmentCornerRadius: CGFloat = 10

    /// Intrinsic width — icon-only segments (**`PushedDetailHeroModeToggle`**-style), not full-bleed.
    static var chromeWidth: CGFloat {
        let tabCount = CGFloat(DiveActivityTab.allCases.count)
        return shellPadding * 2
            + segmentSize * tabCount
            + segmentSpacing * max(tabCount - 1, 0)
    }
}

/// Template asset label for dive overview segmented tabs — fixed aspect ratio, does not fill the segment cell.
private struct DiveActivityTabAssetSegmentLabel: View {
    let assetName: String

    var body: some View {
        let size = DiveActivityTabIcon.segmentLabelSize(for: assetName)
        Image(assetName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size.width, height: size.height)
            .fixedSize(horizontal: true, vertical: true)
    }
}

enum DiveActivityTabIcon {
    /// Matches **`AppToolbarIconButtonMetrics.tapDimension`** — dive overview top chrome row.
    static var menuRowHeight: CGFloat { AppToolbarIconButtonMetrics.tapDimension }

    /// Matches **`Image(systemName:)`** with **`.font(.system(size:weight:))`**.
    nonisolated static let tabGlyphPointSize: CGFloat = 22

    /// **`ScubaTankTab`** reads larger than SF Symbols at the same cap height — size down for glass segmented tabs.
    nonisolated static let scubaTankTabGlyphHeight: CGFloat = 16

    /// Trimmed **`ScubaTankTab.png`** pixel size (**1×** catalog art).
    nonisolated static let scubaTankTabAssetPixelSize = CGSize(width: 35, height: 72)

    /// Pixel width ÷ height — must match **`ScubaTankTab`** asset art.
    nonisolated static var scubaTankTabAspectWidthOverHeight: CGFloat {
        scubaTankTabAssetPixelSize.width / scubaTankTabAssetPixelSize.height
    }

    nonisolated static func segmentLabelSize(for assetName: String) -> CGSize {
        switch assetName {
        case "ScubaTankTab":
            return scaledAssetSize(
                assetPixelSize: scubaTankTabAssetPixelSize,
                targetHeight: scubaTankTabGlyphHeight
            )
        default:
            let side = tabGlyphPointSize
            return CGSize(width: side, height: side)
        }
    }

    /// Tab-bar frame for a template asset (alias of **`segmentLabelSize`**).
    nonisolated static func templateAssetSize(for assetName: String) -> CGSize {
        segmentLabelSize(for: assetName)
    }

    /// Uniform scale from catalog pixels so aspect ratio is preserved at any target height.
    nonisolated static func scaledAssetSize(
        assetPixelSize: CGSize,
        targetHeight: CGFloat
    ) -> CGSize {
        guard assetPixelSize.height > 0 else { return .zero }
        let scale = targetHeight / assetPixelSize.height
        return CGSize(
            width: assetPixelSize.width * scale,
            height: assetPixelSize.height * scale
        )
    }
}
