import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// List and manage **`Certification`** rows for the signed-in profile.
struct CertificationsListView: View {
    @Environment(AccountSession.self) private var accountSession
    @Environment(\.modelContext) private var modelContext

    @Query(
        sort: [
            SortDescriptor(\Certification.dateAttained, order: .reverse),
            SortDescriptor(\Certification.agency, order: .forward),
        ]
    )
    private var allCertifications: [Certification]

    @State private var showsAddCertificationSheet = false
    @State private var certificationPendingDeletion: Certification?
    @State private var optimisticallyRemovedCertificationIDs: Set<UUID> = []

    private var ownedCertifications: [Certification] {
        guard let ownerID = accountSession.currentProfile?.id else { return [] }
        let owned = allCertifications.filter {
            $0.ownerProfileID == ownerID && !optimisticallyRemovedCertificationIDs.contains($0.id)
        }
        return CertificationPresentation.sortedForList(owned)
    }

    var body: some View {
        ZStack {
            AppPage(
                title: "Certifications",
                showsBackButton: true,
                showsBrandWordmark: false,
                titlePlacement: AppHeaderStackedTitleChrome.titlePlacement,
                scrollContentUnderHeader: true,
                trailingContent: {
                addCertificationToolbarButton
            }, content: {
                if ownedCertifications.isEmpty {
                    AppScrollUnderHeaderEmptyState {
                        emptyCertificationsState
                    }
                } else {
                    certificationsList
                }
            })

            if certificationPendingDeletion != nil {
                deleteFlowOverlay
            }
        }
        .hidesBottomTabBarWhenPushed()
        .sheet(isPresented: $showsAddCertificationSheet) {
            CertificationAddSheetView {
                showsAddCertificationSheet = false
            }
        }
    }

    private var addCertificationToolbarButton: some View {
        Button {
            showsAddCertificationSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add certification")
        .accessibilityIdentifier("CertificationsList.AddNew")
    }

    private var emptyCertificationsState: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.Colors.accent.opacity(0.85))

            Text("No certifications yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text("Tap + in the corner to log your first card.")
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.lg)
        .accessibilityIdentifier("CertificationsList.EmptyState")
    }

    private var certificationsList: some View {
        AppScrollUnderHeaderList(listAccessibilityIdentifier: "CertificationsList.List") {
            ForEach(ownedCertifications, id: \.id) { certification in
                NavigationLink {
                    ViewCertificationDetails(certification: certification)
                } label: {
                    CertificationListRowView(certification: certification)
                }
                .buttonStyle(.plain)
                .navigationLinkIndicatorVisibility(.hidden)
                .listRowInsets(AppScrollUnderHeaderListLayout.horizontalRowInsets)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        certificationPendingDeletion = certification
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var deleteFlowOverlay: some View {
        Group {
            if let certification = certificationPendingDeletion {
                confirmDeleteOverlay(certification: certification)
            }
        }
    }

    private func confirmDeleteOverlay(certification: Certification) -> some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.16)) {
                        certificationPendingDeletion = nil
                    }
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Text("Delete certification?")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("Are you sure? This cannot be undone.")
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .center) {
                    Button("Cancel") {
                        withAnimation(.easeOut(duration: 0.16)) {
                            certificationPendingDeletion = nil
                        }
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.tabSelected)
                    .buttonStyle(.plain)

                    Spacer(minLength: AppTheme.Spacing.lg)

                    Button("Delete") {
                        confirmDelete(certification)
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.red)
                    .buttonStyle(.plain)
                }
                .padding(.top, AppTheme.Spacing.sm)
            }
            .padding(AppTheme.Spacing.lg)
            .frame(maxWidth: 320, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.Colors.surfaceElevated)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.Colors.tabUnselected.opacity(0.15), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
            .accessibilityAddTraits(.isModal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("CertificationsList.DeleteConfirmation")
    }

    private func confirmDelete(_ certification: Certification) {
        let id = certification.id
        dismissDeleteOverlayImmediately()
        optimisticallyRemovedCertificationIDs.insert(id)
        Task(priority: .userInitiated) { @MainActor in
            await Task.yield()
            defer { optimisticallyRemovedCertificationIDs.remove(id) }
            try? CertificationDeletion.deletePermanently(certification, modelContext: modelContext)
        }
    }

    private func dismissDeleteOverlayImmediately() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            certificationPendingDeletion = nil
        }
    }
}

// MARK: - Row

private struct CertificationListRowView: View {
    let certification: Certification

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            rowThumbnail

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Text(CertificationPresentation.title(for: certification))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .lineLimit(2)

                    CertificationTypeBadge(cardType: certification.cardType)
                }

                Text(CertificationPresentation.subtitle(for: certification))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(AppTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel)
    }

    private var rowAccessibilityLabel: String {
        var parts = [CertificationPresentation.title(for: certification)]
        parts.append(certification.cardType.displayName)
        parts.append(CertificationPresentation.subtitle(for: certification))
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private var rowThumbnail: some View {
        #if canImport(UIKit)
        if let data = certification.certFrontPicture, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            rowThumbnailPlaceholder
        }
        #else
        rowThumbnailPlaceholder
        #endif
    }

    private var rowThumbnailPlaceholder: some View {
        Image(systemName: "checkmark.seal.fill")
            .font(.title3)
            .foregroundStyle(AppTheme.Colors.accent)
            .frame(width: 48, height: 36)
            .background(AppTheme.Colors.surfaceMuted.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        CertificationsListView()
    }
    .environment(AccountSession.shared)
    .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
