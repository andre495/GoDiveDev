import Foundation

struct DiveSiteDTO: Decodable {
    let id: UUID?
    let siteName: String
    let latCoords: Double?
    let longCoords: Double?
    let siteTags: [String]?
    let siteRating: Int?
}
