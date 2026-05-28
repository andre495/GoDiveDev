import Foundation

/// Bundled field-guide fixture / future remote catalog payload (snake_case JSON).
struct MarineLifeDTO: Decodable {
  let uuid: String
  let commonName: String
  let featureImage: String?
  let scientificName: String?
  let category: String?
  let description: String?
  let minSize: Double?
  let maxSize: Double?
  let avgDepth: Double?

  enum CodingKeys: String, CodingKey {
    case uuid
    case commonName = "common_name"
    case featureImage = "feature_image"
    case scientificName = "scientific_name"
    case category
    case description
    case minSize = "min_size"
    case maxSize = "max_size"
    case avgDepth = "avg_depth"
  }
}
