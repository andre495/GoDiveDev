import SwiftUI

/// Compact **All / Together** glass toggle for friend-profile shared activities
/// (same chrome as **`ExploreSiteScopeToggle`** / **`LogbookFeedScopeToggle`**).
struct FriendProfileActivityFilterToggle: View {
    @Binding var selection: FriendProfileActivityListFilter

    private let segmentCornerRadius: CGFloat = 8
    private let shellCornerRadius: CGFloat = 12

    var body: some View {
        HStack(spacing: 4) {
            ForEach(FriendProfileActivityListFilter.allCases) { filter in
                segmentButton(for: filter)
            }
        }
        .padding(4)
        .glassEffect(.regular, in: .rect(cornerRadius: shellCornerRadius))
        .contentShape(Rectangle())
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Shared activity filter")
        .accessibilityIdentifier(
            FriendProfileContentPagerPresentation.activityFilterAccessibilityIdentifier
        )
    }

    private func segmentButton(for filter: FriendProfileActivityListFilter) -> some View {
        let isSelected = selection == filter

        return Button {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selection = filter
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: filter.systemImage)
                    .font(.caption.weight(.semibold))
                Text(filter.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .contentShape(Rectangle())
            .foregroundStyle(isSelected ? AppTheme.Colors.tabSelected : AppTheme.Colors.tabUnselected)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: segmentCornerRadius, style: .continuous)
                        .fill(AppTheme.Colors.surfaceElevated.opacity(0.92))
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel(filter.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(
            "\(FriendProfileContentPagerPresentation.activityFilterAccessibilityIdentifier).\(filter.rawValue)"
        )
    }
}
