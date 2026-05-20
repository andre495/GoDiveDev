import Foundation

enum DiveSiteMapper {
    static func map(_ dto: DiveSiteDTO) -> DiveSite {
        DiveSite(
            id: dto.id ?? UUID(),
            siteName: dto.siteName,
            country: dto.country ?? "",
            region: dto.region ?? "",
            bodyOfWater: dto.bodyOfWater ?? "",
            latCoords: dto.latCoords,
            longCoords: dto.longCoords,
            siteTags: dto.siteTags ?? [],
            siteRating: dto.siteRating
        )
    }
}
