import Foundation

struct DiveSiteDTO: Decodable {
    let id: UUID?
    let siteName: String
    let country: String?
    let region: String?
    let bodyOfWater: String?
    let latCoords: Double?
    let longCoords: Double?
    let siteTags: [String]?
    let siteRating: Int?
}
