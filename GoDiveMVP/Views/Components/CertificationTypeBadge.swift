import SwiftUI

/// Type pill on certification list rows (**Certification** vs **Specialty**).
struct CertificationTypeBadge: View {
    let cardType: CertificationCardType

    var body: some View {
        let style = CertificationPresentation.typeBadgeStyle(for: cardType)
        Text(style.label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(style.foreground)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background {
                Capsule()
                    .fill(style.background)
            }
            .accessibilityLabel(style.label)
    }
}
