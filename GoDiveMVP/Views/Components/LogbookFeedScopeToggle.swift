import SwiftUI

/// **My Activities / Buddy Feed** control for Activity Log — matches **`ExploreSiteScopeToggle`** chrome.
struct LogbookFeedScopeToggle: View {
    @Binding var selection: LogbookFeedScope

    private let segmentCornerRadius: CGFloat = 8
    private let shellCornerRadius: CGFloat = 12

    var body: some View {
        HStack(spacing: 4) {
            ForEach(LogbookFeedScope.allCases) { scope in
                segmentButton(for: scope)
            }
        }
        .padding(4)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: shellCornerRadius))
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Activity log feed scope")
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
            HStack(spacing: 6) {
                Image(systemName: scope.systemImage)
                    .font(.caption.weight(.semibold))
                Text(scope.segmentTitle)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .foregroundStyle(isSelected ? AppTheme.Colors.tabSelected : AppTheme.Colors.tabUnselected)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: segmentCornerRadius, style: .continuous)
                        .fill(AppTheme.Colors.surfaceElevated.opacity(0.92))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(scope.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("Logbook.FeedScope.\(scope.rawValue)")
    }
}
