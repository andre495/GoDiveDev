import SwiftUI

/// **Me / Buddies** control for Activity Log — equal-width segments in a Liquid Glass shell
/// (same chrome pattern as **`ExploreSiteScopeToggle`** / dive icon tabs).
struct LogbookFeedScopeToggle: View {
    @Binding var selection: LogbookFeedScope

    private var equalSegmentWidth: CGFloat {
        LogbookFeedScopeTogglePresentation.equalSegmentWidth()
    }

    var body: some View {
        HStack(spacing: LogbookFeedScopeTogglePresentation.interSegmentSpacing) {
            ForEach(LogbookFeedScope.allCases) { scope in
                segmentButton(for: scope)
            }
        }
        .padding(LogbookFeedScopeTogglePresentation.shellPadding)
        // Non-interactive glass: `.interactive()` on a plain-Button shell steals taps.
        .glassEffect(
            .regular,
            in: .rect(cornerRadius: LogbookFeedScopeTogglePresentation.shellCornerRadius)
        )
        .contentShape(Rectangle())
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Activity log feed scope")
        .accessibilityHint("Swipe left or right on the activity list to switch between Me and Buddies")
        .accessibilityIdentifier(LogbookBuddyFeedPresentation.scopePickerAccessibilityIdentifier)
    }

    private func segmentButton(for scope: LogbookFeedScope) -> some View {
        let isSelected = selection == scope

        return Button {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selection = scope
            }
        } label: {
            HStack(spacing: LogbookFeedScopeTogglePresentation.iconTitleSpacing) {
                Image(systemName: scope.systemImage)
                    .font(.caption.weight(.semibold))
                Text(scope.segmentTitle)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, LogbookFeedScopeTogglePresentation.segmentHorizontalPadding)
            .frame(
                width: equalSegmentWidth,
                height: LogbookFeedScopeTogglePresentation.segmentHeight,
                alignment: .center
            )
            .contentShape(Rectangle())
            .foregroundStyle(isSelected ? AppTheme.Colors.tabSelected : AppTheme.Colors.tabUnselected)
            .background {
                if isSelected {
                    RoundedRectangle(
                        cornerRadius: LogbookFeedScopeTogglePresentation.segmentCornerRadius,
                        style: .continuous
                    )
                    .fill(AppTheme.Colors.surfaceElevated.opacity(0.92))
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel(scope.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("Logbook.FeedScope.\(scope.rawValue)")
    }
}
