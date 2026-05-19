import Foundation

/// Draft values for add / edit certification sheets before persisting a **`Certification`**.
struct CertificationFormValues: Equatable, Sendable {
    var agency: String = ""
    var certName: String = ""
    var certNumber: String = ""
    var dateAttained: Date = .now

    var instructor: String = ""
    var instructorNumber: String = ""
    var diveShop: String = ""

    var isPrimaryCert: Bool = false

    var certFrontPicture: Data?
    var certBackPicture: Data?

    var canSave: Bool {
        !certName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !agency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !certNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init() {}

    init(from certification: Certification) {
        agency = certification.agency
        certName = certification.certName
        certNumber = certification.certNumber
        dateAttained = certification.dateAttained
        instructor = certification.instructor
        instructorNumber = certification.instructorNumber
        diveShop = certification.diveShop ?? ""
        isPrimaryCert = certification.isPrimaryCert
        certFrontPicture = certification.certFrontPicture
        certBackPicture = certification.certBackPicture
    }

    func apply(to certification: Certification) {
        certification.agency = agency.trimmingCharacters(in: .whitespacesAndNewlines)
        certification.certName = certName.trimmingCharacters(in: .whitespacesAndNewlines)
        certification.certNumber = certNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        certification.dateAttained = dateAttained
        certification.instructor = instructor.trimmingCharacters(in: .whitespacesAndNewlines)
        certification.instructorNumber = instructorNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let shop = diveShop.trimmingCharacters(in: .whitespacesAndNewlines)
        certification.diveShop = shop.isEmpty ? nil : shop
        certification.isPrimaryCert = isPrimaryCert
        certification.certFrontPicture = certFrontPicture
        certification.certBackPicture = certBackPicture
    }

    func makeCertification() -> Certification {
        let shop = diveShop.trimmingCharacters(in: .whitespacesAndNewlines)
        return Certification(
            agency: agency.trimmingCharacters(in: .whitespacesAndNewlines),
            certName: certName.trimmingCharacters(in: .whitespacesAndNewlines),
            certNumber: certNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            dateAttained: dateAttained,
            instructor: instructor.trimmingCharacters(in: .whitespacesAndNewlines),
            instructorNumber: instructorNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            diveShop: shop.isEmpty ? nil : shop,
            isPrimaryCert: isPrimaryCert,
            certFrontPicture: certFrontPicture,
            certBackPicture: certBackPicture
        )
    }
}
