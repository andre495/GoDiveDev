import SwiftUI

/// Multi-select water-activity cards shared by logged-out welcome and post–sign-up interests.
struct UserOnboardingActivitySelectionCards: View {
    @Binding var selection: UserOnboardingActivitySelection
    var offeredKinds: [UserOnboardingActivityKind] = UserOnboardingActivityKind.welcomePickerKinds
    var animateAppearance: Bool = true

    @State private var cardsVisible = false

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            ForEach(Array(offeredKinds.enumerated()), id: \.element.id) { index, kind in
                activityCard(for: kind)
                    .opacity(animateAppearance ? (cardsVisible ? 1 : 0) : 1)
                    .offset(y: animateAppearance ? (cardsVisible ? 0 : 18) : 0)
                    .animation(
                        animateAppearance
                            ? .spring(response: 0.5, dampingFraction: 0.82).delay(Double(index) * 0.08)
                            : nil,
                        value: cardsVisible
                    )
            }
        }
        .onAppear {
            guard animateAppearance else {
                cardsVisible = true
                return
            }
            withAnimation(.easeOut(duration: 0.35).delay(0.08)) {
                cardsVisible = true
            }
        }
    }

    private func activityCard(for kind: UserOnboardingActivityKind) -> some View {
        let isSelected = selection.contains(kind)

        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                selection.toggle(kind)
            }
        } label: {
            HStack(spacing: AppTheme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(
                            isSelected
                                ? AppTheme.Colors.accentDeep.opacity(0.22)
                                : AppTheme.Colors.surfaceElevated.opacity(0.65)
                        )
                        .frame(width: 48, height: 48)

                    activityIcon(for: kind, isSelected: isSelected)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .multilineTextAlignment(.leading)

                    Text(kind.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AppTheme.Colors.accentDeep : AppTheme.Colors.tabUnselected.opacity(0.5))
                    .accessibilityHidden(true)
            }
            .padding(AppTheme.Spacing.md)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.Colors.surfaceElevated.opacity(isSelected ? 0.95 : 0.72))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected ? AppTheme.Colors.accentDeep.opacity(0.55) : AppTheme.Colors.tabUnselected.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(kind.accessibilityIdentifier)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func activityIcon(for kind: UserOnboardingActivityKind, isSelected: Bool) -> some View {
        let tint = isSelected ? AppTheme.Colors.accentDeep : AppTheme.Colors.tabUnselected

        if let assetName = kind.assetImageName {
            let size = DiveActivityTabIcon.scaledAssetSize(
                assetPixelSize: DiveActivityTabIcon.scubaTankTabAssetPixelSize,
                targetHeight: 22
            )
            Image(assetName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: size.width, height: size.height)
                .foregroundStyle(tint)
                .scaleEffect(isSelected ? 1.14 : 1)
                .animation(.spring(response: 0.32, dampingFraction: 0.55), value: isSelected)
        } else if let systemImage = kind.systemImage {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .symbolEffect(.bounce, value: isSelected)
        }
    }
}
