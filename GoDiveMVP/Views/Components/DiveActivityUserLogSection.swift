import SwiftUI

/// Manual **Conditions** + **Operator** fields on the dive overview (**large** sheet detent, map tab).
struct DiveActivityUserLogSection: View {
    @Bindable var activity: DiveActivity

    private enum FieldLimit {
        static let shortText = 120
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            conditionsSection
            operatorSection
        }
        .accessibilityIdentifier("DiveOverview.UserLog")
    }

    private var conditionsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            sectionHeader("Conditions")

            userLogCard {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        fieldLabel("Current")
                        Picker("Current", selection: currentStrengthBinding) {
                            ForEach(DiveCurrentStrength.allCases) { level in
                                Text(level.displayTitle).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    optionalTextField(
                        label: "Surface conditions",
                        placeholder: "e.g. Calm, choppy",
                        text: optionalStringBinding(\.surfaceCondition, maxLength: FieldLimit.shortText)
                    )

                    optionalTextField(
                        label: "Entry type",
                        placeholder: "e.g. Shore, boat, giant stride",
                        text: optionalStringBinding(\.entryType, maxLength: FieldLimit.shortText)
                    )

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        fieldLabel("Visibility")
                        Picker("Visibility", selection: visibilityBinding) {
                            Text("Not set").tag(DiveVisibilityRating?.none)
                            ForEach(DiveVisibilityRating.allCases) { rating in
                                Text(rating.displayTitle).tag(Optional(rating))
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }
            }
        }
    }

    private var operatorSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            sectionHeader("Operator")

            userLogCard {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    optionalTextField(
                        label: "Operator",
                        placeholder: "Dive shop or charter company",
                        text: optionalStringBinding(\.diveOperatorName, maxLength: FieldLimit.shortText)
                    )

                    optionalTextField(
                        label: "Divemaster",
                        placeholder: "Name",
                        text: optionalStringBinding(\.diveMasterName, maxLength: FieldLimit.shortText)
                    )

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        fieldLabel("Signature")
                        DiveSignaturePadView(signatureData: $activity.diveSignatureData)
                    }
                }
            }
        }
    }

    private var currentStrengthBinding: Binding<DiveCurrentStrength> {
        Binding(
            get: { activity.resolvedDiveCurrentStrength },
            set: { activity.resolvedDiveCurrentStrength = $0 }
        )
    }

    private var visibilityBinding: Binding<DiveVisibilityRating?> {
        Binding(
            get: { activity.diveVisibility },
            set: { activity.diveVisibility = $0 }
        )
    }

    private func optionalStringBinding(
        _ keyPath: ReferenceWritableKeyPath<DiveActivity, String?>,
        maxLength: Int
    ) -> Binding<String> {
        Binding(
            get: {
                activity[keyPath: keyPath] ?? ""
            },
            set: { newValue in
                let capped = String(newValue.prefix(maxLength))
                let trimmed = capped.trimmingCharacters(in: .whitespacesAndNewlines)
                activity[keyPath: keyPath] = trimmed.isEmpty ? nil : trimmed
            }
        )
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.tabUnselected)
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(AppTheme.Colors.tabUnselected)
    }

    private func optionalTextField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            fieldLabel(label)
            TextField(placeholder, text: text)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .textFieldStyle(.plain)
                .padding(AppTheme.Spacing.sm)
                .background(AppTheme.Colors.surfaceMuted.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func userLogCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(AppTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.Colors.surfaceElevated)
            }
    }
}
