import SwiftData
import SwiftUI

/// Settings → Diagnostic Events — local security / auth / import journal with export + clear.
struct SecurityEventsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountSession.self) private var accountSession
    @State private var events: [SecurityEvent] = []
    @State private var hasLoaded = false
    @State private var showsClearConfirmation = false

    var body: some View {
        AppPage(title: SettingsPresentation.SecurityEvents.title, showsBackButton: true) {
            content
        }
        .hidesBottomTabBarWhenPushed()
        .onAppear { CrashBreadcrumbTrail.noteScreen("securityEvents") }
        .task { await reloadEvents() }
    }

    @ViewBuilder
    private var content: some View {
        if !hasLoaded {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if events.isEmpty {
            emptyState
        } else {
            eventList
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "checkmark.shield")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.Colors.accent)
            Text(SettingsPresentation.SecurityEvents.emptyStateMessage)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("SecurityEvents.EmptyState")
    }

    private var eventList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                actionRow

                ForEach(events) { event in
                    NavigationLink {
                        SecurityEventDetailView(event: event)
                    } label: {
                        eventRow(event)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.top, AppTheme.Spacing.md)
            .padding(.bottom, AppTheme.Spacing.lg)
        }
        .scrollIndicators(.hidden)
        .confirmationDialog(
            SettingsPresentation.SecurityEvents.clearConfirmationTitle,
            isPresented: $showsClearConfirmation,
            titleVisibility: .visible
        ) {
            Button(SettingsPresentation.SecurityEvents.clearButtonTitle, role: .destructive) {
                clearAllEvents()
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ShareLink(item: SecurityEventPresentation.exportText(for: events)) {
                Label(SettingsPresentation.SecurityEvents.exportButtonTitle, systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.glass)
            .accessibilityIdentifier("SecurityEvents.ExportAll")

            Button(role: .destructive) {
                showsClearConfirmation = true
            } label: {
                Label(SettingsPresentation.SecurityEvents.clearButtonTitle, systemImage: "trash")
            }
            .buttonStyle(.glass)
            .accessibilityIdentifier("SecurityEvents.ClearAll")

            Spacer()
        }
    }

    private func eventRow(_ event: SecurityEvent) -> some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Text(SecurityEventPresentation.kindLabel(event.kindRaw))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(event.capturedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                if let detail = event.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .lineLimit(2)
                }
                Text(SecurityEventPresentation.sharedStatusLabel(sharedToCloudAt: event.sharedToCloudAt))
                    .font(.caption)
                    .foregroundStyle(
                        event.sharedToCloudAt == nil
                            ? AppTheme.Colors.secondaryText
                            : AppTheme.Colors.accent
                    )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabUnselected)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func reloadEvents() async {
        let ownerID = accountSession.currentProfile?.id
        let store = SecurityEventStore(container: modelContext.container)
        let loaded = await Task.detached(priority: .userInitiated) {
            store.loadAll(ownerProfileID: ownerID)
        }.value
        events = loaded
        hasLoaded = true
    }

    private func clearAllEvents() {
        let ownerID = accountSession.currentProfile?.id
        events = []
        let store = SecurityEventStore(container: modelContext.container)
        Task.detached(priority: .utility) {
            store.deleteAll(ownerProfileID: ownerID)
        }
    }
}

private struct SecurityEventDetailView: View {
    let event: SecurityEvent

    var body: some View {
        AppPage(title: SecurityEventPresentation.kindLabel(event.kindRaw), showsBackButton: true) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    ShareLink(item: SecurityEventPresentation.exportText(for: event)) {
                        Label(
                            SettingsPresentation.SecurityEvents.exportButtonTitle,
                            systemImage: "square.and.arrow.up"
                        )
                    }
                    .buttonStyle(.glass)
                    .accessibilityIdentifier("SecurityEvents.ExportOne")

                    Text(SecurityEventPresentation.exportText(for: event))
                        .font(.caption.monospaced())
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.vertical, AppTheme.Spacing.md)
            }
            .scrollIndicators(.hidden)
        }
        .hidesBottomTabBarWhenPushed()
    }
}

#Preview {
    NavigationStack {
        SecurityEventsView()
    }
    .environment(AccountSession.shared)
    .modelContainer(for: [SecurityEventRecord.self], inMemory: true)
}
