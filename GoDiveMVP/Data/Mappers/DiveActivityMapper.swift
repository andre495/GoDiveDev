import Foundation

/// Maps seed / JSON DTOs into **`DiveActivity`** using **canonical** persisted units (m, °C, psi — see **`DiveActivity`**).
enum DiveActivityMapper {
    static func map(_ dto: DiveActivityDTO) -> DiveActivity {
        let defaultTank = DiveActivityTankDefaults.resolvedSpecification()
        let importedMaterial = dto.tankMaterial?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let tankMaterial = (importedMaterial?.isEmpty == false) ? importedMaterial : defaultTank.materialLabel
        let activity = DiveActivity(
            id: dto.id ?? UUID(),
            deviceSource: dto.deviceSource,
            sourceDiveId: dto.sourceDiveId,
            startTime: dto.startTime,
            durationMinutes: dto.durationMinutes,
            maxDepthMeters: dto.maxDepthMeters,
            averageDepthMeters: dto.averageDepthMeters,
            bottomTimeSeconds: dto.bottomTimeSeconds,
            surfaceIntervalSeconds: dto.surfaceIntervalSeconds,
            diveNumber: dto.diveNumber,
            waterTempAvgCelsius: dto.waterTempAvgCelsius,
            waterTempMaxCelsius: dto.waterTempMaxCelsius,
            waterTempMinCelsius: dto.waterTempMinCelsius,
            avgAscentRateMetersPerSecond: dto.avgAscentRateMetersPerSecond,
            siteName: dto.siteName,
            locationName: dto.locationName,
            entryCoordinate: dto.coordinate.map { DiveCoordinate(latitude: $0.latitude, longitude: $0.longitude) },
            notes: dto.notes,
            tankMaterial: tankMaterial,
            tankVolumeDescription: defaultTank.storedDescription,
            tankPressureStartPSI: dto.tankPressureStartPSI,
            tankPressureEndPSI: dto.tankPressureEndPSI,
            gasType: dto.gasType,
            oxygenMix: dto.oxygenMix,
            rawImportVersion: dto.rawImportVersion
        )

        activity.profilePoints = dto.profilePoints.map { pointDTO in
            DiveProfilePoint(
                timestamp: pointDTO.timestamp,
                depthMeters: pointDTO.depthMeters,
                temperatureCelsius: pointDTO.temperatureCelsius,
                ascentRateMetersPerSecond: pointDTO.ascentRateMetersPerSecond,
                ndlSeconds: pointDTO.ndlSeconds,
                timeToSurfaceSeconds: pointDTO.timeToSurfaceSeconds,
                tankPressurePSI: pointDTO.tankPressurePSI,
                heartRateBPM: pointDTO.heartRateBPM,
                po2Bars: pointDTO.po2Bars,
                n2Load: pointDTO.n2Load,
                cnsLoad: pointDTO.cnsLoad,
                dive: activity
            )
        }

        activity.buddies = (dto.buddies ?? []).map { buddyDTO in
            DiveBuddyTag(id: buddyDTO.id ?? UUID(), displayName: buddyDTO.displayName, dive: activity)
        }

        activity.applyImportedGasConsumptionMetrics(volumeUsedSurfaceLiters: nil)

        return activity
    }
}
