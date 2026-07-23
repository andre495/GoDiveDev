import SwiftUI

/// Read-only detail for one friend-visible dive projection.
struct FriendSharedDiveDetailView: View {
    let dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    let friendName: String

    @Environment(AccountSession.self) private var accountSession

    private var currentUID: String? {
        GoDiveFirestoreUserProfileMapping.loadCachedFirebaseUID()
    }

    var body: some View {
        AppHeaderlessPage {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    HStack {
                        SecondaryDestinationBackButton()
                        Text(GoDiveSharedDiveProjectionMapping.displayTitle(for: dive))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .lineLimit(2)
                        Spacer()
                    }

                    if GoDiveSharedDiveProjectionMapping.wasCurrentUserTagged(
                        dive: dive,
                        currentFirebaseUID: currentUID
                    ) {
                        Label(
                            GoDiveFriendsPresentation.taggedYouLabel,
                            systemImage: "person.crop.circle.badge.checkmark"
                        )
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.accent)
                    }

                    detailRow("From", friendName)
                    if let start = dive.startTime {
                        detailRow("Date", start.formatted(date: .long, time: .shortened))
                    }
                    if let number = dive.diveNumber {
                        detailRow("Dive #", "\(number)")
                    }
                    if let max = dive.maxDepthMeters {
                        detailRow("Max depth", String(format: "%.1f m", max))
                    }
                    if let avg = dive.averageDepthMeters {
                        detailRow("Avg depth", String(format: "%.1f m", avg))
                    }
                    if let minutes = dive.durationMinutes {
                        detailRow("Duration", "\(minutes) min")
                    }
                    if let bottom = dive.bottomTimeSeconds {
                        detailRow("Bottom time", "\(bottom / 60) min")
                    }
                    if let temp = dive.waterTempMinCelsius {
                        detailRow("Min temp", String(format: "%.1f °C", temp))
                    }
                    if let gas = dive.gasType {
                        detailRow("Gas", gas)
                    }
                    if let mix = dive.oxygenMix {
                        detailRow("O₂", String(format: "%.0f%%", mix))
                    }
                    if let tank = dive.tankVolumeDescription {
                        detailRow("Tank", tank)
                    }

                    if !dive.activityTagNames.isEmpty {
                        sectionTitle("Tags")
                        Text(dive.activityTagNames.joined(separator: ", "))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }

                    if !dive.taggedBuddies.isEmpty {
                        sectionTitle("Buddies")
                        ForEach(Array(dive.taggedBuddies.enumerated()), id: \.offset) { _, buddy in
                            Text(buddy.displayName)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                        }
                    }

                    if !dive.sightings.isEmpty {
                        sectionTitle("Marine life")
                        ForEach(Array(dive.sightings.enumerated()), id: \.offset) { _, sighting in
                            Text(sighting.commonName)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                        }
                    }

                    if !dive.equipmentSummary.isEmpty {
                        sectionTitle("Equipment")
                        Text(dive.equipmentSummary.joined(separator: ", "))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }

                    if let notes = dive.notes, !notes.isEmpty {
                        sectionTitle("Notes")
                        Text(notes)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    } else {
                        Text(GoDiveFriendsPresentation.notesHiddenLabel)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }

                    if dive.mediaPreviews.isEmpty {
                        Text(GoDiveFriendsPresentation.mediaHiddenLabel)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    } else {
                        sectionTitle("Media")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppTheme.Spacing.sm) {
                                ForEach(dive.mediaPreviews, id: \.photoID) { preview in
                                    AsyncImage(url: URL(string: preview.previewURL)) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image.resizable().scaledToFill()
                                        default:
                                            Color.gray.opacity(0.2)
                                        }
                                    }
                                    .frame(width: 120, height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }
                        }
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
        }
        .hidesBottomTabBarWhenPushed()
        .accessibilityIdentifier("FriendSharedDiveDetail.Root")
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .padding(.top, AppTheme.Spacing.sm)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(AppTheme.Colors.secondaryText)
            Spacer()
            Text(value)
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .font(.body)
    }
}
