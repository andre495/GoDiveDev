import FirebaseAuth
import SwiftData
import SwiftUI

struct DiveActivityFriendShareSettingsView: View {
    @Bindable var activity: DiveActivity
    var onDeleted: () -> Void = {}

    var body: some View {
        ActivityFriendShareSettingsForm(
            activityID: activity.id,
            activityKind: .scubaDive,
            sortedDiveMedia: DiveActivityMediaPresentation.sortedPhotos(on: activity),
            sortedSnorkelMedia: [],
            shareActivityEnabled: shareActivityBinding,
            shareMediaEnabled: shareMediaBinding,
            selectedMediaIDs: $draftSelectedMediaIDs,
            notesMode: $draftNotesMode,
            publicNotes: $draftPublicNotes,
            shouldPublish: {
                ActivityFriendShareConfiguration.shouldPublish(dive: activity)
            },
            shareMediaEnabledForStatus: {
                ActivityFriendShareConfiguration.shareMediaEnabled(on: activity)
            },
            privateNotesText: { activity.notes },
            onPersist: persistDraft,
            onPerformDelete: performDelete,
            onDeleted: onDeleted
        )
        .onAppear(perform: loadDraftFromActivity)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountSession.self) private var accountSession
    @AppStorage(AppUserSettings.automaticallyRenumberDivesKey) private var automaticallyRenumberDives = true

    @State private var draftShareActivityEnabled = true
    @State private var draftShareMediaEnabled = false
    @State private var draftSelectedMediaIDs: Set<UUID> = []
    @State private var draftNotesMode: ActivityFriendShareNotesMode = .off
    @State private var draftPublicNotes = ""

    private var shareActivityBinding: Binding<Bool> {
        Binding(
            get: { draftShareActivityEnabled },
            set: { newValue in
                draftShareActivityEnabled = newValue
                if !newValue {
                    draftShareMediaEnabled = false
                }
                persistDraft()
            }
        )
    }

    private var shareMediaBinding: Binding<Bool> {
        Binding(
            get: { draftShareMediaEnabled },
            set: { newValue in
                draftShareMediaEnabled = newValue
                if newValue, draftSelectedMediaIDs.isEmpty {
                    draftSelectedMediaIDs = Set(
                        DiveActivityMediaPresentation.sortedPhotos(on: activity).map(\.id)
                    )
                }
                persistDraft()
            }
        )
    }

    private func loadDraftFromActivity() {
        if ActivityFriendShareConfiguration.usesPerActivitySettings(on: activity) {
            draftShareActivityEnabled = activity.friendShareActivityEnabled
            draftShareMediaEnabled = activity.friendShareMediaEnabled
            draftNotesMode = ActivityFriendShareNotesMode(rawValue: activity.friendShareNotesModeRaw) ?? .off
            draftPublicNotes = activity.friendSharePublicNotes ?? ""
            draftSelectedMediaIDs = ActivityFriendShareConfiguration.displaySelectedMediaIDs(
                on: activity,
                galleryIDs: DiveActivityMediaPresentation.sortedPhotos(on: activity).map(\.id)
            )
        } else {
            let defaults = ActivityFriendShareConfiguration.draftFieldsForDisplay(on: activity)
            draftShareActivityEnabled = defaults.shareActivity
            draftShareMediaEnabled = defaults.shareMedia
            draftNotesMode = defaults.notesMode
            draftPublicNotes = activity.friendSharePublicNotes ?? ""
            draftSelectedMediaIDs = Set(
                DiveActivityMediaPresentation.sortedPhotos(on: activity).map(\.id)
            )
        }
    }

    private func persistDraft() {
        ActivityFriendShareConfiguration.applyConfiguredSettings(
            to: activity,
            shareActivityEnabled: draftShareActivityEnabled,
            shareMediaEnabled: draftShareMediaEnabled,
            selectedMediaIDs: draftSelectedMediaIDs,
            notesMode: draftNotesMode,
            publicNotes: DiveNotesValidation.cappedNotes(draftPublicNotes)
        )
        try? modelContext.save()
        guard let ownerProfileID = accountSession.currentProfile?.id else { return }
        GoDiveFriendShareRefreshCoordinator.scheduleUpsert(
            diveIDs: [activity.id],
            ownerProfileID: ownerProfileID,
            modelContext: modelContext
        )
    }

