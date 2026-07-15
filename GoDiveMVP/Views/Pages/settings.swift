import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountSession.self) private var accountSession
    @AppStorage(AppUserSettings.automaticallyRenumberDivesKey) private var automaticallyRenumberDives = true
    @AppStorage(AppUserSettings.useImperialDisplayUnitsKey) private var useImperialDisplayUnits = true
    @AppStorage(AppUserSettings.defaultTankSizeKey) private var defaultTankSizeRaw = DefaultTankSize.al80.rawValue
    @AppStorage(AppUserSettings.autoUploadMediaToActivitiesKey) private var autoUploadMediaToActivities = true
    @AppStorage(AppUserSettings.shareCrashReportsKey) private var shareCrashReports = false

    @State private var mediaBackfillOverlay: DiveLibraryMediaBackfillOverlayState = .hidden
    @State private var mediaBackfillTask: Task<Void, Never>?

    var body: some View {
        settingsAppPage
            .hidesBottomTabBarWhenPushed()
            .onAppear { CrashBreadcrumbTrail.noteScreen("settings") }
            .onDisappear(perform: cancelMediaBackfillTask)
    }

    private var settingsAppPage: some View {
        AppPage(title: "Settings", showsBackButton: true) {
            SettingsPageContent(
                automaticallyRenumberDives: $automaticallyRenumberDives,
                useImperialDisplayUnits: $useImperialDisplayUnits,
                defaultTankSizeRaw: $defaultTankSizeRaw,
                autoUploadMediaToActivities: $autoUploadMediaToActivities,
                shareCrashReports: $shareCrashReports,
                mediaBackfillOverlay: mediaBackfillOverlay,
                onRenumberWhenEnabled: renumberAllDivesWhenEnabled,
                onAutoUploadEnabled: startMediaBackfillForExistingDives,
                onShareCrashReportsEnabled: uploadCrashReportBacklog,
                onDismissMediaBackfill: dismissMediaBackfillOverlay,
                onCancelMediaBackfill: cancelMediaBackfill
            )
        }
    }

    private func renumberAllDivesWhenEnabled() {
        Task { @MainActor in
            try? DiveActivityDiveNumbering.renumberAllChronologically(modelContext: modelContext)
        }
    }

    private func uploadCrashReportBacklog() {
        CrashReportingService.uploadBacklogNow(container: modelContext.container)
    }

    private func startMediaBackfillForExistingDives() {
        guard let ownerID = accountSession.currentProfile?.id else { return }

        mediaBackfillTask?.cancel()
        mediaBackfillOverlay = .running(
            completed: 0,
            total: 1,
            stage: DiveLibraryMediaAutoAttachPresentation.stageRequestingAccess
        )

        mediaBackfillTask = Task { @MainActor in
            await Task.yield()
            await Task.yield()

            let outcome = await DiveLibraryMediaAutoAttach.attachMatchingLibraryMediaForAllOwnerDives(
                ownerProfileID: ownerID,
                modelContext: modelContext,
                onProgress: applyMediaBackfillProgress
            )

            guard !Task.isCancelled else {
                mediaBackfillOverlay = .cancelled
                return
            }
            mediaBackfillOverlay = .finished(outcome)
        }
    }

    private func applyMediaBackfillProgress(_ update: DiveLibraryMediaAutoAttach.ProgressUpdate) {
        mediaBackfillOverlay = .running(
            completed: update.completed,
            total: update.total,
            stage: update.stage
        )
    }

    private func cancelMediaBackfill() {
        mediaBackfillTask?.cancel()
        mediaBackfillOverlay = .cancelled
    }

    private func dismissMediaBackfillOverlay() {
        mediaBackfillOverlay = .hidden
        cancelMediaBackfillTask()
    }

    private func cancelMediaBackfillTask() {
        mediaBackfillTask?.cancel()
        mediaBackfillTask = nil
    }
}

private struct SettingsPageContent: View {
    @Binding var automaticallyRenumberDives: Bool
    @Binding var useImperialDisplayUnits: Bool
    @Binding var defaultTankSizeRaw: String
    @Binding var autoUploadMediaToActivities: Bool
    @Binding var shareCrashReports: Bool

    @State private var saltWaterWeightText = ""
    @State private var freshWaterWeightText = ""
    @FocusState private var focusedWeightField: SettingsWeightFieldFocus?

    let mediaBackfillOverlay: DiveLibraryMediaBackfillOverlayState
    let onRenumberWhenEnabled: () -> Void
    let onAutoUploadEnabled: () -> Void
    let onShareCrashReportsEnabled: () -> Void
    let onDismissMediaBackfill: () -> Void
    let onCancelMediaBackfill: () -> Void

    var body: some View {
        ZStack {
            settingsForm

            SettingsMediaBackfillOverlayLayer(
                overlay: mediaBackfillOverlay,
                onDismiss: onDismissMediaBackfill,
                onCancel: onCancelMediaBackfill
            )
        }
    }

    private var settingsForm: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            SettingsToggleRow(
                title: SettingsPresentation.ImperialUnits.title,
                infoMessage: SettingsPresentation.ImperialUnits.infoMessage,
                isOn: $useImperialDisplayUnits
            )

            SettingsPickerRow(
                title: SettingsPresentation.DefaultTank.title,
                infoMessage: SettingsPresentation.DefaultTank.infoMessage,
                selection: defaultTankSelection,
                options: DefaultTankSize.allCases.map { (tag: $0, label: $0.settingsPickerTitle) }
            )

