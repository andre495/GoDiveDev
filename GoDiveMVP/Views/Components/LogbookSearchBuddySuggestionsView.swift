import SwiftUI

/// Suggested buddy filters under the logbook search field (oval outline buttons).
struct LogbookSearchBuddySuggestionsView: View {
    let suggestions: [LogbookBuddySearchSuggestion]
    let onSelect: (LogbookBuddySearchSuggestion) -> Void

    private let columns = [GridItem(.adaptive(minimum: 88), spacing: AppTheme.Spacing.sm)]

    var body: some View {
        LogbookBuddyFilterOutlinedSection(trailingHeader: { EmptyView() }) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: AppTheme.Spacing.sm) {
                ForEach(suggestions) { suggestion in
                    Button {
                        onSelect(suggestion)
                    } label: {
                        ActivityTagOvalChipLabel(title: suggestion.buddyName)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("Logbook.BuddySuggestion.\(suggestion.id)")
                    .accessibilityLabel("Filter by buddy \(suggestion.buddyName)")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Logbook.BuddySuggestions")
    }
}

/// Confirmed buddy filter with clear control inside the **Buddies** section card.
struct LogbookActiveBuddyFilterChip: View {
    let buddyName: String
    let onClear: () -> Void

    var body: some View {
        LogbookBuddyFilterOutlinedSection {
            Button("Clear", action: onClear)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabSelected)
        } content: {
            HStack(spacing: AppTheme.Spacing.sm) {
                ActivityTagOvalChipLabel(title: buddyName, isEmphasized: true)
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("Logbook.ActiveBuddyFilter")
        .accessibilityLabel("Filtering by buddy \(buddyName)")
    }
}

/// **Buddies** section header for logbook filter chips.
private struct LogbookBuddiesSectionHeader<Trailing: View>: View {
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "person.2")
                .font(.caption.weight(.semibold))
            Text("Buddies")
                .font(.caption.weight(.semibold))
            Spacer(minLength: AppTheme.Spacing.sm)
            trailing()
        }
        .foregroundStyle(AppTheme.Colors.tabUnselected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Buddies")
    }
}

/// Bordered **Buddies** section card (logbook search chrome).
private struct LogbookBuddyFilterOutlinedSection<Trailing: View, Content: View>: View {
    @ViewBuilder let trailingHeader: () -> Trailing
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            LogbookBuddiesSectionHeader(trailing: trailingHeader)
            content()
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.Colors.tabUnselected.opacity(0.12), lineWidth: 1)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.bottom, AppTheme.Spacing.sm)
    }
}
