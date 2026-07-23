import Foundation

/// Copy and hub options for Logbook **+** → add-activity flow.
enum LogbookAddActivityPresentation: Sendable {
    static let hubPageTitle = "Add activity"
    static let diveUploadPageTitle = "New dive activity"
    static let snorkelUploadPageTitle = "New snorkel activity"
    static let connectDevicePageTitle = "Connect device"

    static let connectDeviceComingSoonMessage =
        "Pair a dive computer or wearable to import activities automatically. This feature is on the way."

    struct HubOption: Identifiable, Sendable {
        let id: String
        let title: String
        let subtitle: String
        let systemImage: String
        let route: LogbookRoute
        let accessibilityIdentifier: String
    }

    static let hubOptions: [HubOption] = [
        HubOption(
            id: "dive",
            title: "New Dive Activity",
            subtitle: "Import a scuba dive or add one manually.",
            systemImage: "water.waves",
            route: .diveActivityUpload,
            accessibilityIdentifier: "Logbook.AddActivityHub.Dive"
        ),
        HubOption(
            id: "snorkel",
            title: "New Snorkel Activity",
            subtitle: "Import a snorkel session from a FIT file.",
            systemImage: "figure.open.water.swim",
            route: .snorkelActivityUpload,
            accessibilityIdentifier: "Logbook.AddActivityHub.Snorkel"
        ),
        HubOption(
            id: "device",
            title: "Connect Device",
            subtitle: "Link a dive computer or wearable.",
            systemImage: "applewatch.radiowaves.left.and.right",
            route: .connectDeviceComingSoon,
            accessibilityIdentifier: "Logbook.AddActivityHub.ConnectDevice"
        ),
    ]
}
