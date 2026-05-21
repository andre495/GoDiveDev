import SwiftData
import SwiftUI

struct ActivityUploadView: View {
    @Environment(\.modelContext) private var modelContext

    /// Called after a successful single-dive import (or bulk import of exactly one new dive).
    var onSuccessfulImport: ((UUID) -> Void)?
    /// Called after bulk UDDF import when more than one dive was inserted (returns to logbook without opening a dive).
    var onBulkImportComplete: (() -> Void)?

    @State private var isFileImporterPresented = false
    @State private var fileImporterMode: DiveFileImporterPresentation.PickerMode = .singleDive
    @State private var showBulkUddfOptionsSheet = false
    @State private var showsManualEntrySheet = false
    @State private var importOverlay: DiveImportOverlayState = .hidden
    @State private var bulkImportSummary: BulkUddfImportSummary?
    @State private var showBulkImportCompleteAlert = false
    @State private var presentBulkUddfImporterAfterOptionsSheet = false
    @State private var activeImportTask: Task<Void, Never>?
    @AppStorage(AppUserSettings.bulkUddfCreateDiveSitesKey) private var bulkCreateDiveSitesFromImport = true

    init(
        onSuccessfulImport: ((UUID) -> Void)? = nil,
        onBulkImportComplete: (() -> Void)? = nil
    ) {
        self.onSuccessfulImport = onSuccessfulImport
        self.onBulkImportComplete = onBulkImportComplete
    }

