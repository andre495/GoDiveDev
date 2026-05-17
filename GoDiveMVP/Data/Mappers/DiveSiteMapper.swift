import Foundation

enum DiveSiteMapper {
    static func map(_ dto: DiveSiteDTO) -> DiveSite {
        DiveSite(
            id: dto.id ?? UUID(),
            siteName: dto.siteName,
            latCoords: dto.latCoords,
            longCoords: dto.longCoords,
            siteTags: dto.siteTags ?? [],
            siteRating: dto.siteRating
        )
    }
}