    private func performDelete(reportProgress: @escaping @MainActor @Sendable (Double) -> Void) async throws {
        let activityID = activity.id
        let renumberAfterDelete = automaticallyRenumberDives
        try await DiveActivityDeletion.delete(
            DiveActivityDeletion.Request(
                activityID: activityID,
                deletedStartTime: activity.startTime,
                deletedId: activityID,
                renumberAfterDelete: renumberAfterDelete
            ),
            container: modelContext.container,
            deferRenumber: renumberAfterDelete,
            mainModelContext: modelContext,
            reportProgress: reportProgress
        )
        if renumberAfterDelete {
            await DivePostDeleteRenumberScheduler.shared.waitForPending()
        }
        ActivityDeleteSuccessPresentation.postDidDelete(activityID: activityID)
        dismiss()
        onDeleted()
    }
}

struct SnorkelActivityFriendShareSettingsView: View {
    @Bindable var activity: SnorkelActivity
    var onDeleted: () -> Void = {}

    var body: some View {
        ActivityFriendShareSettingsForm(
            activityID: activity.id,
            activityKind: .snorkel,
            sortedDiveMedia: [],
            sortedSnorkelMedia: SnorkelActivityMediaPresentation.sortedPhotos(activity.mediaPhotos),
            shareActivityEnabled: shareActivityBinding,
            shareMediaEnabled: shareMediaBinding,
            selectedMediaIDs: $draftSelectedMediaIDs,
            notesMode: $draftNotesMode,
            publicNotes: $draftPublicNotes,
            shouldPublish: {
                ActivityFriendShareConfiguration.shouldPublish(snorkel: activity)
            },
            shareMediaEnabledForStatus: {
                ActivityFriendShareConfiguration.shareMediaEnabled(on: activity)
            },
            privateNotesText: { activity.notes },
            onPersist: persistDraft,
            onPerformDelete: performDelete,
            onDeleted: onDeleted
        )
        .onAppear(perform: loadDraftFromActivity)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountSession.self) private var accountSession

    @State private var draftShareActivityEnabled = true
    @State private var draftShareMediaEnabled = false
    @State private var draftSelectedMediaIDs: Set<UUID> = []
    @State private var draftNotesMode: ActivityFriendShareNotesMode = .off
    @State private var draftPublicNotes = ""

    private var shareActivityBinding: Binding<Bool> {
        Binding(
            get: { draftShareActivityEnabled },
            set: { newValue in
                draftShareActivityEnabled = newValue
                if !newValue {
                    draftShareMediaEnabled = false
                }
                persistDraft()
            }
        )
    }

    private var shareMediaBinding: Binding<Bool> {
        Binding(
            get: { draftShareMediaEnabled },
            set: { newValue in
                draftShareMediaEnabled = newValue
                if newValue, draftSelectedMediaIDs.isEmpty {
                    draftSelectedMediaIDs = Set(
                        SnorkelActivityMediaPresentation.sortedPhotos(activity.mediaPhotos).map(\.id)
                    )
                }
                persistDraft()
            }
        )
    }

    private func loadDraftFromActivity() {
        if ActivityFriendShareConfiguration.usesPerActivitySettings(on: activity) {
            draftShareActivityEnabled = activity.friendShareActivityEnabled
            draftShareMediaEnabled = activity.friendShareMediaEnabled
            draftNotesMode = ActivityFriendShareNotesMode(rawValue: activity.friendShareNotesModeRaw) ?? .off
            draftPublicNotes = activity.friendSharePublicNotes ?? ""
            draftSelectedMediaIDs = ActivityFriendShareConfiguration.displaySelectedMediaIDs(
                on: activity,
                galleryIDs: SnorkelActivityMediaPresentation.sortedPhotos(activity.mediaPhotos).map(\.id)
            )
        } else {
            let defaults = ActivityFriendShareConfiguration.draftFieldsForDisplay(on: activity)
            draftShareActivityEnabled = defaults.shareActivity
            draftShareMediaEnabled = defaults.shareMedia
            draftNotesMode = defaults.notesMode
            draftPublicNotes = activity.friendSharePublicNotes ?? ""
            draftSelectedMediaIDs = Set(
                SnorkelActivityMediaPresentation.sortedPhotos(activity.mediaPhotos).map(\.id)
            )
        }
    }

