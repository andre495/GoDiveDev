import SwiftUI

/// Map-tab Notes card for snorkels — same elevated card + ⋯ edit pattern as dive map notes.
struct SnorkelActivityNotesOverviewSection: View {
    let notes: String?
    let onEditNotes: () -> Void

    private var displayBody: String {
        ActivityNotesPresentation.displayValue(notes: notes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            sectionHeader

            Button(action: onEditNotes) {
                DiveActivityEditableRow(
                    label: ActivityNotesPresentation.sectionTitle,
                    value: displayBody,
                    showsLabel: false
                )
                .padding(AppTheme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.Colors.surfaceElevated)
                }
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Edits snorkel notes")
            .accessibilityIdentifier("SnorkelOverview.NotesCard")
        }
        .accessibilityIdentifier("SnorkelOverview.NotesSection")
    }

    private var sectionHeader: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            Text(ActivityNotesPresentation.sectionTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabUnselected)

            Spacer(minLength: AppTheme.Spacing.sm)

            DiveActivitySectionHeaderActionButton(
                systemImage: "ellipsis",
                accessibilityLabel: "Edit Notes"
            ) {
                onEditNotes()
            }
            .accessibilityIdentifier("SnorkelOverview.Notes.Edit")
        }
    }
}
