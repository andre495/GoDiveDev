import SwiftUI

/// Read-only list of a friend’s shared dive projections.
struct FriendSharedLogbookView: View {
    let friend: GoDiveFriendGraphService.FriendEdge

    @State private var dives: [GoDiveSharedDiveProjectionMapping.FriendVisibleDive] = []
    @State private var isLoading = true

    var body: some View {
        AppHeaderlessPage {
            VStack(spacing: 0) {
                HStack {
                    SecondaryDestinationBackButton()
                    NavigationLink {
                        FriendProfileView(friend: friend)
                    } label: {
                        Text(friend.displayName)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.vertical, AppTheme.Spacing.sm)

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if dives.isEmpty {
                    emptyState
                } else {
                    List(dives) { dive in
                        NavigationLink {
                            FriendSharedDiveDetailView(dive: dive, friendName: friend.displayName)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(GoDiveSharedDiveProjectionMapping.displayTitle(for: dive))
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(AppTheme.Colors.textPrimary)
                                Text(subtitle(for: dive))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .hidesBottomTabBarWhenPushed()
        .task { await load() }
        .accessibilityIdentifier("FriendSharedLogbook.Root")
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Text(GoDiveFriendsPresentation.sharedLogbookEmptyTitle)
                .font(.title3.weight(.semibold))
            Text(GoDiveFriendsPresentation.sharedLogbookEmptyMessage)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func subtitle(for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive) -> String {
        var parts: [String] = []
        if let number = dive.diveNumber {
            parts.append("#\(number)")
        }
        if let start = dive.startTime {
            parts.append(start.formatted(date: .abbreviated, time: .omitted))
        }
        if let max = dive.maxDepthMeters {
            parts.append(String(format: "%.0f m", max))
        }
        if let minutes = dive.durationMinutes {
            parts.append("\(minutes) min")
        }
        return parts.joined(separator: " · ")
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        dives = await GoDiveSharedDiveProjectionSync.fetchFriendSharedDives(friendUID: friend.friendUID)
    }
}
