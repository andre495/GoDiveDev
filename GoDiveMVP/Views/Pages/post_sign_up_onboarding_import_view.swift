import SwiftData
import SwiftUI

/// Post-sign-up UDDF import — options page, optional MacDive guide, file picker; no back; **Skip** → celebration.
struct PostSignUpOnboardingImportView: View {
    @Environment(\.modelContext) private var modelContext

    let onComplete: (_ followsBulkImport: Bool) -> Void

    @State private var showsMacDiveGuide = false
    @State private var isFileImporterPresented = false
    @State private var importOverlay: DiveImportOverlayState = .hidden
    @State private var uddfImportSummary: UddfImportSummary?
    @State private var showUddfImportCompleteAlert = false
    @State private var fileImporterPresentationTask: Task<Void, Never>?
    @State private var activeImportTask: Task<Void, Never>?
    @AppStorage(AppUserSettings.bulkUddfCreateDiveSitesKey) private var importCreateDiveSitesFromImport = true
    @State private var importAttachMediaFromPhotoLibrary = false

    var body: some View {
        ZStack {
            NavigationStack {
                DiveFileImportOptionsView(
                    mode: .uddf,
                    createDiveSitesFromImport: $importCreateDiveSitesFromImport,
                    attachMediaFromPhotoLibrary: $importAttachMediaFromPhotoLibrary,
                    onChooseFile: requestFileImporter,
                    onOpenMacDiveGuide: { showsMacDiveGuide = true },
                    showsBackButton: false,
                    usesOnboardingPrimaryButton: true,
                    skipButtonTitle: onboardingSkipTitle,
                    skipButtonAccessibilityIdentifier: PostSignUpOnboardingImportPresentation.skipButtonAccessibilityIdentifier,
                    onSkip: onboardingSkipAction
                )
                .accessibilityIdentifier(PostSignUpOnboardingImportPresentation.optionsAccessibilityIdentifier)
                .navigationDestination(isPresented: $showsMacDiveGuide) {
                    MacDiveUddfImportGuideView(
                        onChooseFile: requestFileImporter,
                        showsBackButton: false,
                        skipButtonTitle: onboardingSkipTitle,
                        skipButtonAccessibilityIdentifier: PostSignUpOnboardingImportPresentation.skipButtonAccessibilityIdentifier,
                        onSkip: onboardingSkipAction
                    )
                }
            }
            .accessibilityIdentifier(PostSignUpOnboardingImportPresentation.rootAccessibilityIdentifier)

            if importOverlay != .hidden {
                DiveImportProgressOverlayView(overlay: $importOverlay)
                    .zIndex(1)
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: DiveFileImporterPresentation.PickerMode.uddf.allowedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleDiveFileImportResult(result)
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
        .onAppear {
            importAttachMediaFromPhotoLibrary = AppUserSettings.autoUploadMediaToActivities
        }
        .onDisappear {
            fileImporterPresentationTask?.cancel()
            fileImporterPresentationTask = nil
        }
    }

    private var onboardingSkipTitle: String? {
        importOverlay.allowsAbortingOnboardingImport
            ? PostSignUpOnboardingImportPresentation.skipButtonTitle
            : nil
    }

    private var onboardingSkipAction: (() -> Void)? {
        importOverlay.allowsAbortingOnboardingImport ? { advanceToCelebration(followsBulkImport: false) } : nil
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

    private func handleDiveFileImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            beginUddfImport(from: url)
        case .failure(let error):
            guard !DiveFileImporterPresentation.isUserCancellation(error) else { return }
            importOverlay = .failed(error.localizedDescription)
        }
    }

    private func beginUddfImport(from url: URL) {
        importOverlay = .start(.readingFile)
        activeImportTask?.cancel()
        activeImportTask = Task(priority: .userInitiated) { @MainActor in
            let backgroundTask = DiveFileImportBackgroundTask.Token()
            backgroundTask.begin()
            defer { backgroundTask.end() }
            await yieldForImportOverlayPaint()
            guard !Task.isCancelled else {
                importOverlay = .failed(DiveFileImportInterruption.userMessage)
                return
            }
            await runUddfImport(from: url)
        }
    }

    @MainActor
    private func yieldForImportOverlayPaint() async {
        await Task.yield()
        await Task.yield()
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
                        fraction: DiveImportMilestone.creatingDiveLogs.fraction(
                            completed: processed,
                            total: total
                        )
                    )
                },
                onMediaAttachProgress: { update in
                    importOverlay = .importing(
                        milestone: .addingMedia,
                        fraction: DiveImportMilestone.addingMedia.fraction(
                            completed: update.completed,
                            total: update.total
                        )
                    )
                }
            )
            await yieldForImportOverlayPaint()

            guard !Task.isCancelled else {
                importOverlay = .failed(DiveFileImportInterruption.userMessage)
                return
            }
            await finishImport(outcome: outcome)
        } catch let uddf as UddfDecodeError {
            guard !Task.isCancelled else {
                importOverlay = .failed(DiveFileImportInterruption.userMessage)
                return
            }
            importOverlay = .failed(uddf.localizedDescription)
        } catch {
            guard !Task.isCancelled else {
                importOverlay = .failed(DiveFileImportInterruption.userMessage)
                return
            }
            importOverlay = .failed(error.localizedDescription)
        }
    }

    @MainActor
    private func finishImport(outcome: DiveFileImportOutcome) async {
        guard !Task.isCancelled else {
            importOverlay = .failed(DiveFileImportInterruption.userMessage)
            return
        }
        if outcome.bulkImportFinishedWithCounts {
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
            advanceToCelebration(followsBulkImport: false)
        } else {
            importOverlay = .failed(outcome.userMessage)
        }
    }

    @MainActor
    private func dismissUddfImportSummaryAndContinue() {
        showUddfImportCompleteAlert = false
        uddfImportSummary = nil
        advanceToCelebration(followsBulkImport: true)
    }

    @MainActor
    private func advanceToCelebration(followsBulkImport: Bool) {
        SignInCelebrationTransitionDiagnostics.resetAnchor("import_advanceToCelebration")
        SignInCelebrationTransitionDiagnostics.mark(
            "import_advanceToCelebration followsBulkImport=\(followsBulkImport)"
        )
        Task { @MainActor in
            let signpostID = SignInCelebrationTransitionDiagnostics.begin(.importToCelebration)
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(followsBulkImport ? 350 : 80))
            guard !Task.isCancelled else {
                SignInCelebrationTransitionDiagnostics.end(.importToCelebration, signpostID: signpostID)
                return
            }
            SignInCelebrationTransitionDiagnostics.mark("import_onComplete_calling")
            onComplete(followsBulkImport)
            SignInCelebrationTransitionDiagnostics.end(.importToCelebration, signpostID: signpostID)
        }
    }
}

#Preview {
    PostSignUpOnboardingImportView(onComplete: { _ in })
        .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
