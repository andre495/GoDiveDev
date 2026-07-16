import SwiftUI

/// Wrapping oval outline tag chips for a dive activity.
struct DiveActivityTagChipFlow: View {
    let tagNames: [String]

    var body: some View {
        ActivityTagChipWrappingLayout(spacing: AppTheme.Spacing.sm) {
            ForEach(tagNames, id: \.self) { name in
                ActivityTagOvalChipLabel(title: ActivityTagPresentation.chipDisplayTitle(for: name))
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityLabel("Tag \(name)")
            }
        }
    }
}

/// Left-to-right wrapping layout so tag ovals size to content (up to the display-title cap).
struct ActivityTagChipWrappingLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
