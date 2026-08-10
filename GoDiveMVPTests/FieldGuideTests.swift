//
//  FieldGuideTests.swift
//  GoDiveMVPTests
//

import CloudKit
import Contacts
import AuthenticationServices
import CoreGraphics
import CoreLocation
import Foundation
import MapKit
import os
import SwiftUI
#if canImport(Photos)
import Photos
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif
import SwiftData
import Testing
#if canImport(PencilKit)
import PencilKit
#endif
#if os(iOS)
import UIKit
#endif
@testable import GoDiveMVP


struct FieldGuideTests {
        @Test func fieldGuideMarineLifeHeroPresentation_prefersModelOverRemoteImage() {
            let kind = FieldGuideMarineLifeHeroPresentation.heroKind(
                featureModelResourceName: "FrenchAngelfish",
                featureImageResourceName: "marine-life-french-angelfish",
                featureImageURL: "https://example.com/fish.jpg"
            )
            #expect(kind == .model3D(.frenchAngelfish))
        }

        @Test func fieldGuideMarineLifeHeroPresentation_defaultFitExtent_matchesPlateSize() {
            #expect(
                abs(FieldGuideMarineLifeHeroSceneConfiguration.defaultFitExtent - 0.22) < 0.0001
            )
            #expect(
                FieldGuideMarineLifeHeroSceneConfiguration.frenchAngelfish.fitExtent
                    == FieldGuideMarineLifeHeroSceneConfiguration.defaultFitExtent
            )
            let generic = FieldGuideMarineLifeHeroPresentation.sceneConfiguration(
                forModelResourceName: "RedLionfish"
            )
            #expect(generic.fitExtent == FieldGuideMarineLifeHeroSceneConfiguration.defaultFitExtent)
        }

        @Test func fieldGuideMarineLifeHeroFitExtent_usesAverageOrMaxSize() {
            #expect(
                abs(
                    FieldGuideMarineLifeHeroFitExtentPresentation.representativeSizeMeters(
                        minSizeMeters: 0.2,
                        maxSizeMeters: 0.4
                    ) - 0.3
                ) < 0.0001
            )
            #expect(
                abs(
                    FieldGuideMarineLifeHeroFitExtentPresentation.representativeSizeMeters(
                        minSizeMeters: 0,
                        maxSizeMeters: 2.0
                    ) - 2.0
                ) < 0.0001
            )
            #expect(
                FieldGuideMarineLifeHeroFitExtentPresentation.representativeSizeMeters(
                    minSizeMeters: 0,
                    maxSizeMeters: 0
                ) == 0
            )
        }

        @Test func fieldGuideMarineLifeHeroFitExtent_emphasizesMidBandOverExtremes() {
            let fit: (Double) -> Float = { feet in
                let meters = feet / FieldGuideMarineLifeHeroFitExtentPresentation.feetPerMeter
                return FieldGuideMarineLifeHeroFitExtentPresentation.fitExtent(forSizeMeters: meters)
            }

            let atTiny = fit(0.1)
            let atSmallCeiling = fit(0.5)
            let atMid = fit(3.0)
            let atLargeFloor = fit(6.0)
            let atHuge = fit(20.0)
            let unknown = FieldGuideMarineLifeHeroFitExtentPresentation.fitExtent(
                minSizeMeters: 0,
                maxSizeMeters: 0
            )

            #expect(atTiny < atSmallCeiling)
            #expect(atSmallCeiling < atMid)
            #expect(atMid < atLargeFloor)
            #expect(atLargeFloor < atHuge)
            #expect(atHuge <= FieldGuideMarineLifeHeroFitExtentPresentation.maxFitExtent + 0.0001)
            #expect(
                abs(unknown - FieldGuideMarineLifeHeroSceneConfiguration.defaultFitExtent) < 0.0001
            )

            // Per-foot change is largest across the mid band (0.5–6 ft).
            let smallSlope = Double(atSmallCeiling - atTiny) / 0.4
            let midSlope = Double(atLargeFloor - atSmallCeiling) / 5.5
            let largeSlope = Double(atHuge - atLargeFloor) / 14.0
            #expect(midSlope > smallSlope)
            #expect(midSlope > largeSlope)

            // Catalog examples: sergeant major (~0.75 ft) smaller plate than barracuda (~6.6 ft).
            let sergeant = FieldGuideMarineLifeHeroFitExtentPresentation.fitExtent(
                minSizeMeters: 0,
                maxSizeMeters: 0.23
            )
            let barracuda = FieldGuideMarineLifeHeroFitExtentPresentation.fitExtent(
                minSizeMeters: 0,
                maxSizeMeters: 2.0
            )
            #expect(sergeant < barracuda)

            let sized = FieldGuideMarineLifeHeroPresentation.sceneConfiguration(
                forModelResourceName: "GreatBarracuda",
                minSizeMeters: 0,
                maxSizeMeters: 2.0
            )
            #expect(abs(sized.fitExtent - barracuda) < 0.0001)
        }

        @Test func fieldGuideMarineLifeHeroGlowPresentation_accentTintAndDiscPlacement() {
            #expect(FieldGuideMarineLifeHeroGlowPresentation.layers.count == 3)
            let radius = FieldGuideMarineLifeHeroGlowPresentation.baseRadius(fitExtent: 0.22)
            #expect(abs(radius - 0.22 * 0.72) < 0.0001)
            #expect(abs(FieldGuideMarineLifeHeroGlowPresentation.verticalClearance - 0.36) < 0.0001)

            let y = FieldGuideMarineLifeHeroGlowPresentation.discY(
                modelPositionY: -0.09,
                modelExtentY: 1.0,
                modelScale: 0.22
            )
            // Plate sits below the model lowest point (half extent − clearance).
            #expect(
                abs(
                    y - (
                        -0.09
                            - 0.11
                            - FieldGuideMarineLifeHeroGlowPresentation.verticalClearance
                    )
                ) < 0.0001
            )
            let underSpin = FieldGuideMarineLifeHeroGlowPresentation.discPositionUnderSpinAxis(glowY: y)
            #expect(underSpin.x == 0)
            #expect(underSpin.z == 0)
            #expect(underSpin.y == y)

            let tint = FieldGuideMarineLifeHeroGlowPresentation.tintRGB(intensity: 0.5)
            #expect(abs(tint.red - 0) < 0.0001)
            #expect(abs(tint.green - 0.24) < 0.0001)
            #expect(abs(tint.blue - 0.36) < 0.0001)

            let midPulse = FieldGuideMarineLifeHeroGlowPresentation.pulseScale(elapsed: 0)
            #expect(abs(midPulse - 1.0) < 0.0001)
            let peakPulse = FieldGuideMarineLifeHeroGlowPresentation.pulseScale(
                elapsed: Double(.pi / (2 * FieldGuideMarineLifeHeroGlowPresentation.pulseAngularSpeed))
            )
            #expect(abs(peakPulse - (1 + FieldGuideMarineLifeHeroGlowPresentation.pulseAmplitude)) < 0.001)

            let emitterSize = FieldGuideMarineLifeHeroGlowPresentation.particleEmitterShapeSize(
                baseRadius: radius
            )
            #expect(
                abs(
                    emitterSize.x
                        - radius * FieldGuideMarineLifeHeroGlowPresentation.particleEmitterRadiusScale
                ) < 0.0001
            )
            #expect(abs(emitterSize.y - FieldGuideMarineLifeHeroGlowPresentation.particleEmitterHeight) < 0.0001)
            #expect(FieldGuideMarineLifeHeroGlowPresentation.particleLifeSpan > 3.0)
            #expect(FieldGuideMarineLifeHeroGlowPresentation.particleSpeed > 0.06)
            #expect(
                FieldGuideMarineLifeHeroGlowPresentation.particleEmissionDirection == SIMD3<Float>(0, 1, 0)
            )
            #expect(
                abs(
                    FieldGuideMarineLifeHeroGlowPresentation.particleSpreadingAngle - (.pi / 2)
                ) < 0.0001
            )
        }

        @Test func fieldGuideMarineLifeHeroModelMotionPresentation_bobOffset_isSineWave() {
            #expect(
                abs(FieldGuideMarineLifeHeroModelMotionPresentation.bobOffset(elapsed: 0)) < 0.0001
            )
            let peakElapsed = Double(
                .pi / (2 * FieldGuideMarineLifeHeroModelMotionPresentation.bobAngularSpeed)
            )
            #expect(
                abs(
                    FieldGuideMarineLifeHeroModelMotionPresentation.bobOffset(elapsed: peakElapsed)
                        - FieldGuideMarineLifeHeroModelMotionPresentation.bobAmplitude
                ) < 0.0001
            )
            #expect(FieldGuideMarineLifeHeroModelMotionPresentation.bobAmplitude > 0.035)
            #expect(FieldGuideMarineLifeHeroModelMotionPresentation.bobAmplitude < 0.06)
        }

        @Test func fieldGuideMarineLifeHeroPresentation_caribbeanReefSquidUsesBundledModel() {
            let kind = FieldGuideMarineLifeHeroPresentation.heroKind(
                featureModelResourceName: "CaribbeanReefSquid",
                featureImageResourceName: "",
                featureImageURL: ""
            )
            guard case .model3D(let config) = kind else {
                Issue.record("Expected 3D model hero")
                return
            }
            #expect(config.modelResourceName == "CaribbeanReefSquid")
        }

        @Test func fieldGuideMarineLifeHeroPresentation_greenSeaTurtleUsesBundledModel() {
            let kind = FieldGuideMarineLifeHeroPresentation.heroKind(
                featureModelResourceName: "GreenSeaTurtle",
                featureImageResourceName: "",
                featureImageURL: ""
            )
            guard case .model3D(let config) = kind else {
                Issue.record("Expected 3D model hero")
                return
            }
            #expect(config.modelResourceName == "GreenSeaTurtle")
        }

        @Test func fieldGuideMarineLifeHeroPresentation_spottedEagleRayUsesBundledModel() {
            let kind = FieldGuideMarineLifeHeroPresentation.heroKind(
                featureModelResourceName: "SpottedEagleRay",
                featureImageResourceName: "",
                featureImageURL: ""
            )
            guard case .model3D(let config) = kind else {
                Issue.record("Expected 3D model hero")
                return
            }
            #expect(config.modelResourceName == "SpottedEagleRay")
        }

        @Test func fieldGuideMarineLifeHeroPresentation_greatBarracudaUsesBundledModel() {
            let kind = FieldGuideMarineLifeHeroPresentation.heroKind(
                featureModelResourceName: "GreatBarracuda",
                featureImageResourceName: "",
                featureImageURL: ""
            )
            guard case .model3D(let config) = kind else {
                Issue.record("Expected 3D model hero")
                return
            }
            #expect(config.modelResourceName == "GreatBarracuda")
        }

        @Test func fieldGuideMarineLifeHeroPresentation_sergeantMajorUsesBundledModel() {
            let kind = FieldGuideMarineLifeHeroPresentation.heroKind(
                featureModelResourceName: "SergeantMajor",
                featureImageResourceName: "",
                featureImageURL: ""
            )
            guard case .model3D(let config) = kind else {
                Issue.record("Expected 3D model hero")
                return
            }
            #expect(config.modelResourceName == "SergeantMajor")
        }

        @Test func fieldGuideMarineLifeHeroPresentation_rockBeautyUsesBundledModel() {
            let kind = FieldGuideMarineLifeHeroPresentation.heroKind(
                featureModelResourceName: "RockBeauty",
                featureImageResourceName: "",
                featureImageURL: ""
            )
            guard case .model3D(let config) = kind else {
                Issue.record("Expected 3D model hero")
                return
            }
            #expect(config.modelResourceName == "RockBeauty")
        }

        @Test func fieldGuideMarineLifeHeroPresentation_redLionfishUsesBundledModel() {
            let kind = FieldGuideMarineLifeHeroPresentation.heroKind(
                featureModelResourceName: "RedLionfish",
                featureImageResourceName: "",
                featureImageURL: ""
            )
            guard case .model3D(let config) = kind else {
                Issue.record("Expected 3D model hero")
                return
            }
            #expect(config.modelResourceName == "RedLionfish")
        }

        @Test func fieldGuideMarineLifeHeroPresentation_caribbeanReefSharkUsesBundledModel() {
            let kind = FieldGuideMarineLifeHeroPresentation.heroKind(
                featureModelResourceName: "CaribbeanReefShark",
                featureImageResourceName: "",
                featureImageURL: ""
            )
            guard case .model3D(let config) = kind else {
                Issue.record("Expected 3D model hero")
                return
            }
            #expect(config.modelResourceName == "CaribbeanReefShark")
        }

        @Test func fieldGuideMarineLifeHeroPresentation_tarponUsesBundledModel() {
            let kind = FieldGuideMarineLifeHeroPresentation.heroKind(
                featureModelResourceName: "Tarpon",
                featureImageResourceName: "",
                featureImageURL: ""
            )
            guard case .model3D(let config) = kind else {
                Issue.record("Expected 3D model hero")
                return
            }
            #expect(config.modelResourceName == "Tarpon")
        }

        @Test func fieldGuideMarineLifeHeroPresentation_stoplightParrotfishUsesBundledModel() {
            let kind = FieldGuideMarineLifeHeroPresentation.heroKind(
                featureModelResourceName: "StoplightParrotfish",
                featureImageResourceName: "",
                featureImageURL: ""
            )
            guard case .model3D(let config) = kind else {
                Issue.record("Expected 3D model hero")
                return
            }
            #expect(config.modelResourceName == "StoplightParrotfish")
        }

        @Test func fieldGuideMarineLifeHeroPresentation_newModels_applyCatalogSizeFitExtent() {
            let parrot = FieldGuideMarineLifeHeroPresentation.sceneConfiguration(
                forModelResourceName: "StoplightParrotfish",
                minSizeMeters: 0,
                maxSizeMeters: 0.64
            )
            let tarpon = FieldGuideMarineLifeHeroPresentation.sceneConfiguration(
                forModelResourceName: "Tarpon",
                minSizeMeters: 0,
                maxSizeMeters: 2.5
            )
            let shark = FieldGuideMarineLifeHeroPresentation.sceneConfiguration(
                forModelResourceName: "CaribbeanReefShark",
                minSizeMeters: 0,
                maxSizeMeters: 3.0
            )
            #expect(parrot.fitExtent < tarpon.fitExtent)
            #expect(tarpon.fitExtent < shark.fitExtent)
            #expect(
                abs(
                    parrot.fitExtent
                        - FieldGuideMarineLifeHeroFitExtentPresentation.fitExtent(
                            minSizeMeters: 0,
                            maxSizeMeters: 0.64
                        )
                ) < 0.0001
            )
        }

        @Test func fieldGuideMarineLifeHeroPresentation_mediaOverlay_prefersPhotoOverModel() {
            let withPhoto = FieldGuideMarineLifeHeroPresentation.mediaOverlayHeroKind(
                featureModelResourceName: "GreatBarracuda",
                featureImageResourceName: "",
                featureImageURL: "https://example.com/barracuda.jpg"
            )
            guard case .remoteImage(let url) = withPhoto else {
                Issue.record("Expected catalog photo on media overlay when both model and image exist")
                return
            }
            #expect(url.absoluteString == "https://example.com/barracuda.jpg")

            let modelOnly = FieldGuideMarineLifeHeroPresentation.mediaOverlayHeroKind(
                featureModelResourceName: "GreatBarracuda",
                featureImageResourceName: "",
                featureImageURL: ""
            )
            guard case .model3D(let config) = modelOnly else {
                Issue.record("Expected 3D fallback when media overlay has no catalog image")
                return
            }
            #expect(config.modelResourceName == "GreatBarracuda")
        }

        @Test func fieldGuideMarineLifeHeroPresentation_remoteImageWhenNoModel() {
            let kind = FieldGuideMarineLifeHeroPresentation.heroKind(
                featureModelResourceName: "",
                featureImageResourceName: "",
                featureImageURL: "https://example.com/fish.jpg"
            )
            guard case .remoteImage(let url) = kind else {
                Issue.record("Expected remote image hero")
                return
            }
            #expect(url.absoluteString == "https://example.com/fish.jpg")
        }

        @Test func fieldGuideMarineLifeHeroPresentation_placeholderWhenEmpty() {
            let kind = FieldGuideMarineLifeHeroPresentation.heroKind(
                featureModelResourceName: "",
                featureImageResourceName: "",
                featureImageURL: ""
            )
            #expect(kind == .placeholder)
        }

        @Test func fieldGuideMarineLifeBundledImagePresentation_prefersBundledResourceOverRemoteURL() {
            let source = FieldGuideMarineLifeBundledImagePresentation.imageSource(
                featureImageResourceName: "missing-resource",
                featureImageURL: "https://example.com/fish.jpg"
            )
            guard case .remote(let url) = source else {
                Issue.record("Expected remote fallback when bundled file is absent")
                return
            }
            #expect(url.absoluteString == "https://example.com/fish.jpg")
        }

        @Test func fieldGuideMarineLifeBundledImagePresentation_rejectsUnsafeRemoteURLs() {
            #expect(
                FieldGuideMarineLifeBundledImagePresentation.imageSource(
                    featureImageResourceName: "",
                    featureImageURL: "http://example.com/fish.jpg"
                ) == .none
            )
            #expect(
                FieldGuideMarineLifeBundledImagePresentation.imageSource(
                    featureImageResourceName: "",
                    featureImageURL: "https://127.0.0.1/fish.jpg"
                ) == .none
            )
        }

        @Test func fieldGuideMarineLifeBundledImagePresentation_noneWhenEmpty() {
            let source = FieldGuideMarineLifeBundledImagePresentation.imageSource(
                featureImageResourceName: "",
                featureImageURL: ""
            )
            #expect(source == .none)
        }

        @Test func fieldGuideMarineLifeImageLayout_usesFixedMosaicAndHeroBounds() {
            #expect(FieldGuideMarineLifeImageLayout.mosaicAspectRatio == CGFloat(4.0 / 3.0))
            #expect(FieldGuideMarineLifeImageLayout.mosaicLabelBlockHeight == 88)
            #expect(FieldGuideMarineLifeImageLayout.detailHeroBaseHeight == 280)
        }

        @Test func fieldGuideSubcategorySearchPresentation_filtersByTitleOrHint() {
            let angelfishes = FieldGuideTaxonomy.Subcategory(
                id: "angelfishes",
                title: "Angelfishes",
                hint: "Species from Caribbean Reef Life — Angelfishes",
                systemImage: "fish"
            )
            let gobies = FieldGuideTaxonomy.Subcategory(
                id: "gobies",
                title: "Gobies",
                hint: "Species from Caribbean Reef Life — Gobies",
                systemImage: "fish"
            )

            #expect(
                FieldGuideSubcategorySearchPresentation.filtering([angelfishes, gobies], query: "angel")
                    == [angelfishes]
            )
            #expect(
                FieldGuideSubcategorySearchPresentation.filtering([angelfishes, gobies], query: "Caribbean Gobies")
                    == [gobies]
            )
            #expect(
                FieldGuideSubcategorySearchPresentation.showsAllSpeciesFallback(
                    subcategories: [],
                    speciesCount: 12,
                    query: ""
                )
            )
            #expect(
                !FieldGuideSubcategorySearchPresentation.showsAllSpeciesFallback(
                    subcategories: [],
                    speciesCount: 12,
                    query: "octopus"
                )
            )
        }

        @Test func fieldGuideSpeciesHeroPresentation_prefersTaggedVideoAndTogglesSource() {
            let photo = DiveMediaPhoto(sortOrder: 0, mediaKind: .image)
            let video = DiveMediaPhoto(sortOrder: 1, mediaKind: .video)
            #expect(
                FieldGuideSpeciesHeroPresentation.initialTaggedMediaPhotoID(from: [photo, video])
                    == video.id
            )
            #expect(
                FieldGuideSpeciesHeroPresentation.initialTaggedMediaPhotoID(from: [photo])
                    == photo.id
            )
            #expect(FieldGuideSpeciesHeroPresentation.initialTaggedMediaPhotoID(from: []) == nil)

            #expect(
                FieldGuideSpeciesHeroPresentation.resolvedTaggedMedia(
                    selectedID: photo.id,
                    in: [photo, video]
                )?.id == photo.id
            )
            #expect(
                FieldGuideSpeciesHeroPresentation.resolvedTaggedMedia(
                    selectedID: nil,
                    in: [photo, video]
                )?.id == video.id
            )

            #expect(FieldGuideSpeciesHeroPresentation.showsSourceToggle(hasTaggedMedia: true))
            #expect(!FieldGuideSpeciesHeroPresentation.showsSourceToggle(hasTaggedMedia: false))
            #expect(
                FieldGuideSpeciesHeroPresentation.defaultMediaSource(hasTaggedMedia: true)
                    == .taggedUserMedia
            )
            #expect(
                FieldGuideSpeciesHeroPresentation.defaultMediaSource(hasTaggedMedia: false)
                    == .catalogReference
            )
            #expect(
                FieldGuideSpeciesHeroPresentation.toggledSource(.taggedUserMedia)
                    == .catalogReference
            )
            #expect(
                FieldGuideSpeciesHeroPresentation.toggledSource(.catalogReference)
                    == .taggedUserMedia
            )
            #expect(
                FieldGuideSpeciesHeroPresentation.sourceToggleDiameter
                    == DiveBuddyDetailPresentation.profileAvatarDiameter / 2
            )
            #expect(FieldGuideSpeciesHeroPresentation.sourceToggleDiameter == 60)

            let compact = FieldGuideSpeciesHeroPresentation.compactSceneConfiguration(
                for: .frenchAngelfish
            )
            #expect(!compact.allowsDragRotation)
            #expect(compact.modelResourceName == "FrenchAngelfish")
        }

        @Test func fieldGuideSpeciesHeroPresentation_catalogHeroDisplay_defaultsToImageAndToggles() {
            let both = FieldGuideSpeciesHeroPresentation.catalogHeroAvailability(
                featureModelResourceName: "FrenchAngelfish",
                featureImageResourceName: "marine-life-french-angelfish",
                featureImageURL: "https://example.com/fish.jpg"
            )
            #expect(both.hasModel3D)
            #expect(both.hasImage)
            #expect(both.supportsHeaderToggle)
            #expect(
                FieldGuideSpeciesHeroPresentation.defaultCatalogHeroDisplay(availability: both)
                    == .image
            )
            #expect(
                FieldGuideSpeciesHeroPresentation.resolvedCatalogHeroDisplay(
                    selection: .model3D,
                    availability: both
                ) == .model3D
            )
            #expect(
                FieldGuideSpeciesHeroPresentation.toggledCatalogHeroDisplay(.image) == .model3D
            )
            #expect(
                FieldGuideSpeciesHeroPresentation.toggledCatalogHeroDisplay(.model3D) == .image
            )

            let modelOnly = FieldGuideSpeciesHeroPresentation.catalogHeroAvailability(
                featureModelResourceName: "FrenchAngelfish",
                featureImageResourceName: "",
                featureImageURL: ""
            )
            #expect(modelOnly.hasModel3D)
            #expect(!modelOnly.hasImage)
            #expect(!modelOnly.supportsHeaderToggle)
            #expect(
                FieldGuideSpeciesHeroPresentation.resolvedCatalogHeroDisplay(
                    selection: .image,
                    availability: modelOnly
                ) == .model3D
            )

            let imageOnly = FieldGuideSpeciesHeroPresentation.catalogHeroAvailability(
                featureModelResourceName: "",
                featureImageResourceName: "",
                featureImageURL: "https://example.com/fish.jpg"
            )
            #expect(!imageOnly.hasModel3D)
            #expect(imageOnly.hasImage)
            #expect(!imageOnly.supportsHeaderToggle)
            #expect(
                FieldGuideSpeciesHeroPresentation.resolvedCatalogHeroDisplay(
                    selection: .model3D,
                    availability: imageOnly
                ) == .image
            )
        }

        @Test func fieldGuideSpeciesHeroPresentation_catalogPhotoSeamUnderlapLayout() {
            #expect(FieldGuideSpeciesHeroPresentation.catalogPhotoSeamUnderlap == 36)
            #expect(FieldGuideSpeciesHeroPresentation.catalogPhotoVerticalOffset == -206)
            #expect(
                FieldGuideSpeciesHeroPresentation.usesCatalogPhotoSeamUnderlapLayout(
                    heroMode: .media,
                    mediaSource: .catalogReference,
                    catalogHeroDisplay: .image,
                    isShowingTaggedMedia: false
                )
            )
            #expect(
                !FieldGuideSpeciesHeroPresentation.usesCatalogPhotoSeamUnderlapLayout(
                    heroMode: .media,
                    mediaSource: .catalogReference,
                    catalogHeroDisplay: .model3D,
                    isShowingTaggedMedia: false
                )
            )
            #expect(
                !FieldGuideSpeciesHeroPresentation.usesCatalogPhotoSeamUnderlapLayout(
                    heroMode: .map,
                    mediaSource: .catalogReference,
                    catalogHeroDisplay: .image,
                    isShowingTaggedMedia: false
                )
            )
            let taggedVideo = DiveMediaPhoto(sortOrder: 0, mediaKind: .video)
            #expect(
                FieldGuideSpeciesHeroPresentation.isShowingTaggedMediaHero(
                    mediaSource: .taggedUserMedia,
                    heroTaggedMedia: taggedVideo,
                    taggedMediaItemsEmpty: false
                )
            )
            #expect(
                !FieldGuideSpeciesHeroPresentation.usesCatalogPhotoSeamUnderlapLayout(
                    heroMode: .media,
                    mediaSource: .taggedUserMedia,
                    catalogHeroDisplay: .image,
                    isShowingTaggedMedia: true
                )
            )
        }

        @Test func fieldGuideMarineLifeHeroPresentation_catalogImageKind_ignoresModelName() {
            let kind = FieldGuideMarineLifeHeroPresentation.catalogImageKind(
                featureImageResourceName: "",
                featureImageURL: "https://example.com/fish.jpg"
            )
            guard case .remoteImage(let url) = kind else {
                Issue.record("Expected remote catalog image")
                return
            }
            #expect(url.absoluteString == "https://example.com/fish.jpg")
            #expect(
                FieldGuideMarineLifeHeroPresentation.hasCatalogModel(
                    featureModelResourceName: "FrenchAngelfish"
                )
            )
        }

        @Test @MainActor func fieldGuideMarineLifeDetailView_heroHeight_usesPushedLayoutMetrics() {
            let geometryHeight: CGFloat = 852
            let screenWidth: CGFloat = 390
            let topSafeAreaInset: CGFloat = 59
            let seamInputs = HomeOverviewPushedLayoutPresentation.pushedPageSeamInputs()
            let transitionFloor = HomeOverviewLayout.pushedHeroLayoutTransitionViewportCandidate(from: 803)

            let heroHeight = BlueSheetHeaderPageLayoutBuilder.heroHeight(
                geometryHeight: geometryHeight,
                screenWidth: screenWidth,
                topSafeAreaInset: topSafeAreaInset,
                statsPanelContentHeight: seamInputs.statsPanelContentHeight,
                showsBuddyLeaderboard: seamInputs.showsBuddyLeaderboard,
                transitionViewportFloor: transitionFloor
            )
            #expect(heroHeight > FieldGuideMarineLifeImageLayout.detailHeroBaseHeight)
        }

        @Test @MainActor func fieldGuideMarineLifeImageLayout_detailHeroFitsWidthWithoutCropping() {
            #expect(FieldGuideMarineLifeImageLayout.detailHeroBaseHeight == 280)
            #expect(FieldGuideMarineLifeImageLayout.detailHeroDefaultContentMode == .fit)
            let placement = FieldGuideMarineLifeCatalogImage.Placement.detailHero()
            #expect(placement == .detailHero(alignment: .center, contentMode: .fit))
            #expect(placement != .detailHero(alignment: .bottom, contentMode: .fill))
        }

        @Test @MainActor func fieldGuideSpeciesDetailContentPager_pages() {
            #expect(FieldGuideSpeciesDetailContentPagerPresentation.pageCount == 5)
            #expect(
                FieldGuideSpeciesDetailContentPagerPresentation.pages == [
                    .about,
                    .stats,
                    .similarSpecies,
                    .taggedDives,
                    .taggedMedia,
                ]
            )
            #expect(FieldGuideSpeciesDetailContentPagerPresentation.defaultPage == .about)
            #expect(
                FieldGuideSpeciesDetailContentPagerPresentation.pageTitle(for: .similarSpecies)
                    == "Similar species"
            )
            #expect(
                FieldGuideSpeciesDetailContentPagerPresentation.pageTitle(for: .taggedDives) == "Tagged dives"
            )
            #expect(
                FieldGuideSpeciesDetailContentPagerPresentation.accessibilityIdentifier(for: .similarSpecies)
                    == "FieldGuide.SpeciesDetail.ContentPager.SimilarSpecies"
            )
            #expect(
                FieldGuideSpeciesDetailContentPagerPresentation.accessibilityIdentifier(for: .taggedMedia)
                    == "FieldGuide.SpeciesDetail.ContentPager.TaggedMedia"
            )
            #expect(!FieldGuideSpeciesDetailContentPagerPresentation.usesStaticPagerLayout(for: .about))
            #expect(
                FieldGuideSpeciesDetailContentPagerPresentation.emptyStateMessage(for: .taggedDives)
                    == "No dives tagged with this species yet."
            )
            #expect(
                FieldGuideSpeciesDetailContentPagerPresentation.emptyStateMessage(for: .similarSpecies)
                    == "No similar species found in the catalog yet."
            )
            #expect(FieldGuideSpeciesDetailContentPagerPresentation.similarSpeciesGridColumnCount == 2)
            #expect(
                FieldGuideSpeciesDetailContentPagerPresentation.pageSubtitle(for: .about) == "About"
            )
            #expect(
                FieldGuideSpeciesDetailContentPagerPresentation.pageSubtitle(for: .stats)
                    == "Size and Range"
            )
            #expect(
                FieldGuideSpeciesDetailContentPagerPresentation.pageSubtitle(for: .similarSpecies)
                    == "Related Species"
            )
            #expect(
                FieldGuideSpeciesDetailContentPagerPresentation.pageSubtitle(for: .taggedDives)
                    == "Tagged Dives"
            )
            #expect(
                FieldGuideSpeciesDetailContentPagerPresentation.pageSubtitle(for: .taggedMedia)
                    == "Tagged Media"
            )
            #expect(
                FieldGuideSpeciesDetailContentPagerPresentation
                    .pageSubtitleAccessibilityIdentifier(for: .stats)
                    == "FieldGuide.SpeciesDetail.Stats.Subtitle"
            )
            #expect(
                FieldGuideSpeciesDetailContentPagerPresentation
                    .similarSpeciesTileAccessibilityIdentifier(uuid: "marine-life-french-angelfish")
                    == "FieldGuide.SpeciesDetail.SimilarSpecies.marine-life-french-angelfish"
            )
        }

        @Test func fieldGuidePresentation_sightedDiveRowDisplayData_ordersNewestFirst() {
            let older = DiveActivity(
                source: .manual,
                startTime: Date(timeIntervalSince1970: 1_000_000),
                durationMinutes: 1,
                maxDepthMeters: 1
            )
            let newer = DiveActivity(
                source: .manual,
                startTime: Date(timeIntervalSince1970: 2_000_000),
                durationMinutes: 1,
                maxDepthMeters: 1
            )
            let rows = FieldGuidePresentation.sightedDiveRowDisplayData(
                activityIDs: [older.id, newer.id],
                activities: [older, newer],
                unitSystem: .metric
            )
            #expect(rows.count == 2)
            #expect(rows[0].id == newer.id)
            #expect(rows[1].id == older.id)
        }

        @Test func fieldGuideSpeciesDetailMapPresentation_pinsUniqueCoordinatesFromTaggedDives() {
            let site = DiveSite(
                siteName: "Salt Pier",
                latCoords: 12.0835,
                longCoords: -68.283
            )
            let taggedA = DiveActivity(
                source: .manual,
                startTime: Date(timeIntervalSince1970: 100),
                durationMinutes: 40,
                maxDepthMeters: 18,
                siteName: "Salt Pier",
                entryCoordinate: DiveCoordinate(latitude: 12.084, longitude: -68.284)
            )
            taggedA.diveSiteID = site.id
            let taggedB = DiveActivity(
                source: .manual,
                startTime: Date(timeIntervalSince1970: 200),
                durationMinutes: 35,
                maxDepthMeters: 16,
                siteName: "Salt Pier",
                entryCoordinate: DiveCoordinate(latitude: 12.084, longitude: -68.284)
            )
            taggedB.diveSiteID = site.id
            let taggedC = DiveActivity(
                source: .manual,
                startTime: Date(timeIntervalSince1970: 300),
                durationMinutes: 50,
                maxDepthMeters: 22,
                siteName: "Something Else",
                entryCoordinate: DiveCoordinate(latitude: 13.1, longitude: -69.1)
            )

            let pins = FieldGuideSpeciesDetailMapPresentation.pins(
                from: [taggedA, taggedB, taggedC],
                catalogSites: [site]
            )
            #expect(pins.count == 2)
            #expect(pins.allSatisfy { $0.kind == .completed })
            #expect(pins.contains(where: { $0.siteID == site.id }))
            #expect(
                FieldGuideSpeciesDetailMapPresentation.accessibilityLabel(for: pins)
                    == "Species sighting sites map, 2 sites"
            )
        }

        @Test func fieldGuideCatalogBrowseListPresentation_matchesHubListSpacing() {
            #expect(
                FieldGuideCatalogBrowseListPresentation.listRowSpacing
                    == FieldGuideHubTileLayout.listRowSpacing
            )
            #expect(FieldGuideCatalogBrowseListPresentation.listRowSpacing == AppTheme.Spacing.sm)
            let safeTop: CGFloat = 59
            let headerClearance: CGFloat = 52
            #expect(
                FieldGuideCatalogBrowseListPresentation.listTopInset(
                    safeAreaTop: safeTop,
                    headerClearance: headerClearance
                ) == safeTop + headerClearance
            )
            #expect(
                FieldGuideCatalogBrowseListPresentation.listBottomInset(safeAreaBottom: 34)
                    == AppScrollUnderHeaderListLayout.listBottomInset(safeAreaBottom: 34)
            )
        }

        @Test func fieldGuideSpeciesSearchResultsPresentation_searchesFullCatalog() {
            let angelfish = MarineLifeCatalogSnapshot(
                uuid: "marine-life-french-angelfish",
                commonName: "French Angelfish",
                scientificName: "Pomacanthus paru",
                category: "fish",
                subcategory: "angelfishes",
                featureImageURL: "",
                minSizeMeters: 0.2,
                maxSizeMeters: 0.4,
                avgDepthMeters: 12
            )
            let turtle = MarineLifeCatalogSnapshot(
                uuid: "marine-life-green-turtle",
                commonName: "Green Turtle",
                scientificName: "Chelonia mydas",
                category: "reptiles",
                subcategory: "sea-turtles",
                featureImageURL: "",
                minSizeMeters: 0.8,
                maxSizeMeters: 1.5,
                avgDepthMeters: 8
            )
            let fishOnlyPayload = [angelfish]
            let fullCatalog = [angelfish, turtle]

            let scoped = FieldGuideMarineLifeSearch.filtering(fishOnlyPayload, query: "turtle")
            #expect(scoped.isEmpty)

            let globalRows = FieldGuideSpeciesSearchResultsPresentation.rowData(
                catalogSnapshots: fullCatalog,
                query: "turtle",
                unitSystem: .metric
            )
            #expect(globalRows.count == 1)
            #expect(globalRows[0].marineLifeUUID == turtle.uuid)
            #expect(FieldGuideSpeciesSearchEnvironment.searchPlaceholder == "Search Marine Life")
        }

        @Test func fieldGuideSpeciesSearchResultsPresentation_indexedRowData_matchesUnindexedFilter() {
            let angelfish = MarineLifeCatalogSnapshot(
                uuid: "marine-life-french-angelfish",
                commonName: "French Angelfish",
                scientificName: "Pomacanthus paru",
                category: "fish",
                subcategory: "angelfishes",
                featureImageURL: "",
                minSizeMeters: 0.2,
                maxSizeMeters: 0.4,
                avgDepthMeters: 12
            )
            let turtle = MarineLifeCatalogSnapshot(
                uuid: "marine-life-green-turtle",
                commonName: "Green Turtle",
                scientificName: "Chelonia mydas",
                category: "reptiles",
                subcategory: "sea-turtles",
                featureImageURL: "",
                minSizeMeters: 0.8,
                maxSizeMeters: 1.5,
                avgDepthMeters: 8
            )
            let catalog = [angelfish, turtle]
            let index = FieldGuideSpeciesSearchResultsPresentation.searchableTextByUUID(for: catalog)

            let indexedRows = FieldGuideSpeciesSearchResultsPresentation.rowData(
                catalogSnapshots: catalog,
                searchableTextByUUID: index,
                query: "chelonia",
                unitSystem: .metric
            )
            let unindexedRows = FieldGuideSpeciesSearchResultsPresentation.rowData(
                catalogSnapshots: catalog,
                query: "chelonia",
                unitSystem: .metric
            )
            #expect(indexedRows.map(\.marineLifeUUID) == unindexedRows.map(\.marineLifeUUID))
            #expect(indexedRows.count == 1)
            #expect(indexedRows[0].marineLifeUUID == turtle.uuid)
        }

        @Test func fieldGuideCategoryPresentation_detailHeroHeight_includesSafeAreaInset() {
            let inset: CGFloat = 59
            #expect(
                FieldGuideCategoryPresentation.detailHeroHeight(extraTopInset: inset)
                    == FieldGuideCategoryImageLayout.detailHeroBaseHeight + inset
            )
            #expect(FieldGuideCategoryImageLayout.detailHeroBaseHeight == 200)
        }

        @Test @MainActor
        func fieldGuideCategoryAccent_usesContrastyLightAndPastelDarkHubPalette() {
            #expect(FieldGuideTaxonomy.categories.map(\.id) == [
                "plants", "sponges", "corals", "invertebrates", "fishes", "reptiles", "mammals",
            ])
            func luminance(_ rgb: FieldGuideCategoryAccentPresentation.RGB) -> Double {
                0.2126 * rgb.red + 0.7152 * rgb.green + 0.0722 * rgb.blue
            }
            for categoryID in FieldGuideTaxonomy.categories.map(\.id) {
                let pair = FieldGuideCategoryAccentPresentation.huePair(for: categoryID)
                #expect(luminance(pair.light) < luminance(pair.dark))
            }
            #expect(
                FieldGuideCategoryAccentPresentation.darkGradientTopRGB(for: "fishes")
                    == FieldGuideCategoryAccentPresentation.RGB(red: 1.00, green: 0.55, blue: 0.12)
            )
            #expect(
                FieldGuideCategoryAccentPresentation.lightGradientTopRGB(for: "fishes")
                    == FieldGuideCategoryAccentPresentation.RGB(red: 0.78, green: 0.38, blue: 0.04)
            )
            let fishesLightBottom = FieldGuideCategoryAccentPresentation.lightGradientBottomRGB(for: "fishes")
            #expect(
                fishesLightBottom
                    == FieldGuideCategoryAccentPresentation.RGB(
                        red: 0.78 * 0.18,
                        green: 0.38 * 0.18,
                        blue: 0.04 * 0.18
                    )
            )
        }

        @Test func fieldGuideSubcategoryPresentation_matchesCategoryDetailHeroChrome() {
            let inset: CGFloat = 59
            #expect(
                FieldGuideSubcategoryPresentation.detailHeroHeight(extraTopInset: inset)
                    == FieldGuideCategoryPresentation.detailHeroHeight(extraTopInset: inset)
            )
            let safeTop: CGFloat = 59
            let headerClearance: CGFloat = 52
            #expect(
                FieldGuideSubcategoryPresentation.chromeTopInset(
                    safeAreaTop: safeTop,
                    headerClearance: headerClearance
                ) == safeTop + headerClearance
            )
        }

        @Test func fieldGuideCatalogIndex_browsePayload_usesTaxonomySubcategoryTitle() {
            let payload = FieldGuideCatalogIndex.browsePayload(
                categoryID: "fishes",
                subcategoryID: "angelfishes",
                speciesIndex: [:]
            )
            #expect(payload.title == "Angelfishes")
            #expect(payload.categoryID == "fishes")
            #expect(payload.subcategoryID == "angelfishes")
        }

        @Test func fieldGuideMarineLifeHeroPresentation_autoSpinPausesWhileDraggingAndAfterDrag() {
            let now = Date(timeIntervalSinceReferenceDate: 1_000)
            let pausedUntil = now.addingTimeInterval(15)

            #expect(
                !FieldGuideMarineLifeHeroPresentation.shouldAdvanceAutoSpin(
                    autoRotateSpeedRadiansPerSecond: 0.225,
                    isDragging: true,
                    autoSpinPausedUntil: nil,
                    now: now
                )
            )
            #expect(
                !FieldGuideMarineLifeHeroPresentation.shouldAdvanceAutoSpin(
                    autoRotateSpeedRadiansPerSecond: 0.225,
                    isDragging: false,
                    isPinching: true,
                    autoSpinPausedUntil: nil,
                    now: now
                )
            )
            #expect(
                !FieldGuideMarineLifeHeroPresentation.shouldAdvanceAutoSpin(
                    autoRotateSpeedRadiansPerSecond: 0.225,
                    isDragging: false,
                    autoSpinPausedUntil: pausedUntil,
                    now: now
                )
            )
            #expect(
                FieldGuideMarineLifeHeroPresentation.shouldAdvanceAutoSpin(
                    autoRotateSpeedRadiansPerSecond: 0.225,
                    isDragging: false,
                    autoSpinPausedUntil: pausedUntil,
                    now: pausedUntil
                )
            )
        }

        @Test func fieldGuideMarineLifeHeroInteractionPresentation_zoomTrackballAndIdleReset() {
            #expect(
                FieldGuideMarineLifeHeroInteractionPresentation.clampedZoomScale(0.5)
                    == FieldGuideMarineLifeHeroInteractionPresentation.minimumZoomScale
            )
            #expect(
                FieldGuideMarineLifeHeroInteractionPresentation.clampedZoomScale(4)
                    == FieldGuideMarineLifeHeroInteractionPresentation.maximumZoomScale
            )

            let horizontal = FieldGuideMarineLifeHeroInteractionPresentation.dragTrackballRotation(
                translationWidth: 120,
                translationHeight: 0
            )
            #expect(
                FieldGuideMarineLifeHeroInteractionPresentation.hasSignificantUserRotation(horizontal)
            )

            let diagonal = FieldGuideMarineLifeHeroInteractionPresentation.dragTrackballRotation(
                translationWidth: 80,
                translationHeight: 80
            )
            #expect(
                FieldGuideMarineLifeHeroInteractionPresentation.hasSignificantUserRotation(diagonal)
            )

            let now = Date(timeIntervalSinceReferenceDate: 2_000)
            let pausedUntil = now.addingTimeInterval(15)
            let spun = FieldGuideMarineLifeHeroInteractionPresentation.dragTrackballRotation(
                translationWidth: 0,
                translationHeight: 200
            )
            #expect(
                !FieldGuideMarineLifeHeroInteractionPresentation.shouldBeginIdleReset(
                    isDragging: false,
                    isPinching: false,
                    isPlayingIdleReset: false,
                    autoSpinPausedUntil: pausedUntil,
                    zoomScale: 1,
                    committedUserRotation: FieldGuideMarineLifeHeroInteractionPresentation.identityRotation,
                    now: now
                )
            )
            #expect(
                FieldGuideMarineLifeHeroInteractionPresentation.shouldBeginIdleReset(
                    isDragging: false,
                    isPinching: false,
                    isPlayingIdleReset: false,
                    autoSpinPausedUntil: pausedUntil,
                    zoomScale: 1,
                    committedUserRotation: spun,
                    now: pausedUntil
                )
            )

            let mid = FieldGuideMarineLifeHeroInteractionPresentation.idleResetLerp(
                start: 0.2,
                linearProgress: 0.5
            )
            #expect(mid > 0 && mid < 0.2)
        }

        @Test @MainActor func marineLifeCatalogLoader_loadsSortedCatalogOffMainActor() async throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext
            try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context)

            let persistentIDs = await MarineLifeCatalogLoader.fetchSortedPersistentIDs(container: container)
            #expect(!persistentIDs.isEmpty)

            let bound = MarineLifeCatalogLoader.bindModels(persistentIDs: persistentIDs, modelContext: context)
            #expect(bound.count == persistentIDs.count)
            let sortedNames = bound.map(\.commonName)
            #expect(sortedNames == sortedNames.sorted {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            })
        }

        @Test func marineLifeCatalogSeeder_usesBundledMarineLifeResourceName() {
            #expect(MarineLifeCatalogSeeder.bundledResourceName == "marine_life")
        }

        @Test @MainActor func marineLifeCatalogSeeder_seedsFrenchAngelfishModel() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext
            try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context)
            let french = try context.fetch(FetchDescriptor<MarineLife>()).first {
                $0.uuid == "marine-life-french-angelfish"
            }
            #expect(french?.commonName == "French Angelfish")
            #expect(french?.featureImageResourceName == "marine-life-french-angelfish")
            #expect(french?.featureModelResourceName == "FrenchAngelfish")
            #expect(french?.scientificName == "Pomacanthus paru")
        }

        @Test @MainActor func marineLifeCatalogSeeder_seedsCaribbeanReefShark() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext
            try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context)
            let species = try context.fetch(FetchDescriptor<MarineLife>()).first {
                $0.uuid == "marine-life-caribbean-reef-shark"
            }
            #expect(species?.commonName == "Caribbean Reef Shark")
            #expect(species?.scientificName == "Carcharhinus perezii")
            #expect(species?.category == "fishes")
            #expect(species?.subcategory == "sharks")
            #expect(species?.familyName == "Carcharhinidae")
            #expect(species?.featureImageResourceName == "marine-life-caribbean-reef-shark")
            #expect(species?.featureModelResourceName == "CaribbeanReefShark")
            #expect(species?.maxSizeMeters == 3.0)
            #expect(species?.minDepthMeters == 1.0)
            #expect(species?.maxDepthMeters == 100.0)
        }

        @Test @MainActor func marineLifeCatalogSeeder_seedsGreenSeaTurtleModel() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext
            try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context)
            let turtle = try context.fetch(FetchDescriptor<MarineLife>()).first {
                $0.uuid == "marine-life-green-sea-turtle"
            }
            #expect(turtle?.commonName == "Green Sea Turtle")
            #expect(turtle?.scientificName == "Chelonia mydas")
            #expect(turtle?.featureModelResourceName == "GreenSeaTurtle")
            #expect(turtle?.featureImageResourceName == "marine-life-green-sea-turtle")
            #expect(!turtle!.featureImageURL.isEmpty)
        }

        @Test func fieldGuideMarineLifeBundledImagePresentation_greenSeaTurtlePhotoShipsInAppBundle() {
            let url = FieldGuideMarineLifeBundledImagePresentation.bundledPhotoURL(
                resourceName: "marine-life-green-sea-turtle"
            )
            #expect(url != nil)
            let source = FieldGuideMarineLifeBundledImagePresentation.imageSource(
                featureImageResourceName: "marine-life-green-sea-turtle",
                featureImageURL: "https://reefguide.org/pix/greenturtle12.jpg"
            )
            guard case .bundledFile(let bundledURL) = source else {
                Issue.record("Expected bundled green sea turtle photo")
                return
            }
            #expect(bundledURL == url)
        }

        @Test func fieldGuideMarineLifeHeroPresentation_greenSeaTurtleCatalogHasImageAndModel() {
            let availability = FieldGuideSpeciesHeroPresentation.catalogHeroAvailability(
                featureModelResourceName: "GreenSeaTurtle",
                featureImageResourceName: "marine-life-green-sea-turtle",
                featureImageURL: "https://reefguide.org/pix/greenturtle12.jpg"
            )
            #expect(availability.hasModel3D)
            #expect(availability.hasImage)
            #expect(availability.supportsHeaderToggle)
            #expect(
                FieldGuideSpeciesHeroPresentation.defaultCatalogHeroDisplay(
                    availability: availability
                ) == .image
            )
        }

        @Test @MainActor func marineLifeCatalogSeeder_seedsSpottedEagleRayModel() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext
            try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context)
            let ray = try context.fetch(FetchDescriptor<MarineLife>()).first {
                $0.uuid == "marine-life-whitespotted-eagle-ray"
            }
            #expect(ray?.commonName == "Spotted Eagle Ray")
            #expect(ray?.scientificName == "Aetobatus narinari")
            #expect(ray?.featureModelResourceName == "SpottedEagleRay")
        }

        @Test @MainActor func marineLifeCatalogSeeder_seedsGreatBarracudaModel() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext
            try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context)
            let species = try context.fetch(FetchDescriptor<MarineLife>()).first {
                $0.uuid == "marine-life-great-barracuda"
            }
            #expect(species?.commonName == "Great Barracuda")
            #expect(species?.scientificName == "Sphyraena barracuda")
            #expect(species?.featureModelResourceName == "GreatBarracuda")
        }

        @Test @MainActor func marineLifeCatalogSeeder_seedsSergeantMajorModel() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext
            try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context)
            let species = try context.fetch(FetchDescriptor<MarineLife>()).first {
                $0.uuid == "marine-life-sergeant-major"
            }
            #expect(species?.commonName == "Sergeant Major")
            #expect(species?.scientificName == "Abudefduf saxatilis")
            #expect(species?.featureModelResourceName == "SergeantMajor")
        }

        @Test @MainActor func marineLifeCatalogSeeder_seedsRockBeautyModel() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext
            try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context)
            let species = try context.fetch(FetchDescriptor<MarineLife>()).first {
                $0.uuid == "marine-life-rock-beauty"
            }
            #expect(species?.commonName == "Rock Beauty")
            #expect(species?.scientificName == "Holacanthus tricolor")
            #expect(species?.featureModelResourceName == "RockBeauty")
        }

        @Test @MainActor func marineLifeCatalogSeeder_seedsRedLionfishModel() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext
            try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context)
            let species = try context.fetch(FetchDescriptor<MarineLife>()).first {
                $0.uuid == "marine-life-red-lionfish"
            }
            #expect(species?.commonName == "Red Lionfish")
            #expect(species?.scientificName == "Pterois volitans")
            #expect(species?.featureModelResourceName == "RedLionfish")
        }

        @Test @MainActor func marineLifeCatalogSeeder_seedsCaribbeanReefSharkModel() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext
            try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context)
            let species = try context.fetch(FetchDescriptor<MarineLife>()).first {
                $0.uuid == "marine-life-caribbean-reef-shark"
            }
            #expect(species?.commonName == "Caribbean Reef Shark")
            #expect(species?.scientificName == "Carcharhinus perezii")
            #expect(species?.featureModelResourceName == "CaribbeanReefShark")
            #expect(species?.maxSizeMeters == 3.0)
        }

        @Test @MainActor func marineLifeCatalogSeeder_seedsTarponModel() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext
            try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context)
            let species = try context.fetch(FetchDescriptor<MarineLife>()).first {
                $0.uuid == "marine-life-tarpon"
            }
            #expect(species?.commonName == "Tarpon")
            #expect(species?.scientificName == "Megalops atlanticus")
            #expect(species?.featureModelResourceName == "Tarpon")
            #expect(species?.maxSizeMeters == 2.5)
        }

        @Test @MainActor func marineLifeCatalogSeeder_seedsStoplightParrotfishModel() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext
            try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context)
            let species = try context.fetch(FetchDescriptor<MarineLife>()).first {
                $0.uuid == "marine-life-stoplight-parrotfish"
            }
            #expect(species?.commonName == "Stoplight Parrotfish (terminal)")
            #expect(species?.scientificName == "Sparisoma viride")
            #expect(species?.featureModelResourceName == "StoplightParrotfish")
            #expect(species?.maxSizeMeters == 0.64)
        }

        @Test @MainActor func marineLifeCatalogSeeder_seedsNineAdditionalFeatureModels() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext
            try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context)
            let byUUID = Dictionary(
                uniqueKeysWithValues: try context.fetch(FetchDescriptor<MarineLife>()).map { ($0.uuid, $0) }
            )
            let expected: [(uuid: String, common: String, scientific: String, model: String)] = [
                ("marine-life-barred-hamlet", "Barred Hamlet", "Hypoplectrus puella", "BarredHamlet"),
                ("marine-life-black-hamlet", "Black Hamlet", "Hypoplectrus nigricans", "BlackHamlet"),
                ("marine-life-butter-hamlet", "Butter Hamlet", "Hypoplectrus unicolor", "ButterHamlet"),
                ("marine-life-gray-angelfish", "Gray Angelfish", "Pomacanthus arcuatus", "GrayAngelfish"),
                ("marine-life-indigo-hamlet", "Indigo Hamlet", "Hypoplectrus indigo", "IndigoHamlet"),
                ("marine-life-longspine-squirrelfish", "Longspine Squirrelfish", "Holocentrus rufus", "LongspineSquirrelfish"),
                ("marine-life-spot-fin-porcupinefish", "Porcupinefish", "Diodon hystrix", "PorcupineFish"),
                ("marine-life-queen-angelfish", "Queen Angelfish", "Holacanthus ciliaris", "QueenAngelfish"),
                ("marine-life-shy-hamlet", "Shy Hamlet", "Hypoplectrus guttavarius", "ShyHamlet"),
            ]
            for row in expected {
                let species = byUUID[row.uuid]
                #expect(species?.commonName == row.common)
                #expect(species?.scientificName == row.scientific)
                #expect(species?.featureModelResourceName == row.model)
            }
        }

        @Test func fieldGuidePresentation_depthLine_prefersMinMaxRange() {
            let entry = MarineLifeCatalogSnapshot(
                uuid: "queen",
                commonName: "Queen Angelfish",
                scientificName: "Holacanthus ciliaris",
                category: "fish",
                subcategory: "disk-and-large-oval",
                featureImageURL: "",
                minSizeMeters: 0.2,
                maxSizeMeters: 0.36,
                avgDepthMeters: 15.5,
                minDepthMeters: 6,
                maxDepthMeters: 25
            )
            let line = FieldGuidePresentation.sizeDepthLine(for: entry, unitSystem: .imperial)
            #expect(line.contains("20 ft–80 ft"))
            let metricLine = FieldGuidePresentation.depthLine(
                minMeters: 6,
                maxMeters: 25,
                avgMeters: 15.5,
                unitSystem: .metric
            )
            #expect(metricLine == "6 m–25 m")
        }

        @Test @MainActor func marineLifeCatalogSeeder_isIdempotentByUUID() throws {
            let suiteName = "test.marineLife.idempotent.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            defer {
                defaults.removePersistentDomain(forName: suiteName)
            }
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext
            try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context, userDefaults: defaults)
            let firstCount = try context.fetchCount(FetchDescriptor<MarineLife>())
            #expect(firstCount > 0)
            try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context, userDefaults: defaults)
            #expect(try context.fetchCount(FetchDescriptor<MarineLife>()) == firstCount)
        }

        @Test @MainActor func marineLifeCatalogSeeder_skipsUpsertWhenFingerprintMatches() throws {
            let suiteName = "test.marineLife.fingerprint.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            defer {
                defaults.removePersistentDomain(forName: suiteName)
            }
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext
            try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context, userDefaults: defaults)
            let french = try context.fetch(FetchDescriptor<MarineLife>()).first {
                $0.uuid == "marine-life-french-angelfish"
            }
            #expect(french != nil)
            french?.aboutText = "MUTATED_FOR_SKIP_TEST"
            try context.save()

            try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context, userDefaults: defaults)
            let afterSkip = try context.fetch(FetchDescriptor<MarineLife>()).first {
                $0.uuid == "marine-life-french-angelfish"
            }
            #expect(afterSkip?.aboutText == "MUTATED_FOR_SKIP_TEST")

            MarineLifeCatalogSeeder.resetAppliedFingerprintForTesting(userDefaults: defaults)
            try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context, userDefaults: defaults)
            let afterReseed = try context.fetch(FetchDescriptor<MarineLife>()).first {
                $0.uuid == "marine-life-french-angelfish"
            }
            #expect(afterReseed?.aboutText != "MUTATED_FOR_SKIP_TEST")
        }

        @Test @MainActor func marineLifeCatalogSeeder_storesResourceAttributesForLaunchSkip() throws {
            let suiteName = "test.marineLife.resourceAttrs.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            defer {
                defaults.removePersistentDomain(forName: suiteName)
            }
            guard
                let fileURL = Bundle.main.url(forResource: MarineLifeCatalogSeeder.bundledResourceName, withExtension: "json"),
                let expectedAttributes = MarineLifeCatalogSeeder.resourceAttributesToken(at: fileURL)
            else {
                Issue.record("Bundled marine_life.json missing from test host")
                return
            }
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext
            try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context, userDefaults: defaults)
            #expect(defaults.string(forKey: MarineLifeCatalogSeeder.appliedFingerprintDefaultsKey) != nil)
            #expect(
                defaults.string(forKey: MarineLifeCatalogSeeder.appliedResourceAttributesDefaultsKey)
                    == expectedAttributes
            )
        }

        @Test @MainActor func marineLifeCatalogSeeder_prunesSpeciesRemovedFromBundledJSON() throws {
            let suiteName = "test.marineLife.prune.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            defer {
                defaults.removePersistentDomain(forName: suiteName)
            }
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext
            context.insert(
                MarineLife(
                    uuid: "marine-life-orphan-catalog-row",
                    commonName: "Orphan Species",
                    scientificName: "Orphanus testus"
                )
            )
            try context.save()

            try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context, userDefaults: defaults)

            let orphan = try context.fetch(FetchDescriptor<MarineLife>()).first {
                $0.uuid == "marine-life-orphan-catalog-row"
            }
            #expect(orphan == nil)
            #expect(try context.fetchCount(FetchDescriptor<MarineLife>()) > 0)
        }

        @Test @MainActor func marineLifeCatalogSeeder_preservesUserCreatedSpeciesOnReseed() throws {
            let suiteName = "test.marineLife.preserve.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            defer {
                defaults.removePersistentDomain(forName: suiteName)
            }
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext
            let userSpecies = FieldGuideMarineLifeAddPresentation.makeMarineLife(
                from: FieldGuideMarineLifeAddPresentation.FormValues(
                    commonName: "My Custom Goby",
                    scientificName: "Gobius customus",
                    categoryID: "fishes",
                    subcategoryID: "gobies"
                )
            )
            context.insert(userSpecies)
            try context.save()

            try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context, userDefaults: defaults)

            let preserved = try context.fetch(FetchDescriptor<UserMarineLife>()).first {
                $0.uuid == userSpecies.uuid
            }
            #expect(preserved?.commonName == "My Custom Goby")
            #expect(FieldGuideMarineLifeAddPresentation.isUserCreated(uuid: userSpecies.uuid))
            #expect(try context.fetch(FetchDescriptor<MarineLife>()).allSatisfy {
                !FieldGuideMarineLifeAddPresentation.isUserCreated(uuid: $0.uuid)
            })
        }

        @Test @MainActor func marineLifeCatalogUpsert_updatesAndPrunesCatalogRowsPreservingUserPrefix() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext

            context.insert(
                MarineLife(
                    uuid: "marine-life-cdn-keep",
                    commonName: "Old Name",
                    scientificName: "Oldus nameus",
                    ownership: .catalog
                )
            )
            context.insert(
                MarineLife(
                    uuid: "marine-life-cdn-orphan",
                    commonName: "Orphan",
                    scientificName: "Orphanus",
                    ownership: .catalog
                )
            )
            let userUUID = FieldGuideMarineLifeAddPresentation.makeUserCreatedUUID()
            context.insert(
                MarineLife(
                    uuid: userUUID,
                    commonName: "User Keep",
                    scientificName: "Userus keepus",
                    ownership: .userOwned
                )
            )
            try context.save()

            let outcome = try MarineLifeCatalogUpsert.apply(
                dtos: [
                    MarineLifeDTO(
                        uuid: "marine-life-cdn-keep",
                        commonName: "Updated Name",
                        scientificName: "Newus nameus",
                        category: "fishes"
                    ),
                    MarineLifeDTO(
                        uuid: "marine-life-cdn-new",
                        commonName: "Brand New",
                        scientificName: "Brandus newus"
                    ),
                ],
                modelContext: context
            )

            #expect(outcome.upsertedCount == 2)
            #expect(outcome.prunedCount == 1)

            let rows = try context.fetch(FetchDescriptor<MarineLife>())
            let byUUID = Dictionary(uniqueKeysWithValues: rows.map { ($0.uuid, $0) })
            #expect(byUUID["marine-life-cdn-keep"]?.commonName == "Updated Name")
            #expect(byUUID["marine-life-cdn-keep"]?.ownership == .catalog)
            #expect(byUUID["marine-life-cdn-new"]?.commonName == "Brand New")
            #expect(byUUID["marine-life-cdn-orphan"] == nil)
            #expect(byUUID[userUUID]?.commonName == "User Keep")
        }

        @Test func fieldGuideMarineLifeAddPresentation_validatesAndBuildsSpecies() {
            var form = FieldGuideMarineLifeAddPresentation.FormValues(
                commonName: "  Blue Tang  ",
                scientificName: "Acanthurus coeruleus",
                categoryID: "fishes",
                subcategoryID: "surgeonfishes",
                familyName: "Acanthuridae",
                aboutText: "Herbivorous reef fish."
            )
            #expect(FieldGuideMarineLifeAddPresentation.canSave(form))
            let species = FieldGuideMarineLifeAddPresentation.makeMarineLife(from: form)
            #expect(species.commonName == "Blue Tang")
            #expect(species.category == "fishes")
            #expect(species.subcategory == "surgeonfishes")
            #expect(FieldGuideMarineLifeAddPresentation.isUserCreated(uuid: species.uuid))

            form.commonName = "   "
            #expect(!FieldGuideMarineLifeAddPresentation.canSave(form))
            #expect(FieldGuideMarineLifeAddPresentation.sheetTitle == "New species")
            #expect(
                FieldGuideMarineLifeAddPresentation.chromeAccessibilityIdentifier
                    == "FieldGuide.AddSpecies"
            )
        }

        @Test @MainActor
        func fieldGuideMarineLifeAddPresentation_applyEdits_updatesUserCreatedOnly() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)

            let userSpecies = FieldGuideMarineLifeAddPresentation.makeMarineLife(
                from: FieldGuideMarineLifeAddPresentation.FormValues(
                    commonName: "Custom Tang",
                    scientificName: "Acanthurus sp",
                    categoryID: "fishes",
                    subcategoryID: "surgeonfishes",
                    familyName: "Acanthuridae",
                    aboutText: "Original note"
                )
            )
            context.insert(userSpecies)
            try context.save()

            var form = FieldGuideMarineLifeAddPresentation.FormValues(from: userSpecies)
            form.commonName = "Updated Tang"
            form.aboutText = "Revised note"
            try FieldGuideMarineLifeAddPresentation.applyEdits(
                to: userSpecies,
                form: form,
                modelContext: context
            )
            #expect(userSpecies.commonName == "Updated Tang")
            #expect(userSpecies.aboutText == "Revised note")

            let bundled = MarineLife(
                uuid: "marine-life-queen-angelfish",
                commonName: "Queen Angelfish",
                category: "fishes"
            )
            #expect(!FieldGuideMarineLifeAddPresentation.isUserEditable(bundled))
            #expect(
                throws: FieldGuideMarineLifeEditError.notUserCreated
            ) {
                try FieldGuideMarineLifeAddPresentation.applyEdits(
                    to: bundled,
                    form: FieldGuideMarineLifeAddPresentation.FormValues(commonName: "Nope"),
                    modelContext: context,
                    persistImmediately: false
                )
            }
            #expect(FieldGuideMarineLifeEditPresentation.doneAccessibilityIdentifier == "FieldGuide.EditSpeciesSheet.Done")
        }

        @Test @MainActor func marineLifeCatalogSeeder_seedsQueenAngelfish() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext
            try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context)
            let queen = try context.fetch(FetchDescriptor<MarineLife>()).first { $0.uuid == "marine-life-queen-angelfish" }
            #expect(queen?.commonName == "Queen Angelfish")
            #expect(queen?.familyName == "Pomacanthidae")
            #expect(queen?.minDepthMeters == 1)
            #expect(queen?.maxDepthMeters == 70)
        }

        @Test func fieldGuideMarineLifeHero_speciesConfigKeepsGlow() {
            #expect(FieldGuideMarineLifeHeroSceneConfiguration.frenchAngelfish.showsGlow == true)
            let generated = FieldGuideMarineLifeHeroPresentation.sceneConfiguration(
                forModelResourceName: "BarredHamlet"
            )
            #expect(generated.showsGlow == true)
        }

        @Test func fieldGuideTaxonomy_fishesCategoryHasDetailHeaderCopy() {
            let fish = FieldGuideTaxonomy.category(id: "fishes")
            #expect(fish?.title == "Fishes")
            #expect(fish?.description.contains("Caribbean Reef Life") == true)
            #expect(fish?.heroImageName == "FieldGuideCategoryFish")
            #expect(fish?.subcategories.count == 48)
        }

        @Test func fieldGuideTaxonomy_resolvesLegacyCategoryLabels() {
            let ray = MarineLifeCatalogSnapshot(
                uuid: "ray",
                commonName: "Spotted Eagle Ray",
                scientificName: "Aetobatus narinari",
                category: "Ray",
                subcategory: "",
                featureImageURL: "",
                minSizeMeters: 0,
                maxSizeMeters: 0,
                avgDepthMeters: 0
            )
            #expect(FieldGuideTaxonomy.resolvedCategoryID(for: ray) == "fishes")
            #expect(FieldGuideTaxonomy.resolvedSubcategoryID(for: ray) == "rays")
            #expect(FieldGuideTaxonomy.subcategoryTitle(for: ray) == "Rays")
        }

        @Test func fieldGuideCatalogIndex_countsSpeciesPerCategoryAndSubcategory() {
            let samples = [
                MarineLifeCatalogSnapshot(
                    uuid: "a",
                    commonName: "French Angelfish",
                    scientificName: "",
                    category: "fishes",
                    subcategory: "angelfishes",
                    featureImageURL: "",
                    minSizeMeters: 0,
                    maxSizeMeters: 0,
                    avgDepthMeters: 0
                ),
                MarineLifeCatalogSnapshot(
                    uuid: "b",
                    commonName: "Spotted Eagle Ray",
                    scientificName: "",
                    category: "fishes",
                    subcategory: "rays",
                    featureImageURL: "",
                    minSizeMeters: 0,
                    maxSizeMeters: 0,
                    avgDepthMeters: 0
                ),
            ]
            let summaries = FieldGuideCatalogIndex.summaries(for: samples)
            let fish = summaries.first { $0.categoryID == "fishes" }
            #expect(fish?.speciesCount == 2)
            #expect(fish?.subcategoryCounts["angelfishes"] == 1)
            #expect(fish?.subcategoryCounts["rays"] == 1)
            #expect(FieldGuideCatalogIndex.species(in: "fishes", subcategoryID: "eels", catalog: samples).isEmpty)
        }

        @Test func fieldGuideCatalogIndex_summariesAndSubcategoriesSortAlphabeticallyByDisplayTitle() {
            let summaries = FieldGuideCatalogIndex.summaries(for: [])
            #expect(
                summaries.map(\.categoryID) == [
                    "corals",
                    "fishes",
                    "invertebrates",
                    "mammals",
                    "plants",
                    "reptiles",
                    "sponges",
                ]
            )

            let fish = FieldGuideTaxonomy.category(id: "fishes")!
            let ordered = FieldGuideCatalogIndex.sortedSubcategories(fish.subcategories)
            #expect(ordered.first?.title == "Angelfishes")
            #expect(ordered.last?.title == "Wrasses")
            #expect(ordered.map(\.id) == ordered.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }.map(\.id))
        }

        @Test @MainActor func fieldGuideCatalogIndex_categorySummaryIsHashable() {
            let summary = FieldGuideCatalogIndex.CategorySummary(
                categoryID: "fishes",
                speciesCount: 3,
                subcategoryCounts: ["eels": 1, "rays": 2]
            )
            var seen: Set<FieldGuideCatalogIndex.CategorySummary> = []
            seen.insert(summary)
            #expect(seen.contains(summary))
        }

        @Test func fieldGuideCatalogIndex_subcategorySpeciesIndex_lookup() {
            let samples = [
                MarineLifeCatalogSnapshot(
                    uuid: "a",
                    commonName: "Zebra Fish",
                    scientificName: "",
                    category: "fishes",
                    subcategory: "gobies",
                    featureImageURL: "",
                    minSizeMeters: 0,
                    maxSizeMeters: 0,
                    avgDepthMeters: 0
                ),
                MarineLifeCatalogSnapshot(
                    uuid: "b",
                    commonName: "Angelfish",
                    scientificName: "",
                    category: "fishes",
                    subcategory: "angelfishes",
                    featureImageURL: "",
                    minSizeMeters: 0,
                    maxSizeMeters: 0,
                    avgDepthMeters: 0
                ),
                MarineLifeCatalogSnapshot(
                    uuid: "c",
                    commonName: "Another Oval",
                    scientificName: "",
                    category: "fishes",
                    subcategory: "angelfishes",
                    featureImageURL: "",
                    minSizeMeters: 0,
                    maxSizeMeters: 0,
                    avgDepthMeters: 0
                ),
            ]

            let index = FieldGuideCatalogIndex.subcategorySpeciesIndex(for: samples)
            let payload = FieldGuideCatalogIndex.browsePayload(
                categoryID: "fishes",
                subcategoryID: "angelfishes",
                speciesIndex: index
            )

            #expect(payload.title == "Angelfishes")
            #expect(payload.species.map(\.uuid) == ["b", "c"])
            #expect(
                FieldGuideCatalogIndex.browsePayload(
                    categoryID: "fishes",
                    subcategoryID: "eels",
                    speciesIndex: index
                ).species.isEmpty
            )
        }

        @Test func fieldGuideCatalogIndex_representativeSpecies_prefersPhotoInSubcategory() {
            let samples = [
                MarineLifeCatalogSnapshot(
                    uuid: "no-photo",
                    commonName: "Alpha Fish",
                    scientificName: "",
                    category: "fishes",
                    subcategory: "gobies",
                    featureImageURL: "",
                    minSizeMeters: 0,
                    maxSizeMeters: 0,
                    avgDepthMeters: 0
                ),
                MarineLifeCatalogSnapshot(
                    uuid: "with-photo",
                    commonName: "Beta Fish",
                    scientificName: "",
                    category: "fishes",
                    subcategory: "gobies",
                    featureImageURL: "https://example.com/beta.jpg",
                    minSizeMeters: 0,
                    maxSizeMeters: 0,
                    avgDepthMeters: 0
                ),
            ]
            let index = FieldGuideCatalogIndex.subcategorySpeciesIndex(for: samples)
            let representative = FieldGuideCatalogIndex.representativeSpecies(
                categoryID: "fishes",
                subcategoryID: "gobies",
                speciesIndex: index
            )
            #expect(representative?.uuid == "with-photo")
            #expect(FieldGuideCatalogIndex.speciesHasCatalogImage(samples[1]))
            #expect(!FieldGuideCatalogIndex.speciesHasCatalogImage(samples[0]))
        }

        @Test func fieldGuideCatalogIndex_representativeSpecies_fallsBackToFirstSpeciesWithoutPhoto() {
            let samples = [
                MarineLifeCatalogSnapshot(
                    uuid: "only",
                    commonName: "Solo Fish",
                    scientificName: "",
                    category: "fishes",
                    subcategory: "blennies",
                    featureImageURL: "",
                    minSizeMeters: 0,
                    maxSizeMeters: 0,
                    avgDepthMeters: 0
                ),
            ]
            let index = FieldGuideCatalogIndex.subcategorySpeciesIndex(for: samples)
            #expect(
                FieldGuideCatalogIndex.representativeSpecies(
                    categoryID: "fishes",
                    subcategoryID: "blennies",
                    speciesIndex: index
                )?.uuid == "only"
            )
        }

        @Test func fieldGuideHubTileLayout_matchesLogbookActivityRowSpacing() {
            #expect(FieldGuideHubTileLayout.listRowSpacing == AppTheme.Spacing.sm)
            #expect(FieldGuideHubTileLayout.tilePadding == LogbookActivityRowLayout.cardPadding)
            #expect(FieldGuideHubTileLayout.tileCornerRadius == LogbookActivityRowLayout.cardCornerRadius)
            // Taller than the old 96 pt so title + two-line subtitle + species pill keep the same
            // 8 pt breathing room the dive activity tile has (content no longer crams the edges).
            #expect(FieldGuideHubTileLayout.tileHeight == 108)
            #expect(
                FieldGuideHubTileLayout.tileHeight
                    >= FieldGuideHubTileLayout.subtitleTwoLineMinHeight
                        + 2 * FieldGuideHubTileLayout.tilePadding
            )
            #expect(FieldGuideHubTileLayout.subtitleTwoLineMinHeight > 0)
            #expect(FieldGuideHubTileLayout.hubTitleScrollFeather == 44)
            #expect(FieldGuideHubTileLayout.hubScrollScrimHeight(topChromeInset: 111) == 155)
            #expect(FieldGuideHubTileLayout.titleTwoLineMinHeight(isFeatured: false) > 0)
        }

        @Test func fieldGuideHubTileLayout_speciesBadgeMatchesCompactActivityOvalInsets() {
            // Species pill insets align with the dive activity tile's compact oval
            // (`ActivityTagOvalChipLabel` with `isCompact: true` → horizontal 10, vertical 4).
            #expect(FieldGuideHubTileLayout.speciesBadgeHorizontalPadding == 10)
            #expect(FieldGuideHubTileLayout.speciesBadgeVerticalPadding == 4)
        }

        @Test func fieldGuideMarineLifeSearch_precomputedSearchText_matchesLegacyMatcher() {
            let angelfish = MarineLifeCatalogSnapshot(
                uuid: "marine-life-angelfish",
                commonName: "French Angelfish",
                scientificName: "Pomacanthus paru",
                category: "fish",
                subcategory: "disk-and-large-oval",
                featureImageURL: "",
                minSizeMeters: 0.2,
                maxSizeMeters: 0.4,
                avgDepthMeters: 12
            )
            let haystack = FieldGuideMarineLifeSearch.precomputedSearchText(for: angelfish)
            #expect(haystack.contains("french angelfish"))
            #expect(FieldGuideMarineLifeSearch.matches(angelfish, query: "french"))
            #expect(haystack.contains("pomacanthus"))
            #expect(FieldGuideMarineLifeSearch.matches(angelfish, query: "paru"))
            #expect(!haystack.contains("turtle"))
            #expect(!FieldGuideMarineLifeSearch.matches(angelfish, query: "turtle"))
        }

        @Test func fieldGuideMarineLifeSearch_matchesCommonScientificOrCategory() {
            let angelfish = MarineLifeCatalogSnapshot(
                uuid: "marine-life-angelfish",
                commonName: "French Angelfish",
                scientificName: "Pomacanthus paru",
                category: "fish",
                subcategory: "disk-and-large-oval",
                featureImageURL: "",
                minSizeMeters: 0.2,
                maxSizeMeters: 0.35,
                avgDepthMeters: 15
            )
            #expect(FieldGuideMarineLifeSearch.matches(angelfish, query: "french"))
            #expect(FieldGuideMarineLifeSearch.matches(angelfish, query: "pomacanthus"))
            #expect(FieldGuideMarineLifeSearch.matches(angelfish, query: "fish"))
            #expect(!FieldGuideMarineLifeSearch.matches(angelfish, query: "turtle"))
            #expect(FieldGuideMarineLifeSearch.filtering([angelfish], query: "paru").count == 1)
            #expect(FieldGuideMarineLifeSearch.filtering([angelfish], query: "").count == 1)
        }

        @Test func fieldGuidePresentation_listDetailLine_joinsScientificNameAndSizeDepth() {
            #expect(
                FieldGuidePresentation.listDetailLine(
                    scientificName: "Pomacanthus paru",
                    sizeDepthLine: "up to 18 in · avg 45 ft"
                ) == "Pomacanthus paru · up to 18 in · avg 45 ft"
            )
            #expect(
                FieldGuidePresentation.listDetailLine(
                    scientificName: "",
                    sizeDepthLine: "avg 15 m"
                ) == "avg 15 m"
            )
            #expect(FieldGuidePresentation.listTrailingLabel(category: "Fish") == "Fish")
            #expect(FieldGuidePresentation.listTrailingLabel(category: "  ") == "—")
        }

        @Test func fieldGuideTaggedMediaPresentation_galleryRefreshToken_changesWhenSightingsChange() {
            let dive = DiveActivity(source: .manual, startTime: .now, durationMinutes: 1, maxDepthMeters: 1)
            let firstPhoto = DiveMediaPhoto(capturedAt: .now, dive: dive)
            let secondPhoto = DiveMediaPhoto(capturedAt: .now, dive: dive)
            let first = SightingInstance(
                marineLifeUUID: "a",
                sightingDateTime: .now,
                diveActivity: dive,
                mediaPhoto: firstPhoto
            )
            let second = SightingInstance(
                marineLifeUUID: "a",
                sightingDateTime: .now,
                diveActivity: dive,
                mediaPhoto: secondPhoto
            )
            let diveID = dive.id
            let tokenA = FieldGuideTaggedMediaPresentation.galleryRefreshToken(
                sightings: [first],
                ownerDiveActivityIDs: [diveID]
            )
            let tokenB = FieldGuideTaggedMediaPresentation.galleryRefreshToken(
                sightings: [first, second],
                ownerDiveActivityIDs: [diveID]
            )
            #expect(tokenA != tokenB)
        }

        @Test @MainActor func fieldGuideTaggedMediaPresentation_resolvedTaggedMediaPhotos_fetchesByMediaPhotoID() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)

            let dive = DiveActivity(source: .manual, startTime: .now, durationMinutes: 1, maxDepthMeters: 1)
            context.insert(dive)
            let media = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 5_000), dive: dive)
            context.insert(media)

            let sighting = SightingInstance(
                marineLifeUUID: "species-fetch-by-id",
                sightingDateTime: Date(timeIntervalSince1970: 5_000),
                diveActivity: dive
            )
            sighting.mediaPhoto = nil
            sighting.mediaPhotoID = media.id
            context.insert(sighting)
            try context.save()

            let photos = FieldGuideTaggedMediaPresentation.resolvedTaggedMediaPhotos(
                sightings: [sighting],
                ownerDiveActivityIDs: [dive.id],
                modelContext: context
            )
            #expect(photos.count == 1)
            #expect(photos[0].id == media.id)
        }

        @Test @MainActor func fieldGuideTaggedMediaPresentation_collectsUniqueOwnerPhotos_oldestCaptureFirst() {
            let dive = DiveActivity(source: .manual, startTime: .now, durationMinutes: 1, maxDepthMeters: 1)
            let otherDive = DiveActivity(source: .manual, startTime: .now, durationMinutes: 1, maxDepthMeters: 1)
            let older = DiveMediaPhoto(
                capturedAt: Date(timeIntervalSince1970: 1_000),
                dive: dive
            )
            let newer = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 2_000), dive: dive)
            let otherDivePhoto = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 3_000), dive: otherDive)

            let speciesUUID = "marine-life-tagged-media"
            let sightings = [
                SightingInstance(
                    marineLifeUUID: speciesUUID,
                    sightingDateTime: Date(timeIntervalSince1970: 2_000),
                    diveActivity: dive,
                    mediaPhoto: newer
                ),
                SightingInstance(
                    marineLifeUUID: speciesUUID,
                    sightingDateTime: Date(timeIntervalSince1970: 1_500),
                    diveActivity: dive,
                    mediaPhoto: older
                ),
                SightingInstance(
                    marineLifeUUID: speciesUUID,
                    sightingDateTime: Date(timeIntervalSince1970: 1_600),
                    diveActivity: dive,
                    mediaPhoto: older
                ),
                SightingInstance(
                    marineLifeUUID: speciesUUID,
                    sightingDateTime: Date(timeIntervalSince1970: 3_000),
                    diveActivity: otherDive,
                    mediaPhoto: otherDivePhoto
                ),
            ]

            let photos = FieldGuideTaggedMediaPresentation.taggedMediaPhotos(
                sightings: sightings,
                ownerDiveActivityIDs: [dive.id]
            )
            #expect(photos.map(\.id) == [older.id, newer.id])

            let offsets = FieldGuideTaggedMediaPresentation.timeZoneOffsetByMediaID(
                sightings: sightings,
                ownerDiveActivityIDs: [dive.id],
                timeZoneOffsetByActivityID: [dive.id: -14_400]
            )
            #expect(offsets[older.id] == -14_400)
            #expect(offsets[newer.id] == -14_400)
            #expect(offsets[otherDivePhoto.id] == nil)
        }

        @Test func fieldGuidePresentation_sightedActivityLinks_sortsNewestFirstAndFormatsTitle() {
            let olderID = UUID()
            let newerID = UUID()
            let links = FieldGuidePresentation.sightedActivityLinks(
                activityIDs: [olderID, newerID],
                activities: [
                    DiveActivitySightingLinkSnapshot(
                        id: olderID,
                        diveSiteID: nil,
                        resolvedSiteName: "Salt Pier",
                        startTime: Date(timeIntervalSince1970: 1_000_000),
                        timeZoneOffsetSeconds: nil
                    ),
                    DiveActivitySightingLinkSnapshot(
                        id: newerID,
                        diveSiteID: nil,
                        resolvedSiteName: nil,
                        startTime: Date(timeIntervalSince1970: 2_000_000),
                        timeZoneOffsetSeconds: nil
                    ),
                ]
            )

            #expect(links.count == 2)
            #expect(links[0].id == newerID)
            #expect(links[0].title == "New Dive")
            #expect(links[1].id == olderID)
            #expect(links[1].title == "Salt Pier")
            #expect(!links[0].dateText.isEmpty)
        }

        @Test func fieldGuideTaggedMediaPresentation_linkedMediaItems_mapsPhotosToParentDives() {
            let dive = DiveActivity(source: .manual, startTime: .now, durationMinutes: 1, maxDepthMeters: 1)
            let photo = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 1_000), dive: dive)
            let sighting = SightingInstance(
                marineLifeUUID: "species-linked-media",
                sightingDateTime: Date(timeIntervalSince1970: 1_000),
                diveActivity: dive,
                mediaPhoto: photo
            )
            sighting.mediaPhotoID = photo.id

            let linked = FieldGuideTaggedMediaPresentation.linkedMediaItems(
                sightings: [sighting],
                ownerDiveActivityIDs: [dive.id],
                mediaItems: [photo]
            )
            #expect(linked.count == 1)
            #expect(linked[0].id == photo.id)
            #expect(linked[0].diveActivityID == dive.id)
        }

        @Test func fieldGuideCatalogCacheBuild_indexesBoundSnapshotsWithoutRefetch() {
            let snapshots = [
                MarineLifeCatalogSnapshot(
                    uuid: "a",
                    commonName: "Queen Angelfish",
                    scientificName: "Holacanthus ciliaris",
                    category: "fishes",
                    subcategory: "angelfishes",
                    featureImageURL: "",
                    minSizeMeters: 0.1,
                    maxSizeMeters: 0.4,
                    avgDepthMeters: 10
                ),
                MarineLifeCatalogSnapshot(
                    uuid: "b",
                    commonName: "French Angelfish",
                    scientificName: "Pomacanthus paru",
                    category: "fishes",
                    subcategory: "angelfishes",
                    featureImageURL: "",
                    minSizeMeters: 0.1,
                    maxSizeMeters: 0.4,
                    avgDepthMeters: 12
                ),
            ]
            let built = FieldGuideCatalogCacheBuild.make(snapshots: snapshots)
            #expect(built.snapshots.count == 2)
            #expect(built.categorySummaries == FieldGuideCatalogIndex.summaries(for: snapshots))
            #expect(
                built.subcategorySpeciesIndex
                    == FieldGuideCatalogIndex.subcategorySpeciesIndex(for: snapshots)
            )
        }

        @Test func fieldGuideNavigationPresentation_showsRootTabBarOnBrowsePages() {
            #expect(
                FieldGuideNavigationPresentation.showsRootTabBar(for: .hub)
            )
            #expect(
                FieldGuideNavigationPresentation.showsRootTabBar(for: .categoryBrowse)
            )
            #expect(
                FieldGuideNavigationPresentation.showsRootTabBar(for: .subcategoryBrowse)
            )
            #expect(
                !FieldGuideNavigationPresentation.showsRootTabBar(for: .pushedDetail)
            )
        }

        @Test @MainActor func marineLifeCatalogLoader_commonNameMapAndUUIDBind() async throws {
            let dual = try AppSwiftDataDualStoreFactory.makeInMemorySplitContainer()
            let context = ModelContext(dual.container)
            let manta = MarineLife(uuid: "ml-manta", commonName: "Manta Ray")
            let turtle = MarineLife(uuid: "ml-turtle", commonName: "Green Turtle")
            context.insert(manta)
            context.insert(turtle)
            try context.save()

            let names = await MarineLifeCatalogLoader.fetchCommonNameByUUID(container: dual.container)
            #expect(names["ml-manta"] == "Manta Ray")
            #expect(names["ml-turtle"] == "Green Turtle")
            #expect(MarineLifeCatalogLoader.commonNameByUUID(from: [manta, turtle])["ml-manta"] == "Manta Ray")

            let thinNames = await MarineLifeCatalogLoader.fetchCommonNameByUUID(
                uuids: ["ml-manta"],
                container: dual.container
            )
            #expect(thinNames["ml-manta"] == "Manta Ray")
            #expect(thinNames["ml-turtle"] == nil)
            #expect(
                MarineLifeCatalogLoader.commonNameByUUID(
                    uuids: ["ml-turtle"],
                    modelContext: context
                )["ml-turtle"] == "Green Turtle"
            )

            let bound = MarineLifeCatalogLoader.bindModels(uuids: ["ml-manta"], modelContext: context)
            #expect(bound.count == 1)
            #expect(bound[0].uuid == "ml-manta")
            #expect(MarineLifeCatalogLoader.bindModel(uuid: "ml-turtle", modelContext: context)?.commonName == "Green Turtle")
            #expect(MarineLifeCatalogLoader.bindModel(uuid: "missing", modelContext: context) == nil)
        }

            @Test func marineLifeMapper_mapsSnakeCaseDTO() {
                let dto = MarineLifeDTO(
                    uuid: "marine-life-test-turtle",
                    commonName: "Green Sea Turtle",
                    featureImage: "https://example.com/turtle.jpg",
                    scientificName: "Chelonia mydas",
                    category: "marine_reptiles",
                    subcategory: "turtles",
                    description: "Herbivorous sea turtle.",
                    minSize: 0.5,
                    maxSize: 1.1,
                    avgDepth: 10
                )
                let species = MarineLifeMapper.map(dto)
                #expect(species.uuid == "marine-life-test-turtle")
                #expect(species.commonName == "Green Sea Turtle")
                #expect(species.featureImageURL == "https://example.com/turtle.jpg")
                #expect(species.category == "marine_reptiles")
                #expect(species.subcategory == "turtles")
                #expect(species.aboutText == "Herbivorous sea turtle.")
                #expect(species.minSizeMeters == 0.5)
                #expect(species.avgDepthMeters == 10)
            }
            @Test func marineLifeMapper_mapsQueenAngelfishExtendedCatalogFields() {
                let dto = MarineLifeDTO(
                    uuid: "marine-life-queen-angelfish",
                    commonName: "Queen Angelfish",
                    featureImage: nil,
                    scientificName: "Holacanthus ciliaris",
                    category: "Fish",
                    subcategory: "Disk and Large Oval",
                    familyName: "Angelfishes",
                    description: "Oval-bodied angelfish.",
                    minSize: 0.2,
                    maxSize: 0.36,
                    minDepth: 6,
                    maxDepth: 25,
                    avgDepth: nil,
                    distinctiveFeatures: "Blue with yellow rims on scales.",
                    abundance: "Common in Florida, Bahamas, Gulf of Mexico, Bermuda.",
                    habitatBehavior: "Swim slowly near corals.",
                    diverReaction: "Wary, tend to keep their distance."
                )
                let species = MarineLifeMapper.map(dto)
                #expect(species.commonName == "Queen Angelfish")
                #expect(species.category == "fish")
                #expect(species.subcategory == "disk-and-large-oval")
                #expect(species.familyName == "Angelfishes")
                #expect(species.minDepthMeters == 6)
                #expect(species.maxDepthMeters == 25)
                #expect(species.avgDepthMeters == 15.5)
                #expect(species.distinctiveFeatures == "Blue with yellow rims on scales.")
                #expect(species.diverReaction == "Wary, tend to keep their distance.")
            }
            @Test func marineLifeMapper_mapsFeatureModelResourceName() {
                let dto = MarineLifeDTO(
                    uuid: "marine-life-french-angelfish",
                    commonName: "French Angelfish",
                    featureModel: "FrenchAngelfish",
                    scientificName: "Pomacanthus paru"
                )
                let species = MarineLifeMapper.map(dto)
                #expect(species.featureModelResourceName == "FrenchAngelfish")
            }
            @Test @MainActor func marineLifeBiologySimilarity_frenchAngelfishGoldenTopMatches() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = container.mainContext
                try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context)
                let catalog = try context.fetch(FetchDescriptor<MarineLife>()).map(\.fieldGuideCatalogSnapshot)
                let seed = catalog.first { $0.uuid == "marine-life-french-angelfish" }
                #expect(seed != nil)
                guard let seed else { return }

                let ranked = MarineLifeBiologySimilarity.rank(
                    seed: seed,
                    catalog: catalog,
                    limit: MarineLifeBiologySimilarity.defaultLimit
                )
                #expect(ranked.count == 6)
                #expect(ranked.map(\.uuid) == [
                    "marine-life-angelfish",
                    "marine-life-queen-angelfish",
                    "marine-life-rock-beauty",
                    "marine-life-cherubfish",
                    "marine-life-flameback-angelfish",
                    "marine-life-gray-angelfish",
                ])
                #expect(ranked[0].score == 16.5)
                #expect(ranked[1].score == 16.5)
                #expect(ranked[2].score == 16.5)
                #expect(ranked[3].score == 14.5)
                #expect(ranked[4].score == 14.5)
                #expect(ranked[5].score == 14.5)
                #expect(ranked.allSatisfy { $0.uuid != seed.uuid })
            }
            @Test func marineLifeBiologySimilarity_mergePrefersSightingBoostForFrenchAngelfishFixture() {
                let biology: [MarineLifeBiologySimilarity.RankedMatch] = [
                    .init(uuid: "marine-life-angelfish", score: 16.5, evidence: []),
                    .init(uuid: "marine-life-queen-angelfish", score: 16.5, evidence: []),
                    .init(uuid: "marine-life-rock-beauty", score: 16.5, evidence: []),
                    .init(uuid: "marine-life-cherubfish", score: 14.5, evidence: []),
                    .init(uuid: "marine-life-flameback-angelfish", score: 14.5, evidence: []),
                    .init(uuid: "marine-life-gray-angelfish", score: 14.5, evidence: []),
                ]
                let sightingScores: [String: Double] = [
                    "marine-life-gray-angelfish": 5.0,
                    "marine-life-community-only": 3.0,
                ]
                let merged = MarineLifeBiologySimilarity.merge(
                    biology: biology,
                    sightingScoresByUUID: sightingScores,
                    limit: 8
                )
                #expect(merged.first?.uuid == "marine-life-gray-angelfish")
                #expect(merged.first?.totalScore == 19.5)
                #expect(merged.first?.biologyScore == 14.5)
                #expect(merged.first?.sightingScore == 5.0)
                #expect(merged.contains { $0.uuid == "marine-life-community-only" && $0.totalScore == 3.0 })
                #expect(merged.count == 7)

                let cache = SpeciesSimilarityCacheDocument(
                    schemaVersion: 1,
                    updatedAt: "2026-08-05T00:00:00Z",
                    bySpecies: [
                        "marine-life-french-angelfish": [
                            .init(uuid: "marine-life-gray-angelfish", sightingScore: 5.0, evidence: nil),
                            .init(uuid: "marine-life-community-only", sightingScore: 3.0, evidence: nil),
                        ],
                    ]
                )
                let fromCache = SpeciesSimilarityCDNCache.sightingScores(
                    forSeedUUID: "marine-life-french-angelfish",
                    document: cache
                )
                #expect(fromCache["marine-life-gray-angelfish"] == 5.0)
                #expect(
                    SpeciesSimilarityCDNCache.sightingScores(
                        forSeedUUID: "missing",
                        document: cache
                    ).isEmpty
                )
            }
            @Test @MainActor func marineLifeSightingRecorder_untagSpeciesOnDive_removesLocalSighting() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = container.mainContext
                let owner = UserProfile(appleUserIdentifier: "owner-untag", displayName: "Pat")
                let dive = DiveActivity(
                    source: .manual,
                    startTime: Date(timeIntervalSince1970: 2_200_000),
                    durationMinutes: 40,
                    maxDepthMeters: 16
                )
                dive.owner = owner
                let species = MarineLife(uuid: "marine-life-test-untag", commonName: "Untag Fish")
                context.insert(owner)
                context.insert(dive)
                context.insert(species)
                try context.save()

                _ = try MarineLifeSightingRecorder.tagSpeciesOnDive(
                    species,
                    dive: dive,
                    owner: owner,
                    modelContext: context
                )
                #expect(
                    try MarineLifeSightingRecorder.sightings(
                        forDiveActivityID: dive.id,
                        modelContext: context
                    ).count == 1
                )

                try MarineLifeSightingRecorder.untagSpeciesOnDive(
                    marineLifeUUID: species.uuid,
                    dive: dive,
                    owner: owner,
                    modelContext: context
                )
                #expect(
                    try MarineLifeSightingRecorder.sightings(
                        forDiveActivityID: dive.id,
                        modelContext: context
                    ).isEmpty
                )
            }
            @Test func marineLifeBiologySimilarity_excludesSeedAndRespectsLimit() {
                let seed = MarineLifeCatalogSnapshot(
                    uuid: "marine-life-seed",
                    commonName: "Seed Fish",
                    scientificName: "",
                    category: "fishes",
                    subcategory: "angelfishes",
                    featureImageURL: "",
                    minSizeMeters: 0,
                    maxSizeMeters: 0.4,
                    avgDepthMeters: 0,
                    familyName: "Pomacanthidae",
                    aboutText: "Yellow and gray fish",
                    minDepthMeters: 3,
                    maxDepthMeters: 100,
                    distinctiveFeatures: "Body shape: short and / or deep"
                )
                let twin = MarineLifeCatalogSnapshot(
                    uuid: "marine-life-twin",
                    commonName: "Twin Fish",
                    scientificName: "",
                    category: "fishes",
                    subcategory: "angelfishes",
                    featureImageURL: "",
                    minSizeMeters: 0,
                    maxSizeMeters: 0.4,
                    avgDepthMeters: 0,
                    familyName: "Pomacanthidae",
                    aboutText: "Yellow reef fish",
                    minDepthMeters: 3,
                    maxDepthMeters: 80,
                    distinctiveFeatures: "Body shape: short and / or deep"
                )
                let other = MarineLifeCatalogSnapshot(
                    uuid: "marine-life-other",
                    commonName: "Other Fish",
                    scientificName: "",
                    category: "fishes",
                    subcategory: "angelfishes",
                    featureImageURL: "",
                    minSizeMeters: 0,
                    maxSizeMeters: 0.4,
                    avgDepthMeters: 0,
                    familyName: "Pomacanthidae",
                    aboutText: "Yellow reef fish",
                    minDepthMeters: 3,
                    maxDepthMeters: 80,
                    distinctiveFeatures: "Body shape: short and / or deep"
                )
                let ranked = MarineLifeBiologySimilarity.rank(
                    seed: seed,
                    catalog: [seed, twin, other],
                    limit: 1
                )
                #expect(ranked.count == 1)
                #expect(ranked[0].uuid == "marine-life-other" || ranked[0].uuid == "marine-life-twin")
                #expect(!ranked.contains(where: { $0.uuid == seed.uuid }))
            }
            @Test func marineLifeCommonNameFormatting_titleCasesEachWord() {
                #expect(MarineLifeCommonNameFormatting.normalized("French angelfish") == "French Angelfish")
                #expect(MarineLifeCommonNameFormatting.normalized("  GREEN SEA TURTLE  ") == "Green Sea Turtle")
                #expect(MarineLifeCommonNameFormatting.normalized("spotted eagle ray") == "Spotted Eagle Ray")
            }
            @Test func marineLifeCommonNameFormatting_handlesHyphensAndApostrophes() {
                #expect(MarineLifeCommonNameFormatting.normalized("king angelfish") == "King Angelfish")
                #expect(MarineLifeCommonNameFormatting.normalized("two-spot demoiselle") == "Two-Spot Demoiselle")
            }
            @Test func marineLifeCommonNameFormatting_stripsJuvenileSuffix() {
                #expect(MarineLifeCommonNameFormatting.normalized("Rock Beauty (juvenile)") == "Rock Beauty")
                #expect(MarineLifeCommonNameFormatting.normalized("Blue angelfish (Juvenile)") == "Blue Angelfish")
                #expect(MarineLifeCommonNameFormatting.normalized("Gray Angelfish ( juvenile )") == "Gray Angelfish")
                #expect(
                    MarineLifeCommonNameFormatting.stripJuvenileSuffix("rock beauty (juvenile)")
                        == "rock beauty"
                )
            }
            @Test @MainActor func marineLifeCommonNameNormalization_updatesStoredRows() throws {
                let suiteName = "test.commonNameNorm.\(UUID().uuidString)"
                let defaults = UserDefaults(suiteName: suiteName)!
                defer {
                    defaults.removePersistentDomain(forName: suiteName)
                }
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = container.mainContext
                let species = MarineLife(uuid: "marine-life-legacy-case", commonName: "legacy species")
                context.insert(species)
                try context.save()

                species.commonName = "french angelfish"
                try context.save()

                try MarineLifeCommonNameNormalization.normalizeStoredCatalogIfNeeded(
                    modelContext: context,
                    userDefaults: defaults
                )
                #expect(species.commonName == "French Angelfish")

                species.commonName = "queen angelfish"
                try context.save()
                try MarineLifeCommonNameNormalization.normalizeStoredCatalogIfNeeded(
                    modelContext: context,
                    userDefaults: defaults
                )
                #expect(species.commonName == "queen angelfish")
            }
            @Test @MainActor func marineLifeSightingRecorder_tagSpeciesOnDive_dedupesWithMediaTag() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = container.mainContext
                let owner = UserProfile(appleUserIdentifier: "owner-ml-dive", displayName: "Pat")
                let dive = DiveActivity(
                    source: .manual,
                    startTime: Date(timeIntervalSince1970: 2_100_000),
                    durationMinutes: 40,
                    maxDepthMeters: 16
                )
                dive.owner = owner
                let species = MarineLife(uuid: "marine-life-test-hamlet", commonName: "Barred Hamlet")
                let media = DiveMediaPhoto(sortOrder: 0, mediaKind: .image, photosLocalIdentifier: "ph-test-1")
                dive.mediaPhotos = [media]
                context.insert(owner)
                context.insert(dive)
                context.insert(species)
                context.insert(media)
                try context.save()

                let mediaSighting = try MarineLifeSightingRecorder.tagSpecies(
                    species,
                    on: media,
                    dive: dive,
                    captureContext: nil,
                    owner: owner,
                    modelContext: context
                )
                let diveSighting = try MarineLifeSightingRecorder.tagSpeciesOnDive(
                    species,
                    dive: dive,
                    owner: owner,
                    modelContext: context
                )
                #expect(diveSighting.sightingUUID == mediaSighting.sightingUUID)

                let all = try MarineLifeSightingRecorder.sightings(
                    forDiveActivityID: dive.id,
                    modelContext: context
                )
                #expect(all.count == 1)
                let chips = DiveActivityMarineLifeOverviewPresentation.uniqueSpeciesChips(
                    sightings: all,
                    catalog: [species]
                )
                #expect(chips.map(\.marineLifeUUID) == [species.uuid])
            }
            @Test @MainActor func marineLifeSightingRecorder_tagSpeciesOnSnorkel_dedupesWithMediaTag() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = container.mainContext
                let owner = UserProfile(appleUserIdentifier: "owner-ml-snorkel", displayName: "Pat")
                let snorkel = SnorkelActivity(
                    source: .manual,
                    startTime: Date(timeIntervalSince1970: 2_200_000),
                    durationMinutes: 45
                )
                snorkel.owner = owner
                let species = MarineLife(uuid: "marine-life-test-parrotfish", commonName: "Stoplight Parrotfish")
                let media = SnorkelMediaPhoto(sortOrder: 0, mediaKind: .image, photosLocalIdentifier: "ph-snorkel-1")
                snorkel.mediaPhotos = [media]
                context.insert(owner)
                context.insert(snorkel)
                context.insert(species)
                context.insert(media)
                try context.save()

                let mediaSighting = try MarineLifeSightingRecorder.tagSpecies(
                    species,
                    on: media,
                    snorkel: snorkel,
                    owner: owner,
                    modelContext: context
                )
                let snorkelSighting = try MarineLifeSightingRecorder.tagSpeciesOnSnorkel(
                    species,
                    snorkel: snorkel,
                    owner: owner,
                    modelContext: context
                )
                #expect(snorkelSighting.sightingUUID == mediaSighting.sightingUUID)

                let all = try MarineLifeSightingRecorder.sightings(
                    forSnorkelActivityID: snorkel.id,
                    modelContext: context
                )
                #expect(all.count == 1)
            }
            @Test @MainActor func marineLifeSightingRecorder_tagsMediaAndUpdatesUserRecord() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = container.mainContext

                let owner = UserProfile(appleUserIdentifier: "test-tag", displayName: "Diver")
                let dive = DiveActivity(
                    source: .manual,
                    startTime: Date(timeIntervalSince1970: 3_000_000),
                    durationMinutes: 40,
                    maxDepthMeters: 20
                )
                dive.owner = owner
                dive.ownerProfileID = owner.id
                let media = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 3_000_100))
                media.link(to: dive)
                let species = MarineLife(uuid: "marine-life-tag-test", commonName: "French Angelfish")

                context.insert(owner)
                context.insert(dive)
                context.insert(media)
                context.insert(species)

                let contextCapture = DiveMediaCaptureContext(elapsedSeconds: 600, depthMeters: 15)
                _ = try MarineLifeSightingRecorder.tagSpecies(
                    species,
                    on: media,
                    dive: dive,
                    captureContext: contextCapture,
                    owner: owner,
                    modelContext: context
                )

                let sightings = try context.fetch(FetchDescriptor<SightingInstance>())
                #expect(sightings.count == 1)
                #expect(sightings[0].marineLifeUUID == species.uuid)
                #expect(sightings[0].mediaPhotoID == media.id)
                #expect(sightings[0].sightingDateTime == media.capturedAt)
                #expect(sightings[0].sightingDepthMeters == 15)

                let records = try MarineLifeUserRecordOwnership.userRecords(
                    forOwnerProfileID: owner.id,
                    modelContext: context
                )
                #expect(records.count == 1)
                #expect(records[0].isSighted)
                #expect(records[0].activitiesSightedOn.contains(dive.id))
                #expect(records[0].userTaggedMedia.contains("media:\(media.id.uuidString)"))
            }
            @Test @MainActor func marineLifeSightingRecorder_sightingsForMedia_filtersByPhotoID() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = container.mainContext

                let owner = UserProfile(appleUserIdentifier: "test-sightings-filter", displayName: "Diver")
                let dive = DiveActivity(
                    source: .manual,
                    startTime: Date(timeIntervalSince1970: 3_100_000),
                    durationMinutes: 40,
                    maxDepthMeters: 20
                )
                dive.owner = owner
                dive.ownerProfileID = owner.id
                let taggedMedia = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 3_100_100))
                let otherMedia = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 3_100_200))
                taggedMedia.link(to: dive)
                otherMedia.link(to: dive)
                let angelfish = MarineLife(uuid: "marine-life-filter-angelfish", commonName: "French Angelfish")
                let ray = MarineLife(uuid: "marine-life-filter-ray", commonName: "Spotted Eagle Ray")
                let turtle = MarineLife(uuid: "marine-life-filter-turtle", commonName: "Green Turtle")

                context.insert(owner)
                context.insert(dive)
                context.insert(taggedMedia)
                context.insert(otherMedia)
                context.insert(angelfish)
                context.insert(ray)
                context.insert(turtle)

                _ = try MarineLifeSightingRecorder.tagSpecies(
                    angelfish,
                    on: taggedMedia,
                    dive: dive,
                    captureContext: nil,
                    owner: owner,
                    modelContext: context
                )
                _ = try MarineLifeSightingRecorder.tagSpecies(
                    ray,
                    on: taggedMedia,
                    dive: dive,
                    captureContext: nil,
                    owner: owner,
                    modelContext: context
                )
                _ = try MarineLifeSightingRecorder.tagSpecies(
                    turtle,
                    on: otherMedia,
                    dive: dive,
                    captureContext: nil,
                    owner: owner,
                    modelContext: context
                )

                let taggedSightings = try MarineLifeSightingRecorder.sightings(
                    forMediaPhotoID: taggedMedia.id,
                    modelContext: context
                )
                #expect(taggedSightings.count == 2)
                #expect(Set(taggedSightings.map(\.marineLifeUUID)) == Set([angelfish.uuid, ray.uuid]))
            }
            @Test @MainActor func marineLifeSightingRecorder_tagPendingSpecies_persistsBatchWithSingleSave() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = container.mainContext

                let owner = UserProfile(appleUserIdentifier: "test-batch-tag", displayName: "Diver")
                let dive = DiveActivity(
                    source: .manual,
                    startTime: Date(timeIntervalSince1970: 3_200_000),
                    durationMinutes: 40,
                    maxDepthMeters: 20
                )
                dive.owner = owner
                dive.ownerProfileID = owner.id
                let media = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 3_200_100))
                media.link(to: dive)
                let angelfish = MarineLife(uuid: "marine-life-batch-angelfish", commonName: "French Angelfish")
                let ray = MarineLife(uuid: "marine-life-batch-ray", commonName: "Spotted Eagle Ray")

                context.insert(owner)
                context.insert(dive)
                context.insert(media)
                context.insert(angelfish)
                context.insert(ray)

                try MarineLifeSightingRecorder.tagPendingSpecies(
                    [angelfish, ray],
                    on: media,
                    dive: dive,
                    captureContext: DiveMediaCaptureContext(elapsedSeconds: 600, depthMeters: 12),
                    owner: owner,
                    modelContext: context
                )

                let sightings = try MarineLifeSightingRecorder.sightings(
                    forMediaPhotoID: media.id,
                    modelContext: context
                )
                #expect(sightings.count == 2)
                #expect(Set(sightings.map(\.marineLifeUUID)) == Set([angelfish.uuid, ray.uuid]))

                let records = try MarineLifeUserRecordOwnership.userRecords(
                    forOwnerProfileID: owner.id,
                    modelContext: context
                )
                #expect(records.count == 2)
                #expect(records.allSatisfy { $0.isSighted })
                #expect(records.allSatisfy { $0.activitiesSightedOn.contains(dive.id) })
                #expect(records.allSatisfy { $0.userTaggedMedia.contains("media:\(media.id.uuidString)") })
            }
            @Test @MainActor func marineLifeSightingRecorder_batchFetch_scopesByDiveAndMediaIDs() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = container.mainContext

                let owner = UserProfile(appleUserIdentifier: "batch-sightings", displayName: "Diver")
                let linkedDive = DiveActivity(
                    source: .manual,
                    startTime: Date(timeIntervalSince1970: 4_000_000),
                    durationMinutes: 45,
                    maxDepthMeters: 20
                )
                linkedDive.owner = owner
                linkedDive.ownerProfileID = owner.id

                let otherDive = DiveActivity(
                    source: .manual,
                    startTime: Date(timeIntervalSince1970: 4_100_000),
                    durationMinutes: 30,
                    maxDepthMeters: 12
                )
                otherDive.owner = owner
                otherDive.ownerProfileID = owner.id

                let taggedMedia = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 4_000_100))
                taggedMedia.link(to: linkedDive)
                let otherMedia = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 4_100_100))
                otherMedia.link(to: otherDive)

                let species = MarineLife(uuid: "batch-species", commonName: "Parrotfish", scientificName: "Sparisoma")
                context.insert(species)
                context.insert(linkedDive)
                context.insert(otherDive)

                _ = try MarineLifeSightingRecorder.tagSpecies(
                    species,
                    on: taggedMedia,
                    dive: linkedDive,
                    captureContext: nil,
                    owner: owner,
                    modelContext: context
                )
                _ = try MarineLifeSightingRecorder.tagSpecies(
                    species,
                    on: otherMedia,
                    dive: otherDive,
                    captureContext: nil,
                    owner: owner,
                    modelContext: context
                )

                let diveScoped = try MarineLifeSightingRecorder.sightings(
                    forDiveActivityIDs: [linkedDive.id],
                    modelContext: context
                )
                #expect(diveScoped.count == 1)
                #expect(diveScoped[0].diveActivityID == linkedDive.id)

                let mediaScoped = try MarineLifeSightingRecorder.sightings(
                    forMediaPhotoIDs: [taggedMedia.id],
                    modelContext: context
                )
                #expect(mediaScoped.count == 1)
                #expect(mediaScoped[0].mediaPhotoID == taggedMedia.id)
            }
}
