import SwiftData
import SwiftUI

/// Certification detail metadata — Details page (agency, number, date, dive count).
struct CertificationDetailDetailsMetadataView: View {
    @Bindable var certification: Certification
    let divesLoggedSinceAttainedCount: Int

    var body: some View {
        detailSection(title: "Certification") {
            detailRow(label: "Agency", value: CertificationPresentation.displayString(certification.agency))
            detailRow(label: "Number", value: CertificationPresentation.displayString(certification.certNumber))
            detailRow(
                label: "Date attained",
                value: CertificationPresentation.formattedDate(certification.dateAttained)
            )
            detailRow(
                label: "Dives",
                value: CertificationPresentation.divesLoggedSinceAttainedLabel(
                    count: divesLoggedSinceAttainedCount
                )
            )
            .accessibilityIdentifier("CertificationDetails.DivesSinceAttained")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("CertificationDetails.Details")
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

/// Certification detail metadata — Instructor & shop page.
struct CertificationDetailInstructorMetadataView: View {
    @Bindable var certification: Certification

    var body: some View {
        detailSection(title: CertificationDetailContentPagerPresentation.instructorAndShopSectionTitle) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("CertificationDetails.InstructorAndShop")
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
