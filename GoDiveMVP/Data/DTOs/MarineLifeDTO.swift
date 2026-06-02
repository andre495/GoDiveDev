import Foundation

/// Bundled field-guide fixture / future remote catalog payload (snake_case JSON).
struct MarineLifeDTO: Decodable {
  let uuid: String
  let commonName: String
  let featureImage: String?
  let scientificName: String?
  let category: String?
  let subcategory: String?
  let familyName: String?
  let description: String?
  let minSize: Double?
  let maxSize: Double?
  let minDepth: Double?
  let maxDepth: Double?
  let avgDepth: Double?
  let distinctiveFeatures: String?
  let abundance: String?
  let habitatBehavior: String?
  let diverReaction: String?

  enum CodingKeys: String, CodingKey {
    case uuid
    case commonName = "common_name"
    case featureImage = "feature_image"
    case scientificName = "scientific_name"
    case category
    case subcategory
    case familyName = "family_name"
    case description
    case minSize = "min_size"
    case maxSize = "max_size"
    case minDepth = "min_depth"
    case maxDepth = "max_depth"
    case avgDepth = "avg_depth"
    case distinctiveFeatures = "distinctive_features"
    case abundance
    case habitatBehavior = "habitat_behavior"
    case diverReaction = "diver_reaction"
  }

  init(
    uuid: String,
    commonName: String,
    featureImage: String? = nil,
    scientificName: String? = nil,
    category: String? = nil,
    subcategory: String? = nil,
    familyName: String? = nil,
    description: String? = nil,
    minSize: Double? = nil,
    maxSize: Double? = nil,
    minDepth: Double? = nil,
    maxDepth: Double? = nil,
    avgDepth: Double? = nil,
    distinctiveFeatures: String? = nil,
    abundance: String? = nil,
    habitatBehavior: String? = nil,
    diverReaction: String? = nil
  ) {
    self.uuid = uuid
    self.commonName = commonName
    self.featureImage = featureImage
    self.scientificName = scientificName
    self.category = category
    self.subcategory = subcategory
    self.familyName = familyName
    self.description = description
    self.minSize = minSize
    self.maxSize = maxSize
    self.minDepth = minDepth
    self.maxDepth = maxDepth
    self.avgDepth = avgDepth
    self.distinctiveFeatures = distinctiveFeatures
    self.abundance = abundance
    self.habitatBehavior = habitatBehavior
    self.diverReaction = diverReaction
  }
}
