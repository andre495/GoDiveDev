import SwiftData
import SwiftUI

struct SnorkelActivityUploadView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountSession.self) private var accountSession

    var onSuccessfulImport: ((UUID) -> Void)?

    init(onSuccessfulImport: ((UUID) -> Void)? = nil) {
        self.onSuccessfulImport = onSuccessfulImport
    }

    @State private var isFileImporterPresented = false
    @State private var showsManualEntrySheet = false
    @State private var importOverlay: DiveImportOverlayState = .hidden
    @State private var activeImportTask: Task<Void, Never>?
    @State private var fileImporterPresentationTask: Task<Void, Never>?
    @AppStorage(AppUserSettings.bulkUddfCreateDiveSitesKey) private var importCreateDiveSitesFromImport = true
    @State private var importAttachMediaFromPhotoLibrary = false
    @State private var importResultAlert: SnorkelImportAlertPresentation.Payload?
    @State private var showImportResultAlert = false
    @State private var pendingImportedActivityID: UUID?

    var body: some View {
        AppPage(title: LogbookAddActivityPresentation.snorkelUploadPageTitle, showsBackButton: !importOverlay.disablesSourceButtons) {
            ZStack {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    Text("Import a snorkel from your computer, or add the details yourself.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    snorkelImportSection

                    snorkelManualEntrySection

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.vertical, AppTheme.Spacing.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                if importOverlay != .hidden {
                    DiveImportProgressOverlayView(overlay: $importOverlay)
                        .zIndex(1)
                }
            }
        }
        .sheet(isPresented: $showsManualEntrySheet) {
            ManualSnorkelEntrySheet { input in
                confirmManualSnorkel(input)
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: DiveFileImporterPresentation.PickerMode.fit.allowedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFitImportResult(result)
        }
        .onDisappear {
            fileImporterPresentationTask?.cancel()
            fileImporterPresentationTask = nil
        }
        .alert(
            importResultAlert.map { SnorkelImportAlertPresentation.title(for: $0) } ?? "Import",
            isPresented: $showImportResultAlert
        ) {
            Button("OK", role: .cancel) {
                dismissSnorkelImportResultAlert()
            }
        } message: {
            if let importResultAlert {
                Text(SnorkelImportAlertPresentation.message(for: importResultAlert))
            }
        }
        .accessibilityIdentifier("Logbook.SnorkelActivityUpload.Root")
    }

    private var snorkelImportSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            snorkelSourceSection(title: "Import from a file") {
                snorkelSourceCard(
                    title: "Garmin",
                    subtitle: "Snorkel or Open Water swim from Garmin Connect.",
                    tag: ".fit",
                    systemImage: "doc.badge.arrow.up",
                    accessibilityIdentifier: "SnorkelActivityUpload.FileUpload"
                ) {
                    requestFileImporter()
                }
            }

            Toggle(isOn: $importCreateDiveSitesFromImport) {
                Text("Create dive sites from import names")
                    .font(.subheadline)
            }
            .tint(AppTheme.Colors.accent)

            Toggle(isOn: $importAttachMediaFromPhotoLibrary) {
                Text("Attach matching photos from library")
                    .font(.subheadline)
            }
            .tint(AppTheme.Colors.accent)
        }
    }

    private var snorkelManualEntrySection: some View {
        snorkelSourceSection(title: "Add it yourself") {
            snorkelSourceCard(
                title: "Manual entry",
                subtitle: "Type in your snorkel details by hand.",
                tag: nil,
                systemImage: "square.and.pencil",
                accessibilityIdentifier: "SnorkelActivityUpload.ManualEntry"
            ) {
                showsManualEntrySheet = true
            }
        }
    }

    @ViewBuilder
    private func snorkelSourceSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(AppTheme.Colors.mutedText)
                .padding(.leading, 4)

            content()
        }
    }

    private func snorkelSourceCard(
        title: String,
        subtitle: String,
        tag: String?,
        systemImage: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.md) {
                snorkelSourceIconBadge(systemImage: systemImage)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Text(title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)

                        if let tag {
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
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.Colors.surfaceElevated)
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(AddActivityCardButtonStyle())
        .disabled(importOverlay.disablesSourceButtons)
        .accessibilityLabel(tag.map { "\(title). \($0). \(subtitle)" } ?? "\(title). \(subtitle)")
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func requestFileImporter() {
        fileImporterPresentationTask?.cancel()
        isFileImporterPresented = false
        fileImporterPresentationTask = Task { @MainActor in
            await DiveFileImporterPresentation.awaitPresentationSurfaceReady()
            guard !Task.isCancelled else { return }
            isFileImporterPresented = true
            fileImporterPresentationTask = nil
        }
    }

    @MainActor
    private func confirmManualSnorkel(_ input: ManualSnorkelEntryInput) {
        let activity = SnorkelActivityManualCreation.makeBlankActivity(from: input)
        let outcome = SnorkelActivityManualCreation.persist(
            activity,
            siteSelection: input.siteSelection,
            modelContext: modelContext
        )
        if let id = outcome.primaryInsertedActivityId {
            if case .newSite = input.siteSelection,
               let diveSiteID = activity.diveSiteID,
               let site = try? DiveLinkedSiteResolver.existingUserDiveSite(id: diveSiteID, modelContext: modelContext) {
                Task { @MainActor in
                    await DiveSiteTimeZoneResolution.ensureResolved(
                        for: site,
                        at: activity.startTime,
                        resolver: MapKitGeocodingTimeZoneResolver.shared
                    )
                    try? modelContext.save()
                }
            }
            if let ownerID = accountSession.currentProfile?.id {
                Task { @MainActor in
                    await SnorkelLibraryMediaAutoAttachScheduler.attachAfterSnorkelPersisted(
                        activity,
                        ownerProfileID: ownerID,
                        modelContext: modelContext
                    )
                }
            }
            onSuccessfulImport?(id)
        } else {
            presentImportResult(SnorkelImportAlertPresentation.failurePayload(
                message: outcome.userMessage
            ))
        }
    }

    private func handleFitImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            beginFitImport(from: url)
        case .failure(let error):
            guard !DiveFileImporterPresentation.isUserCancellation(error) else { return }
            presentImportResult(SnorkelImportAlertPresentation.failurePayload(
                message: GoDiveUserFacingError.importUserMessage(for: error)
            ))
        }
    }

    private func beginFitImport(from url: URL) {
        importOverlay = .start(.readingFile)
        activeImportTask?.cancel()
        activeImportTask = Task(priority: .userInitiated) { @MainActor in
            let backgroundTask = DiveFileImportBackgroundTask.Token()
            backgroundTask.begin()
            defer { backgroundTask.end() }
            await yieldForImportOverlayPaint()
            await runFitImport(from: url)
        }
    }

    @MainActor
    private func yieldForImportOverlayPaint() async {
        await Task.yield()
        await Task.yield()
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
                try FitSnorkelFileImport.readFitFileData(from: url)
            }.value

            withAnimation(.easeInOut(duration: 0.2)) {
                importOverlay = .start(.parsingFile)
            }
            await yieldForImportOverlayPaint()

            guard let owner = accountSession.currentProfile else {
                presentImportResult(SnorkelImportAlertPresentation.failurePayload(
                    message: "Sign in to import snorkel sessions."
                ))
                return
            }

            withAnimation(.easeInOut(duration: 0.2)) {
                importOverlay = .start(.creatingDiveLogs)
            }
            await yieldForImportOverlayPaint()

            let outcome = await FitSnorkelFileImport.importFitData(
                data,
                modelContext: modelContext,
                owner: owner,
                createMissingDiveSites: importCreateDiveSitesFromImport,
                attachMedia: false
            )

            guard !Task.isCancelled else { return }

            if outcome.didSucceed, importAttachMediaFromPhotoLibrary,
               let activityID = outcome.primaryInsertedActivityId,
               let activity = (try? SnorkelActivityOwnership.activities(
                   forOwnerProfileID: owner.id,
                   modelContext: modelContext
               ))?.first(where: { $0.id == activityID }) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    importOverlay = .start(.addingMedia)
                }
                await yieldForImportOverlayPaint()
                await SnorkelLibraryMediaAutoAttachScheduler.attachAfterSnorkelPersisted(
                    activity,
                    ownerProfileID: owner.id,
                    modelContext: modelContext,
                    attachMediaFromPhotoLibrary: true
                )
            }

            await finishSnorkelImport(outcome: outcome)
        } catch {
            presentImportResult(SnorkelImportAlertPresentation.failurePayload(
                message: GoDiveUserFacingError.importUserMessage(for: error)
            ))
        }
    }

    @MainActor
    private func finishSnorkelImport(outcome: SnorkelFileImportOutcome) async {
        guard !Task.isCancelled else { return }
        if outcome.didSucceed {
            withAnimation(.easeInOut(duration: 0.2)) {
                importOverlay = .importing(milestone: .addingMedia, fraction: 1.0)
            }
            try? await Task.sleep(for: DiveImportSuccessTiming.sleepAfterCompleteBeforeDismiss)
            if let owner = accountSession.currentProfile {
                GoDiveFriendShareRefreshCoordinator.scheduleRepublish(
                    ownerProfileID: owner.id,
                    modelContext: modelContext
                )
            }
        }
        importOverlay = .hidden
        pendingImportedActivityID = outcome.didSucceed ? outcome.primaryInsertedActivityId : nil
        presentImportResult(SnorkelImportAlertPresentation.payload(for: outcome))
    }

    @MainActor
    private func dismissSnorkelImportResultAlert() {
        let shouldOpenDetail = importResultAlert?.isSuccess == true
        let activityID = pendingImportedActivityID
        showImportResultAlert = false
        importResultAlert = nil
        pendingImportedActivityID = nil
        guard shouldOpenDetail, let activityID else { return }
        onSuccessfulImport?(activityID)
    }

    @MainActor
    private func presentImportResult(_ payload: SnorkelImportAlertPresentation.Payload) {
        importOverlay = .hidden
        importResultAlert = payload
        showImportResultAlert = true
    }

    private func snorkelSourceIconBadge(systemImage: String) -> some View {
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
}