    var body: some View {
        AppPage(title: "Add activity", showsBackButton: true) {
            ZStack {
                VStack(spacing: AppTheme.Spacing.sm) {
                    addActivitySourcePanel(
                        title: "File upload",
                        subtitle: ".uddf or .fit",
                        systemImage: "doc.badge.arrow.up",
                        accessibilityIdentifier: "ActivityUpload.FileUpload"
                    ) {
                        presentFileImporter(mode: .singleDive)
                    }

                    addActivitySourcePanel(
                        title: "Manual entry",
                        systemImage: "square.and.pencil",
                        accessibilityIdentifier: "ActivityUpload.ManualEntry"
                    ) {
                        showsManualEntrySheet = true
                    }

                    addActivitySourceBulkPanel(
                        title: "Bulk upload UDDF dives",
                        subtitle: ".uddf with multiple dive records",
                        systemImage: "doc.on.doc",
                        accessibilityLabel: "Bulk upload UDDF dives. .uddf with multiple dive records",
                        accessibilityIdentifier: "ActivityUpload.BulkUddf"
                    ) {
                        showBulkUddfOptionsSheet = true
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.vertical, AppTheme.Spacing.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if importOverlay != .hidden {
                    diveImportProgressOverlay
                        .zIndex(1)
                }
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: fileImporterMode.allowedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleDiveFileImportResult(result, bulkUddf: fileImporterMode.isBulkUddf)
        }
        .onDisappear {
            activeImportTask?.cancel()
            activeImportTask = nil
            // Do not reset `isFileImporterPresented` here — that cancels the picker mid-presentation.
            if importOverlay.disablesSourceButtons {
                importOverlay = .hidden
            }
        }
        .sheet(isPresented: $showsManualEntrySheet) {
            ManualDiveEntrySheet { input in
                confirmManualDive(input)
            }
        }
        .sheet(isPresented: $showBulkUddfOptionsSheet, onDismiss: {
            if presentBulkUddfImporterAfterOptionsSheet {
                presentBulkUddfImporterAfterOptionsSheet = false
                presentFileImporter(mode: .bulkUddf)
            }
        }) {
            bulkUddfImportOptionsSheet
        }
        .alert("Import complete", isPresented: $showBulkImportCompleteAlert) {
            Button("OK", role: .cancel) {
                dismissBulkImportSummaryAndContinue()
            }
        } message: {
            if let bulkImportSummary {
                Text(BulkUddfImportSummary.message(for: bulkImportSummary))
            }
        }
        .hidesBottomTabBarWhenPushed()
    }

    @ViewBuilder
    private func addActivitySourcePanel(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: systemImage)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.accent)

                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(AppTheme.Spacing.md)
            .background { activitySourceTileBackground }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(importOverlay.disablesSourceButtons)
        .accessibilityLabel(subtitle.map { "\(title). \($0)" } ?? title)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    @ViewBuilder
    private func addActivitySourceBulkPanel(
        title: String,
        subtitle: String,
        systemImage: String,
        accessibilityLabel: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.accent)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.md)
            .frame(maxWidth: .infinity)
            .background { activitySourceTileBackground }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(importOverlay.disablesSourceButtons)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var activitySourceTileBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(AppTheme.Colors.surfaceElevated)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.Colors.tabUnselected.opacity(0.2), lineWidth: 1)
            }
    }

    private var bulkUddfImportOptionsSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                Text(
                    "You can import all of your UDDF dive records at once. If importing from MacDive, please first export the UDDF file to your phone's file system by selecting Settings > Export these dives to UDDF."
                )
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

                Toggle(isOn: $bulkCreateDiveSitesFromImport) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Create dive sites from import")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text("Adds new catalog sites for unmatched names and links dives to existing sites when they already match.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(AppTheme.Colors.accent)
                .accessibilityIdentifier("ActivityUpload.BulkUddf.CreateSitesToggle")

                Spacer(minLength: 0)

                Button("Choose UDDF file") {
                    presentBulkUddfImporterAfterOptionsSheet = true
                    showBulkUddfOptionsSheet = false
                }
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.md)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.Colors.accent)
                }
                .foregroundStyle(.white)
                .accessibilityIdentifier("ActivityUpload.BulkUddf.ChooseFile")
            }
            .padding(AppTheme.Spacing.lg)
            .navigationTitle("Bulk UDDF import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showBulkUddfOptionsSheet = false
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .appSheetPresentationChrome()
    }

    private var diveImportProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                switch importOverlay {
                case .hidden:
                    EmptyView()
                case .singleProgress(let progress, let stage):
                    Text("Importing dive")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    ProgressView(value: progress, total: 1.0)
                        .tint(AppTheme.Colors.accent)
                    Text(stage)
                        .font(.body)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                case .bulkProgress(let imported, let duplicates, let processed, let total, let stage):
                    Text("Bulk UDDF import")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    ProgressView(value: Double(processed), total: max(1, Double(total)))
                        .tint(AppTheme.Colors.accent)
                    Text("\(imported) of \(total) dives imported")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.linear(duration: 0.08), value: imported)
                    if duplicates > 0 {
                        Text("\(duplicates) duplicate dive\(duplicates == 1 ? "" : "s") found")
                            .font(.body.weight(.medium))
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .monospacedDigit()
                    }
                    if let stage {
                        Text(stage)
                            .font(.body)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                case .failed(let message):
                    Text("Import failed")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(message)
                        .font(.body)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Dismiss") {
                        importOverlay = .hidden
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.tabSelected)
                    .buttonStyle(.plain)
                    .padding(.top, AppTheme.Spacing.sm)
                }
            }
            .padding(AppTheme.Spacing.lg)
            .frame(maxWidth: 320, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.Colors.surfaceElevated)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.Colors.tabUnselected.opacity(0.15), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.28), radius: 14, y: 8)
            .accessibilityAddTraits(.isModal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// One **`.fileImporter`** per screen; set mode then present on the next run loop (matches bulk sheet timing).
    private func presentFileImporter(mode: DiveFileImporterPresentation.PickerMode) {
        fileImporterMode = mode
        isFileImporterPresented = false
        DispatchQueue.main.async {
            isFileImporterPresented = true
        }
    }

    private func handleDiveFileImportResult(_ result: Result<[URL], Error>, bulkUddf: Bool) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            beginImport(from: url, bulkUddf: bulkUddf)
        case .failure(let error):
            guard !DiveFileImporterPresentation.isUserCancellation(error) else { return }
            importOverlay = .failed(error.localizedDescription)
        }
    }

    private func beginImport(from url: URL, bulkUddf: Bool) {
        if bulkUddf {
            importOverlay = .bulkProgress(imported: 0, duplicates: 0, processed: 0, total: 0, stage: "Reading file…")
        } else {
            importOverlay = .singleProgress(0.05, "Importing dive…")
        }
        activeImportTask?.cancel()
        activeImportTask = Task(priority: .userInitiated) { @MainActor in
            await yieldForImportOverlayPaint()
            guard !Task.isCancelled else { return }
            if bulkUddf {
                await runBulkUddfImport(from: url)
            } else {
                await runDiveFileImport(from: url)
            }
        }
    }

    /// Lets SwiftUI commit **`importOverlay`** before blocking import work on the main actor.
    @MainActor
    private func yieldForImportOverlayPaint() async {
        await Task.yield()
        await Task.yield()
    }

    @MainActor
    private func confirmManualDive(_ input: ManualDiveEntryInput) {
        let activity = DiveActivityManualCreation.makeBlankActivity(from: input)
        let outcome = DiveActivityManualCreation.persist(activity, modelContext: modelContext)
        if let id = outcome.primaryInsertedDiveId {
            onSuccessfulImport?(id)
        } else {
            importOverlay = .failed(outcome.userMessage)
        }
    }

    @MainActor
    private func runDiveFileImport(from url: URL) async {
        defer { activeImportTask = nil }
        guard !Task.isCancelled else { return }
        do {
            let ext = url.pathExtension.lowercased()

            withAnimation(.easeInOut(duration: 0.15)) {
                importOverlay = .singleProgress(0.12, "Reading file…")
            }
            await yieldForImportOverlayPaint()

            let data = try await Task.detached(priority: .userInitiated) {
                if ext == "uddf" {
                    return try UddfDiveFileImport.readUddfFileData(from: url)
                }
                return try FitDiveFileImport.readFitFileData(from: url)
            }.value

            withAnimation(.easeInOut(duration: 0.2)) {
                importOverlay = .singleProgress(0.38, "Processing dive…")
            }
            await yieldForImportOverlayPaint()

            let outcome: DiveFileImportOutcome
            if ext == "uddf" {
                await yieldForImportOverlayPaint()
                let activities = try UddfDiveFileDecoder.buildDiveActivities(from: data)
                await yieldForImportOverlayPaint()
                outcome = await UddfDiveFileImport.persistImportedActivities(
                    activities,
                    modelContext: modelContext,
                    createMissingDiveSites: true
                )
            } else {
                await yieldForImportOverlayPaint()
                let activity = try FitDiveFileDecoder.buildDiveActivity(from: data)
                await yieldForImportOverlayPaint()
                outcome = FitDiveFileImport.persistImportedActivity(activity, modelContext: modelContext)
            }
            guard !Task.isCancelled else { return }
            await finishImport(outcome: outcome, isBulkUddf: false)
        } catch {
            guard !Task.isCancelled else { return }
            importOverlay = .failed(error.localizedDescription)
        }
    }

    @MainActor
    private func runBulkUddfImport(from url: URL) async {
        defer { activeImportTask = nil }
        guard !Task.isCancelled else { return }
        do {
            guard url.pathExtension.lowercased() == "uddf" else {
                importOverlay = .failed("Bulk import requires a .uddf file.")
                return
            }

            withAnimation(.easeInOut(duration: 0.15)) {
                importOverlay = .bulkProgress(imported: 0, duplicates: 0, processed: 0, total: 0, stage: "Reading file…")
            }

            let data = try await Task.detached(priority: .userInitiated) {
                try UddfDiveFileImport.readUddfFileData(from: url)
            }.value

            withAnimation(.easeInOut(duration: 0.15)) {
                importOverlay = .bulkProgress(imported: 0, duplicates: 0, processed: 0, total: 0, stage: "Parsing dives…")
            }
            await yieldForImportOverlayPaint()

            await yieldForImportOverlayPaint()
            let activities = try UddfDiveFileDecoder.buildDiveActivities(from: data)

            let total = activities.count
            guard total > 0 else {
                importOverlay = .failed(UddfDecodeError.noDives.localizedDescription)
                return
            }

            withAnimation(.easeInOut(duration: 0.15)) {
                importOverlay = .bulkProgress(imported: 0, duplicates: 0, processed: 0, total: total, stage: "Importing dives…")
            }
            await yieldForImportOverlayPaint()

            let outcome = await UddfDiveFileImport.persistImportedActivities(
                activities,
                modelContext: modelContext,
                createMissingDiveSites: bulkCreateDiveSitesFromImport,
                onProgress: { imported, duplicates, processed, _ in
                    importOverlay = .bulkProgress(
                        imported: imported,
                        duplicates: duplicates,
                        processed: processed,
                        total: total,
                        stage: "Importing dives…"
                    )
                }
            )
            await yieldForImportOverlayPaint()

            guard !Task.isCancelled else { return }
            await finishImport(outcome: outcome, isBulkUddf: true)
        } catch let uddf as UddfDecodeError {
            guard !Task.isCancelled else { return }
            importOverlay = .failed(uddf.localizedDescription)
        } catch {
            guard !Task.isCancelled else { return }
            importOverlay = .failed(error.localizedDescription)
        }
    }

    @MainActor
    private func finishImport(outcome: DiveFileImportOutcome, isBulkUddf: Bool) async {
        guard !Task.isCancelled else { return }
        if isBulkUddf, outcome.bulkImportFinishedWithCounts {
            importOverlay = .hidden
            bulkImportSummary = BulkUddfImportSummary(
                imported: outcome.insertedCount ?? 0,
                duplicates: outcome.skippedDuplicateCount ?? 0,
                diveSitesCreated: outcome.createdDiveSiteCount ?? 0,
                primaryInsertedDiveId: outcome.primaryInsertedDiveId
            )
            showBulkImportCompleteAlert = true
            return
        }

        if outcome.didSucceed {
            withAnimation(.easeInOut(duration: 0.2)) {
                importOverlay = .singleProgress(1.0, "Complete")
            }
            try? await Task.sleep(for: DiveImportSuccessTiming.sleepAfterCompleteBeforeDismiss)
            importOverlay = .hidden

            if let id = outcome.primaryInsertedDiveId {
                onSuccessfulImport?(id)
            }
        } else {
            importOverlay = .failed(outcome.userMessage)
        }
    }

    @MainActor
    private func dismissBulkImportSummaryAndContinue() {
        showBulkImportCompleteAlert = false
        guard let summary = bulkImportSummary else { return }
        bulkImportSummary = nil

        if summary.imported > 1 {
            onBulkImportComplete?()
        } else if summary.imported == 1, let id = summary.primaryInsertedDiveId {
            onSuccessfulImport?(id)
        } else {
            onBulkImportComplete?()
        }
    }
}

