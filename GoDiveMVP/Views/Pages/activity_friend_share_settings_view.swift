import FirebaseAuth
import SwiftData
import SwiftUI

struct DiveActivityFriendShareSettingsView: View {
    @Bindable var activity: DiveActivity

    var body: some View {
        ActivityFriendShareSettingsForm(
            activityID: activity.id,
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
            onPersist: persistDraft
        )
        .onAppear(perform: loadDraftFromActivity)
    }

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
}

struct SnorkelActivityFriendShareSettingsView: View {
    @Bindable var activity: SnorkelActivity

    var body: some View {
        ActivityFriendShareSettingsForm(
            activityID: activity.id,
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
            onPersist: persistDraft
        )
        .onAppear(perform: loadDraftFromActivity)
    }

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
}

// MARK: - Shared form

private struct ActivityFriendShareSettingsForm: View {
    let activityID: UUID
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

    @AppStorage(AppUserSettings.shareDivesWithFriendsKey) private var globalShareEnabled = true

    @State private var statusChecklist: ActivityFriendShareStatusPresentation.ShareStatusChecklist?
    @State private var statusRefreshTask: Task<Void, Never>?

    private var mediaSelectionEnabled: Bool {
        shareActivityEnabled.wrappedValue
    }

    private var notesControlsEnabled: Bool {
        shareActivityEnabled.wrappedValue
    }

    var body: some View {
        NavigationStack {
            AppPage(
                title: ActivityFriendSharePresentation.settingsPageTitle,
                showsBackButton: true,
                showsBrandWordmark: false,
                scrollContentUnderHeader: true
            ) {
                settingsFormContent
            }
        }
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
        .onChange(of: publicNotes) { _, _ in
            onPersist()
        }
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

            notesSection

            statusFooter
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.bottom, AppTheme.Spacing.lg)
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

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SettingsPickerRow(
                title: ActivityFriendSharePresentation.shareNotesTitle,
                infoMessage: ActivityFriendSharePresentation.shareNotesInfo,
                selection: $notesMode,
                options: ActivityFriendShareNotesMode.allCases.map { mode in
                    (mode, mode.settingsLabel)
                }
            )
            .disabled(!notesControlsEnabled)

            if notesMode == .publicNotes {
                TextField(
                    ActivityFriendSharePresentation.publicNotesPlaceholder,
                    text: $publicNotes,
                    axis: .vertical
                )
                .lineLimit(3...8)
                .textFieldStyle(.roundedBorder)
                .disabled(!notesControlsEnabled)
            }
        }
        .accessibilityIdentifier("ActivityFriendShare.NotesSection")
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
        .padding(.top, AppTheme.Spacing.md)
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