            defaultDiverWeightsSection

            SettingsToggleRow(
                title: SettingsPresentation.AutomaticallyRenumberDives.title,
                infoMessage: SettingsPresentation.AutomaticallyRenumberDives.infoMessage,
                isOn: $automaticallyRenumberDives
            )
            .onChange(of: automaticallyRenumberDives) { _, isOn in
                guard isOn else { return }
                onRenumberWhenEnabled()
            }

            SettingsToggleRow(
                title: SettingsPresentation.AutoUploadMediaToActivities.title,
                infoMessage: SettingsPresentation.AutoUploadMediaToActivities.infoMessage,
                isOn: $autoUploadMediaToActivities
            )
            .onChange(of: autoUploadMediaToActivities) { wasOn, isOn in
                guard isOn, !wasOn else { return }
                onAutoUploadEnabled()
            }

            SettingsToggleRow(
                title: SettingsPresentation.ShareCrashReports.title,
                infoMessage: SettingsPresentation.ShareCrashReports.infoMessage,
                isOn: $shareCrashReports
            )
            .onChange(of: shareCrashReports) { wasOn, isOn in
                guard isOn, !wasOn else { return }
                onShareCrashReportsEnabled()
            }

            SettingsNavigationLinkRow(
                title: SettingsPresentation.CrashReports.title,
                infoMessage: SettingsPresentation.CrashReports.infoMessage
            ) {
                CrashReportsView()
            }

            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.top, AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear(perform: reloadDefaultWeightFields)
        .onChange(of: useImperialDisplayUnits) { _, _ in
            reloadDefaultWeightFields()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedWeightField = nil
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabSelected)
            }
        }
    }

    private var defaultDiverWeightsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SettingsSectionHeader(
                title: SettingsPresentation.DefaultDiverWeights.sectionTitle,
                infoMessage: SettingsPresentation.DefaultDiverWeights.infoMessage
            )

            SettingsWeightFieldRow(
                title: SettingsPresentation.DefaultDiverWeights.saltWaterTitle,
                unitLabel: SettingsPresentation.diverWeightUnitLabel(useImperial: useImperialDisplayUnits),
                text: $saltWaterWeightText,
                focused: $focusedWeightField,
                focusCase: .saltWater
            )
            .onChange(of: saltWaterWeightText) { _, newValue in
                persistDefaultWeightText(newValue) { kilograms in
                    AppUserSettings.setDefaultSaltwaterWeightKilograms(kilograms)
                }
            }

            SettingsWeightFieldRow(
                title: SettingsPresentation.DefaultDiverWeights.freshWaterTitle,
                unitLabel: SettingsPresentation.diverWeightUnitLabel(useImperial: useImperialDisplayUnits),
                text: $freshWaterWeightText,
                focused: $focusedWeightField,
                focusCase: .freshWater
            )
            .onChange(of: freshWaterWeightText) { _, newValue in
                persistDefaultWeightText(newValue) { kilograms in
                    AppUserSettings.setDefaultFreshwaterWeightKilograms(kilograms)
                }
            }
        }
    }

    private func reloadDefaultWeightFields() {
        let system: DiveDisplayUnitSystem = useImperialDisplayUnits ? .imperial : .metric
        saltWaterWeightText = DiveActivityFieldValueParsing.formatDiverWeightInput(
            kilograms: AppUserSettings.defaultSaltwaterWeightKilograms(),
            displayUnits: system
        )
        freshWaterWeightText = DiveActivityFieldValueParsing.formatDiverWeightInput(
            kilograms: AppUserSettings.defaultFreshwaterWeightKilograms(),
            displayUnits: system
        )
    }

    private func persistDefaultWeightText(
        _ text: String,
        setter: (Double?) -> Void
    ) {
        let system: DiveDisplayUnitSystem = useImperialDisplayUnits ? .imperial : .metric
        setter(DiveActivityFieldValueParsing.parseDiverWeightKilograms(text, displayUnits: system))
    }

    private var defaultTankSelection: Binding<DefaultTankSize> {
        Binding(
            get: { DefaultTankSize(rawValue: defaultTankSizeRaw) ?? .al80 },
            set: { defaultTankSizeRaw = $0.rawValue }
        )
    }
}

private struct SettingsMediaBackfillOverlayLayer: View {
    let overlay: DiveLibraryMediaBackfillOverlayState
    let onDismiss: () -> Void
    let onCancel: () -> Void

    var body: some View {
        Group {
            if overlay.isVisible {
                switch overlay {
                case .running:
                    DiveLibraryMediaBackfillProgressOverlay(
                        state: overlay,
                        onDismiss: onDismiss,
                        onCancel: onCancel
                    )
                case .finished, .cancelled:
                    DiveLibraryMediaBackfillProgressOverlay(
                        state: overlay,
                        onDismiss: onDismiss,
                        onCancel: nil
                    )
                case .hidden:
                    EmptyView()
                }
            }
        }
        .zIndex(2)
    }
}

#Preview {
    SettingsView()
        .environment(AccountSession.shared)
        .modelContainer(
            for: [
                DiveActivity.self,
                DiveBuddy.self,
                DiveBuddyTag.self,
                DiveProfilePoint.self,
                DiveSite.self,
            ],
            inMemory: true
        )
}
