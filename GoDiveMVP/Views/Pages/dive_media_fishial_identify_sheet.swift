import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif

private struct FishialIdentifySheetTopSpacing: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.appSheetContentTopSpacing()
        } else {
            content
        }
    }
}

/// Progress, still picker, Fishial recognition, and user confirmation for one dive media item.
struct DiveMediaFishialIdentifySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let media: DiveMediaPhoto
    let dive: DiveActivity
    let catalogSites: [DiveSite]

    @State private var phase: Phase = .loading(.loadingMedia())
    @State private var videoScrubFraction = DiveMediaFishialFrameExport.defaultVideoScrubFraction

    private enum Phase {
        case loading(FishialIdentifyProgress)
        #if canImport(UIKit)
        case selectingPhoto(FishialIdentifyCandidateFrame)
        #endif
        #if canImport(UIKit) && canImport(AVFoundation)
        case selectingVideo(FishialVideoScrubContext)
        #endif
        case recognizing(FishialIdentifyProgress)
        case reviewNoMatches(DiveMediaFishialIdentification.Outcome)
        case confirmSingle(
            DiveMediaFishialIdentification.Outcome,
            FishialRecognitionPresentation.RankedSpecies
        )
        case selectSpecies(
            DiveMediaFishialIdentification.Outcome,
            options: [FishialRecognitionPresentation.RankedSpecies],
            selectedScientificName: String?
        )
        case saved(speciesName: String)
        case declinedSingle(DiveMediaFishialIdentification.Outcome)
        case failed(String)
    }

    private var isVideoSelectionPhase: Bool {
        if case .selectingVideo = phase { return true }
        return false
    }

    private var identifyPresentationDetents: Set<PresentationDetent> {
        isVideoSelectionPhase ? [.large] : [.medium, .large]
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .loading(let progress):
                    loadingContent(progress: progress)
                #if canImport(UIKit)
                case .selectingPhoto(let frame):
                    photoSelectionContent(frame: frame)
                #endif
                #if canImport(UIKit) && canImport(AVFoundation)
                case .selectingVideo(let context):
                    videoSelectionContent(context: context)
                #endif
                case .recognizing(let progress):
                    recognizingContent(progress: progress)
                case .reviewNoMatches(let outcome):
                    reviewNoMatchesContent(outcome: outcome)
                case .confirmSingle(let outcome, let species):
                    confirmSingleContent(outcome: outcome, species: species)
                case .selectSpecies(let outcome, let options, let selectedScientificName):
                    selectSpeciesContent(
                        outcome: outcome,
                        options: options,
                        selectedScientificName: selectedScientificName
                    )
                case .saved(let speciesName):
                    savedContent(speciesName: speciesName)
                case .declinedSingle(let outcome):
                    declinedSingleContent(outcome: outcome)
                case .failed(let message):
                    failedContent(message: message)
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: isVideoSelectionPhase ? .center : .topLeading
            )
            .modifier(FishialIdentifySheetTopSpacing(isEnabled: !isVideoSelectionPhase))
            .navigationTitle("Identify fish")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    toolbarTrailingContent
                }
            }
        }
        .presentationDetents(identifyPresentationDetents)
        .presentationDragIndicator(.visible)
        .appSheetPresentationChrome()
        .interactiveDismissDisabled(isBlockingInteraction)
        .task(id: media.id) {
            await prepareSelection()
        }
        .accessibilityIdentifier("DiveMediaFishialIdentify.Root")
    }

    @ViewBuilder
    private var toolbarTrailingContent: some View {
        switch phase {
        case .loading, .recognizing:
            EmptyView()
        #if canImport(UIKit)
        case .selectingPhoto, .selectingVideo:
            Button("Identify") {
                Task { await identifySelectedStill() }
            }
            .fontWeight(.semibold)
            .accessibilityIdentifier("DiveMediaFishialIdentify.Identify")
        #endif
        case .selectSpecies(_, _, let selectedScientificName):
            Button("Save") {
                guard let selectedScientificName else { return }
                saveConfirmedSpecies(selectedScientificName)
            }
            .fontWeight(.semibold)
            .disabled(selectedScientificName == nil)
            .accessibilityIdentifier("DiveMediaFishialIdentify.Save")
        case .reviewNoMatches, .declinedSingle, .saved, .failed:
            Button("Done") { dismiss() }
                .fontWeight(.semibold)
                .accessibilityIdentifier("DiveMediaFishialIdentify.Done")
        case .confirmSingle:
            EmptyView()
        }
    }

    private var isBlockingInteraction: Bool {
        switch phase {
        case .loading, .recognizing:
            return true
        default:
            return false
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
    private func photoSelectionContent(frame: FishialIdentifyCandidateFrame) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Text("Confirm this still, then tap Identify to send one request to Fishial.")
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Image(uiImage: frame.previewImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityIdentifier("DiveMediaFishialIdentify.PhotoPreview")
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.bottom, AppTheme.Spacing.lg)
        }
        .accessibilityIdentifier("DiveMediaFishialIdentify.Selection")
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
    private func reviewNoMatchesContent(outcome: DiveMediaFishialIdentification.Outcome) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Text("No matches")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text(FishialIdentificationReviewPresentation.noMatchesMessage)
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
        .accessibilityIdentifier("DiveMediaFishialIdentify.NoMatches")
    }

    @ViewBuilder
    private func confirmSingleContent(
        outcome: DiveMediaFishialIdentification.Outcome,
        species: FishialRecognitionPresentation.RankedSpecies
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                Text(FishialIdentificationReviewPresentation.confirmSinglePrompt)
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                speciesCard(species, isSelected: true)

                HStack(spacing: AppTheme.Spacing.md) {
                    Button {
                        saveConfirmedSpecies(species.scientificName)
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
        options: [FishialRecognitionPresentation.RankedSpecies],
        selectedScientificName: String?
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Text(FishialIdentificationReviewPresentation.selectMultiplePrompt)
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(options, id: \.scientificName) { species in
                        Button {
                            phase = .selectSpecies(
                                outcome,
                                options: options,
                                selectedScientificName: species.scientificName
                            )
                        } label: {
                            speciesCard(
                                species,
                                isSelected: species.scientificName == selectedScientificName
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(
                            "DiveMediaFishialIdentify.Option.\(species.scientificName)"
                        )
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.bottom, AppTheme.Spacing.lg)
        }
        .accessibilityIdentifier("DiveMediaFishialIdentify.SelectSpecies")
    }

    @ViewBuilder
    private func savedContent(speciesName: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Fish ID saved")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

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

            Text("This ID will appear on the media sheet at medium height.")
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
    private func speciesCard(
        _ species: FishialRecognitionPresentation.RankedSpecies,
        isSelected: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text(species.scientificName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)

                Text(FishialIdentificationResultPresentation.formattedAccuracy(species.accuracy))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
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

    private func resultBody(from outcome: DiveMediaFishialIdentification.Outcome) -> String {
        FishialIdentificationResultPresentation.resultLines(from: outcome).joined(separator: "\n")
    }

    @MainActor
    private func prepareSelection() async {
        phase = .loading(.loadingMedia())
        #if canImport(UIKit)
        do {
            switch try await DiveMediaFishialIdentification.prepareSelection(for: media) {
            case .photo(let frame):
                phase = .selectingPhoto(frame)
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
        switch FishialIdentificationReviewPresentation.reviewMode(for: outcome.rankedSpecies) {
        case .noMatches:
            phase = .reviewNoMatches(outcome)
        case .confirmSingle(let species):
            phase = .confirmSingle(outcome, species)
        case .selectFromMultiple(let options):
            phase = .selectSpecies(
                outcome,
                options: options,
                selectedScientificName: options.first?.scientificName
            )
        }
    }

    @MainActor
    private func saveConfirmedSpecies(_ scientificName: String) {
        do {
            let saved = try DiveMediaFishialIdentificationStorage.saveConfirmedSpecies(
                scientificName,
                on: media,
                modelContext: modelContext
            )
            phase = .saved(speciesName: saved)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    #if canImport(UIKit)
    @MainActor
    private func identifySelectedStill() async {
        switch phase {
        case .selectingPhoto(let frame):
            phase = .recognizing(.recognizingSelectedFrame())
            do {
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

        #if canImport(AVFoundation)
        case .selectingVideo(let context):
            phase = .recognizing(.exportingSelectedStill())
            do {
                let frame = try await DiveMediaFishialIdentification.exportSelectedVideoFrame(
                    context: context,
                    atFraction: videoScrubFraction
                ) { progress in
                    phase = .recognizing(progress)
                }
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
        #endif

        default:
            break
        }
    }
    #endif
}
