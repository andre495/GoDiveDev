import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Read-only certification detail with **Edit** sheet.
struct ViewCertificationDetails: View {
    @Bindable var certification: Certification

    @State private var showsEditSheet = false

    var body: some View {
        AppPage(title: "Certification", showsBackButton: true, trailingContent: {
            AppEditToolbarButton(
                action: { showsEditSheet = true },
                accessibilityIdentifier: "CertificationDetails.Edit"
            )
        }, content: {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    detailHeaderSection
                    cardPhotosSection
                    certificationSection
                    instructorSection
                }
                .padding(AppTheme.Spacing.md)
            }
        })
        .hidesBottomTabBarWhenPushed()
        .sheet(isPresented: $showsEditSheet) {
            CertificationEditSheetView(certification: certification) {
                showsEditSheet = false
            }
        }
        .accessibilityIdentifier("CertificationDetails.Root")
    }

    private var detailHeaderSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
                Text(CertificationPresentation.detailHeaderName(for: certification))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                CertificationTypeBadge(cardType: certification.cardType)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(detailHeaderAccessibilityLabel)
        .accessibilityIdentifier("CertificationDetails.Header")
    }

    private var detailHeaderAccessibilityLabel: String {
        let name = CertificationPresentation.detailHeaderName(for: certification)
        return "\(name), \(certification.cardType.displayName)"
    }

    private var hasCardPhotos: Bool {
        certification.certFrontPicture != nil || certification.certBackPicture != nil
    }

    @ViewBuilder
    private var cardPhotosSection: some View {
        if hasCardPhotos {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                if certification.certFrontPicture != nil, certification.certBackPicture != nil {
                    cardPhotosPager
                } else if let front = certification.certFrontPicture {
                    cardPhotoHero(data: front, label: "Front")
                } else if let back = certification.certBackPicture {
                    cardPhotoHero(data: back, label: "Back")
                }
            }
        }
    }

    private var cardPhotosPager: some View {
        TabView {
            cardPhotoHero(data: certification.certFrontPicture, label: "Front", showsLabelInPager: true)
            cardPhotoHero(data: certification.certBackPicture, label: "Back", showsLabelInPager: true)
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: Self.cardPhotoHeroHeight)
        .accessibilityIdentifier("CertificationDetails.CardPhotosPager")
    }

    /// ISO/IEC 7810 ID-1 aspect (credit-card style).
    private static let cardPhotoAspectRatio: CGFloat = 85.6 / 53.98
    private static let cardPhotoHeroHeight: CGFloat = 248

    @ViewBuilder
    private func cardPhotoHero(data: Data?, label: String, showsLabelInPager: Bool = false) -> some View {
        #if canImport(UIKit)
        if let data, let image = UIImage(data: data) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                if !showsLabelInPager {
                    cardPhotoLabel(label)
                }

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .aspectRatio(Self.cardPhotoAspectRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: Self.cardPhotoHeroHeight)
                    .background(AppTheme.Colors.surfaceMuted.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.Colors.tabUnselected.opacity(0.18), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.14), radius: 14, y: 8)
                    .accessibilityLabel("\(label) of certification card")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .overlay(alignment: .topLeading) {
                if showsLabelInPager {
                    cardPhotoLabel(label)
                        .padding(AppTheme.Spacing.sm)
                }
            }
            .accessibilityIdentifier("CertificationDetails.CardPhoto.\(label)")
        }
        #endif
    }

    private func cardPhotoLabel(_ label: String) -> some View {
        Text(label)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                Capsule()
                    .fill(AppTheme.Colors.surfaceElevated.opacity(0.92))
            }
    }

    private var certificationSection: some View {
        detailSection(title: "Certification") {
            detailRow(label: "Agency", value: CertificationPresentation.displayString(certification.agency))
            detailRow(label: "Number", value: CertificationPresentation.displayString(certification.certNumber))
            detailRow(label: "Date attained", value: CertificationPresentation.formattedDate(certification.dateAttained))
        }
    }

    private var instructorSection: some View {
        detailSection(title: "Instructor & shop") {
            detailRow(label: "Instructor", value: CertificationPresentation.displayString(certification.instructor))
            detailRow(
                label: "Instructor number",
                value: CertificationPresentation.displayString(certification.instructorNumber)
            )
            detailRow(label: "Dive shop", value: CertificationPresentation.displayString(certification.diveShop))
            detailRow(
                label: "Shop identification number",
                value: CertificationPresentation.displayString(certification.diveShopNumber)
            )
        }
    }

    private func detailSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                content()
            }
            .padding(AppTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.Colors.surfaceElevated)
            )
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
            Text(value)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
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
