import Foundation

enum ActivityFriendSharePresentation: Sendable {
    static let settingsPageTitle = "Buddy Sharing"
    static let shareActivityTitle = "Share activity with buddies"
    static let shareActivityInfo = "When on, buddies can see this activity in your shared logbook. Turn off to keep this dive or snorkel private."

    static let shareMediaTitle = "Share media with buddies"
    static let shareMediaInfo = "Choose which photos and videos from this activity are visible to buddies."
    static let selectMediaTitle = "Choose shared media"

    static let shareNotesTitle = "Share private notes with buddies"
    static let shareNotesInfo = "When on, your private activity notes are included for buddies on this activity. Off keeps notes private."

    static let globalSharingOffMessage = "Buddy sharing is off in Settings, so nothing is published until you turn on Share activities with buddies. Per-activity choices are saved and apply when sharing is enabled."

    static let editButtonAccessibilityLabel = "Activity settings"

    // MARK: - Publish status footer

    static let statusSharingOffLabel = "Sharing Off"
    static let statusUploadBannerLabel = "Upload in progress…"
    static let statusActivityRowTitle = "Activity"
    static let statusMediaRowTitle = "Media"
    static let statusNotesRowTitle = "Private Notes"
    static let statusSharedLabel = "Shared"
    static let statusUploadingLabel = "Uploading"
    static let statusOffLabel = "Off"
}
