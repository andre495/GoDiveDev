import Foundation

extension Notification.Name {
    /// Posted when connectivity may allow deferred friend-share content uploads (Wi‑Fi available).
    static let goDiveSharedMediaContentUploadDue = Notification.Name("goDiveSharedMediaContentUploadDue")
}

/// Policy for dive / catalog media when the device has no usable network (e.g. airplane mode).
enum AppNetworkConnectivityPresentation: Sendable {

    nonisolated static func isConnected(pathStatusSatisfied: Bool) -> Bool {
        pathStatusSatisfied
    }

    nonisolated static func allowsCloudMediaFetch(isConnected: Bool) -> Bool {
        isConnected
    }

    nonisolated static func allowsFullResolutionMediaUpgrade(isConnected: Bool) -> Bool {
        isConnected
    }

    /// PhotoKit **`isNetworkAccessAllowed`** for library references.
    nonisolated static func photoKitAllowsNetworkAccess(isConnected: Bool) -> Bool {
        isConnected
    }

    /// Friend-share **content-tier** uploads (full JPEG / MP4). Thumbnails may still upload on cellular.
    nonisolated static func allowsFriendShareContentUpload(
        isConnected: Bool,
        usesWiFi: Bool,
        wifiOnly: Bool
    ) -> Bool {
        guard isConnected else { return false }
        guard wifiOnly else { return true }
        return usesWiFi
    }

    /// Friend-visible **content-tier** downloads (full JPEG / MP4 stream). Thumbnails may still load on cellular.
    nonisolated static func allowsFriendSharedMediaContentDownload(
        isConnected: Bool,
        usesWiFi: Bool,
        wifiOnly: Bool,
        allowsConstrainedNetworkAccess: Bool
    ) -> Bool {
        FriendSharedMediaPresentation.allowsContentDownload(
            isConnected: isConnected,
            usesWiFi: usesWiFi,
            wifiOnly: wifiOnly,
            allowsConstrainedNetworkAccess: allowsConstrainedNetworkAccess
        )
    }
}
