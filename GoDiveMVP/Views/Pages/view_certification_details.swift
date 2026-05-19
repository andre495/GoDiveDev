import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Read-only certification detail with **Edit** sheet.
struct ViewCertificationDetails: View {
    @Bindable var certification: Certification

    @State private var showsEditSheet = false

    private var pageTitle: String {
        CertificationPresentation.title(for: certification)
    }

    var body: some View {
        AppPage(title: pageTitle, showsBackButton: true, trailingContent: {
            Button("Edit") {
                showsEditSheet = true
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.tabSelected)
            .accessibilityIdentifier("CertificationDetails.Edit")
        }, content: {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    cardPhotosSection
                    certificationSection
                    instructorSection
                    primarySection
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

    private var cardPhotosSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            if certification.certFrontPicture != nil || certification.certBackPicture != nil {
                Text("Card photos")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                HStack(spacing: AppTheme.Spacing.md) {
                    cardPhoto(data: certification.certFrontPicture, label: "Front")
                    cardPhoto(data: certification.certBackPicture, label: "Back")
                }
            }
        }
    }

    @ViewBuilder
    private func cardPhoto(data: Data?, label: String) -> some View {
        #if canImport(UIKit)
        if let data, let image = UIImage(data: data) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        #endif
    }

    private var certificationSection: some View {
        detailSection(title: "Certification") {
            detailRow(label: "Name", value: CertificationPresentation.displayString(certification.certName))
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
        }
    }

    private var primarySection: some View {
        detailSection(title: "Profile") {
            detailRow(
                label: "Primary certification",
                value: CertificationPresentation.yesNo(certification.isPrimaryCert)
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
        isPrimaryCert: true
    )
    return NavigationStack {
        ViewCertificationDetails(certification: certification)
    }
    .modelContainer(container)
}
