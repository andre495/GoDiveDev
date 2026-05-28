import Foundation

enum MarineLifeMapper {
  static func map(_ dto: MarineLifeDTO) -> MarineLife {
    MarineLife(
      uuid: dto.uuid,
      commonName: dto.commonName,
      featureImageURL: dto.featureImage ?? "",
      scientificName: dto.scientificName ?? "",
      category: dto.category ?? "",
      aboutText: dto.description ?? "",
      minSizeMeters: dto.minSize ?? 0,
      maxSizeMeters: dto.maxSize ?? 0,
      avgDepthMeters: dto.avgDepth ?? 0
    )
  }
}
