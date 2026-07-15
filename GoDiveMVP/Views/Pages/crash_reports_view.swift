import SwiftData
import SwiftUI

/// Settings → Crash Reports — locally captured crashes / abnormal exits with export + clear.
struct CrashReportsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var reports: [CrashReport] = []
    @State private var hasLoaded = false
    @State private var showsClearConfirmation = false

    var body: some View {
        AppPage(title: SettingsPresentation.CrashReports.title, showsBackButton: true) {
            content
        }
        .hidesBottomTabBarWhenPushed()
        .onAppear { CrashBreadcrumbTrail.noteScreen("crashReports") }
        .task { await reloadReports() }
    }

    @ViewBuilder
    private var content: some View {
        if !hasLoaded {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if reports.isEmpty {
            emptyState
        } else {
            reportList
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "checkmark.shield")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.Colors.accent)
            Text(SettingsPresentation.CrashReports.emptyStateMessage)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("CrashReports.EmptyState")
    }

    private var reportList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                actionRow

                ForEach(reports) { report in
                    NavigationLink {
                        CrashReportDetailView(report: report)
                    } label: {
                        reportRow(report)
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
            SettingsPresentation.CrashReports.clearConfirmationTitle,
            isPresented: $showsClearConfirmation,
            titleVisibility: .visible
        ) {
            Button(SettingsPresentation.CrashReports.clearButtonTitle, role: .destructive) {
                clearAllReports()
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ShareLink(item: CrashReportPresentation.exportText(for: reports)) {
                Label(SettingsPresentation.CrashReports.exportButtonTitle, systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.glass)
            .accessibilityIdentifier("CrashReports.ExportAll")

            Button(role: .destructive) {
                showsClearConfirmation = true
            } label: {
                Label(SettingsPresentation.CrashReports.clearButtonTitle, systemImage: "trash")
            }
            .buttonStyle(.glass)
            .accessibilityIdentifier("CrashReports.ClearAll")

            Spacer()
        }
    }

    private func reportRow(_ report: CrashReport) -> some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Text(CrashReportPresentation.kindLabel(report.kind))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(report.capturedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                Text(report.reason)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(2)
                Text(CrashReportPresentation.sharedStatusLabel(sharedToCloudAt: report.sharedToCloudAt))
                    .font(.caption)
                    .foregroundStyle(
                        report.sharedToCloudAt == nil
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

    private func reloadReports() async {
        let store = CrashReportStore(container: modelContext.container)
        let loaded = await Task.detached(priority: .userInitiated) {
            store.loadAll()
        }.value
        reports = loaded
        hasLoaded = true
    }

    private func clearAllReports() {
        reports = []
        let store = CrashReportStore(container: modelContext.container)
        Task.detached(priority: .utility) {
            store.deleteAll()
        }
    }
}

/// Full diagnostic body for one report, shareable on its own.
private struct CrashReportDetailView: View {
    let report: CrashReport

    var body: some View {
        AppPage(title: CrashReportPresentation.kindLabel(report.kind), showsBackButton: true) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    ShareLink(item: CrashReportPresentation.exportText(for: report)) {
                        Label(
                            SettingsPresentation.CrashReports.exportButtonTitle,
                            systemImage: "square.and.arrow.up"
                        )
                    }
                    .buttonStyle(.glass)
                    .accessibilityIdentifier("CrashReports.ExportOne")

                    Text(CrashReportPresentation.exportText(for: report))
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
        CrashReportsView()
    }
    .modelContainer(for: [CrashReportRecord.self], inMemory: true)
}
