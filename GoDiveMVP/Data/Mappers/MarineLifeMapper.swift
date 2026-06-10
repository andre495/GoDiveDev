import Foundation

enum MarineLifeMapper {
  static func map(_ dto: MarineLifeDTO) -> MarineLife {
    let categoryID = normalizedCategoryID(dto.category)
    let subcategoryID = normalizedSubcategoryID(dto.subcategory, categoryID: categoryID)
    let minDepth = dto.minDepth ?? 0
    let maxDepth = dto.maxDepth ?? 0
    let avgDepth = resolvedAvgDepthMeters(
      avgDepth: dto.avgDepth,
      minDepth: minDepth,
      maxDepth: maxDepth
    )

    return MarineLife(
      uuid: dto.uuid,
      commonName: dto.commonName,
      featureImageURL: dto.featureImage ?? "",
      featureImageResourceName: dto.featureImageResource ?? "",
      featureModelResourceName: dto.featureModel ?? "",
      scientificName: dto.scientificName ?? "",
      category: categoryID,
      subcategory: subcategoryID,
      familyName: dto.familyName ?? "",
      aboutText: dto.description ?? "",
      minSizeMeters: dto.minSize ?? 0,
      maxSizeMeters: dto.maxSize ?? 0,
      minDepthMeters: minDepth,
      maxDepthMeters: maxDepth,
      avgDepthMeters: avgDepth,
      distinctiveFeatures: dto.distinctiveFeatures ?? "",
      abundance: dto.abundance ?? "",
      habitatBehavior: dto.habitatBehavior ?? "",
      diverReaction: dto.diverReaction ?? ""
    )
  }

  nonisolated static func normalizedCategoryID(_ raw: String?) -> String {
    guard let raw else { return "" }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "" }
    let slug = FieldGuideTaxonomy.normalizedCategoryID(trimmed)
    if FieldGuideTaxonomy.category(id: slug) != nil { return slug }
    return slug
  }

  nonisolated static func normalizedSubcategoryID(_ raw: String?, categoryID: String) -> String {
    guard let raw else { return "" }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "" }
    let slug = FieldGuideTaxonomy.normalizedSubcategoryID(trimmed)
    if FieldGuideTaxonomy.subcategory(categoryID: categoryID, subcategoryID: slug) != nil {
      return slug
    }
    return slug
  }

  nonisolated static func resolvedAvgDepthMeters(
    avgDepth: Double?,
    minDepth: Double,
    maxDepth: Double
  ) -> Double {
    if let avgDepth, avgDepth > 0 { return avgDepth }
    guard minDepth > 0, maxDepth > 0 else {
      return max(minDepth, maxDepth)
    }
    return (minDepth + maxDepth) / 2
  }
}
