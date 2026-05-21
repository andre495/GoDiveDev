import Foundation

extension Certification {
    var cardType: CertificationCardType {
        get { CertificationCardType(rawValue: cardTypeRaw) ?? .certification }
        set { cardTypeRaw = newValue.rawValue }
    }
}
