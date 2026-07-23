import SwiftData
import SwiftUI

/// Read-only certification detail with **Edit** sheet (blue sheet + front/back card hero).
struct ViewCertificationDetails: View {
    @Bindable var certification: Certification

    @Query private var ownerActivities: [DiveActivity]

    @State private var showsEditSheet = false
    @State private var heroSide: CertificationDetailHeroSide

    private static let noOwnerQueryToken = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    init(certification: Certification) {
        self.certification = certification
        let ownerID = AccountSession.shared.currentProfile?.id ?? Self.noOwnerQueryToken
        _ownerActivities = Query(
            filter: #Predicate<DiveActivity> { $0.ownerProfileID == ownerID },
            sort: [
                SortDescriptor(\.startTime, order: .reverse),
                SortDescriptor(\.id, order: .forward),
            ]
        )
        _heroSide = State(
            initialValue: CertificationDetailHeroPresentation.defaultHeroSide(
                frontPicture: certification.certFrontPicture,
                backPicture: certification.certBackPicture
            )
        )
    }

    private var showsHeroSideToggle: Bool {
        CertificationDetailHeroPresentation.showsHeroSideToggle(
            frontPicture: certification.certFrontPicture,
            backPicture: certification.certBackPicture
        )
    }

    private var heroPhotoData: Data? {
        CertificationDetailHeroPresentation.photoData(
            for: heroSide,
            frontPicture: certification.certFrontPicture,
            backPicture: certification.certBackPicture
        )
    }

    private var divesLoggedSinceAttainedCount: Int {
        CertificationPresentation.divesLoggedSinceAttainedCount(
            startTimes: ownerActivities.map(\.startTime),
            dateAttained: certification.dateAttained
        )
    }

    var body: some View {
        BlueSheetDetailPage(
            configuration: .pushedDetailWithStandardPanelBodySpacing(
                accessibilityRootIdentifier: "CertificationDetails.Root"
            ),
            hero: { _ in
                CertificationDetailHeroBand(photoData: heroPhotoData)
            },
            heroOverlay: { _ in
                if showsHeroSideToggle {
                    CertificationDetailHeroSideToggle(selectedSide: $heroSide)
                        .padding(.trailing, AppTheme.Spacing.md)
                        .padding(.bottom, CertificationDetailHeroPresentation.heroModeToggleBottomPadding)
                }
            },
            panelOverlay: { EmptyView() },
            pinnedContent: {
                certificationPinnedSummary
            },
            panelContent: { bottomScrollInset, _ in
                CertificationDetailContentPager(
                    certification: certification,
                    divesLoggedSinceAttainedCount: divesLoggedSinceAttainedCount,
                    bottomScrollInset: bottomScrollInset
                )
            },
            topChrome: { safeTop, topInset, _ in
                BlueSheetDetailTopChrome(
                    safeTop: safeTop,
                    topInset: topInset,
                    onEdit: { showsEditSheet = true },
                    editAccessibilityIdentifier: "CertificationDetails.Edit"
                )
            }
        )
        .sheet(isPresented: $showsEditSheet) {
            CertificationEditSheetView(certification: certification) {
                showsEditSheet = false
            }
        }
        .onChange(of: certification.certFrontPicture) { _, _ in
            syncHeroSideWithAvailablePhotos()
        }
        .onChange(of: certification.certBackPicture) { _, _ in
            syncHeroSideWithAvailablePhotos()
        }
    }

    private var certificationPinnedSummary: some View {
        BlueSheetPinnedSummary(
            title: CertificationPresentation.detailHeaderName(for: certification),
            accessibilityIdentifier: "CertificationDetails.TitleBlock",
            topRow: {
                CertificationTypeBadge(cardType: certification.cardType)
                    .accessibilityIdentifier("CertificationDetails.TypeBadge")
            }
        )
    }

    private func syncHeroSideWithAvailablePhotos() {
        let hasFront = certification.certFrontPicture != nil
        let hasBack = certification.certBackPicture != nil
        if !CertificationDetailHeroPresentation.showsHeroSideToggle(hasFront: hasFront, hasBack: hasBack) {
            heroSide = CertificationDetailHeroPresentation.defaultHeroSide(
                hasFront: hasFront,
                hasBack: hasBack
            )
            return
        }
        switch heroSide {
        case .front where !hasFront:
            heroSide = .back
        case .back where !hasBack:
            heroSide = .front
        default:
            break
        }
    }
}

#Preview {
    let container = try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
    let certification = Certification(
        agency: "PADI",
        certName: "Rescue Diver",
        certNumber: "OW-12345",
        dateAttained: .now,
        instructor: "Jane Smith",
        cardType: .specialty
    )
    return NavigationStack {
        ViewCertificationDetails(certification: certification)
    }
    .modelContainer(container)
}
