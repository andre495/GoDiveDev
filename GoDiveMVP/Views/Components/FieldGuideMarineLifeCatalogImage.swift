import SwiftUI

/// Fixed-size, center-cropped remote catalog photos for Field Guide surfaces.
enum FieldGuideMarineLifeImageLayout {
    /// Shared 4:3 crop for species mosaic tiles.
    static let mosaicAspectRatio: CGFloat = 4 / 3
    /// Keeps mosaic cards the same height below the photo.
    static let mosaicLabelBlockHeight: CGFloat = 88
    /// Detail hero height before safe-area extension.
    static let detailHeroBaseHeight: CGFloat = 280
}

struct FieldGuideMarineLifeCatalogImage: View {
    enum Placement: Equatable {
        case mosaicTile(accent: Color)
        case detailHero(totalHeight: CGFloat)
        case mediaSheetHero(height: CGFloat, cornerRadius: CGFloat = AppTheme.Spacing.md)
    }

    let imageURLString: String
    let placement: Placement

    var body: some View {
        switch placement {
        case .mosaicTile(let accent):
            boundedImage(
                height: nil,
                aspectRatio: FieldGuideMarineLifeImageLayout.mosaicAspectRatio,
                cornerRadius: 0,
                accent: accent
            )
        case .detailHero(let totalHeight):
            boundedImage(
                height: totalHeight,
                aspectRatio: nil,
                cornerRadius: 0,
                accent: AppTheme.Colors.tabUnselected
            )
        case .mediaSheetHero(let height, let cornerRadius):
            boundedImage(
                height: height,
                aspectRatio: nil,
                cornerRadius: cornerRadius,
                accent: AppTheme.Colors.tabUnselected
            )
        }
    }

    @ViewBuilder
    private func boundedImage(
        height: CGFloat?,
        aspectRatio: CGFloat?,
        cornerRadius: CGFloat,
        accent: Color
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        Color.clear
            .frame(maxWidth: .infinity)
            .modifier(
                FieldGuideMarineLifeImageBoundsModifier(
                    height: height,
                    aspectRatio: aspectRatio
                )
            )
            .background {
                placeholder(accent: accent)
            }
            .overlay {
                if let url = resolvedURL {
                    remoteFillImage(url: url, accent: accent)
                }
            }
            .clipShape(shape)
            .contentShape(shape)
    }

    @ViewBuilder
    private func remoteFillImage(url: URL, accent: Color) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                GeometryReader { proxy in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }
            case .failure:
                placeholder(accent: accent)
            case .empty:
                placeholder(accent: accent)
                    .overlay {
                        ProgressView()
                            .tint(accent.opacity(0.55))
                    }
            @unknown default:
                placeholder(accent: accent)
            }
        }
    }

    private var resolvedURL: URL? {
        let trimmed = imageURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }
        return url
    }

    private func placeholder(accent: Color) -> some View {
        Rectangle()
            .fill(accent.opacity(0.12))
            .overlay {
                Image(systemName: "fish")
                    .font(placeholderIconFont)
                    .foregroundStyle(accent.opacity(0.55))
            }
    }

    private var placeholderIconFont: Font {
        switch placement {
        case .mosaicTile:
            return .title2
        case .detailHero, .mediaSheetHero:
            return .largeTitle
        }
    }
}

private struct FieldGuideMarineLifeImageBoundsModifier: ViewModifier {
    let height: CGFloat?
    let aspectRatio: CGFloat?

    func body(content: Content) -> some View {
        if let aspectRatio {
            content
                .aspectRatio(aspectRatio, contentMode: .fit)
        } else if let height {
            content
                .frame(height: height)
        } else {
            content
        }
    }
}