    private func persistDraft() {
        ActivityFriendShareConfiguration.applyConfiguredSettings(
            to: activity,
            shareActivityEnabled: draftShareActivityEnabled,
            shareMediaEnabled: draftShareMediaEnabled,
            selectedMediaIDs: draftSelectedMediaIDs,
            notesMode: draftNotesMode,
            publicNotes: DiveNotesValidation.cappedNotes(draftPublicNotes)
        )
        try? modelContext.save()
        guard let ownerProfileID = accountSession.currentProfile?.id else { return }
        GoDiveFriendShareRefreshCoordinator.scheduleUpsert(
            diveIDs: [activity.id],
            ownerProfileID: ownerProfileID,
            modelContext: modelContext
        )
    }

    private func performDelete(reportProgress: @escaping @MainActor @Sendable (Double) -> Void) async throws {
        let activityID = activity.id
        try await SnorkelActivityDeletion.deletePermanently(
            activity,
            modelContext: modelContext,
            reportProgress: reportProgress
        )
        ActivityDeleteSuccessPresentation.postDidDelete(activityID: activityID)
        dismiss()
        onDeleted()
    }
}

// MARK: - Shared form

private struct ActivityFriendShareSettingsForm: View {
    let activityID: UUID
    let activityKind: FriendSharedActivityKind
    let sortedDiveMedia: [DiveMediaPhoto]
    let sortedSnorkelMedia: [SnorkelMediaPhoto]
    let shareActivityEnabled: Binding<Bool>
    let shareMediaEnabled: Binding<Bool>
    @Binding var selectedMediaIDs: Set<UUID>
    @Binding var notesMode: ActivityFriendShareNotesMode
    @Binding var publicNotes: String
    let shouldPublish: () -> Bool
    let shareMediaEnabledForStatus: () -> Bool
    let privateNotesText: () -> String?
    let onPersist: () -> Void
    let onPerformDelete: (@escaping @MainActor @Sendable (Double) -> Void) async throws -> Void
    let onDeleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppUserSettings.shareDivesWithFriendsKey) private var globalShareEnabled = true

    @State private var statusChecklist: ActivityFriendShareStatusPresentation.ShareStatusChecklist?
    @State private var statusRefreshTask: Task<Void, Never>?
    @State private var showsDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteProgress: Double = 0
    @State private var deleteErrorMessage: String?

    private var mediaSelectionEnabled: Bool {
        shareActivityEnabled.wrappedValue
    }

    private var notesControlsEnabled: Bool {
        shareActivityEnabled.wrappedValue
    }

    private var sharePrivateNotesBinding: Binding<Bool> {
        Binding(
            get: { notesMode.sharePrivateNotesToggleIsOn },
            set: { notesMode = ActivityFriendShareNotesMode.fromSharePrivateNotesToggle($0) }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    settingsFormContent
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.top, DiveActivityOverviewPanelMetrics.panelContentTopPadding)
                        .padding(.bottom, AppTheme.Spacing.lg)
                }
                .scrollIndicators(.visible)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                activityDeleteSection
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.top, AppTheme.Spacing.md)
                    .padding(.bottom, AppTheme.Spacing.lg)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(ActivitySettingsPresentation.pageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppGlassToolbarCancelButton(
                        action: { dismiss() },
                        accessibilityIdentifier: "ActivitySettings.Cancel"
                    )
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppGlassProminentDoneButton(
                        action: { dismiss() },
                        accessibilityIdentifier: "ActivitySettings.Done"
                    )
                }
            }
        }
        .diveActivityOverviewPanelModalSheetPresentation()
        .accessibilityIdentifier("ActivitySettings.Root")
        .onAppear {
            scheduleStatusRefresh()
        }
        .onDisappear {
            statusRefreshTask?.cancel()
            statusRefreshTask = nil
        }
        .onChange(of: shareActivityEnabled.wrappedValue) { _, _ in
            scheduleStatusRefresh()
        }
        .onChange(of: shareMediaEnabled.wrappedValue) { _, _ in
            scheduleStatusRefresh()
        }
        .onChange(of: notesMode) { _, _ in
            onPersist()
            scheduleStatusRefresh()
        }
        .onChange(of: selectedMediaIDs) { _, _ in
            onPersist()
            scheduleStatusRefresh()
        }
        .alert(
            ActivitySettingsPresentation.deleteFailedAlertTitle,
            isPresented: deleteErrorBinding
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage ?? "Try again.")
        }
        .confirmationDialog(
            ActivitySettingsPresentation.deleteConfirmationTitle(activityKind: activityKind),
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                ActivitySettingsPresentation.deleteButtonTitle(activityKind: activityKind),
                role: .destructive
            ) {
                confirmDelete()
            }
        } message: {
            Text(ActivitySettingsPresentation.deleteConfirmationMessage)
        }
        .overlay {
            if isDeleting {
                ActivityDeleteProgressOverlay(
                    progress: deleteProgress,
                    accessibilityLabel: ActivitySettingsPresentation.deleteProgressAccessibilityLabel(
                        activityKind: activityKind
                    )
                )
            }
        }
    }

    private var deleteErrorBinding: Binding<Bool> {
        Binding(
            get: { deleteErrorMessage != nil },
            set: { if !$0 { deleteErrorMessage = nil } }
        )
    }

    private var settingsFormContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            if !globalShareEnabled {
                Text(ActivityFriendSharePresentation.globalSharingOffMessage)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            SettingsToggleRow(
                title: ActivityFriendSharePresentation.shareActivityTitle,
                infoMessage: ActivityFriendSharePresentation.shareActivityInfo,
                isOn: shareActivityEnabled
            )

            SettingsToggleRow(
                title: ActivityFriendSharePresentation.shareMediaTitle,
                infoMessage: ActivityFriendSharePresentation.shareMediaInfo,
                isOn: shareMediaEnabled
            )
            .disabled(!shareActivityEnabled.wrappedValue)

            SettingsNavigationLinkRow(
                title: ActivityFriendSharePresentation.selectMediaTitle,
                infoMessage: ActivityFriendSharePresentation.shareMediaInfo
            ) {
                mediaSelectionDestination
            }
            .disabled(!mediaSelectionEnabled || !shareMediaEnabled.wrappedValue)
            .opacity(mediaSelectionEnabled && shareMediaEnabled.wrappedValue ? 1 : 0.45)

            SettingsToggleRow(
                title: ActivityFriendSharePresentation.shareNotesTitle,
                infoMessage: ActivityFriendSharePresentation.shareNotesInfo,
                isOn: sharePrivateNotesBinding
            )
            .disabled(!notesControlsEnabled)
            .accessibilityIdentifier("ActivityFriendShare.NotesSection")

            statusFooter
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var activityDeleteSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Divider()

            Button(
                ActivitySettingsPresentation.deleteButtonTitle(activityKind: activityKind),
                role: .destructive
            ) {
                showsDeleteConfirmation = true
            }
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(isDeleting)
            .accessibilityIdentifier("ActivitySettings.Delete")
        }
    }

    private func confirmDelete() {
        guard !isDeleting else { return }
        isDeleting = true
        deleteProgress = 0.06
        Task { @MainActor in
            do {
                try await onPerformDelete { progress in
                    deleteProgress = progress
                }
            } catch {
                deleteErrorMessage = error.localizedDescription
                isDeleting = false
                deleteProgress = 0
            }
        }
    }

    @ViewBuilder
    private var mediaSelectionDestination: some View {
        if !sortedDiveMedia.isEmpty {
            ActivityFriendShareMediaSelectionView(
                mediaSource: .dive(sortedDiveMedia),
                selectedMediaIDs: $selectedMediaIDs,
                isEnabled: mediaSelectionEnabled && shareMediaEnabled.wrappedValue
            )
        } else {
            ActivityFriendShareMediaSelectionView(
                mediaSource: .snorkel(sortedSnorkelMedia),
                selectedMediaIDs: $selectedMediaIDs,
                isEnabled: mediaSelectionEnabled && shareMediaEnabled.wrappedValue
            )
        }
    }

    @ViewBuilder
    private var statusFooter: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Divider()
            if let checklist = statusChecklist {
                if checklist.isUploading {
                    uploadInProgressBanner
                }
                shareChecklistRows(checklist)
            } else {
                Text(ActivityFriendSharePresentation.statusSharingOffLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityIdentifier("ActivityFriendShare.StatusLabel")
            }
        }
    }

    private var uploadInProgressBanner: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ProgressView()
                .controlSize(.small)
            Text(ActivityFriendSharePresentation.statusUploadBannerLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.accent)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityIdentifier("ActivityFriendShare.StatusLabel")
    }

    private func shareChecklistRows(
        _ checklist: ActivityFriendShareStatusPresentation.ShareStatusChecklist
    ) -> some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            shareChecklistRow(
                title: ActivityFriendSharePresentation.statusActivityRowTitle,
                state: checklist.activity,
                accessibilityIdentifier: "ActivityFriendShare.Status.Activity"
            )
            shareChecklistRow(
                title: ActivityFriendSharePresentation.statusMediaRowTitle,
                state: checklist.media,
                accessibilityIdentifier: "ActivityFriendShare.Status.Media"
            )
            shareChecklistRow(
                title: ActivityFriendSharePresentation.statusNotesRowTitle,
                state: checklist.notes,
                accessibilityIdentifier: "ActivityFriendShare.Status.Notes"
            )
        }
    }

    private func shareChecklistRow(
        title: String,
        state: ActivityFriendShareStatusPresentation.ShareItemState,
        accessibilityIdentifier: String
    ) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: checklistIconName(for: state))
                .font(.subheadline)
                .foregroundStyle(checklistIconColor(for: state))
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Spacer()
            Text(checklistStateLabel(for: state))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(checklistStateColor(for: state))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func checklistIconName(for state: ActivityFriendShareStatusPresentation.ShareItemState) -> String {
        switch state {
        case .shared: "checkmark.circle.fill"
        case .inProgress: "arrow.up.circle"
        case .off: "minus.circle"
        }
    }

    private func checklistIconColor(for state: ActivityFriendShareStatusPresentation.ShareItemState) -> Color {
        switch state {
        case .shared: AppTheme.Colors.accent
        case .inProgress: AppTheme.Colors.accent
        case .off: AppTheme.Colors.secondaryText
        }
    }

    private func checklistStateLabel(for state: ActivityFriendShareStatusPresentation.ShareItemState) -> String {
        switch state {
        case .shared: ActivityFriendSharePresentation.statusSharedLabel
        case .inProgress: ActivityFriendSharePresentation.statusUploadingLabel
        case .off: ActivityFriendSharePresentation.statusOffLabel
        }
    }

    private func checklistStateColor(for state: ActivityFriendShareStatusPresentation.ShareItemState) -> Color {
        switch state {
        case .shared: AppTheme.Colors.textPrimary
        case .inProgress: AppTheme.Colors.accent
        case .off: AppTheme.Colors.secondaryText
        }
    }

    private func scheduleStatusRefresh() {
        statusRefreshTask?.cancel()
        statusRefreshTask = Task {
            await refreshStatus()
            guard statusChecklist?.isUploading == true else { return }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            scheduleStatusRefresh()
        }
    }

    @MainActor
    private func refreshStatus() async {
        let ownerUID = Auth.auth().currentUser?.uid
        let galleryIDs = sortedDiveMedia.isEmpty
            ? Set(sortedSnorkelMedia.map(\.id))
            : Set(sortedDiveMedia.map(\.id))
        let hasShareableMedia = !selectedMediaIDs.intersection(galleryIDs).isEmpty
        let notesExpected = ActivityFriendShareStatusPresentation.notesExpected(
            mode: notesMode,
            privateNotes: privateNotesText(),
            publicNotes: publicNotes
        )
        statusChecklist = await ActivityFriendShareStatusPresentation.refreshChecklist(
            activityID: activityID,
            shouldPublish: globalShareEnabled && shouldPublish(),
            shareMediaEnabled: shareMediaEnabledForStatus(),
            hasShareableMedia: hasShareableMedia,
            notesExpected: notesExpected,
            ownerUID: ownerUID
        )
    }
}
