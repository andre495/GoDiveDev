import SwiftUI

/// Trip / buddy media overlay — **View on dive**, position chip, optional star + marine-life controls.
struct TripDetailMediaGalleryOverlayControls: View {
    enum OpenOnDivePlacement {
        case leading
        case trailing
    }

    let openOnDiveTitle: String
    let positionLabel: String?
    let isFeatured: Bool
    var showsMarineLifeTagButton: Bool = true
    var openOnDivePlacement: OpenOnDivePlacement = .leading
    let showsMarineLifeTagIndicator: Bool
    let onOpenOnDive: () -> Void
    var onToggleFeatured: (() -> Void)?
    var onToggleMarineLife: (() -> Void)?
    var featureToggleAccessibilityIdentifier = "TripDetail.Media.FeatureToggle"
    var openOnDiveAccessibilityIdentifier = "TripDetail.Media.OpenOnDive"
    var marineLifeAccessibilityIdentifier = "TripDetail.Media.MarineLifeTag"

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                if openOnDivePlacement == .leading {
                    openOnDiveButton
                }

                Spacer(minLength: 0)

                if let positionLabel {
                    mediaOverlayChip {
                        Text(positionLabel)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .accessibilityHidden(true)
                }

                if openOnDivePlacement == .trailing {
                    openOnDiveButton
                }
            }

            Spacer(minLength: 0)

            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                if showsMarineLifeTagButton {
                    if onToggleFeatured != nil {
                        featureStarButton
                    }

                    Spacer(minLength: 0)

                    if showsMarineLifeTagIndicator, let onToggleMarineLife {
                        marineLifeTagButton(action: onToggleMarineLife)
                    }
                } else if onToggleFeatured != nil {
                    Spacer(minLength: 0)
                    featureStarButton
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.bottom, AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var openOnDiveButton: some View {
        Button(action: onOpenOnDive) {
            mediaOverlayChip {
                Label(openOnDiveTitle, systemImage: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.accent)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(openOnDiveAccessibilityIdentifier)
    }

    private var featureStarButton: some View {
        Button(action: { onToggleFeatured?() }) {
            Image(systemName: isFeatured ? "star.fill" : "star")
                .font(.title3.weight(.semibold))
                .foregroundStyle(isFeatured ? AppTheme.Colors.accent : .white)
                .frame(width: 44, height: 44)
                .background { overlayIconBackground }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFeatured ? "Featured buddy media" : "Feature on buddy header")
        .accessibilityHint(
            isFeatured
                ? "Removes this as the buddy header media and uses a random tagged item instead."
                : "Shows this photo or video on the buddy header. Only one item can be featured."
        )
        .accessibilityIdentifier(featureToggleAccessibilityIdentifier)
    }

    private func marineLifeTagButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "fish.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.accent)
                .frame(width: 44, height: 44)
                .background { overlayIconBackground }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Marine life")
        .accessibilityHint("Shows species tagged on this photo")
        .accessibilityIdentifier(marineLifeAccessibilityIdentifier)
    }

    private func mediaOverlayChip<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, TripDetailMediaGalleryPresentation.overlayChipHorizontalPadding)
            .padding(.vertical, TripDetailMediaGalleryPresentation.overlayChipVerticalPadding)
            .background(
                .black.opacity(TripDetailMediaGalleryPresentation.overlayChipBackgroundOpacity),
                in: Capsule()
            )
    }

    private var overlayIconBackground: some View {
        Circle()
            .fill(.black.opacity(0.42))
            .background {
                Circle()
                    .fill(.ultraThinMaterial)
            }
            .clipShape(Circle())
    }
}