struct BulkUddfImportSummary: Equatable {
    let imported: Int
    let duplicates: Int
    let diveSitesCreated: Int
    let primaryInsertedDiveId: UUID?

    static func message(for summary: BulkUddfImportSummary) -> String {
        [
            "\(summary.imported) dive\(summary.imported == 1 ? "" : "s") imported",
            "\(summary.duplicates) duplicate dive\(summary.duplicates == 1 ? "" : "s") found",
            "\(summary.diveSitesCreated) dive site\(summary.diveSitesCreated == 1 ? "" : "s") created",
        ].joined(separator: "\n")
    }
}

private enum DiveImportOverlayState: Equatable {
    case hidden
    case singleProgress(Double, String)
    case bulkProgress(imported: Int, duplicates: Int, processed: Int, total: Int, stage: String?)
    case failed(String)

    /// Disables Add-activity tiles only while an import is actively running (not on failure).
    var disablesSourceButtons: Bool {
        switch self {
        case .hidden, .failed: return false
        case .singleProgress, .bulkProgress: return true
        }
    }
}

/// After **Complete**, keep the scrim up briefly so the success state reads before dismiss.
private enum DiveImportSuccessTiming {
    static let sleepAfterCompleteBeforeDismiss: Duration = .milliseconds(800)
}

#Preview {
    let schema = Schema([
        DiveActivity.self,
        DiveBuddyTag.self,
        DiveProfilePoint.self,
        DiveSite.self,
    ])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [configuration])
    return ActivityUploadView()
        .modelContainer(container)
}
