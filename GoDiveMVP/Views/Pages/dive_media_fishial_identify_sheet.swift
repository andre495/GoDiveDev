import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif

/// Progress, still picker, Fishial recognition, and user confirmation for one dive media item.
struct DiveMediaFishialIdentifySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountSession.self) private var accountSession

    @State private var catalog: [MarineLife] = []

    let media: DiveMediaPhoto
    let dive: DiveActivity
    let catalogSites: [DiveSite]
    let captureContext: DiveMediaCaptureContext?

    @State private var phase: Phase = .loading(.loadingMedia())
    @State private var videoScrubFraction = DiveMediaFishialFrameExport.defaultVideoScrubFraction
    #if canImport(UIKit)
    @State private var cropGestureScale: CGFloat = 1
    @State private var cropLastGestureScale: CGFloat = 1
    @State private var cropOffset: CGSize = .zero
    @State private var cropLastOffset: CGSize = .zero
    @State private var cropViewportSize: CGSize = .zero
    #endif

    private enum Phase {
        case loading(FishialIdentifyProgress)
        #if canImport(UIKit)
        case croppingStill(FishialStillCropContext)
        #endif
        #if canImport(UIKit) && canImport(AVFoundation)
        case selectingVideo(FishialVideoScrubContext)
        #endif
        case recognizing(FishialIdentifyProgress)
        case reviewNoFishDetected(DiveMediaFishialIdentification.Outcome)
        case reviewUnmatchedFishial(
            DiveMediaFishialIdentification.Outcome,
            primarySpeciesName: String
        )
        case confirmSingle(
            DiveMediaFishialIdentification.Outcome,
            FishialCatalogReviewOption
        )
        case selectSpecies(
            DiveMediaFishialIdentification.Outcome,
            options: [FishialCatalogReviewOption],
            selectedMarineLifeUUIDs: Set<String>
        )
        case saved(speciesNames: [String])
        case declinedSingle(DiveMediaFishialIdentification.Outcome)
        case failed(String)
    }

    /// Crop / video scrub fill the large blue panel; review copy aligns to the top.
    private var usesFullBleedMediaLayout: Bool {
        #if canImport(UIKit)
        if case .croppingStill = phase { return true }
        #endif
        #if canImport(UIKit) && canImport(AVFoundation)
        if case .selectingVideo = phase { return true }
        #endif
        return false
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .loading(let progress):
                    loadingContent(progress: progress)
                #if canImport(UIKit)
                case .croppingStill(let context):
                    croppingStillContent(context: context)
                #endif
                #if canImport(UIKit) && canImport(AVFoundation)
                case .selectingVideo(let context):
                    videoSelectionContent(context: context)
                #endif
                case .recognizing(let progress):
                    recognizingContent(progress: progress)
                case .reviewNoFishDetected(let outcome):
                    reviewNoFishDetectedContent(outcome: outcome)
                case .reviewUnmatchedFishial(let outcome, let primarySpeciesName):
                    reviewUnmatchedFishialContent(
                        outcome: outcome,
                        primarySpeciesName: primarySpeciesName
                    )
                case .confirmSingle(let outcome, let option):
                    confirmSingleContent(outcome: outcome, option: option)
                case .selectSpecies(let outcome, let options, let selectedMarineLifeUUIDs):
                    selectSpeciesContent(
                        outcome: outcome,
                        options: options,
                        selectedMarineLifeUUIDs: selectedMarineLifeUUIDs
                    )
                case .saved(let speciesNames):
                    savedContent(speciesNames: speciesNames)
                case .declinedSingle(let outcome):
                    declinedSingleContent(outcome: outcome)
                case .failed(let message):
                    failedContent(message: message)
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: usesFullBleedMediaLayout ? .center : .topLeading
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    leadingToolbarContent
                }
                ToolbarItem(placement: .confirmationAction) {
                    trailingToolbarContent
                }
            }
        }
        .diveActivityOverviewPanelModalSheetPresentation()
        .task(id: media.id) {
            let container = modelContext.container
            async let catalogIDs = MarineLifeCatalogLoader.fetchSortedPersistentIDs(container: container)
            await prepareSelection()
            catalog = MarineLifeCatalogLoader.bindModels(
                persistentIDs: await catalogIDs,
                modelContext: modelContext
            )
        }
        .accessibilityIdentifier("DiveMediaFishialIdentify.Root")
    }

    @ViewBuilder
    private var leadingToolbarContent: some View {
        #if canImport(UIKit) && canImport(AVFoundation)
        if case .croppingStill(let context) = phase, context.videoScrubContext != nil {
            Button("Back") {
                guard let videoScrubContext = context.videoScrubContext else { return }
                resetCropGestures()
                phase = .selectingVideo(videoScrubContext)
            }
            .fontWeight(.semibold)
            .foregroundStyle(AppTheme.Colors.headerChromeIconForeground)
            .accessibilityIdentifier("DiveMediaFishialIdentify.BackToScrub")
        } else {
            AppGlassToolbarCancelButton(
                action: { dismiss() },
                accessibilityIdentifier: DiveMarineLifeTagSheetPresentation.identifySheetCancelAccessibilityIdentifier
            )
        }
        #else
        AppGlassToolbarCancelButton(
            action: { dismiss() },
            accessibilityIdentifier: DiveMarineLifeTagSheetPresentation.identifySheetCancelAccessibilityIdentifier
        )
        #endif
    }

    @ViewBuilder
    private var trailingToolbarContent: some View {
        switch phase {
        case .loading, .recognizing:
            EmptyView()
        #if canImport(UIKit) && canImport(AVFoundation)
        case .selectingVideo:
            AppGlassProminentDoneButton(
                action: { Task { await continueFromVideoScrub() } },
                accessibilityIdentifier: "DiveMediaFishialIdentify.Continue",
                title: "Continue"
            )
        #endif
        #if canImport(UIKit)
        case .croppingStill:
            AppGlassProminentDoneButton(
                action: { Task { await identifyCroppedStill() } },
                accessibilityIdentifier: "DiveMediaFishialIdentify.Identify",
                title: "Identify"
            )
        #endif
        case .selectSpecies(_, let options, let selectedMarineLifeUUIDs):
            AppGlassProminentDoneButton(
                action: {
                    let selectedOptions = options.filter {
                        selectedMarineLifeUUIDs.contains($0.marineLifeUUID)
                    }
                    guard !selectedOptions.isEmpty else { return }
                    saveConfirmedCatalogMatches(selectedOptions)
                },
                accessibilityIdentifier: DiveMarineLifeTagSheetPresentation.identifySheetDoneAccessibilityIdentifier,
                isEnabled: !selectedMarineLifeUUIDs.isEmpty
            )
        case .reviewNoFishDetected, .reviewUnmatchedFishial, .declinedSingle, .saved, .failed:
            AppGlassProminentDoneButton(
                action: { dismiss() },
                accessibilityIdentifier: DiveMarineLifeTagSheetPresentation.identifySheetDoneAccessibilityIdentifier
            )
        case .confirmSingle:
            EmptyView()
        }
    }

    @ViewBuilder
    private func loadingContent(progress: FishialIdentifyProgress) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            Text("Preparing media")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            ProgressView()
                .tint(AppTheme.Colors.accent)

            Text(progress.stage)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .accessibilityIdentifier("DiveMediaFishialIdentify.Loading")
    }

    #if canImport(UIKit)
    @ViewBuilder
    private func croppingStillContent(context: FishialStillCropContext) -> some View {
        FishialImageCropEditorView(
            sourceImage: context.sourceImage,
            instruction: cropInstruction(for: context),
            gestureScale: $cropGestureScale,
            lastGestureScale: $cropLastGestureScale,
            offset: $cropOffset,
            lastOffset: $cropLastOffset,
            viewportSize: $cropViewportSize
        )
        .accessibilityIdentifier("DiveMediaFishialIdentify.Crop")
    }

    private func cropInstruction(for context: FishialStillCropContext) -> String {
        #if canImport(AVFoundation)
        if context.videoScrubContext != nil {
            return FishialImageCropPresentation.exportedStillInstruction
        }
        #endif
        return FishialImageCropPresentation.photoInstruction
    }
    #endif

    #if canImport(UIKit) && canImport(AVFoundation)
    @ViewBuilder
    private func videoSelectionContent(context: FishialVideoScrubContext) -> some View {
        FishialVideoStillScrubPickerView(
            context: context,
            scrubFraction: $videoScrubFraction
        )
        .accessibilityIdentifier("DiveMediaFishialIdentify.Selection")
    }
    #endif

    @ViewBuilder
    private func recognizingContent(progress: FishialIdentifyProgress) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            Text("Identifying fish")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            ProgressView()
                .tint(AppTheme.Colors.accent)

            Text(progress.stage)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .accessibilityIdentifier("DiveMediaFishialIdentify.Recognizing")
    }

    @ViewBuilder
    private func reviewNoFishDetectedContent(outcome: DiveMediaFishialIdentification.Outcome) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Text("No fish detected")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text(FishialIdentificationReviewPresentation.noFishDetectedMessage)
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(resultBody(from: outcome))
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.bottom, AppTheme.Spacing.lg)
        }
        .accessibilityIdentifier("DiveMediaFishialIdentify.NoFishDetected")
    }

    @ViewBuilder
    private func reviewUnmatchedFishialContent(
        outcome: DiveMediaFishialIdentification.Outcome,
        primarySpeciesName: String
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Text("No field guide match")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text(FishialIdentificationReviewPresentation.unmatchedFieldGuideMessage(
                    speciesName: primarySpeciesName
                ))
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Dismiss") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.Colors.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("DiveMediaFishialIdentify.UnmatchedDismiss")

                Text(resultBody(from: outcome))
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.bottom, AppTheme.Spacing.lg)
        }
        .accessibilityIdentifier("DiveMediaFishialIdentify.UnmatchedFieldGuide")
    }

    @ViewBuilder
    private func confirmSingleContent(
        outcome: DiveMediaFishialIdentification.Outcome,
        option: FishialCatalogReviewOption
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                Text(FishialIdentificationReviewPresentation.confirmSinglePrompt)
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                catalogMatchCard(option, isSelected: true)

                fieldGuideEntryLink(for: option)

                HStack(spacing: AppTheme.Spacing.md) {
                    Button {
                        saveConfirmedCatalogMatch(option)
                    } label: {
                        Text("Yes, save ID")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.Colors.accent)
                    .accessibilityIdentifier("DiveMediaFishialIdentify.ConfirmYes")

                    Button {
                        phase = .declinedSingle(outcome)
                    } label: {
                        Text("Not accurate")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("DiveMediaFishialIdentify.ConfirmNo")
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.bottom, AppTheme.Spacing.lg)
        }
        .accessibilityIdentifier("DiveMediaFishialIdentify.ConfirmSingle")
    }

    @ViewBuilder
    private func selectSpeciesContent(
        outcome: DiveMediaFishialIdentification.Outcome,
        options: [FishialCatalogReviewOption],
        selectedMarineLifeUUIDs: Set<String>
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Text(FishialIdentificationReviewPresentation.selectMultiplePrompt)
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(options, id: \.marineLifeUUID) { option in
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            Button {
                                var updated = selectedMarineLifeUUIDs
                                if updated.contains(option.marineLifeUUID) {
                                    updated.remove(option.marineLifeUUID)
                                } else {
                                    updated.insert(option.marineLifeUUID)
                                }
                                phase = .selectSpecies(
                                    outcome,
                                    options: options,
                                    selectedMarineLifeUUIDs: updated
                                )
                            } label: {
                                catalogMatchCard(
                                    option,
                                    isSelected: selectedMarineLifeUUIDs.contains(option.marineLifeUUID)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier(
                                "DiveMediaFishialIdentify.Option.\(option.marineLifeUUID)"
                            )

                            fieldGuideEntryLink(for: option)
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.bottom, AppTheme.Spacing.lg)
        }
        .accessibilityIdentifier("DiveMediaFishialIdentify.SelectSpecies")
    }

    @ViewBuilder
    private func savedContent(speciesNames: [String]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Fish ID saved")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                ForEach(speciesNames, id: \.self) { speciesName in
                    HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "sparkles")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.accent)
                            .accessibilityHidden(true)

                        Text(speciesName)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Text(FishialConfirmedSpeciesPresentation.savedFishIDNote(speciesCount: speciesNames.count))
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .accessibilityIdentifier("DiveMediaFishialIdentify.Saved")
    }

    @ViewBuilder
    private func declinedSingleContent(outcome: DiveMediaFishialIdentification.Outcome) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Text("ID not saved")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("Fishial’s suggestion was not saved to this media item.")
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(resultBody(from: outcome))
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.bottom, AppTheme.Spacing.lg)
        }
        .accessibilityIdentifier("DiveMediaFishialIdentify.Declined")
    }

    @ViewBuilder
    private func failedContent(message: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Could not identify fish")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text(message)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .accessibilityIdentifier("DiveMediaFishialIdentify.Failed")
    }

    @ViewBuilder
    private func catalogMatchCard(
        _ option: FishialCatalogReviewOption,
        isSelected: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            FieldGuideMarineLifeCatalogImage(
                imageURLString: option.featureImageURL,
                bundleResourceName: option.featureImageResourceName,
                placement: .mediaSheetHero(height: 72, cornerRadius: 8)
            )
            .frame(width: 96, height: 72)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text(option.catalogCommonName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)

                Text(option.catalogScientificName)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.leading)

                Text(FishialIdentificationResultPresentation.formattedAccuracy(option.fishialAccuracy))
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)

                if option.nameMatchScore < 1.0 {
                    Text("Fishial: \(option.fishialScientificName)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.tabUnselected)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.Colors.accent)
                    .accessibilityHidden(true)
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? AppTheme.Colors.accent.opacity(0.12) : AppTheme.Colors.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isSelected ? AppTheme.Colors.accent : AppTheme.Colors.tabUnselected.opacity(0.25),
                    lineWidth: isSelected ? 2 : 1
                )
        )
    }

    @ViewBuilder
    private func fieldGuideEntryLink(for option: FishialCatalogReviewOption) -> some View {
        if let species = catalog.first(where: { $0.uuid == option.marineLifeUUID }) {
            NavigationLink {
                FieldGuideMarineLifeDetailView(
                    species: species,
                    ownerProfileID: accountSession.currentProfile?.id,
                    onOpenDive: { _ in dismiss() }
                )
                .hidesBottomTabBarWhenPushed()
            } label: {
                Label(
                    FishialIdentificationReviewPresentation.fieldGuideEntryLinkTitle,
                    systemImage: "book.closed.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.accent)
            }
            .accessibilityIdentifier("DiveMediaFishialIdentify.FieldGuide.\(option.marineLifeUUID)")
        }
    }

    private func resultBody(from outcome: DiveMediaFishialIdentification.Outcome) -> String {
        FishialIdentificationResultPresentation.resultLines(from: outcome).joined(separator: "\n")
    }

    @MainActor
    private func prepareSelection() async {
        phase = .loading(.loadingMedia())
        #if canImport(UIKit)
        do {
            switch try await DiveMediaFishialIdentification.prepareSelection(for: media) {
            case .photoCrop(let context):
                resetCropGestures()
                phase = .croppingStill(context)
            #if canImport(AVFoundation)
            case .video(let context):
                videoScrubFraction = DiveMediaFishialFrameExport.defaultVideoScrubFraction
                phase = .selectingVideo(context)
            #endif
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
        #else
        phase = .failed(FishialAPIError.missingCredentials.localizedDescription)
        #endif
    }

    @MainActor
    private func transitionToReview(_ outcome: DiveMediaFishialIdentification.Outcome) {
        let catalogSnapshots = catalog.map(FishialMarineLifeCatalogSnapshot.init(marineLife:))
        let catalogOptions = FishialMarineLifeCatalogMatching.catalogReviewOptions(
            from: outcome.rankedSpecies,
            catalog: catalogSnapshots
        )
        switch FishialIdentificationReviewPresentation.reviewMode(
            for: catalogOptions,
            rankedSpecies: outcome.rankedSpecies
        ) {
        case .noFishDetected:
            phase = .reviewNoFishDetected(outcome)
        case .unmatchedFishialSuggestion(let primarySpeciesName):
            phase = .reviewUnmatchedFishial(outcome, primarySpeciesName: primarySpeciesName)
        case .confirmSingle(let option):
            phase = .confirmSingle(outcome, option)
        case .selectFromMultiple(let options):
            phase = .selectSpecies(
                outcome,
                options: options,
                selectedMarineLifeUUIDs: []
            )
        }
    }

    @MainActor
    private func saveConfirmedCatalogMatch(_ option: FishialCatalogReviewOption) {
        guard let owner = accountSession.currentProfile else {
            phase = .failed(DiveMediaFishialIdentificationStorageError.missingSignedInProfile.localizedDescription)
            return
        }
        guard let marineLife = catalog.first(where: { $0.uuid == option.marineLifeUUID }) else {
            phase = .failed("Could not find that species in the catalog.")
            return
        }
        do {
            let saved = try DiveMediaFishialIdentificationStorage.saveConfirmedCatalogMatch(
                option,
                marineLife: marineLife,
                media: media,
                dive: dive,
                captureContext: captureContext,
                owner: owner,
                modelContext: modelContext
            )
            phase = .saved(speciesNames: [saved])
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    @MainActor
    private func saveConfirmedCatalogMatches(_ options: [FishialCatalogReviewOption]) {
        guard let owner = accountSession.currentProfile else {
            phase = .failed(DiveMediaFishialIdentificationStorageError.missingSignedInProfile.localizedDescription)
            return
        }
        let marineLifeByUUID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.uuid, $0) })
        guard options.allSatisfy({ marineLifeByUUID[$0.marineLifeUUID] != nil }) else {
            phase = .failed(DiveMediaFishialIdentificationStorageError.missingCatalogSpecies.localizedDescription)
            return
        }
        do {
            let saved = try DiveMediaFishialIdentificationStorage.saveConfirmedCatalogMatches(
                options,
                marineLifeByUUID: marineLifeByUUID,
                media: media,
                dive: dive,
                captureContext: captureContext,
                owner: owner,
                modelContext: modelContext
            )
            phase = .saved(speciesNames: saved)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    #if canImport(UIKit)
    @MainActor
    private func resetCropGestures() {
        cropGestureScale = 1
        cropLastGestureScale = 1
        cropOffset = .zero
        cropLastOffset = .zero
        cropViewportSize = .zero
    }

    #if canImport(AVFoundation)
    @MainActor
    private func continueFromVideoScrub() async {
        guard case .selectingVideo(let context) = phase else { return }
        phase = .loading(.exportingSelectedStill())
        do {
            let frame = try await DiveMediaFishialIdentification.exportSelectedVideoFrame(
                context: context,
                atFraction: videoScrubFraction
            ) { progress in
                phase = .loading(progress)
            }
            resetCropGestures()
            phase = .croppingStill(
                FishialStillCropContext(
                    exportedFrame: frame,
                    videoScrubContext: context
                )
            )
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
    #endif

    @MainActor
    private func identifyCroppedStill() async {
        guard case .croppingStill(let context) = phase else { return }
        guard cropViewportSize.width > 0, cropViewportSize.height > 0 else {
            phase = .failed("Could not prepare the crop.")
            return
        }
        do {
            let resolvedOffset = FishialImageCropRenderer.clampedOffset(
                cropOffset,
                drawSize: FishialImageCropRenderer.scaledDrawSize(
                    imageSize: context.sourceImage.size,
                    cropSize: cropViewportSize,
                    gestureScale: cropGestureScale
                ),
                cropSize: cropViewportSize
            )
            let frame: FishialIdentifyCandidateFrame
            if context.isPhotoSelection, let diveMedia = context.diveMedia {
                phase = .loading(.exportingSelectedStill())
                frame = try await DiveMediaFishialFrameExport.exportCroppedPhotoFrame(
                    diveMedia: diveMedia,
                    cropViewportSize: cropViewportSize,
                    gestureScale: cropGestureScale,
                    offset: resolvedOffset,
                    displayScale: displayScale
                )
            } else {
                frame = try DiveMediaFishialFrameExport.croppedCandidateFrame(
                    sourceImage: context.sourceImage,
                    cropViewportSize: cropViewportSize,
                    gestureScale: cropGestureScale,
                    offset: resolvedOffset,
                    filename: context.filename,
                    displayScale: displayScale
                )
            }
            phase = .recognizing(.recognizingSelectedFrame())
            let outcome = try await DiveMediaFishialIdentification.recognizeSelectedFrame(
                frame,
                dive: dive,
                catalogSites: catalogSites
            ) { progress in
                phase = .recognizing(progress)
            }
            transitionToReview(outcome)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
    #endif
}
