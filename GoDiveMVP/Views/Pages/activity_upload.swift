import SwiftData
import SwiftUI

struct ActivityUploadView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountSession.self) private var accountSession

    /// Called after a successful FIT import (or UDDF import of exactly one new dive).
    var onSuccessfulImport: ((UUID) -> Void)?
    /// Called after a UDDF import when more than one dive was inserted (returns to logbook without opening a dive).
    var onBulkImportComplete: (() -> Void)?

    @State private var isFileImporterPresented = false
    @State private var fileImporterMode: DiveFileImporterPresentation.PickerMode = .fit
    @State private var showImportOptionsSheet = false
    /// Which file type the options sheet is configuring (drives copy + which picker opens after dismiss).
    @State private var importOptionsMode: DiveFileImporterPresentation.PickerMode = .uddf
    @State private var showsManualEntrySheet = false
    @State private var importOverlay: DiveImportOverlayState = .hidden
    @State private var uddfImportSummary: UddfImportSummary?
    @State private var showUddfImportCompleteAlert = false
    @State private var presentImporterAfterOptionsSheet = false
    @State private var activeImportTask: Task<Void, Never>?
    @AppStorage(AppUserSettings.bulkUddfCreateDiveSitesKey) private var importCreateDiveSitesFromImport = true
    @State private var importAttachMediaFromPhotoLibrary = false

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
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                        addActivityIntro

                        addActivitySection(title: "Import from a file") {
                            addActivitySourceCard(
                                title: "Garmin FIT",
                                subtitle: "A single dive from your Garmin dive computer.",
                                tag: ".fit",
                                systemImage: "doc.badge.arrow.up",
                                accessibilityIdentifier: "ActivityUpload.FileUpload"
                            ) {
                                importOptionsMode = .fit
                                showImportOptionsSheet = true
                            }

                            addActivitySourceCard(
                                title: "UDDF",
                                subtitle: "One or many dives, e.g. exported from MacDive.",
                                tag: ".uddf",
                                systemImage: "doc.on.doc",
                                accessibilityIdentifier: "ActivityUpload.BulkUddf"
                            ) {
                                importOptionsMode = .uddf
                                showImportOptionsSheet = true
                            }
                        }

                        addActivitySection(title: "Add it yourself") {
                            addActivitySourceCard(
                                title: "Manual entry",
                                subtitle: "Type in your dive details by hand.",
                                tag: nil,
                                systemImage: "square.and.pencil",
                                accessibilityIdentifier: "ActivityUpload.ManualEntry"
                            ) {
                                showsManualEntrySheet = true
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.vertical, AppTheme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

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
            handleDiveFileImportResult(result)
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
        .sheet(isPresented: $showImportOptionsSheet, onDismiss: {
            if presentImporterAfterOptionsSheet {
                presentImporterAfterOptionsSheet = false
                presentFileImporter(mode: importOptionsMode)
            }
        }) {
            importOptionsSheet
        }
        .alert("Import complete", isPresented: $showUddfImportCompleteAlert) {
            Button("OK", role: .cancel) {
                dismissUddfImportSummaryAndContinue()
            }
        } message: {
            if let uddfImportSummary {
                Text(UddfImportSummary.message(for: uddfImportSummary))
            }
        }
        .hidesBottomTabBarWhenPushed()
    }

    private var addActivityIntro: some View {
        Text("Import a dive from your computer, or add the details yourself.")
            .font(.subheadline)
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func addActivitySection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(AppTheme.Colors.mutedText)
                .padding(.leading, 4)

            VStack(spacing: AppTheme.Spacing.md) {
                content()
            }
        }
    }

    @ViewBuilder
    private func addActivitySourceCard(
        title: String,
        subtitle: String,
        tag: String?,
        systemImage: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.md) {
                sourceIconBadge(systemImage: systemImage)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Text(title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)

                        if let tag {
                            sourceFileTypeTag(tag)
                        }
                    }

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: AppTheme.Spacing.sm)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
            }
            .padding(AppTheme.Spacing.md)
            .frame(maxWidth: .infinity)
            .background { activitySourceTileBackground }
            .contentShape(Rectangle())
        }
        .buttonStyle(AddActivityCardButtonStyle())
        .disabled(importOverlay.disablesSourceButtons)
        .accessibilityLabel(tag.map { "\(title). \($0). \(subtitle)" } ?? "\(title). \(subtitle)")
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func sourceIconBadge(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 52, height: 52)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.Colors.accent,
                                AppTheme.Colors.accent.opacity(0.78),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .shadow(color: AppTheme.Colors.accent.opacity(0.28), radius: 6, y: 3)
    }

    private func sourceFileTypeTag(_ tag: String) -> some View {
        Text(tag)
            .font(.caption2.weight(.semibold))
            .monospaced()
            .foregroundStyle(AppTheme.Colors.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background {
                Capsule(style: .continuous)
                    .fill(AppTheme.Colors.accent.opacity(0.12))
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(AppTheme.Colors.accent.opacity(0.25), lineWidth: 1)
            }
    }

    private var activitySourceTileBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(AppTheme.Colors.surfaceElevated)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.Colors.tabUnselected.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }

    private var importOptionsSheet: some View {
        let isUddf = importOptionsMode.isUddf
        let idPrefix = isUddf ? "ActivityUpload.BulkUddf" : "ActivityUpload.FitImport"

        return NavigationStack {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                Text(
                    isUddf
                        ? "Import one or all of your UDDF dive records at once. If importing from MacDive, please first export the UDDF file to your phone's file system by selecting Settings > Export these dives to UDDF."
                        : "Import a single dive from a Garmin .fit file exported from your dive computer."
                )
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

                Toggle(isOn: $importCreateDiveSitesFromImport) {
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
                .accessibilityIdentifier("\(idPrefix).CreateSitesToggle")

                Toggle(isOn: $importAttachMediaFromPhotoLibrary) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(SettingsPresentation.BulkUddfImport.attachMediaTitle)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text(SettingsPresentation.BulkUddfImport.attachMediaSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(AppTheme.Colors.accent)
                .accessibilityIdentifier("\(idPrefix).AttachMediaToggle")

                Spacer(minLength: 0)

                Button(isUddf ? "Choose UDDF file" : "Choose FIT file") {
                    presentImporterAfterOptionsSheet = true
                    showImportOptionsSheet = false
                }
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.md)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.Colors.accent)
                }
                .foregroundStyle(.white)
                .accessibilityIdentifier("\(idPrefix).ChooseFile")
            }
            .padding(AppTheme.Spacing.lg)
            .navigationTitle(isUddf ? "UDDF import" : "Garmin FIT import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showImportOptionsSheet = false
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .appSheetPresentationChrome()
        .onAppear {
            importAttachMediaFromPhotoLibrary = AppUserSettings.autoUploadMediaToActivities
        }
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
                case .importing(let milestone, let fraction):
                    ProgressView(value: fraction, total: 1.0)
                        .tint(AppTheme.Colors.accent)
                        .animation(.easeInOut(duration: 0.2), value: fraction)
                    Text(milestone.label)
                        .font(.body)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: milestone)
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

    /// One **`.fileImporter`** per screen; set mode then present on the next run loop (matches UDDF sheet timing).
    private func presentFileImporter(mode: DiveFileImporterPresentation.PickerMode) {
        fileImporterMode = mode
        isFileImporterPresented = false
        DispatchQueue.main.async {
            isFileImporterPresented = true
        }
    }

    private func handleDiveFileImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            beginImport(from: url)
        case .failure(let error):
            guard !DiveFileImporterPresentation.isUserCancellation(error) else { return }
            importOverlay = .failed(error.localizedDescription)
        }
    }

    /// UDDF (one or many dives) always uses the consolidated UDDF import; everything else is treated as Garmin FIT.
    private func beginImport(from url: URL) {
        let isUddf = url.pathExtension.lowercased() == "uddf"
        importOverlay = .start(.readingFile)
        activeImportTask?.cancel()
        activeImportTask = Task(priority: .userInitiated) { @MainActor in
            await yieldForImportOverlayPaint()
            guard !Task.isCancelled else { return }
            if isUddf {
                await runUddfImport(from: url)
            } else {
                await runFitImport(from: url)
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
            if let ownerID = accountSession.currentProfile?.id {
                Task { @MainActor in
                    await DiveLibraryMediaAutoAttachScheduler.attachAfterDivePersisted(
                        activity,
                        ownerProfileID: ownerID,
                        modelContext: modelContext
                    )
                }
            }
            onSuccessfulImport?(id)
        } else {
            importOverlay = .failed(outcome.userMessage)
        }
    }

    @MainActor
    private func runFitImport(from url: URL) async {
        defer { activeImportTask = nil }
        guard !Task.isCancelled else { return }
        do {
            withAnimation(.easeInOut(duration: 0.15)) {
                importOverlay = .start(.readingFile)
            }
            await yieldForImportOverlayPaint()

            let data = try await Task.detached(priority: .userInitiated) {
                try FitDiveFileImport.readFitFileData(from: url)
            }.value

            withAnimation(.easeInOut(duration: 0.2)) {
                importOverlay = .start(.creatingDiveLogs)
            }
            await yieldForImportOverlayPaint()

            let activity = try FitDiveFileDecoder.buildDiveActivity(from: data)
            await yieldForImportOverlayPaint()
            let outcome = await FitDiveFileImport.persistImportedActivity(
                activity,
                modelContext: modelContext,
                attachMedia: false,
                createMissingDiveSites: importCreateDiveSitesFromImport
            )

            guard !Task.isCancelled else { return }

            if outcome.didSucceed, importAttachMediaFromPhotoLibrary, let ownerID = accountSession.currentProfile?.id {
                withAnimation(.easeInOut(duration: 0.2)) {
                    importOverlay = .start(.addingMedia)
                }
                await yieldForImportOverlayPaint()
                await DiveLibraryMediaAutoAttachScheduler.attachAfterDivePersisted(
                    activity,
                    ownerProfileID: ownerID,
                    modelContext: modelContext,
                    attachMediaFromPhotoLibrary: true
                )
            }

            guard !Task.isCancelled else { return }
            await finishImport(outcome: outcome, isUddf: false)
        } catch {
            guard !Task.isCancelled else { return }
            importOverlay = .failed(error.localizedDescription)
        }
    }

    @MainActor
    private func runUddfImport(from url: URL) async {
        defer { activeImportTask = nil }
        guard !Task.isCancelled else { return }
        do {
            guard url.pathExtension.lowercased() == "uddf" else {
                importOverlay = .failed("Bulk import requires a .uddf file.")
                return
            }

            withAnimation(.easeInOut(duration: 0.15)) {
                importOverlay = .start(.readingFile)
            }

            let data = try await Task.detached(priority: .userInitiated) {
                try UddfDiveFileImport.readUddfFileData(from: url)
            }.value

            await yieldForImportOverlayPaint()
            let activities = try UddfDiveFileDecoder.buildDiveActivities(from: data)

            let total = activities.count
            guard total > 0 else {
                importOverlay = .failed(UddfDecodeError.noDives.localizedDescription)
                return
            }

            withAnimation(.easeInOut(duration: 0.15)) {
                importOverlay = .start(.creatingDiveLogs)
            }
            await yieldForImportOverlayPaint()

            let outcome = await UddfDiveFileImport.persistImportedActivities(
                activities,
                modelContext: modelContext,
                createMissingDiveSites: importCreateDiveSitesFromImport,
                attachMediaFromPhotoLibrary: importAttachMediaFromPhotoLibrary,
                onProgress: { _, _, processed, _ in
                    importOverlay = .importing(
                        milestone: .creatingDiveLogs,
                        fraction: DiveImportMilestone.creatingDiveLogs.fraction(completed: processed, total: total)
                    )
                },
                onMediaAttachProgress: { update in
                    importOverlay = .importing(
                        milestone: .addingMedia,
                        fraction: DiveImportMilestone.addingMedia.fraction(completed: update.completed, total: update.total)
                    )
                }
            )
            await yieldForImportOverlayPaint()

            guard !Task.isCancelled else { return }
            await finishImport(outcome: outcome, isUddf: true)
        } catch let uddf as UddfDecodeError {
            guard !Task.isCancelled else { return }
            importOverlay = .failed(uddf.localizedDescription)
        } catch {
            guard !Task.isCancelled else { return }
            importOverlay = .failed(error.localizedDescription)
        }
    }

    @MainActor
    private func finishImport(outcome: DiveFileImportOutcome, isUddf: Bool) async {
        guard !Task.isCancelled else { return }
        if isUddf, outcome.bulkImportFinishedWithCounts {
            importOverlay = .hidden
            uddfImportSummary = UddfImportSummary(
                imported: outcome.insertedCount ?? 0,
                duplicates: outcome.skippedDuplicateCount ?? 0,
                diveSitesCreated: outcome.createdDiveSiteCount ?? 0,
                primaryInsertedDiveId: outcome.primaryInsertedDiveId
            )
            showUddfImportCompleteAlert = true
            return
        }

        if outcome.didSucceed {
            withAnimation(.easeInOut(duration: 0.2)) {
                importOverlay = .importing(milestone: .addingMedia, fraction: 1.0)
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
    private func dismissUddfImportSummaryAndContinue() {
        showUddfImportCompleteAlert = false
        guard let summary = uddfImportSummary else { return }
        uddfImportSummary = nil

        if summary.imported > 1 {
            onBulkImportComplete?()
        } else if summary.imported == 1, let id = summary.primaryInsertedDiveId {
            onSuccessfulImport?(id)
        } else {
            onBulkImportComplete?()
        }
    }
}

struct UddfImportSummary: Equatable {
    let imported: Int
    let duplicates: Int
    let diveSitesCreated: Int
    let primaryInsertedDiveId: UUID?

    static func message(for summary: UddfImportSummary) -> String {
        [
            "\(summary.imported) dive\(summary.imported == 1 ? "" : "s") imported",
            "\(summary.duplicates) duplicate dive\(summary.duplicates == 1 ? "" : "s") found",
            "\(summary.diveSitesCreated) dive site\(summary.diveSitesCreated == 1 ? "" : "s") created",
        ].joined(separator: "\n")
    }
}

/// The three user-facing milestones shown in the simplified import dialog.
enum DiveImportMilestone: Equatable {
    case readingFile
    case creatingDiveLogs
    case addingMedia

    var label: String {
        switch self {
        case .readingFile: return "Reading File"
        case .creatingDiveLogs: return "Creating Dive Logs"
        case .addingMedia: return "Adding Media"
        }
    }

    /// Bar position when the milestone begins.
    var startFraction: Double {
        switch self {
        case .readingFile: return 0.05
        case .creatingDiveLogs: return 0.30
        case .addingMedia: return 0.75
        }
    }

    /// Bar position when the milestone finishes (where the next one begins).
    var endFraction: Double {
        switch self {
        case .readingFile: return 0.30
        case .creatingDiveLogs: return 0.75
        case .addingMedia: return 1.0
        }
    }

    /// Interpolated bar value for `completed` of `total` units of work inside the milestone.
    func fraction(completed: Int, total: Int) -> Double {
        guard total > 0 else { return startFraction }
        let ratio = min(1, max(0, Double(completed) / Double(total)))
        return startFraction + (endFraction - startFraction) * ratio
    }
}

private enum DiveImportOverlayState: Equatable {
    case hidden
    case importing(milestone: DiveImportMilestone, fraction: Double)
    case failed(String)

    /// Enters a milestone at its starting bar position.
    static func start(_ milestone: DiveImportMilestone) -> DiveImportOverlayState {
        .importing(milestone: milestone, fraction: milestone.startFraction)
    }

    /// Disables Add-activity tiles only while an import is actively running (not on failure).
    var disablesSourceButtons: Bool {
        switch self {
        case .hidden, .failed: return false
        case .importing: return true
        }
    }
}

/// Subtle press feedback for the Add-activity source cards (scale + dim on touch).
private struct AddActivityCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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
