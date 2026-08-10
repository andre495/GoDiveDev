//
//  DiveActivityOverviewTests.swift
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


struct DiveActivityOverviewTests {
        @Test func diveDepthProfileSeries_emptySortedInput() {
            #expect(DiveDepthProfileSeries.samples(sortedAscending: []).isEmpty)
        }

        @Test func diveDepthProfileSeries_elapsedFromFirstSample() throws {
            let cal = Calendar(identifier: .gregorian)
            var c = DateComponents()
            c.year = 2025
            c.month = 6
            c.day = 10
            c.hour = 9
            c.minute = 0
            c.second = 0
            let t0 = try #require(cal.date(from: c))
            let t1 = try #require(cal.date(byAdding: .minute, value: 10, to: t0))
            let rows: [(timestamp: Date, depthMeters: Double)] = [
                (t0, 0.5),
                (t1, 12.0),
            ]
            let s = DiveDepthProfileSeries.samples(sortedAscending: rows)
            #expect(s.count == 2)
            #expect(s[0].elapsedSeconds == 0)
            #expect(abs(s[1].elapsedSeconds - 600) < 0.001)
            #expect(s[1].depthMeters == 12)
        }

        @Test @MainActor
        func diveDepthProfileSeries_sortsUnsortedProfilePoints() throws {
            let schema = Schema([
                DiveActivity.self,
                DiveBuddy.self,
                DiveBuddyTag.self,
                DiveProfilePoint.self,
                DiveSite.self,
            ])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            let dive = DiveActivity(
                source: .manual,
                startTime: Date(timeIntervalSince1970: 100_000),
                durationMinutes: 30,
                maxDepthMeters: 20
            )
            context.insert(dive)
            let late = DiveProfilePoint(timestamp: Date(timeIntervalSince1970: 100_600), depthMeters: 10)
            let early = DiveProfilePoint(timestamp: Date(timeIntervalSince1970: 100_100), depthMeters: 5)
            dive.profilePoints.append(late)
            dive.profilePoints.append(early)
            try context.save()
            let s = DiveDepthProfileSeries.samples(fromProfilePoints: dive.profilePoints)
            #expect(s.map(\.depthMeters) == [5, 10])
            #expect(s[0].elapsedSeconds == 0)
            #expect(abs(s[1].elapsedSeconds - 500) < 0.001)
        }

        @Test func diveDepthProfileSeries_elapsedAtChartX() {
            let t = DiveDepthProfileSeries.elapsedSeconds(atChartX: 50, rectMinX: 0, rectWidth: 100, maxElapsed: 200)
            #expect(abs(t - 100) < 0.001)
        }

        @Test func diveDepthProfileSeries_indexNearestElapsed() {
            let s = [
                DiveDepthProfileSample(elapsedSeconds: 0, depthMeters: 1),
                DiveDepthProfileSample(elapsedSeconds: 60, depthMeters: 5),
                DiveDepthProfileSample(elapsedSeconds: 120, depthMeters: 3),
            ]
            #expect(DiveDepthProfileSeries.indexNearestElapsed(45, in: s) == 1)
            #expect(DiveDepthProfileSeries.indexNearestElapsed(0, in: s) == 0)
            #expect(DiveDepthProfileSeries.indexNearestElapsed(200, in: s) == 2)
            #expect(DiveDepthProfileSeries.indexNearestElapsed(30, in: s) == 0)
            #expect(DiveDepthProfileSeries.indexNearestElapsed(90, in: s) == 1)
        }

        @Test func diveActivityOverviewPanelMetrics_shouldPublishLiveHeightFraction_throttlesSmallDeltas() {
            #expect(
                !DiveActivityOverviewPanelMetrics.shouldPublishLiveHeightFraction(
                    previous: 0.50,
                    next: 0.503
                )
            )
            #expect(
                DiveActivityOverviewPanelMetrics.shouldPublishLiveHeightFraction(
                    previous: 0.50,
                    next: 0.50 + DiveActivityOverviewPanelMetrics.liveHeightFractionPublishEpsilon
                )
            )
            #expect(
                DiveActivityOverviewPanelMetrics.shouldPublishLiveHeightFraction(
                    previous: 0.50,
                    next: 0.501,
                    force: true
                )
            )
        }

        @Test func diveDepthProfileSeries_pressureSamples_omitsNilTankPressure() throws {
            let t0 = Date(timeIntervalSince1970: 1_000_000)
            let dive = DiveActivity(
                source: .manual,
                startTime: t0,
                durationMinutes: 30,
                maxDepthMeters: 20
            )
            let p0 = DiveProfilePoint(timestamp: t0, depthMeters: 0, tankPressurePSI: 3000)
            let p1 = DiveProfilePoint(timestamp: t0.addingTimeInterval(60), depthMeters: 10)
            let p2 = DiveProfilePoint(timestamp: t0.addingTimeInterval(120), depthMeters: 15, tankPressurePSI: 1500)
            dive.profilePoints = [p0, p1, p2]

            let samples = DiveDepthProfileSeries.pressureSamples(fromProfilePoints: dive.profilePoints)
            #expect(samples.count == 2)
            #expect(samples[0].pressurePSI == 3000)
            #expect(abs(samples[1].elapsedSeconds - 120) < 0.001)
            #expect(samples[1].pressurePSI == 1500)
        }

        @Test func diveDepthProfileSeries_sortedOverloads_matchDefaultBuilders() {
            let t0 = Date(timeIntervalSince1970: 4_000_000)
            let points = [
                DiveProfilePoint(timestamp: t0.addingTimeInterval(600), depthMeters: 20, tankPressurePSI: 2400),
                DiveProfilePoint(timestamp: t0, depthMeters: 3, tankPressurePSI: 3000),
                DiveProfilePoint(timestamp: t0.addingTimeInterval(300), depthMeters: 12, tankPressurePSI: nil),
            ]
            let sorted = points.sorted { $0.timestamp < $1.timestamp }

            #expect(
                DiveDepthProfileSeries.samples(fromProfilePoints: points)
                    == DiveDepthProfileSeries.samples(fromSortedProfilePoints: sorted)
            )
            #expect(
                DiveDepthProfileSeries.pressureSamples(fromProfilePoints: points)
                    == DiveDepthProfileSeries.pressureSamples(fromSortedProfilePoints: sorted)
            )
        }

        @Test func diveTankOverviewHeroPresentation_showsMinimizedProfileChart_onlyAtMinimizedWithSamples() {
            #expect(
                DiveTankOverviewHeroPresentation.showsMinimizedProfileChart(for: .minimized, depthSampleCount: 2)
            )
            #expect(
                !DiveTankOverviewHeroPresentation.showsMinimizedProfileChart(for: .minimized, depthSampleCount: 1)
            )
            #expect(
                !DiveTankOverviewHeroPresentation.showsMinimizedProfileChart(for: .large, depthSampleCount: 10)
            )
        }

        @Test func diveTankOverviewHeroPresentation_largeProfileChartFrame_isEdgeToEdgeAboveSheetSeam() {
            let layoutSize = CGSize(width: 390, height: 640)
            let layoutHeight: CGFloat = 844
            let topObstruction: CGFloat = 100
            let largeMargin = layoutHeight * DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction
            let frame = DiveTankOverviewHeroPresentation.minimizedProfileChartFrame(
                layoutSize: layoutSize,
                layoutHeight: layoutHeight,
                topObstructionHeight: topObstruction,
                bottomContentMargin: largeMargin,
                isLandscape: false,
                detent: .large,
                chartSizingBottomContentMargin: largeMargin
            )
            #expect(abs(frame.minX) < 0.5)
            #expect(abs(frame.width - layoutSize.width) < 0.5)
            #expect(abs(frame.minY - DiveTankOverviewHeroPresentation.largeDetentSheetSeamCornerBleed) < 0.5)
            #expect(
                abs(
                    frame.maxY
                        - (
                            layoutHeight - largeMargin
                                + DiveTankOverviewHeroPresentation.largeDetentSheetSeamCornerBleed
                        )
                ) < 0.5
            )
        }

        @Test func diveTankOverviewHeroPresentation_minimizedProfileChartFrame_matchesLargeSizeAndSeamAligned() {
            let layoutSize = CGSize(width: 390, height: 640)
            let layoutHeight: CGFloat = 844
            let topObstruction: CGFloat = 100
            let minimizedMargin = layoutHeight * DiveActivityOverviewPanelMetrics.minimizedHeightFraction
            let largeMargin = layoutHeight * DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction
            let minimizedFrame = DiveTankOverviewHeroPresentation.minimizedProfileChartFrame(
                layoutSize: layoutSize,
                layoutHeight: layoutHeight,
                topObstructionHeight: topObstruction,
                bottomContentMargin: minimizedMargin,
                isLandscape: false,
                detent: .minimized,
                chartSizingBottomContentMargin: largeMargin
            )
            let largeFrame = DiveTankOverviewHeroPresentation.minimizedProfileChartFrame(
                layoutSize: layoutSize,
                layoutHeight: layoutHeight,
                topObstructionHeight: topObstruction,
                bottomContentMargin: largeMargin,
                isLandscape: false,
                detent: .large,
                chartSizingBottomContentMargin: largeMargin
            )
            #expect(abs(minimizedFrame.width - largeFrame.width) < 0.5)
            let expectedScaled = largeFrame.height * DiveTankOverviewHeroPresentation.minimizedPortraitChartHeightScale
            let seamMaxHeight = layoutHeight - minimizedMargin
                + DiveTankOverviewHeroPresentation.largeDetentSheetSeamCornerBleed
            #expect(abs(minimizedFrame.height - min(expectedScaled, seamMaxHeight)) < 1)
            #expect(minimizedFrame.height > largeFrame.height + 1)
            #expect(abs(minimizedFrame.midX - layoutSize.width / 2) < 1)
            #expect(abs(minimizedFrame.maxY - (
                layoutHeight - minimizedMargin + DiveTankOverviewHeroPresentation.largeDetentSheetSeamCornerBleed
            )) < 0.5)
            #expect(minimizedFrame.minY >= DiveTankOverviewHeroPresentation.profileChartBandTop - 0.5)
        }

        @Test func diveTankOverviewHeroPresentation_portraitChartHeightScale_growsWithCollapse() {
            #expect(DiveTankOverviewHeroPresentation.minimizedPortraitChartHeightScale == 1.6)
            #expect(
                DiveTankOverviewHeroPresentation.portraitChartHeightScale(
                    detent: .large,
                    collapseProgress: nil
                ) == 1
            )
            #expect(
                DiveTankOverviewHeroPresentation.portraitChartHeightScale(
                    detent: .minimized,
                    collapseProgress: nil
                ) == 1.6
            )
            #expect(
                abs(
                    DiveTankOverviewHeroPresentation.portraitChartHeightScale(
                        detent: .large,
                        collapseProgress: 0.5
                    ) - 1.3
                ) < 0.001
            )
            #expect(
                DiveTankOverviewHeroPresentation.portraitChartTopFadeFraction == 0.14
            )
            #expect(
                DiveTankOverviewHeroPresentation.minimizedPortraitChartTopFadeFraction
                    == DiveTankOverviewHeroPresentation.portraitChartTopFadeFraction
            )
        }

        @Test func diveTankOverviewHeroPresentation_minimizedProfileChartFrame_keepsSizeWhileSeamMoves() {
            let layoutSize = CGSize(width: 390, height: 640)
            let layoutHeight: CGFloat = 844
            let topObstruction: CGFloat = 100
            let minimizedMargin = layoutHeight * DiveActivityOverviewPanelMetrics.minimizedHeightFraction
            let largeMargin = layoutHeight * DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction
            let resting = DiveTankOverviewHeroPresentation.minimizedProfileChartFrame(
                layoutSize: layoutSize,
                layoutHeight: layoutHeight,
                topObstructionHeight: topObstruction,
                bottomContentMargin: minimizedMargin,
                isLandscape: false,
                detent: .minimized,
                chartSizingBottomContentMargin: largeMargin
            )
            let dragged = DiveTankOverviewHeroPresentation.minimizedProfileChartFrame(
                layoutSize: layoutSize,
                layoutHeight: layoutHeight,
                topObstructionHeight: topObstruction,
                bottomContentMargin: largeMargin,
                isLandscape: false,
                detent: .minimized,
                chartSizingBottomContentMargin: largeMargin
            )
            #expect(abs(resting.width - dragged.width) < 0.5)
            #expect(dragged.height < resting.height)
            #expect(dragged.maxY < resting.maxY)
        }

        @Test func diveDepthProfileOverlayChartLayout_edgeToEdgePlotRect_usesFullBounds() {
            let size = CGSize(width: 390, height: 220)
            let rect = DiveDepthProfileOverlayChartLayout.plotRect(
                in: size,
                chromeStyle: .edgeToEdge
            )
            #expect(abs(rect.minX) < 0.1)
            #expect(abs(rect.minY) < 0.1)
            #expect(abs(rect.width - size.width) < 0.1)
            #expect(abs(rect.height - size.height) < 0.1)
        }

        @Test func diveTankOverviewHeroPresentation_landscapeMinimizedProfileChart_isEdgeToEdge() {
            let layoutSize = CGSize(width: 844, height: 390)
            let layoutHeight: CGFloat = 390
            let topObstruction: CGFloat = 60
            let bottomMargin: CGFloat = 34
            #expect(DiveTankOverviewHeroPresentation.isLandscapeLayout(layoutSize: layoutSize))
            let frame = DiveTankOverviewHeroPresentation.minimizedProfileChartFrame(
                layoutSize: layoutSize,
                layoutHeight: layoutHeight,
                topObstructionHeight: topObstruction,
                bottomContentMargin: bottomMargin,
                isLandscape: true
            )
            #expect(abs(frame.minX) < 0.5)
            #expect(abs(frame.width - layoutSize.width) < 0.5)
            #expect(abs(frame.minY - DiveTankOverviewHeroPresentation.profileChartBandTop) < 0.5)
            #expect(abs(frame.maxY - (layoutHeight - bottomMargin)) < 0.5)
        }

        @Test func diveDepthProfileChartViewport_zoomAndPan_clampsToFullDive() {
            var viewport = DiveDepthProfileChartViewport.full(elapsedMax: 600)
            #expect(!viewport.isZoomed(fullElapsedMax: 600))

            viewport.zoom(scale: 2, anchorFraction: 0.5, fullElapsedMax: 600)
            #expect(viewport.isZoomed(fullElapsedMax: 600))
            #expect(viewport.elapsedSpan < 600)
            #expect(viewport.elapsedStart >= 0)
            #expect(viewport.elapsedEnd <= 600)

            viewport.pan(elapsedDelta: 400, fullElapsedMax: 600)
            #expect(viewport.elapsedEnd <= 600 + 0.001)
            #expect(viewport.elapsedStart >= 0)

            viewport.reset(fullElapsedMax: 600)
            #expect(!viewport.isZoomed(fullElapsedMax: 600))
            #expect(abs(viewport.elapsedEnd - 600) < 0.001)
        }

        @Test func diveDepthProfileOverlayChartLayout_depthPoint_respectsViewportWindow() {
            let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
            let viewport = DiveDepthProfileChartViewport(elapsedStart: 100, elapsedEnd: 300)
            let sample = DiveDepthProfileSample(elapsedSeconds: 200, depthMeters: 10)
            let point = DiveDepthProfileOverlayChartLayout.depthPoint(
                sample: sample,
                in: rect,
                viewport: viewport,
                maxDepth: 20
            )
            #expect(abs(point.x - 100) < 0.5)
            let expectedY = DiveDepthProfileChartPresentation.depthPlotY(
                depthMeters: 10,
                axisMaxDepthMeters: 20,
                in: rect
            )
            #expect(abs(point.y - expectedY) < 0.5)
        }

        @Test func diveDepthProfileChartPresentation_depthPlotY_reservesFifteenPercentTopBuffer() {
            let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
            let axisMax: Double = 36
            let surfaceY = DiveDepthProfileChartPresentation.depthPlotY(
                depthMeters: 0,
                axisMaxDepthMeters: axisMax,
                in: rect
            )
            #expect(
                abs(surfaceY - (rect.minY + CGFloat(DiveDepthProfileChartPresentation.depthAxisTopBufferFraction) * rect.height))
                    < 0.5
            )
            #expect(surfaceY > rect.minY)
        }

        @Test func diveDepthProfileChartPresentation_largeDetentTopBuffer_isThirtyPercentTotal() {
            let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
            let axisMax: Double = 36
            let buffer = DiveDepthProfileChartPresentation.depthAxisTopBufferFraction(for: .edgeToEdge)
            #expect(abs(buffer - 0.30) < 0.001)
            let surfaceY = DiveDepthProfileChartPresentation.depthPlotY(
                depthMeters: 0,
                axisMaxDepthMeters: axisMax,
                in: rect,
                topBufferFraction: buffer
            )
            #expect(abs(surfaceY - (rect.minY + CGFloat(buffer) * rect.height)) < 0.5)
        }

        @Test func diveDepthProfileChartAxisPresentation_formatsDiveTimeMinutes() {
            #expect(DiveDepthProfileChartAxisPresentation.formattedDiveTimeMinutes(elapsedSeconds: 0) == "0 min")
            #expect(DiveDepthProfileChartAxisPresentation.formattedDiveTimeMinutes(elapsedSeconds: 60) == "1 min")
            #expect(DiveDepthProfileChartAxisPresentation.formattedDiveTimeMinutes(elapsedSeconds: 90) == "1.5 min")
            #expect(DiveDepthProfileChartAxisPresentation.scrubTimeLabel(elapsedSeconds: 150) == "Time 2.5 min")
            #expect(
                DiveDepthProfileChartAxisPresentation.scrubDepthLabel(depthMeters: 10, system: .metric)
                    == "Depth 10.0 m"
            )
            #expect(
                DiveDepthProfileChartAxisPresentation.scrubDepthLabel(depthMeters: 10, system: .imperial)
                    == "Depth 32.8 ft"
            )
        }

        @Test func diveDepthProfileChartAxisPresentation_timeTicks_coverVisibleWindowInMinutes() {
            let viewport = DiveDepthProfileChartViewport(elapsedStart: 0, elapsedEnd: 1_800)
            let ticks = DiveDepthProfileChartAxisPresentation.timeTicks(viewport: viewport)
            #expect(ticks.count == 2)
            #expect(!ticks.contains { $0.label == "0 min" })
            #expect(abs((ticks[0].canonicalValue) - 900) < 0.001)
            #expect(ticks[0].label == "15 min")
            #expect(abs(ticks[0].fraction - 0.5) < 0.001)
            #expect(abs((ticks[1].canonicalValue) - 1_800) < 0.001)
            #expect(ticks[1].label == "30 min")
            #expect(abs(ticks[1].fraction - 1.0) < 0.001)
        }

        @Test func diveDepthProfileChartPresentation_depthAxisExtendsTwentyPercentBeyondMax() {
            let axisMax = DiveDepthProfileChartPresentation.depthAxisMaximumMeters(
                dataMaxMeters: 30.48,
                hintMeters: 0
            )
            #expect(abs(axisMax - (30.48 * 1.2)) < 0.01)
            #expect(DiveDepthProfileChartPresentation.depthAxisExtensionFraction == 0.2)
            #expect(DiveDepthProfileChartPresentation.depthAxisTopBufferFraction == 0.15)
        }

        @Test func diveDepthProfileChartPresentation_lightlySmoothedPressureSamples_preservesEndpoints() {
            let samples = [
                DiveDepthProfilePressureSample(elapsedSeconds: 0, pressurePSI: 3_000),
                DiveDepthProfilePressureSample(elapsedSeconds: 60, pressurePSI: 2_500),
                DiveDepthProfilePressureSample(elapsedSeconds: 120, pressurePSI: 1_800),
                DiveDepthProfilePressureSample(elapsedSeconds: 180, pressurePSI: 1_200),
            ]
            let smoothed = DiveDepthProfileChartPresentation.lightlySmoothedPressureSamples(samples)
            #expect(smoothed.count == samples.count)
            #expect(smoothed.first?.pressurePSI == samples.first?.pressurePSI)
            #expect(smoothed.last?.pressurePSI == samples.last?.pressurePSI)
            #expect(smoothed[1].pressurePSI != samples[1].pressurePSI)
        }

        @Test func diveDepthProfileChartPresentation_downsampledPressureSamplesForLine_bucketsEveryFiveSeconds() {
            var samples: [DiveDepthProfilePressureSample] = []
            for second in stride(from: 0, through: 60, by: 1) {
                let wobble = Double(second % 3) * 12
                samples.append(
                    DiveDepthProfilePressureSample(
                        elapsedSeconds: Double(second),
                        pressurePSI: 3_000 - Double(second) * 20 + wobble
                    )
                )
            }
            let downsampled = DiveDepthProfileChartPresentation.downsampledPressureSamplesForLine(samples)
            #expect(downsampled.count < samples.count)
            #expect(downsampled.first?.elapsedSeconds == 0)
            #expect(downsampled.first?.pressurePSI == samples.first?.pressurePSI)
            #expect(downsampled.last?.elapsedSeconds == 60)
            #expect(downsampled.last?.pressurePSI == samples.last?.pressurePSI)
            let interior = downsampled.dropFirst().dropLast()
            for point in interior {
                let remainder = point.elapsedSeconds.truncatingRemainder(dividingBy: 5)
                #expect(abs(remainder - 2.5) < 0.01)
            }
        }

        @Test func diveDepthProfileChartPresentation_downsampledPressureSamplesForLine_shortDive_keepsAllPoints() {
            let samples = [
                DiveDepthProfilePressureSample(elapsedSeconds: 0, pressurePSI: 3_000),
                DiveDepthProfilePressureSample(elapsedSeconds: 2, pressurePSI: 2_900),
                DiveDepthProfilePressureSample(elapsedSeconds: 4, pressurePSI: 2_800),
            ]
            let downsampled = DiveDepthProfileChartPresentation.downsampledPressureSamplesForLine(samples)
            #expect(downsampled.count == samples.count)
        }

        @Test func diveDepthProfileChartPresentation_depthProfileAreaPath_closesAboveCurve() {
            let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
            let viewport = DiveDepthProfileChartViewport(elapsedStart: 0, elapsedEnd: 120)
            let samples = [
                DiveDepthProfileSample(elapsedSeconds: 0, depthMeters: 0),
                DiveDepthProfileSample(elapsedSeconds: 60, depthMeters: 12),
                DiveDepthProfileSample(elapsedSeconds: 120, depthMeters: 6),
            ]
            let axisMax = DiveDepthProfileChartPresentation.depthAxisMaximumMeters(dataMaxMeters: 12)
            let above = DiveDepthProfileChartPresentation.depthProfileAreaPath(
                samples: samples,
                in: rect,
                viewport: viewport,
                axisMaxDepthMeters: axisMax
            )
            let below = DiveDepthProfileChartPresentation.depthProfileUnderCurveAreaPath(
                samples: samples,
                in: rect,
                viewport: viewport,
                axisMaxDepthMeters: axisMax
            )
            #expect(!above.isEmpty)
            #expect(!below.isEmpty)
            #expect(above.contains(CGPoint(x: 100, y: 8)))
            #expect(!below.contains(CGPoint(x: 100, y: 8)))
            #expect(below.contains(CGPoint(x: 100, y: 92)))
            #expect(!above.contains(CGPoint(x: 100, y: 92)))
        }

        @Test func diveDepthProfileChartPresentation_forcesDarkAppearancePalette() {
            #expect(DiveDepthProfileChartPresentation.forcesDarkAppearance)
            #expect(DiveDepthProfileChartPresentation.underfillTopOpacity == 0.55)
            #expect(DiveDepthProfileChartPresentation.underfillBottomOpacity == 0.94)

            let light = UITraitCollection(userInterfaceStyle: .light)
            let dark = UITraitCollection(userInterfaceStyle: .dark)
            let underfillTopLight = UIColor(AppTheme.Colors.depthProfileUnderfillTop).resolvedColor(with: light)
            let underfillTopDark = UIColor(AppTheme.Colors.depthProfileUnderfillTop).resolvedColor(with: dark)
            let underfillBottomLight = UIColor(AppTheme.Colors.depthProfileUnderfillBottom).resolvedColor(with: light)
            let underfillBottomDark = UIColor(AppTheme.Colors.depthProfileUnderfillBottom).resolvedColor(with: dark)
            let pageTopLight = UIColor(AppTheme.Colors.surfaceGradientTop).resolvedColor(with: light)
            let pageTopDark = UIColor(AppTheme.Colors.surfaceGradientTop).resolvedColor(with: dark)

            // Underfill is fixed to dark ocean stops in both appearances.
            #expect(underfillTopLight == underfillTopDark)
            #expect(underfillBottomLight == underfillBottomDark)
            #expect(underfillTopDark == pageTopDark)
            #expect(underfillTopLight != pageTopLight)
        }

        @Test func diveDepthProfileChartAxisPresentation_depthTicks_unitAware() {
            let metric = DiveDepthProfileChartAxisPresentation.depthTicks(
                maxDepthMeters: 40,
                system: .metric
            )
            #expect(metric.count >= 2)
            #expect(metric.first?.label == "0 m")
            #expect(metric.last?.label == "40 m")
            #expect(abs((metric.last?.fraction ?? 0) - 1) < 0.001)

            let imperial = DiveDepthProfileChartAxisPresentation.depthTicks(
                maxDepthMeters: 30.48, // 100 ft
                system: .imperial
            )
            #expect(imperial.count >= 2)
            #expect(imperial.first?.label == "0 ft")
            #expect(imperial.last?.label.contains("ft") == true)
            #expect(abs((imperial.last?.fraction ?? 0) - 1) < 0.001)
        }

        @Test func diveDepthProfileChartAxisPresentation_niceStep_uses1_2_5_ladder() {
            #expect(abs(DiveDepthProfileChartAxisPresentation.niceStep(range: 30, targetCount: 4) - 10) < 0.001)
            #expect(abs(DiveDepthProfileChartAxisPresentation.niceStep(range: 100, targetCount: 5) - 50) < 0.001)
            #expect(abs(DiveDepthProfileChartAxisPresentation.niceStep(range: 12, targetCount: 4) - 5) < 0.001)
        }

        @Test func diveDepthProfileOverlayChartLayout_plotRect_reservesAxisInsets() {
            let size = CGSize(width: 320, height: 180)
            let rect = DiveDepthProfileOverlayChartLayout.plotRect(in: size)
            #expect(abs(rect.minX - DiveDepthProfileOverlayChartLayout.insetLeading) < 0.1)
            #expect(abs(rect.minY - DiveDepthProfileOverlayChartLayout.insetTop) < 0.1)
            #expect(
                abs(rect.maxX - (size.width - DiveDepthProfileOverlayChartLayout.insetTrailing)) < 0.1
            )
            #expect(
                abs(rect.maxY - (size.height - DiveDepthProfileOverlayChartLayout.insetBottom)) < 0.1
            )
        }

        @Test func diveTankOverviewHeroPresentation_landscapeMinimized_hidesGasSummaryAndShowsMediaMarkers() {
            #expect(
                !DiveTankOverviewHeroPresentation.showsMinimizedTankGasSummary(
                    for: .minimized,
                    isLandscape: true,
                    startPSI: 3000,
                    endPSI: 1200
                )
            )
            #expect(
                DiveTankOverviewHeroPresentation.showsMinimizedTankGasSummary(
                    for: .minimized,
                    isLandscape: false,
                    startPSI: 3000,
                    endPSI: 1200
                )
            )
            #expect(
                !DiveTankOverviewHeroPresentation.showsMinimizedCylinder(for: .minimized, isLandscape: true)
            )
            #expect(DiveTankOverviewHeroPresentation.showsMediaMarkersOnLandscapeProfile(isLandscape: true))
            #expect(!DiveTankOverviewHeroPresentation.showsMediaMarkersOnLandscapeProfile(isLandscape: false))
        }

        @Test func diveTankOverviewHeroPresentation_landscapeChartChromeCommitDelay_isPositive() {
            #expect(DiveTankOverviewHeroPresentation.landscapeChartChromeCommitDelay > .zero)
        }

        @Test func diveActivityOverviewLandscapePresentation_hidesSheetAndUnlocksMapAtEveryDetent() {
            #expect(DiveActivityOverviewLandscapePresentation.hidesOverviewPanel(isLandscape: true))
            #expect(!DiveActivityOverviewLandscapePresentation.hidesOverviewPanel(isLandscape: false))
            #expect(
                DiveActivityOverviewLandscapePresentation.allowsMapInteraction(
                    isLandscape: true,
                    detentAllowsInteraction: false
                )
            )
            #expect(
                !DiveActivityOverviewLandscapePresentation.allowsMapInteraction(
                    isLandscape: false,
                    detentAllowsInteraction: false
                )
            )
            #expect(
                DiveActivityOverviewLandscapePresentation.allowsMapInteraction(
                    isLandscape: false,
                    detentAllowsInteraction: true
                )
            )
        }

        @Test func diveTankOverviewHeroPresentation_landscapeProfileChart_atEveryDetent() {
            for detent in [DiveActivityOverviewDetent.minimized, .large] {
                #expect(
                    DiveTankOverviewHeroPresentation.showsProfileChart(
                        for: detent,
                        depthSampleCount: 4,
                        isLandscape: true
                    )
                )
                #expect(
                    !DiveTankOverviewHeroPresentation.showsTankCylinderHero(
                        for: detent,
                        isLandscape: true
                    )
                )
            }
            #expect(
                DiveTankOverviewHeroPresentation.showsProfileChart(
                    for: .large,
                    depthSampleCount: 4,
                    isLandscape: false
                )
            )
            #expect(
                !DiveTankOverviewHeroPresentation.showsTankCylinderHero(
                    for: .large,
                    isLandscape: false
                )
            )
        }

        @Test func diveActivityOverviewLandscapePresentation_mapBottomMargin_usesDeviceLargeSheetHeight() {
            let context = DiveActivityOverviewSheetLayoutContext(
                layoutHeight: 844,
                screenWidth: 393,
                topSafeInset: 59,
                bottomSafeInset: 34
            )
            let margin = DiveActivityOverviewLandscapePresentation.mapBottomContentMargin(
                layoutContext: context,
                detent: .large,
                liveHeightFraction: nil,
                isLandscape: false
            )
            let expected = DiveActivityOverviewDetent.sheetHeight(
                for: .large,
                layoutHeight: 844,
                bottomSafeInset: 34,
                screenWidth: 393,
                topSafeInset: 59
            )
            #expect(abs(margin - expected) < 0.5)
            let referenceOnly = DiveActivityOverviewDetent.bottomObstructionHeight(
                layoutHeight: 844,
                detent: .large,
                bottomSafeInset: 34
            )
            #expect(margin >= referenceOnly - 0.5)
        }

        @Test func diveActivityOverviewLandscapePresentation_mapBottomMargin_liveFraction_matchesContinuousSheet() {
            let context = DiveActivityOverviewSheetLayoutContext.presentationReference
            let fraction: CGFloat = 0.35
            let margin = DiveActivityOverviewLandscapePresentation.mapBottomContentMargin(
                layoutContext: context,
                detent: .large,
                liveHeightFraction: fraction,
                isLandscape: false
            )
            let expected = DiveActivityOverviewDetent.sheetHeight(
                forHeightFraction: fraction,
                layoutHeight: context.layoutHeight,
                bottomSafeInset: context.bottomSafeInset
            )
            #expect(abs(margin - expected) < 0.01)
        }

        @Test func diveTankOverviewHeroPresentation_landscapeMinimized_hidesSheetAndShowsRotateHintInPortrait() {
            #expect(
                DiveTankOverviewHeroPresentation.showsRotatePhoneHint(
                    for: .minimized,
                    isLandscape: false,
                    depthSampleCount: 4
                )
            )
            #expect(
                !DiveTankOverviewHeroPresentation.showsRotatePhoneHint(
                    for: .minimized,
                    isLandscape: true,
                    depthSampleCount: 4
                )
            )
            let layoutHeight: CGFloat = 844
            let bottomSafe: CGFloat = 34
            let withSheet = DiveActivityOverviewDetent.bottomObstructionHeight(
                layoutHeight: layoutHeight,
                detent: .minimized,
                bottomSafeInset: bottomSafe
            )
            let withoutSheet = DiveTankOverviewHeroPresentation.tankHeroBottomContentMargin(
                layoutHeight: layoutHeight,
                detent: .minimized,
                bottomSafeInset: bottomSafe,
                isLandscape: true
            )
            #expect(withoutSheet < withSheet)
        }

        @Test func diveTankOverviewHeroPresentation_minimizedRotateHintTopInset_sitsBelowGrabber() {
            #expect(
                DiveTankOverviewHeroPresentation.minimizedPortraitRotateHintTopInset
                    == DiveActivityOverviewPanelMetrics.embeddedGrabberRowHeight + 4
            )
        }

        @Test func diveTankOverviewHeroPresentation_showsAnimatedDepthChartBubbles_byDetent() {
            #expect(
                !DiveTankOverviewHeroPresentation.showsAnimatedDepthChartBubbles(
                    for: .large,
                    isLandscape: false
                )
            )
            #expect(
                DiveTankOverviewHeroPresentation.showsAnimatedDepthChartBubbles(
                    for: .minimized,
                    isLandscape: false
                )
            )
            #expect(
                DiveTankOverviewHeroPresentation.showsAnimatedDepthChartBubbles(
                    for: .large,
                    isLandscape: true
                )
            )
            #expect(
                DiveTankOverviewHeroPresentation.showsAnimatedDepthChartBubbles(
                    for: .minimized,
                    isLandscape: true
                )
            )
        }

        @Test func diveDepthProfileOverlayChartLayout_resolvedBaseline_prefersEndingPSI() {
            let samples = [
                DiveDepthProfilePressureSample(elapsedSeconds: 0, pressurePSI: 3000),
                DiveDepthProfilePressureSample(elapsedSeconds: 100, pressurePSI: 1500),
            ]
            let baseline = DiveDepthProfileOverlayChartLayout.resolvedPressureBaselinePSI(
                endingPSI: 1400,
                pressureSamples: samples
            )
            #expect(baseline == 1400)
        }

        @Test func diveDepthProfileScrubCalloutPresentation_labelTopPadding_sitsBelowTabMenu() {
            let topSafeInset: CGFloat = 59
            let chromeTopPadding = AppTheme.Spacing.sm
            let padding = DiveDepthProfileScrubCalloutPresentation.labelTopPadding(
                topSafeInset: topSafeInset,
                chromeTopPadding: chromeTopPadding
            )
            #expect(
                padding
                    == topSafeInset
                        + chromeTopPadding
                        + DiveDepthProfileScrubCalloutPresentation.iconTabBarChromeRowHeight
                        + DiveDepthProfileScrubCalloutPresentation.gapBelowTabMenu
            )

            let topObstruction: CGFloat = 104
            let legacyPadding = DiveDepthProfileScrubCalloutPresentation.labelTopPadding(
                topObstructionHeight: topObstruction
            )
            #expect(
                legacyPadding
                    == topObstruction
                        + DiveDepthProfileScrubCalloutPresentation.iconTabBarShellVerticalInset
                        + DiveDepthProfileScrubCalloutPresentation.gapBelowTabMenu
            )
        }

        @Test func diveDepthProfileScrubCalloutPresentation_labelTopPadding_pinsAtMinimizedChartFade() {
            let layoutSize = CGSize(width: 390, height: 640)
            let layoutHeight: CGFloat = 844
            let topObstruction: CGFloat = 100
            let minimizedMargin = layoutHeight * DiveActivityOverviewPanelMetrics.minimizedHeightFraction
            let largeMargin = layoutHeight * DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction
            let chartFrame = DiveTankOverviewHeroPresentation.minimizedProfileChartFrame(
                layoutSize: layoutSize,
                layoutHeight: layoutHeight,
                topObstructionHeight: topObstruction,
                bottomContentMargin: minimizedMargin,
                isLandscape: false,
                detent: .minimized,
                chartSizingBottomContentMargin: largeMargin
            )
            let padding = DiveDepthProfileScrubCalloutPresentation.labelTopPaddingPinnedAtMinimizedPortraitChartFade(
                chartFrame: chartFrame
            )
            let fadeBandHeight = chartFrame.height
                * DiveTankOverviewHeroPresentation.minimizedPortraitChartTopFadeFraction
            let expected = chartFrame.minY + max(6, fadeBandHeight * 0.4)
            #expect(abs(padding - expected) < 0.01)
            #expect(padding > chartFrame.minY)
            #expect(padding < chartFrame.minY + fadeBandHeight)
        }

        @Test func diveDepthProfileOverlayChartLayout_pressurePoint_alignsWithDepthBandAndBuffer() {
            let rect = CGRect(x: 10, y: 20, width: 100, height: 120)
            let maxDepthMeters: Double = 30
            let axisMax = DiveDepthProfileChartPresentation.depthAxisMaximumMeters(dataMaxMeters: maxDepthMeters)
            let band = DiveDepthProfileOverlayChartLayout.depthDataVerticalBand(
                in: rect,
                minDepthMeters: 0,
                maxDepthMeters: maxDepthMeters,
                axisMaxDepthMeters: axisMax
            )
            let start = DiveDepthProfileOverlayChartLayout.pressurePoint(
                sample: DiveDepthProfilePressureSample(elapsedSeconds: 0, pressurePSI: 3000),
                in: rect,
                maxElapsed: 100,
                minDepthMeters: 0,
                maxDepthMeters: maxDepthMeters,
                axisMaxDepthMeters: axisMax,
                minPressurePSI: 1500,
                maxPressurePSI: 3000
            )
            let end = DiveDepthProfileOverlayChartLayout.pressurePoint(
                sample: DiveDepthProfilePressureSample(elapsedSeconds: 100, pressurePSI: 1500),
                in: rect,
                maxElapsed: 100,
                minDepthMeters: 0,
                maxDepthMeters: maxDepthMeters,
                axisMaxDepthMeters: axisMax,
                minPressurePSI: 1500,
                maxPressurePSI: 3000
            )
            #expect(abs(start.y - band.minY) < 0.01)
            #expect(abs(end.y - band.maxY) < 0.01)
            #expect(end.y < rect.maxY - 1)
            #expect(start.y < end.y)
        }

        @Test func diveDepthProfileOverlayChartLayout_chartX_landscapeBuffer_insetsDataBand() {
            let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
            let buffer = DiveDepthProfileChartPresentation.landscapeHorizontalEdgeBufferFraction
            let startX = DiveDepthProfileOverlayChartLayout.chartX(
                forElapsedFraction: 0,
                in: rect,
                horizontalEdgeBufferFraction: buffer
            )
            let endX = DiveDepthProfileOverlayChartLayout.chartX(
                forElapsedFraction: 1,
                in: rect,
                horizontalEdgeBufferFraction: buffer
            )
            #expect(abs(startX - 14) < 0.01)
            #expect(abs(endX - 186) < 0.01)
        }

        @Test func diveDepthProfileOverlayChartLayout_elapsedSeconds_rejectsLandscapeBufferMargins() {
            let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
            let viewport = DiveDepthProfileChartViewport.full(elapsedMax: 100)
            let buffer = DiveDepthProfileChartPresentation.landscapeHorizontalEdgeBufferFraction
            #expect(
                DiveDepthProfileOverlayChartLayout.elapsedSeconds(
                    atChartX: 5,
                    in: rect,
                    viewport: viewport,
                    horizontalEdgeBufferFraction: buffer
                ) == nil
            )
            #expect(
                DiveDepthProfileOverlayChartLayout.elapsedSeconds(
                    atChartX: 195,
                    in: rect,
                    viewport: viewport,
                    horizontalEdgeBufferFraction: buffer
                ) == nil
            )
            let mid = DiveDepthProfileOverlayChartLayout.elapsedSeconds(
                atChartX: 100,
                in: rect,
                viewport: viewport,
                horizontalEdgeBufferFraction: buffer
            )
            #expect(mid != nil)
            #expect(abs((mid ?? 0) - 50) < 0.01)
        }

        @Test func diveDepthProfileOverlayChartLayout_tracedProfilePath_extendsFlatIntoBufferForFillOnly() {
            let rect = CGRect(x: 0, y: 0, width: 100, height: 80)
            let points = [
                CGPoint(x: 10, y: 40),
                CGPoint(x: 90, y: 60),
            ]
            let fillPath = DiveDepthProfileOverlayChartLayout.tracedProfilePath(
                points: points,
                in: rect,
                horizontalEdgeBufferFraction: 0.07,
                extendsIntoHorizontalBuffers: true
            )
            let linePath = DiveDepthProfileOverlayChartLayout.tracedProfilePath(
                points: points,
                in: rect,
                horizontalEdgeBufferFraction: 0.07,
                extendsIntoHorizontalBuffers: false
            )
            #expect(abs(fillPath.boundingRect.minX - rect.minX) < 0.01)
            #expect(abs(fillPath.boundingRect.maxX - rect.maxX) < 0.01)
            #expect(abs(linePath.boundingRect.minX - 10) < 0.01)
            #expect(abs(linePath.boundingRect.maxX - 90) < 0.01)
        }

        @Test func diveActivityOverviewMapTeardown_showsLiveMap_untilRequested() {
            #expect(DiveActivityOverviewMapTeardown.showsLiveMap(teardownRequested: false))
            #expect(!DiveActivityOverviewMapTeardown.showsLiveMap(teardownRequested: true))
        }

        @Test func diveActivityMapSitePrompt_isEligibleWhenUnlinkedWithEntryOrName() {
            let withGPS = DiveActivity(
                source: .garminMK3,
                startTime: Date(),
                durationMinutes: 30,
                maxDepthMeters: 10,
                entryCoordinate: DiveCoordinate(latitude: 12, longitude: -68)
            )
            #expect(DiveActivityMapSitePrompt.isEligible(for: withGPS))

            let withName = DiveActivity(
                source: .macDive,
                startTime: Date(),
                durationMinutes: 30,
                maxDepthMeters: 10,
                siteName: "Salt Pier"
            )
            #expect(DiveActivityMapSitePrompt.isEligible(for: withName))

            let linked = DiveActivity(
                source: .manual,
                startTime: Date(),
                durationMinutes: 30,
                maxDepthMeters: 10,
                siteName: "Salt Pier"
            )
            let site = DiveSite(siteName: "Catalog", latCoords: 12, longCoords: -68)
            DiveActivitySiteAssociation.link(linked, to: site)
            #expect(!DiveActivityMapSitePrompt.isEligible(for: linked))
        }

        @Test func diveActivityMapSitePrompt_showsInfoButtonOnlyAfterDecline() {
            let activity = DiveActivity(
                source: .garminMK3,
                startTime: Date(),
                durationMinutes: 30,
                maxDepthMeters: 10,
                entryCoordinate: DiveCoordinate(latitude: 12, longitude: -68)
            )
            #expect(DiveActivityMapSitePrompt.shouldPresentAutomatically(for: activity, userDeclined: false))
            #expect(!DiveActivityMapSitePrompt.showsInfoButton(for: activity, userDeclined: false))
            #expect(!DiveActivityMapSitePrompt.shouldPresentAutomatically(for: activity, userDeclined: true))
            #expect(DiveActivityMapSitePrompt.showsInfoButton(for: activity, userDeclined: true))
        }

        @Test func diveActivityOverviewPanelMetrics_mediaCarouselScreenAlignmentTopInset_matchesDetentGap() {
            let layoutHeight: CGFloat = 800
            let largeInset = DiveActivityOverviewPanelMetrics.mediaCarouselScreenAlignmentTopInset(
                layoutHeight: layoutHeight,
                detent: .large
            )
            let expected = layoutHeight * (
                DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction
                    - DiveActivityOverviewPanelMetrics.minimizedHeightFraction
            )
            #expect(abs(largeInset - expected) < 0.02)
            #expect(
                abs(
                    DiveActivityOverviewPanelMetrics.mediaCarouselExpandedRegionHeight(layoutHeight: layoutHeight)
                        - expected
                ) < 0.02
            )
        }

        @Test func diveActivityOverviewPanelMetrics_panelContentTopPadding_isSharedAcrossDetents() {
            #expect(DiveActivityOverviewPanelMetrics.panelContentTopPadding == 10)
            #expect(
                DiveActivityOverviewPanelMetrics.panelContentTopPadding
                    < AppTheme.Sheet.contentTopSpacing
            )
        }

        @Test func diveActivityFieldEditing_applyDraft_doesNotChangeSourceOrImportVersion() {
            let activity = DiveActivity(
                source: .macDive,
                startTime: Date(),
                durationMinutes: 40,
                maxDepthMeters: 18,
                rawImportVersion: "UDDF 3.2"
            )
            var draft = DiveActivityFieldEditDraft()
            draft.source = .manual
            draft.text = "Edited"
            DiveActivityFieldEditing.applyDraft(draft, for: .source, to: activity, displayUnits: .metric)
            DiveActivityFieldEditing.applyDraft(draft, for: .rawImportVersion, to: activity, displayUnits: .metric)
            #expect(activity.source == .macDive)
            #expect(activity.rawImportVersion == "UDDF 3.2")
        }

        @Test func diveActivityFieldEditing_applyDraft_skipsManualEntryOnlyFieldsOnImports() {
            let activity = DiveActivity(
                source: .garminMK3,
                startTime: Date(),
                durationMinutes: 40,
                maxDepthMeters: 18
            )
            var draft = DiveActivityFieldEditDraft()
            draft.text = "52"
            DiveActivityFieldEditing.applyDraft(draft, for: .durationMinutes, to: activity, displayUnits: .metric)
            #expect(activity.durationMinutes == 40)
        }

        @Test func diveActivityMapSitePrompt_draft_prefillsPlaceFromImportLocation() {
            let activity = DiveActivity(
                source: .macDive,
                startTime: Date(),
                durationMinutes: 40,
                maxDepthMeters: 18,
                siteName: "Salt Pier",
                locationName: "Bonaire, Caribbean Netherlands"
            )
            let draft = DiveActivityMapSitePrompt.draft(from: activity)
            #expect(draft.siteName == "Salt Pier")
            #expect(draft.region == "Bonaire")
            #expect(draft.country == "Caribbean Netherlands")
        }

        @Test func diveActivityMapSitePrompt_draft_keepsCatalogPlaceWhenEditing() {
            let activity = DiveActivity(
                source: .manual,
                startTime: Date(),
                durationMinutes: 1,
                maxDepthMeters: 1,
                locationName: "Ignored, Place"
            )
            let site = DiveSite(
                siteName: "Catalog Reef",
                country: "Mexico",
                region: "Baja",
                bodyOfWater: "Sea of Cortez",
                latCoords: 24.5,
                longCoords: -110.2
            )
            let draft = DiveActivityMapSitePrompt.draft(
                from: activity,
                catalogSite: DiveLinkedSiteResolver.resolved(from: site)
            )
            #expect(draft.siteName == "Catalog Reef")
            #expect(draft.country == "Mexico")
            #expect(draft.region == "Baja")
            #expect(draft.bodyOfWater == "Sea of Cortez")
        }

        @Test func diveActivityMapSitePrompt_draft_fillsEmptyCatalogPlaceFromImport() {
            let activity = DiveActivity(
                source: .macDive,
                startTime: Date(),
                durationMinutes: 1,
                maxDepthMeters: 1,
                locationName: "Bonaire, Caribbean Netherlands"
            )
            let site = DiveSite(siteName: "Salt Pier")
            let draft = DiveActivityMapSitePrompt.draft(
                from: activity,
                catalogSite: DiveLinkedSiteResolver.resolved(from: site)
            )
            #expect(draft.region == "Bonaire")
            #expect(draft.country == "Caribbean Netherlands")
        }

        @Test func diveActivityFieldValueParsing_depthAndPressureRespectDisplayUnits() {
            #expect(DiveActivityFieldValueParsing.parseDepthMeters("30", displayUnits: .metric) == 30)
            #expect(
                abs((DiveActivityFieldValueParsing.parseDepthMeters("100", displayUnits: .imperial) ?? 0) - 30.48) < 0.1
            )
            #expect(DiveActivityFieldValueParsing.parsePressurePSI("200", displayUnits: .imperial) == 200)
            #expect(
                abs((DiveActivityFieldValueParsing.parsePressurePSI("200", displayUnits: .metric) ?? 0) - 2900.75) < 1
            )
        }

        @Test func diveActivityFieldEditing_applyDraft_updatesDuration() {
            let activity = DiveActivity(
                source: .manual,
                startTime: Date(),
                durationMinutes: 40,
                maxDepthMeters: 18
            )
            var draft = DiveActivityFieldEditDraft()
            draft.text = "52"
            DiveActivityFieldEditing.applyDraft(draft, for: .durationMinutes, to: activity, displayUnits: .metric)
            #expect(activity.durationMinutes == 52)
        }

        @Test func diveActivityFieldEditing_signatureDisplayValue_usesPlaceholderWhenEmpty() {
            let activity = DiveActivity(
                source: .manual,
                startTime: Date(),
                durationMinutes: 40,
                maxDepthMeters: 18
            )
            let empty = DiveActivityFieldEditing.displayValue(
                for: .diveSignature,
                activity: activity,
                displayUnits: .metric,
                profileGasStats: .init(sampleCount: 0, minPSI: 0, maxPSI: 0)
            )
            #expect(empty == "—")
        }

        @Test func diveActivityOverviewTabSelection_allTabs_useLargeDetent() {
            #expect(DiveActivityOverviewTabSelection.overviewDetent(whenSelecting: .map) == .large)
            #expect(DiveActivityOverviewTabSelection.overviewDetent(whenSelecting: .tank) == .large)
            #expect(DiveActivityOverviewTabSelection.overviewDetent(whenSelecting: .camera) == .large)
            #expect(DiveActivityOverviewTabSelection.overviewDetent(whenSelectingSnorkel: .map) == .large)
            #expect(DiveActivityOverviewTabSelection.overviewDetent(whenSelectingSnorkel: .heartRate) == .large)
            #expect(DiveActivityOverviewTabSelection.overviewDetent(whenSelectingSnorkel: .camera) == .large)
        }

        @Test func diveActivityOverviewTabPager_swipeAdvancesDiveAndSnorkelTabs() {
            let threshold = DiveActivityOverviewTabPagerPresentation.swipeAdvanceThreshold
            #expect(
                DiveActivityOverviewTabPagerPresentation.diveTabAfterHorizontalSwipe(
                    from: .map,
                    translationWidth: -threshold
                ) == .tank
            )
            #expect(
                DiveActivityOverviewTabPagerPresentation.diveTabAfterHorizontalSwipe(
                    from: .tank,
                    translationWidth: -threshold
                ) == .camera
            )
            #expect(
                DiveActivityOverviewTabPagerPresentation.diveTabAfterHorizontalSwipe(
                    from: .camera,
                    translationWidth: threshold
                ) == .tank
            )
            #expect(
                DiveActivityOverviewTabPagerPresentation.diveTabAfterHorizontalSwipe(
                    from: .map,
                    translationWidth: threshold
                ) == nil
            )
            #expect(
                DiveActivityOverviewTabPagerPresentation.diveTabAfterHorizontalSwipe(
                    from: .camera,
                    translationWidth: -threshold
                ) == nil
            )
            #expect(
                DiveActivityOverviewTabPagerPresentation.snorkelTabAfterHorizontalSwipe(
                    from: .map,
                    translationWidth: -threshold
                ) == .heartRate
            )
            #expect(
                DiveActivityOverviewTabPagerPresentation.snorkelTabAfterHorizontalSwipe(
                    from: .heartRate,
                    translationWidth: -threshold
                ) == .camera
            )
            #expect(
                DiveActivityOverviewTabPagerPresentation.snorkelTabAfterHorizontalSwipe(
                    from: .camera,
                    translationWidth: threshold
                ) == .heartRate
            )
            #expect(
                DiveActivityOverviewTabPagerPresentation.snorkelTabAfterHorizontalSwipe(
                    from: .map,
                    translationWidth: -(threshold - 1)
                ) == nil
            )
        }

        @Test func diveActivityOverviewTabPager_allowsSwipeOnlyAtLargeRestingDetent() {
            #expect(
                DiveActivityOverviewTabPagerPresentation.allowsHorizontalTabSwipe(
                    detent: .large,
                    isGrabberDragging: false
                )
            )
            #expect(
                !DiveActivityOverviewTabPagerPresentation.allowsHorizontalTabSwipe(
                    detent: .minimized,
                    isGrabberDragging: false
                )
            )
            #expect(
                !DiveActivityOverviewTabPagerPresentation.allowsHorizontalTabSwipe(
                    detent: .large,
                    isGrabberDragging: true
                )
            )
            #expect(
                DiveActivityOverviewTabPagerPresentation.isHorizontalSwipeDominant(
                    translation: CGSize(width: 40, height: 10)
                )
            )
            #expect(
                !DiveActivityOverviewTabPagerPresentation.isHorizontalSwipeDominant(
                    translation: CGSize(width: 10, height: 40)
                )
            )
        }

        @Test func diveActivityOverviewTabSelection_friendSharedMedia_usesMinimizedDetent() {
            #expect(DiveActivityOverviewTabSelection.friendSharedOverviewDetent(whenSelecting: .map) == .large)
            #expect(DiveActivityOverviewTabSelection.friendSharedOverviewDetent(whenSelecting: .tank) == .large)
            #expect(DiveActivityOverviewTabSelection.friendSharedOverviewDetent(whenSelecting: .camera) == .minimized)
            #expect(DiveActivityOverviewTabSelection.friendSharedOverviewDetent(whenSelectingSnorkel: .map) == .large)
            #expect(DiveActivityOverviewTabSelection.friendSharedOverviewDetent(whenSelectingSnorkel: .heartRate) == .large)
            #expect(DiveActivityOverviewTabSelection.friendSharedOverviewDetent(whenSelectingSnorkel: .camera) == .minimized)
        }

        @Test @MainActor
        func diveActivityMapCoordinateResolution_skipsCatalogLookupWhenEntryGPSPresent() {
            let activity = DiveActivity(
                source: .manual,
                startTime: Date(),
                durationMinutes: 45,
                maxDepthMeters: 18
            )
            activity.entryCoordinate = DiveCoordinate(latitude: 12.1, longitude: -68.9)
            #expect(!DiveActivityMapCoordinateResolution.needsCatalogSiteLookup(for: activity))
        }

        @Test func diveDepthProfileMediaPlotting_depthMeters_interpolatesBetweenSamples() {
            let samples = [
                DiveDepthProfileSample(elapsedSeconds: 0, depthMeters: 0),
                DiveDepthProfileSample(elapsedSeconds: 100, depthMeters: 20),
            ]
            #expect(DiveDepthProfileMediaPlotting.depthMeters(atElapsed: 50, in: samples) == 10)
        }

        @Test @MainActor func diveDepthProfileMediaPlotting_markers_onlyWithinDiveWindow() {
            let start = Date(timeIntervalSince1970: 1_000_000)
            let points = [
                DiveProfilePoint(timestamp: start, depthMeters: 5),
                DiveProfilePoint(timestamp: start.addingTimeInterval(600), depthMeters: 18),
            ]
            let samples = DiveDepthProfileSeries.samples(fromProfilePoints: points)
            let inWindow = DiveMediaPhoto(
                sortOrder: 0,
                mediaKind: .image,
                capturedAt: start.addingTimeInterval(300)
            )
            let before = DiveMediaPhoto(
                sortOrder: 1,
                mediaKind: .image,
                capturedAt: start.addingTimeInterval(-60)
            )
            let after = DiveMediaPhoto(
                sortOrder: 2,
                mediaKind: .video,
                capturedAt: start.addingTimeInterval(900)
            )
            let markers = DiveDepthProfileMediaPlotting.markers(
                mediaPhotos: [inWindow, before, after],
                profileSamples: samples,
                activityStartTime: start,
                durationMinutes: 10,
                profilePoints: points
            )
            #expect(markers.count == 1)
            #expect(markers.first?.mediaID == inWindow.id)
            #expect(markers.first?.isVideo == false)
            #expect(markers.first?.elapsedSeconds == 300)
        }

        @Test func diveDepthProfileMediaPlotting_captureContext_matchesMarkerWindow() {
            let start = Date(timeIntervalSince1970: 2_000_000)
            let points = [
                DiveProfilePoint(timestamp: start, depthMeters: 0),
                DiveProfilePoint(timestamp: start.addingTimeInterval(1200), depthMeters: 30),
            ]
            let samples = DiveDepthProfileSeries.samples(fromProfilePoints: points)
            let media = DiveMediaPhoto(
                sortOrder: 0,
                mediaKind: .image,
                capturedAt: start.addingTimeInterval(600)
            )
            let context = DiveDepthProfileMediaPlotting.captureContext(
                for: media,
                profileSamples: samples,
                activityStartTime: start,
                durationMinutes: 20,
                profilePoints: points
            )
            #expect(context?.elapsedSeconds == 600)
            #expect(context?.depthMeters == 15)
        }

        @Test func diveDepthProfileMediaPlotting_captureContextsByMediaID_matchesCaptureContext() {
            let start = Date(timeIntervalSince1970: 2_100_000)
            let points = [
                DiveProfilePoint(timestamp: start, depthMeters: 0),
                DiveProfilePoint(timestamp: start.addingTimeInterval(1200), depthMeters: 30),
            ]
            let samples = DiveDepthProfileSeries.samples(fromProfilePoints: points)
            let inWindow = DiveMediaPhoto(sortOrder: 0, mediaKind: .image, capturedAt: start.addingTimeInterval(300))
            let outWindow = DiveMediaPhoto(sortOrder: 1, mediaKind: .video, capturedAt: start.addingTimeInterval(1300))

            let contexts = DiveDepthProfileMediaPlotting.captureContextsByMediaID(
                mediaPhotos: [inWindow, outWindow],
                profileSamples: samples,
                activityStartTime: start,
                durationMinutes: 20,
                profilePoints: points
            )
            let single = DiveDepthProfileMediaPlotting.captureContext(
                for: inWindow,
                profileSamples: samples,
                activityStartTime: start,
                durationMinutes: 20,
                profilePoints: points
            )

            #expect(contexts[inWindow.id] == single)
            #expect(contexts[outWindow.id] == nil)
        }

        @Test func diveDepthProfileMediaPlotting_markerThumbnailScale_isOneAtFullViewport() {
            let viewport = DiveDepthProfileChartViewport.full(elapsedMax: 1000)
            #expect(
                DiveDepthProfileMediaPlotting.markerThumbnailScale(
                    viewport: viewport,
                    fullElapsedMax: 1000
                ) == 1
            )
            #expect(
                DiveDepthProfileMediaPlotting.markerThumbnailDisplaySize(
                    viewport: viewport,
                    fullElapsedMax: 1000
                ) == DiveDepthProfileMediaPlotting.markerThumbnailSize
            )
        }

        @Test func diveDepthProfileMediaPlotting_markerThumbnailScale_growsWhenZoomedIn() {
            var viewport = DiveDepthProfileChartViewport.full(elapsedMax: 1000)
            viewport.zoom(scale: 4, anchorFraction: 0.5, fullElapsedMax: 1000)
            let scale = DiveDepthProfileMediaPlotting.markerThumbnailScale(
                viewport: viewport,
                fullElapsedMax: 1000
            )
            #expect(scale > 1)
            #expect(scale <= DiveDepthProfileMediaPlotting.markerThumbnailMaxScale)
            #expect(
                DiveDepthProfileMediaPlotting.markerThumbnailDisplaySize(
                    viewport: viewport,
                    fullElapsedMax: 1000
                ) > DiveDepthProfileMediaPlotting.markerThumbnailSize
            )
        }

        @Test func diveDepthProfileMediaPlotting_markerThumbnailMetrics_areCompactSquares() {
            #expect(DiveDepthProfileMediaPlotting.markerThumbnailSize == 28)
            #expect(DiveDepthProfileMediaPlotting.markerThumbnailCornerRadius == 5)
            #expect(
                DiveDepthProfileMediaPlotting.markerThumbnailSize
                    < DiveActivityMediaPresentation.carouselThumbnailSize
            )
        }

        @Test func diveActivityOverviewDetent_mapCameraDetent_followsRestingDetent() {
            #expect(DiveActivityOverviewDetent.large.mapCameraDetent == .large)
            #expect(DiveActivityOverviewDetent.minimized.mapCameraDetent == .minimized)
        }

        @Test func diveActivityOverviewDetent_allowsMapInteraction_onlyWhenMinimized() {
            #expect(DiveActivityOverviewDetent.minimized.allowsMapInteraction)
            #expect(!DiveActivityOverviewDetent.large.allowsMapInteraction)
        }

        @Test func diveTankOverviewHeroPresentation_scale_byDetent() {
            #expect(DiveTankOverviewHeroPresentation.scale(for: .minimized) == 0.5)
            #expect(DiveTankOverviewHeroPresentation.scale(for: .large) == 1)
        }

        @Test func diveTankOverviewHeroPresentation_minimizedEntranceAnimation_isSnappy() {
            #expect(DiveTankOverviewHeroPresentation.minimizedEntranceAnimationDuration == 2.4)
            #expect(DiveTankOverviewHeroPresentation.minimizedWaterTopFadeDuration == 0.35)
            #expect(DiveTankOverviewHeroPresentation.minimizedWaterTopFadeHeightFraction == 0.5)
            #expect(DiveTankOverviewHeroPresentation.profileStrokeFadeCompleteCollapseProgress == 0.22)
        }

        @Test func diveTankOverviewHeroPresentation_shouldPlayMinimizedEntranceAnimation_onlyWhenCollapsingToMinimized() {
            #expect(
                DiveTankOverviewHeroPresentation.shouldPlayMinimizedEntranceAnimation(
                    from: .large,
                    to: .minimized
                )
            )
            #expect(
                !DiveTankOverviewHeroPresentation.shouldPlayMinimizedEntranceAnimation(
                    from: .minimized,
                    to: .large
                )
            )
            #expect(
                !DiveTankOverviewHeroPresentation.shouldPlayMinimizedEntranceAnimation(
                    from: .minimized,
                    to: .minimized
                )
            )
        }

        @Test func diveTankOverviewHeroPresentation_collapseProgress_mapsLiveSheetHeight() {
            let context = DiveActivityOverviewSheetLayoutContext.presentationReference
            let large = DiveActivityOverviewPanelMetrics.largeHeightFraction(in: context)
            let minimized = DiveActivityOverviewPanelMetrics.minimizedHeightFraction
            #expect(
                DiveTankOverviewHeroPresentation.collapseProgress(
                    liveHeightFraction: large,
                    layoutContext: context
                ) == 0
            )
            #expect(
                DiveTankOverviewHeroPresentation.collapseProgress(
                    liveHeightFraction: minimized,
                    layoutContext: context
                ) == 1
            )
            let mid = DiveTankOverviewHeroPresentation.collapseProgress(
                liveHeightFraction: (large + minimized) / 2,
                layoutContext: context
            )
            #expect(abs(mid - 0.5) < 0.02)
        }

        @Test func diveTankOverviewHeroPresentation_profileStrokeOpacity_fadesWhileCollapsingFromLarge() {
            #expect(
                DiveTankOverviewHeroPresentation.profileStrokeAndUnderfillOpacity(
                    sheetDetent: .large,
                    collapseProgress: 0
                ) == 1
            )
            #expect(
                DiveTankOverviewHeroPresentation.profileStrokeAndUnderfillOpacity(
                    sheetDetent: .large,
                    collapseProgress: DiveTankOverviewHeroPresentation.profileStrokeFadeCompleteCollapseProgress
                ) == 0
            )
            #expect(
                DiveTankOverviewHeroPresentation.profileStrokeAndUnderfillOpacity(
                    sheetDetent: .large,
                    collapseProgress: 0.11
                ) > 0.45
            )
            #expect(
                DiveTankOverviewHeroPresentation.profileStrokeAndUnderfillOpacity(
                    sheetDetent: .large,
                    collapseProgress: 0.11
                ) < 0.55
            )
            #expect(
                DiveTankOverviewHeroPresentation.profileStrokeAndUnderfillOpacity(
                    sheetDetent: .large,
                    collapseProgress: 1
                ) == 0
            )
            #expect(
                DiveTankOverviewHeroPresentation.profileStrokeAndUnderfillOpacity(
                    sheetDetent: .minimized,
                    collapseProgress: 1
                ) == 1
            )
            #expect(DiveTankOverviewHeroPresentation.profileStrokeFadeCompleteCollapseProgress == 0.22)
        }

        @Test func diveTankOverviewHeroPresentation_shouldSkipMinimizedEntranceAfterDrag_nearMinimized() {
            let context = DiveActivityOverviewSheetLayoutContext.presentationReference
            let minimized = DiveActivityOverviewPanelMetrics.minimizedHeightFraction
            #expect(
                DiveTankOverviewHeroPresentation.shouldSkipMinimizedEntranceAfterDrag(
                    liveHeightFraction: minimized,
                    layoutContext: context
                )
            )
            let large = DiveActivityOverviewPanelMetrics.largeHeightFraction(in: context)
            #expect(
                !DiveTankOverviewHeroPresentation.shouldSkipMinimizedEntranceAfterDrag(
                    liveHeightFraction: large,
                    layoutContext: context
                )
            )
        }

        @Test func diveTankOverviewHeroPresentation_interpolatedPortraitProfileChartFrame_blendsLargeAndMinimized() {
            let layoutSize = CGSize(width: 390, height: 640)
            let layoutHeight: CGFloat = 844
            let topObstruction: CGFloat = 100
            let minimizedMargin = layoutHeight * DiveActivityOverviewPanelMetrics.minimizedHeightFraction
            let largeMargin = layoutHeight * DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction
            let large = DiveTankOverviewHeroPresentation.portraitProfileChartFrame(
                layoutSize: layoutSize,
                layoutHeight: layoutHeight,
                topObstructionHeight: topObstruction,
                bottomContentMargin: minimizedMargin,
                chartSizingBottomContentMargin: largeMargin,
                heightScale: 1
            )
            let minimized = DiveTankOverviewHeroPresentation.portraitProfileChartFrame(
                layoutSize: layoutSize,
                layoutHeight: layoutHeight,
                topObstructionHeight: topObstruction,
                bottomContentMargin: minimizedMargin,
                chartSizingBottomContentMargin: largeMargin,
                heightScale: DiveTankOverviewHeroPresentation.minimizedPortraitChartHeightScale
            )
            let mid = DiveTankOverviewHeroPresentation.interpolatedPortraitProfileChartFrame(
                layoutSize: layoutSize,
                layoutHeight: layoutHeight,
                topObstructionHeight: topObstruction,
                bottomContentMargin: minimizedMargin,
                chartSizingBottomContentMargin: largeMargin,
                collapseProgress: 0.5
            )
            #expect(abs(mid.height - (large.height + minimized.height) / 2) < 1)
            #expect(mid.height > large.height + 1)
            #expect(mid.height < minimized.height + 1)
        }

        @Test func diveTankOverviewHeroPresentation_portraitChartDragTransform_identityAtRestTracksTarget() {
            let base = CGRect(x: 0, y: 100, width: 390, height: 300)
            let identity = DiveTankOverviewHeroPresentation.portraitChartDragTransform(
                baseFrame: base,
                targetFrame: base
            )
            #expect(abs(identity.scaleY - 1) < 0.0001)
            #expect(abs(identity.centerY - base.midY) < 0.0001)

            let target = CGRect(x: 0, y: 50, width: 390, height: 450)
            let dragged = DiveTankOverviewHeroPresentation.portraitChartDragTransform(
                baseFrame: base,
                targetFrame: target
            )
            #expect(abs(dragged.scaleY - 1.5) < 0.0001)
            #expect(abs(dragged.centerY - target.midY) < 0.0001)
        }

        @MainActor
        @Test func diveActivityOverviewLiveSheetState_defaultsToRestingDetentAndClearsRelease() {
            let state = DiveActivityOverviewLiveSheetState()
            #expect(state.heightFraction == DiveActivityOverviewDetent.defaultSelection.heightFraction)
            #expect(state.dragReleaseHeightFraction == nil)
            state.dragReleaseHeightFraction = 0.21
            #expect(state.dragReleaseHeightFraction == 0.21)
            state.dragReleaseHeightFraction = nil
            #expect(state.dragReleaseHeightFraction == nil)
        }

        @Test func diveTankOverviewHeroPresentation_minimizedChromeOpacity_fadesOnExpand() {
            #expect(
                DiveTankOverviewHeroPresentation.minimizedChromeOpacity(
                    sheetDetent: .minimized,
                    isLandscape: false,
                    collapseProgress: 1,
                    chromeRevealProgress: 1
                ) == 1
            )
            #expect(
                DiveTankOverviewHeroPresentation.minimizedChromeOpacity(
                    sheetDetent: .minimized,
                    isLandscape: false,
                    collapseProgress: 0.25,
                    chromeRevealProgress: 1
                ) == 0.25
            )
            #expect(
                DiveTankOverviewHeroPresentation.minimizedChromeOpacity(
                    sheetDetent: .large,
                    isLandscape: false,
                    collapseProgress: 0.5,
                    chromeRevealProgress: 1
                ) == 0
            )
            #expect(
                DiveTankOverviewHeroPresentation.minimizedChromeOpacity(
                    sheetDetent: .minimized,
                    isLandscape: true,
                    collapseProgress: 1,
                    chromeRevealProgress: 1
                ) == 0
            )
        }

        @Test func diveTankOverviewHeroPresentation_collapseWaterBackdropOpacity_clearsWithTopFade() {
            #expect(
                DiveTankOverviewHeroPresentation.collapseWaterBackdropOpacity(
                    collapseProgress: 1,
                    waterTopHalfFadeProgress: 0
                ) == 1
            )
            #expect(
                DiveTankOverviewHeroPresentation.collapseWaterBackdropOpacity(
                    collapseProgress: 1,
                    waterTopHalfFadeProgress: 1
                ) == 0
            )
            #expect(
                DiveTankOverviewHeroPresentation.collapseWaterBackdropOpacity(
                    collapseProgress: 0.5,
                    waterTopHalfFadeProgress: 0
                ) == 0.5
            )
        }

        @Test func diveTankOverviewHeroPresentation_displayedPsiConsumed_scalesWithRevealProgress() {
            #expect(
                DiveTankOverviewHeroPresentation.displayedPsiConsumed(
                    consumedPSI: 900,
                    revealProgress: 0.5
                ) == 450
            )
            #expect(
                DiveTankOverviewHeroPresentation.displayedPsiConsumed(
                    consumedPSI: 900,
                    revealProgress: 1.2
                ) == 900
            )
        }

        @Test func diveTankOverviewHeroPresentation_profileLineRevealProgress_usesMinimizedProgressOnlyOnMinimized() {
            #expect(
                DiveTankOverviewHeroPresentation.profileLineRevealProgress(
                    sheetDetent: .large,
                    minimizedRevealProgress: 0.25
                ) == 1
            )
            #expect(
                DiveTankOverviewHeroPresentation.profileLineRevealProgress(
                    sheetDetent: .minimized,
                    minimizedRevealProgress: 0.25
                ) == 0.25
            )
        }

        @Test func diveTankOverviewHeroPresentation_large_portraitProfileChart_inHeroBand() {
            #expect(
                DiveTankOverviewHeroPresentation.showsProfileChart(
                    for: .large,
                    depthSampleCount: 4,
                    isLandscape: false
                )
            )
            #expect(
                DiveTankOverviewHeroPresentation.showsInteractiveProfileChartChrome(
                    for: .large,
                    isLandscape: false,
                    depthSampleCount: 4
                )
            )
            #expect(
                !DiveTankOverviewHeroPresentation.showsMediaMarkersOnLandscapeProfile(isLandscape: false)
            )
            #expect(
                DiveTankOverviewHeroPresentation.showsMediaMarkersOnLandscapeProfile(isLandscape: true)
            )
            #expect(
                DiveTankOverviewHeroPresentation.showsTankHeroVisuals(
                    for: .large,
                    depthSampleCount: 4,
                    isLandscape: false
                )
            )
            let layoutSize = CGSize(width: 390, height: 844)
            let largeFraction = DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction
            let bottomMargin = layoutSize.height * largeFraction
            let frame = DiveTankOverviewHeroPresentation.minimizedProfileChartFrame(
                layoutSize: layoutSize,
                layoutHeight: layoutSize.height,
                topObstructionHeight: 100,
                bottomContentMargin: bottomMargin,
                isLandscape: false,
                detent: .large,
                chartSizingBottomContentMargin: bottomMargin
            )
            #expect(abs(frame.minX) < 0.5)
            #expect(abs(frame.width - layoutSize.width) < 0.5)
            #expect(abs(frame.minY - DiveTankOverviewHeroPresentation.largeDetentSheetSeamCornerBleed) < 0.5)
            #expect(
                abs(
                    frame.maxY
                        - (
                            layoutSize.height - bottomMargin
                                + DiveTankOverviewHeroPresentation.largeDetentSheetSeamCornerBleed
                        )
                ) < 0.5
            )
        }

        @Test func diveTankOverviewHeroPresentation_large_fullFill_andGasLabelOnly() {
            #expect(!DiveTankOverviewHeroPresentation.showsTankHero(for: .large))
            #expect(DiveTankOverviewHeroPresentation.showsTankHero(for: .minimized))
            #expect(DiveTankOverviewHeroPresentation.layoutDetent(for: .large) == .large)
            #expect(DiveTankOverviewHeroPresentation.layoutDetent(for: .minimized) == .minimized)
            #expect(!DiveTankOverviewHeroPresentation.showsGasMixLabel(for: .large))
            #expect(!DiveTankOverviewHeroPresentation.showsGasMixLabel(for: .minimized))
            #expect(
                DiveTankOverviewHeroPresentation.displayPressureFillFraction(
                    sheetDetent: .large,
                    animatedFillFraction: 0.25
                ) == 1
            )
            #expect(
                DiveTankOverviewHeroPresentation.displayPressureFillFraction(
                    sheetDetent: .minimized,
                    animatedFillFraction: 0.25
                ) == 0.25
            )
            #expect(DiveGasMixImport.tankHeroLabel(gasType: "Nitrox", oxygenMix: 32) == "Nitrox 32%")
            #expect(DiveGasMixImport.tankHeroLabel(gasType: nil, oxygenMix: 32) == "No gas specified")
            #expect(DiveGasMixImport.tankHeroLabel(gasType: "Air", oxygenMix: nil) == "No gas specified")
        }

        @Test func diveTankOverviewHeroPresentation_minimizedTopInset_includesDownshift() {
            let chromeTop: CGFloat = 100
            let padding = DiveTankOverviewHeroPresentation.topTrailingPadding(topObstructionHeight: chromeTop)
            #expect(
                padding.top
                    == chromeTop
                    + DiveTankOverviewHeroPresentation.minimizedTopInsetBelowChrome
                    + DiveTankOverviewHeroPresentation.minimizedAdditionalTopOffset
                    + DiveTankOverviewHeroPresentation.heroContentDownwardOffset
            )
        }

        @Test func diveTankOverviewHeroPresentation_layoutMetrics_animatesMediumToMinimized() {
            let layoutSize = CGSize(width: 390, height: 640)
            let layoutHeight: CGFloat = 844
            let topObstruction: CGFloat = 100
            let bottomMargin = layoutHeight * DiveActivityOverviewPanelMetrics.minimizedHeightFraction
            let cylinderHeight: CGFloat = 148

            let medium = DiveTankOverviewHeroPresentation.layoutMetrics(
                detent: .large,
                layoutSize: layoutSize,
                layoutHeight: layoutHeight,
                topObstructionHeight: topObstruction,
                bottomContentMargin: layoutHeight * DiveActivityOverviewPanelMetrics.mediumHeightFraction,
                cylinderHeight: cylinderHeight
            )
            let minimized = DiveTankOverviewHeroPresentation.layoutMetrics(
                detent: .minimized,
                layoutSize: layoutSize,
                layoutHeight: layoutHeight,
                topObstructionHeight: topObstruction,
                bottomContentMargin: bottomMargin,
                cylinderHeight: cylinderHeight
            )

            #expect(medium.scale == 1)
            #expect(minimized.scale == DiveTankOverviewHeroPresentation.minimizedScale)
            #expect(minimized.cylinderCenterX > medium.cylinderCenterX)
            #expect(minimized.cylinderCenterY < medium.cylinderCenterY)
            #expect(minimized.gasLabelCenterY > minimized.cylinderCenterY)
        }

        @Test func diveTankOverviewHeroPresentation_verticalCenterOffset_medium_shiftsFromPaddedMidpoint() {
            let layoutHeight: CGFloat = 800
            let topObstruction: CGFloat = 100
            let bottomMargin = layoutHeight * DiveActivityOverviewPanelMetrics.mediumHeightFraction
            let offset = DiveTankOverviewHeroPresentation.verticalCenterOffset(
                layoutHeight: layoutHeight,
                topObstructionHeight: topObstruction,
                bottomContentMargin: bottomMargin,
                sheetHeightFraction: DiveActivityOverviewPanelMetrics.mediumHeightFraction
            )
            let targetY = DiveLocationMapPresentation.targetPinScreenYFraction(
                layoutHeight: layoutHeight,
                topObstructionHeight: topObstruction,
                sheetHeightFraction: DiveActivityOverviewPanelMetrics.mediumHeightFraction
            ) * layoutHeight
            let defaultCenterY = (layoutHeight - bottomMargin) / 2
            #expect(abs(offset - (targetY - defaultCenterY)) < 0.01)
            #expect(offset > 0)
        }

        @Test func diveTankOverviewHeroPresentation_layoutMetrics_large_centerY_matchesTargetPinY() {
            let layoutSize = CGSize(width: 390, height: 844)
            let layoutHeight = layoutSize.height
            let topObstruction: CGFloat = 100
            let largeFraction = DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction
            let bottomMargin = layoutHeight * largeFraction
            let cylinderHeight: CGFloat = 148
            let metrics = DiveTankOverviewHeroPresentation.layoutMetrics(
                detent: .large,
                layoutSize: layoutSize,
                layoutHeight: layoutHeight,
                topObstructionHeight: topObstruction,
                bottomContentMargin: bottomMargin,
                cylinderHeight: cylinderHeight
            )
            let targetY = DiveLocationMapPresentation.targetPinScreenYFraction(
                layoutHeight: layoutHeight,
                topObstructionHeight: topObstruction,
                sheetHeightFraction: largeFraction
            ) * layoutHeight
            #expect(
                abs(
                    metrics.cylinderCenterY
                        - (targetY + DiveTankOverviewHeroPresentation.heroContentDownwardOffset)
                ) < 0.5
            )
        }

        @Test func diveActivityOverviewPanelMetrics_snappedHeightFraction_snapsToNearestDetent() {
            let large = DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction
            let minimized = DiveActivityOverviewPanelMetrics.minimizedHeightFraction
            #expect(
                DiveActivityOverviewPanelMetrics.snappedHeightFraction(
                    currentFraction: large,
                    predictedFraction: 0.18
                ) == minimized
            )
            #expect(
                DiveActivityOverviewPanelMetrics.snappedHeightFraction(
                    currentFraction: minimized,
                    predictedFraction: large
                ) == large
            )
            #expect(
                DiveActivityOverviewPanelMetrics.snappedHeightFraction(
                    currentFraction: minimized,
                    predictedFraction: 0.87
                ) == large
            )
        }

        @Test func diveActivityOverviewPanelMetrics_mediumHeightFraction_isHalfScreen() {
            #expect(DiveActivityOverviewPanelMetrics.mediumHeightFraction == 0.50)
        }

        @Test func diveActivityOverviewPanelMetrics_heightFractionWhileDragging_followsFinger() {
            let medium = DiveActivityOverviewPanelMetrics.mediumHeightFraction
            #expect(
                DiveActivityOverviewPanelMetrics.heightFractionWhileDragging(
                    restingFraction: medium,
                    dragTranslation: 0,
                    layoutHeight: 800
                ) == medium
            )
            #expect(
                DiveActivityOverviewPanelMetrics.heightFractionWhileDragging(
                    restingFraction: medium,
                    dragTranslation: 160,
                    layoutHeight: 800
                ) < medium
            )
        }

        @Test func diveActivityOverviewPanelMetrics_clampedHeightFraction_limitsRange() {
            let large = DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction
            #expect(DiveActivityOverviewPanelMetrics.clampedHeightFraction(0.05) == 0.20)
            #expect(DiveActivityOverviewPanelMetrics.clampedHeightFraction(0.99) == large)
        }

        @Test func diveActivityOverviewPanelMetrics_shouldExpandFromScroll_atMinimized() {
            #expect(
                DiveActivityOverviewPanelMetrics.shouldExpandFromScroll(
                    restingFraction: DiveActivityOverviewPanelMetrics.minimizedHeightFraction,
                    scrollOffsetY: 40
                )
            )
            #expect(
                !DiveActivityOverviewPanelMetrics.shouldExpandFromScroll(
                    restingFraction: DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction,
                    scrollOffsetY: 40
                )
            )
        }

        @Test func diveActivityOverviewPanelMetrics_snappedHeightFractionAfterDrag_twoDetentsOnly() {
            let minimized = DiveActivityOverviewPanelMetrics.minimizedHeightFraction
            let large = DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction

            #expect(
                DiveActivityOverviewPanelMetrics.snappedHeightFractionAfterDrag(
                    currentFraction: minimized,
                    predictedFraction: large,
                    verticalTranslation: -80
                ) == large
            )
            #expect(
                DiveActivityOverviewPanelMetrics.snappedHeightFractionAfterDrag(
                    currentFraction: large,
                    predictedFraction: minimized,
                    verticalTranslation: 80
                ) == minimized
            )
        }

        @Test func diveActivityOverviewPanelMetrics_shouldCollapseFromScroll_whenExpanded() {
            #expect(
                DiveActivityOverviewPanelMetrics.shouldCollapseFromScroll(
                    restingFraction: DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction,
                    scrollOffsetY: -30
                )
            )
            #expect(
                !DiveActivityOverviewPanelMetrics.shouldCollapseFromScroll(
                    restingFraction: DiveActivityOverviewPanelMetrics.minimizedHeightFraction,
                    scrollOffsetY: -30
                )
            )
        }

        @Test func diveActivityOverviewPanelMetrics_mapPanelVisibility_followsRestingDetent() {
            let minimized = DiveActivityOverviewPanelMetrics.minimizedHeightFraction
            let large = DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction

            #expect(
                !DiveActivityOverviewPanelMetrics.mapPanelShowsStatsBox(
                    restingDetent: .minimized,
                    heightFraction: minimized
                )
            )
            #expect(
                DiveActivityOverviewPanelMetrics.mapPanelShowsStatsBox(
                    restingDetent: .large,
                    heightFraction: large
                )
            )
            #expect(
                !DiveActivityOverviewPanelMetrics.mapPanelShowsDetails(
                    restingDetent: .minimized,
                    heightFraction: minimized
                )
            )
            #expect(
                DiveActivityOverviewPanelMetrics.mapPanelShowsDetails(
                    restingDetent: .large,
                    heightFraction: large
                )
            )
        }

        @Test func diveActivityOverviewPanelMetrics_mapRevealProgress_tracksDetentBands() {
            let minimized = DiveActivityOverviewPanelMetrics.minimizedHeightFraction
            let large = DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction

            #expect(
                DiveActivityOverviewPanelMetrics.mapStatsRevealProgress(heightFraction: minimized) == 0
            )
            #expect(
                DiveActivityOverviewPanelMetrics.mapStatsRevealProgress(heightFraction: large) == 1
            )
            #expect(
                DiveActivityOverviewPanelMetrics.mapDetailsRevealProgress(heightFraction: minimized) == 0
            )
            #expect(
                DiveActivityOverviewPanelMetrics.mapDetailsRevealProgress(heightFraction: large) == 1
            )
        }

        @Test func diveActivityOverviewPanelMetrics_nextDetent_stepsThroughAllHeights() {
            let minimized = DiveActivityOverviewPanelMetrics.minimizedHeightFraction
            let large = DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction

            #expect(DiveActivityOverviewPanelMetrics.nextTallerDetent(after: minimized) == large)
            #expect(DiveActivityOverviewPanelMetrics.nextTallerDetent(after: large) == nil)

            #expect(DiveActivityOverviewPanelMetrics.nextShorterDetent(after: large) == minimized)
            #expect(DiveActivityOverviewPanelMetrics.nextShorterDetent(after: minimized) == nil)
        }

        @Test func diveActivityOverviewDetent_nearest_toHeightFraction_mapsDetents() {
            let large = DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction
            #expect(
                DiveActivityOverviewDetent.nearest(
                    toHeightFraction: DiveActivityOverviewPanelMetrics.minimizedHeightFraction
                ) == .minimized
            )
            #expect(
                DiveActivityOverviewDetent.nearest(
                    toHeightFraction: large
                ) == .large
            )
            let midpoint = (DiveActivityOverviewPanelMetrics.minimizedHeightFraction + large) / 2
            #expect(DiveActivityOverviewDetent.nearest(toHeightFraction: midpoint) == .large)
        }

        @Test func diveActivityOverviewDetent_roundTripsPresentationDetent() {
            for detent in DiveActivityOverviewDetent.allCases {
                let presentation = detent.presentationDetent
                #expect(DiveActivityOverviewDetent(presentationDetent: presentation) == detent)
                #expect(detent.nextTaller() != nil || detent == .large)
                #expect(detent.nextShorter() != nil || detent == .minimized)
            }
            #expect(DiveActivityOverviewDetent.large.nextTaller() == nil)
            #expect(DiveActivityOverviewDetent.minimized.nextShorter() == nil)
            #expect(DiveActivityOverviewDetent.minimized.nextTaller() == .large)
        }

        @Test func diveActivityOverviewDetent_bottomObstructionHeight_usesFraction() {
            let layoutHeight: CGFloat = 800
            let bottomSafeInset: CGFloat = 34
            let expected = DiveActivityOverviewDetent.sheetHeight(
                for: .large,
                layoutHeight: layoutHeight,
                bottomSafeInset: bottomSafeInset
            )
            let height = DiveActivityOverviewDetent.bottomObstructionHeight(
                layoutHeight: layoutHeight,
                detent: .large,
                bottomSafeInset: bottomSafeInset
            )
            #expect(abs(height - expected) < 0.02)
        }

        @Test func diveActivityOverviewDetent_sheetHeight_forHeightFraction_isContinuous() {
            let layoutHeight: CGFloat = 800
            let inset: CGFloat = 34
            let fraction: CGFloat = 0.62
            #expect(
                DiveActivityOverviewDetent.sheetHeight(
                    forHeightFraction: fraction,
                    layoutHeight: layoutHeight,
                    bottomSafeInset: inset
                ) == layoutHeight * fraction + inset
            )
        }

        @Test func diveActivityOverviewDetent_sheetHeight_includesBottomSafeInset() {
            let sheet = DiveActivityOverviewDetent.sheetHeight(
                for: .minimized,
                layoutHeight: 844,
                bottomSafeInset: 34
            )
            #expect(abs(sheet - (844 * 0.20 + 34)) < 0.01)
        }

        @Test func diveActivityOverviewPanelMetrics_accessibilityDetentDescription_labelsRestingHeights() {
            #expect(
                DiveActivityOverviewPanelMetrics.accessibilityDetentDescription(
                    for: DiveActivityOverviewPanelMetrics.minimizedHeightFraction
                ) == "Minimized"
            )
            #expect(
                DiveActivityOverviewPanelMetrics.accessibilityDetentDescription(
                    for: DiveActivityOverviewPanelMetrics.mediumHeightFraction
                ) == "Expanded"
            )
            #expect(
                DiveActivityOverviewPanelMetrics.accessibilityDetentDescription(
                    for: DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction
                ) == "Expanded"
            )
        }

        @Test func diveActivityOverviewPresentation_siteHeaderTitle_prefersTrimmedSiteName() {
            #expect(
                DiveActivityOverviewPresentation.siteHeaderTitle(siteName: "Salt Pier", fallback: "Dive") == "Salt Pier"
            )
            #expect(
                DiveActivityOverviewPresentation.siteHeaderTitle(siteName: "  ", fallback: "Garmin MK3") == "Garmin MK3"
            )
            #expect(
                DiveActivityOverviewPresentation.siteHeaderTitle(siteName: nil, fallback: "Dive") == "Dive"
            )
            #expect(
                DiveActivityOverviewPresentation.siteHeaderTitle(
                    siteName: nil,
                    fallback: DiveActivityOverviewPresentation.newDiveActivitySiteTitle
                ) == "New Dive Activity"
            )
        }

        @Test func snorkelActivityOverviewPresentation_siteHeaderTitle_usesNewSnorkelActivityWhenUntitled() {
            #expect(
                SnorkelActivityOverviewPresentation.siteHeaderTitle(siteName: "Hanauma Bay") == "Hanauma Bay"
            )
            #expect(
                SnorkelActivityOverviewPresentation.siteHeaderTitle(siteName: "  ")
                    == SnorkelActivityOverviewPresentation.newSnorkelActivitySiteTitle
            )
            #expect(
                SnorkelActivityOverviewPresentation.siteHeaderTitle(siteName: nil)
                    == "New Snorkel Activity"
            )
        }

        @Test func snorkelActivityOverviewPresentation_mapStats_swimDistanceUsesMetersOrYards() {
            let imperial = SnorkelActivityOverviewPresentation.mapOverviewStatsLayout(
                durationMinutes: 30,
                swimDistanceMeters: 100,
                maxDepthMeters: 2,
                avgTemperatureCelsius: 26,
                displayUnits: .imperial
            )
            #expect(imperial.leadingStats[1].valueNumber == "109")
            #expect(imperial.leadingStats[1].valueUnit == "yd")
            #expect(imperial.leadingStats[1].icon == .waterWaves)
            let metric = SnorkelActivityOverviewPresentation.mapOverviewStatsLayout(
                durationMinutes: 30,
                swimDistanceMeters: 210,
                maxDepthMeters: 2,
                avgTemperatureCelsius: 26,
                displayUnits: .metric
            )
            #expect(metric.leadingStats[1].valueNumber == "210")
            #expect(metric.leadingStats[1].valueUnit == "m")
            #expect(metric.leadingStats[1].icon == .waterWaves)
        }

        @Test func diveActivityOverviewPresentation_siteTitleLinksToCatalogOverview_requiresLinkedSiteID() {
            let siteID = UUID()
            #expect(
                DiveActivityOverviewPresentation.siteTitleLinksToCatalogOverview(linkedCatalogSiteID: siteID)
            )
            #expect(
                !DiveActivityOverviewPresentation.siteTitleLinksToCatalogOverview(linkedCatalogSiteID: nil)
            )
        }

        @Test func diveActivityOverviewPresentation_mapHeaderCopy() {
            #expect(DiveActivityOverviewPresentation.activityIdentitySymbolPointSize == 24)
            #expect(
                DiveActivityOverviewPresentation.diveNumberChipLabel(
                    diveNumber: 12,
                    diveNumberExplicitlyNone: false
                ) == "#12"
            )
            #expect(
                DiveActivityOverviewPresentation.diveNumberChipLabel(
                    diveNumber: nil,
                    diveNumberExplicitlyNone: true
                ) == nil
            )
            #expect(
                DiveActivityOverviewPresentation.regionCountryLine(
                    region: "Bonaire",
                    country: "Caribbean Netherlands"
                ) == "🇧🇶 Bonaire, Caribbean Netherlands"
            )
            #expect(
                DiveActivityOverviewPresentation.regionCountryLine(
                    locationName: "Negril, Jamaica"
                ) == "🇯🇲 Negril, Jamaica"
            )
            let line = DiveActivityOverviewPresentation.startDateDashTimeLine(
                startTime: Date(timeIntervalSince1970: 0),
                timeZoneOffsetSeconds: 0
            )
            #expect(line.contains(" - "))
            let parts = line.split(separator: " - ", maxSplits: 1).map(String.init)
            #expect(parts.count == 2)
            #expect(!parts[1].contains(parts[0]))
        }

        @Test func diveActivityOverviewPresentation_mapOverviewStatsLayout() {
            let layout = DiveActivityOverviewPresentation.mapOverviewStatsLayout(
                durationMinutes: 42,
                maxDepthMeters: 18.3,
                averageDepthMeters: 12,
                surfaceIntervalSeconds: 3600,
                displayUnits: .imperial
            )
            #expect(layout.leadingStats.count == 2)
            #expect(layout.leadingStats[0].titleLine1 == "Dive")
            #expect(layout.leadingStats[0].titleLine2 == "Duration")
            #expect(layout.leadingStats[0].valueNumber == "42")
            #expect(layout.leadingStats[0].valueUnit == "min")
            #expect(layout.leadingStats[0].icon == .clock)
            #expect(layout.leadingStats[1].titleLine1 == "Surface")
            #expect(layout.leadingStats[1].titleLine2 == "Interval")
            #expect(layout.leadingStats[1].valueNumber == "60")
            #expect(layout.leadingStats[1].valueUnit == "min")
            #expect(layout.leadingStats[1].icon == .palmTree)
            let longInterval = DiveActivityOverviewPresentation.formattedMapSurfaceIntervalParts(5_400)
            #expect(longInterval.number == "1 Hr")
            #expect(longInterval.unit == "30 Mins")
            let justOverHour = DiveActivityOverviewPresentation.formattedMapSurfaceIntervalParts(3_660)
            #expect(justOverHour.number == "1 Hr")
            #expect(justOverHour.unit == "1 Min")
            let twoHours = DiveActivityOverviewPresentation.formattedMapSurfaceIntervalParts(7_200)
            #expect(twoHours.number == "2 Hrs")
            #expect(twoHours.unit == "0 Mins")
            #expect(DiveActivityOverviewPresentation.mapSurfaceIntervalHourUnit(1) == "Hr")
            #expect(DiveActivityOverviewPresentation.mapSurfaceIntervalHourUnit(2) == "Hrs")
            #expect(DiveActivityOverviewPresentation.mapSurfaceIntervalMinuteUnit(1) == "Min")
            #expect(DiveActivityOverviewPresentation.mapSurfaceIntervalMinuteUnit(30) == "Mins")
            #expect(layout.depthStats[0].titleLine1 == "Avg")
            #expect(layout.depthStats[1].titleLine1 == "Max")
            #expect(layout.depthStats[1].valueNumber == "60.0")
            #expect(layout.depthStats[1].valueUnit == "ft")
            #expect(layout.depthStats[0].valueNumber == "39.4")
            #expect(abs(layout.depthGauge.maxFillFraction - (18.3 / 40)) < 0.001)
            #expect(abs(layout.depthGauge.avgLineFraction - (12 / 40)) < 0.001)
            #expect(layout.depthGauge.showsAverageLine)
            #expect(
                DiveActivityOverviewPresentation.splitDisplayValue("60.0 ft").number == "60.0"
            )
            #expect(
                DiveActivityOverviewPresentation.splitDisplayValue("60.0 ft").unit == "ft"
            )
            #expect(
                DiveActivityOverviewPresentation.depthGaugeFillFraction(depthMeters: 80, referenceMaxMeters: 40) == 1
            )
            #expect(
                DiveActivityOverviewPresentation.formattedDurationSeconds(nil) == "—"
            )
        }

        @Test func diveActivityOverviewPanelMetrics_mapMinimizedScrollContentMinHeight() {
            let height = DiveActivityOverviewPanelMetrics.mapMinimizedPanelScrollContentMinHeight(
                layoutHeight: 844,
                bottomSafeInset: 34
            )
            #expect(height > 0)
        }

        @Test func diveActivityOverviewUIStateStore_roundTripsSnapshotByActivityID() {
            DiveActivityOverviewUIStateStore.resetForTesting()
            defer { DiveActivityOverviewUIStateStore.resetForTesting() }

            let activityID = UUID()
            let snapshot = DiveActivityOverviewUISnapshot(
                selectedActivityTab: .tank,
                overviewSheetDetent: .large,
                isOverviewPanelPresented: true,
                selectedDiveMediaPhotoID: UUID(),
                overviewPanelScrollOffsetY: 120
            )
            DiveActivityOverviewUIStateStore.save(snapshot, for: activityID)
            #expect(DiveActivityOverviewUIStateStore.snapshot(for: activityID) == snapshot)
            DiveActivityOverviewUIStateStore.remove(activityID: activityID)
            #expect(DiveActivityOverviewUIStateStore.snapshot(for: activityID) == nil)
        }

        @Test func diveActivityOverviewUIStateStore_discardSession_blocksPersistUntilSessionActive() {
            DiveActivityOverviewUIStateStore.resetForTesting()
            defer { DiveActivityOverviewUIStateStore.resetForTesting() }

            let activityID = UUID()
            let mediaSnapshot = DiveActivityOverviewUISnapshot(
                selectedActivityTab: .camera,
                overviewSheetDetent: .large,
                isOverviewPanelPresented: true,
                selectedDiveMediaPhotoID: UUID(),
                overviewPanelScrollOffsetY: 80
            )
            DiveActivityOverviewUIStateStore.save(mediaSnapshot, for: activityID)
            DiveActivityOverviewUIStateStore.discardDiveSession(activityID: activityID)
            #expect(DiveActivityOverviewUIStateStore.snapshot(for: activityID) == nil)

            // Pop-to-logbook race: `onDisappear` must not re-save after discard.
            DiveActivityOverviewUIStateStore.save(mediaSnapshot, for: activityID)
            #expect(DiveActivityOverviewUIStateStore.snapshot(for: activityID) == nil)

            DiveActivityOverviewUIStateStore.noteDiveSessionActive(activityID: activityID)
            let mapSnapshot = DiveActivityOverviewUISnapshot(
                selectedActivityTab: .map,
                overviewSheetDetent: .large,
                isOverviewPanelPresented: true,
                selectedDiveMediaPhotoID: nil,
                overviewPanelScrollOffsetY: 0
            )
            DiveActivityOverviewUIStateStore.save(mapSnapshot, for: activityID)
            #expect(DiveActivityOverviewUIStateStore.snapshot(for: activityID) == mapSnapshot)
        }

        @Test func diveActivityOverviewUIStatePresentation_discardWhenActivityLeavesLogbookPath() {
            DiveActivityOverviewUIStateStore.resetForTesting()
            defer { DiveActivityOverviewUIStateStore.resetForTesting() }

            let diveID = UUID()
            let snorkelID = UUID()
            DiveActivityOverviewUIStateStore.save(
                DiveActivityOverviewUISnapshot(
                    selectedActivityTab: .camera,
                    overviewSheetDetent: .large,
                    isOverviewPanelPresented: true,
                    selectedDiveMediaPhotoID: nil,
                    overviewPanelScrollOffsetY: 40
                ),
                for: diveID
            )
            DiveActivityOverviewUIStateStore.saveSnorkel(
                SnorkelActivityOverviewUISnapshot(
                    selectedActivityTab: .camera,
                    overviewSheetDetent: .large,
                    isOverviewPanelPresented: true,
                    selectedMediaPhotoID: nil,
                    overviewPanelScrollOffsetY: 24
                ),
                for: snorkelID
            )

            let previous: [LogbookRoute] = [
                .diveDetail(diveID),
                .snorkelDetail(snorkelID),
                .diveSite(UUID()),
            ]
            let current: [LogbookRoute] = [.diveSite(UUID())]
            DiveActivityOverviewUIStatePresentation.discardSessionsLeavingStack(
                previousDiveIDs: DiveActivityOverviewUIStatePresentation.diveActivityIDs(
                    inLogbookPath: previous
                ),
                currentDiveIDs: DiveActivityOverviewUIStatePresentation.diveActivityIDs(
                    inLogbookPath: current
                ),
                previousSnorkelIDs: DiveActivityOverviewUIStatePresentation.snorkelActivityIDs(
                    inLogbookPath: previous
                ),
                currentSnorkelIDs: DiveActivityOverviewUIStatePresentation.snorkelActivityIDs(
                    inLogbookPath: current
                )
            )
            #expect(DiveActivityOverviewUIStateStore.snapshot(for: diveID) == nil)
            #expect(DiveActivityOverviewUIStateStore.snorkelSnapshot(for: snorkelID) == nil)
        }

        @Test func diveActivityOverviewUIStatePresentation_keepsSnapshotWhenNestedSiteStaysOnPath() {
            DiveActivityOverviewUIStateStore.resetForTesting()
            defer { DiveActivityOverviewUIStateStore.resetForTesting() }

            let diveID = UUID()
            let snapshot = DiveActivityOverviewUISnapshot(
                selectedActivityTab: .camera,
                overviewSheetDetent: .large,
                isOverviewPanelPresented: true,
                selectedDiveMediaPhotoID: nil,
                overviewPanelScrollOffsetY: 60
            )
            DiveActivityOverviewUIStateStore.save(snapshot, for: diveID)

            let previous: [LogbookRoute] = [.diveDetail(diveID)]
            let current: [LogbookRoute] = [.diveDetail(diveID), .diveSite(UUID())]
            DiveActivityOverviewUIStatePresentation.discardSessionsLeavingStack(
                previousDiveIDs: DiveActivityOverviewUIStatePresentation.diveActivityIDs(
                    inLogbookPath: previous
                ),
                currentDiveIDs: DiveActivityOverviewUIStatePresentation.diveActivityIDs(
                    inLogbookPath: current
                )
            )
            #expect(DiveActivityOverviewUIStateStore.snapshot(for: diveID) == snapshot)
            #expect(
                DiveActivityOverviewUIStatePresentation.activityIDsLeavingStack(
                    previous: [diveID],
                    current: [diveID]
                ).isEmpty
            )
        }

        @Test func diveActivityOverviewScrollRestoration_effectiveOffsetUsesFallbackWhenBindingCleared() {
            #expect(
                DiveActivityOverviewScrollRestoration.effectiveScrollOffsetForRestoration(
                    persisted: 0,
                    fallback: 180
                ) == 180
            )
            #expect(
                DiveActivityOverviewScrollRestoration.effectiveScrollOffsetForRestoration(
                    persisted: 12,
                    fallback: 8
                ) == 12
            )
            #expect(
                DiveActivityOverviewScrollRestoration.effectiveScrollOffsetForRestoration(
                    persisted: 0,
                    fallback: 2
                ) == 0
            )
        }

        @Test func diveActivityOverviewScrollRestoration_ignoresSuddenResetToTopWhileDeepScrolled() {
            #expect(
                DiveActivityOverviewScrollRestoration.shouldIgnoreSuddenScrollResetToTop(
                    proposedOffset: 0,
                    persistedOffset: 200,
                    lastReportedOffset: 198
                )
            )
            #expect(
                !DiveActivityOverviewScrollRestoration.shouldIgnoreSuddenScrollResetToTop(
                    proposedOffset: 0,
                    persistedOffset: 200,
                    lastReportedOffset: 4
                )
            )
        }

        @Test func diveActivityOverviewScrollRestoration_insetOnlyWhenReturningFromNestedNavigation() {
            #expect(
                !DiveActivityOverviewScrollRestoration.shouldApplyScrollRestorationInset(
                    fallback: 0,
                    persisted: 120
                )
            )
            #expect(
                DiveActivityOverviewScrollRestoration.shouldApplyScrollRestorationInset(
                    fallback: 180,
                    persisted: 0
                )
            )
            #expect(
                !DiveActivityOverviewScrollRestoration.shouldApplyScrollRestorationInset(
                    fallback: 180,
                    persisted: 220
                )
            )
            #expect(
                !DiveActivityOverviewScrollRestoration.shouldApplyScrollRestorationInset(
                    fallback: 120,
                    persisted: 120
                )
            )
            #expect(
                !DiveActivityOverviewScrollRestoration.shouldApplyScrollRestorationInset(
                    fallback: 2,
                    persisted: 200
                )
            )
        }

        @Test @MainActor func snorkelActivityOverviewUIStateStore_roundTripsSnapshotByActivityID() {
            DiveActivityOverviewUIStateStore.resetForTesting()
            defer { DiveActivityOverviewUIStateStore.resetForTesting() }

            let activityID = UUID()
            let snapshot = SnorkelActivityOverviewUISnapshot(
                selectedActivityTab: .map,
                overviewSheetDetent: .large,
                isOverviewPanelPresented: true,
                selectedMediaPhotoID: nil,
                overviewPanelScrollOffsetY: 96
            )
            DiveActivityOverviewUIStateStore.saveSnorkel(snapshot, for: activityID)
            #expect(DiveActivityOverviewUIStateStore.snorkelSnapshot(for: activityID) == snapshot)
            DiveActivityOverviewUIStateStore.removeSnorkel(activityID: activityID)
            #expect(DiveActivityOverviewUIStateStore.snorkelSnapshot(for: activityID) == nil)
        }

        @Test @MainActor func snorkelActivityOverviewUIStateStore_discardSession_blocksPersistUntilSessionActive() {
            DiveActivityOverviewUIStateStore.resetForTesting()
            defer { DiveActivityOverviewUIStateStore.resetForTesting() }

            let activityID = UUID()
            let mediaSnapshot = SnorkelActivityOverviewUISnapshot(
                selectedActivityTab: .camera,
                overviewSheetDetent: .large,
                isOverviewPanelPresented: true,
                selectedMediaPhotoID: UUID(),
                overviewPanelScrollOffsetY: 48
            )
            DiveActivityOverviewUIStateStore.saveSnorkel(mediaSnapshot, for: activityID)
            DiveActivityOverviewUIStateStore.discardSnorkelSession(activityID: activityID)
            #expect(DiveActivityOverviewUIStateStore.snorkelSnapshot(for: activityID) == nil)
            DiveActivityOverviewUIStateStore.saveSnorkel(mediaSnapshot, for: activityID)
            #expect(DiveActivityOverviewUIStateStore.snorkelSnapshot(for: activityID) == nil)

            DiveActivityOverviewUIStateStore.noteSnorkelSessionActive(activityID: activityID)
            DiveActivityOverviewUIStateStore.saveSnorkel(mediaSnapshot, for: activityID)
            #expect(DiveActivityOverviewUIStateStore.snorkelSnapshot(for: activityID) == mediaSnapshot)
        }

        @Test func diveActivityFieldValueParsing_diverWeight_roundTripImperialAndMetric() {
            #expect(
                DiveActivityFieldValueParsing.parseDiverWeightKilograms("12.0", displayUnits: .imperial)
                    == 12.0 / 2.2046226218
            )
            #expect(
                DiveActivityFieldValueParsing.formatDiverWeightInput(kilograms: 5.0, displayUnits: .metric) == "5.0"
            )
            #expect(
                DiveQuantityFormatting.diverWeight(kilograms: 5.0, system: .metric) == "5.0 kg"
            )
            #expect(
                DiveQuantityFormatting.diverWeight(kilograms: nil, system: .imperial) == "—"
            )
        }

            @Test func diveTankMinimizedGasSummary_psiConsumed_subtractsEndFromStart() {
                #expect(DiveTankMinimizedGasSummary.psiConsumedPSI(startPSI: 3000, endPSI: 1200) == 1800)
                #expect(DiveTankMinimizedGasSummary.psiConsumedPSI(startPSI: 3000, endPSI: nil) == nil)
                #expect(DiveTankMinimizedGasSummary.psiConsumedPSI(startPSI: nil, endPSI: 500) == nil)
                #expect(DiveTankMinimizedGasSummary.psiConsumedPSI(startPSI: 1000, endPSI: 1500) == 0)
            }
            @Test func diveTankMinimizedGasSummary_sacRateLine_formatsValue() {
                #expect(DiveTankMinimizedGasSummary.usedLine(formattedConsumed: "1,800 psi") == "1,800 psi used.")
                #expect(DiveTankMinimizedGasSummary.sacRateLine(formattedRate: "24.3 psi/min") == "SAC: 24.3 psi/min")
                #expect(DiveTankMinimizedGasSummary.rmvRateLine(formattedRate: "18.4 L/min") == "RMV: 18.4 L/min")
                #expect(DiveTankMinimizedGasSummary.sacRateLabel == "SAC:")
                #expect(DiveTankMinimizedGasSummary.rmvRateLabel == "RMV:")
            }
            @Test func diveTankMinimizedGasSummary_consumedTally_countsUpFromZero() {
                let start = DiveTankMinimizedGasSummary.minimizedGasConsumedTally(
                    totalConsumedPSI: 1800,
                    revealProgress: 0,
                    system: .imperial
                )
                #expect(start.numericAnimationValue == 0)
                #expect(start.pressureValueText == "0")
                #expect(start.unitSuffix == " psi")

                let mid = DiveTankMinimizedGasSummary.minimizedGasConsumedTally(
                    totalConsumedPSI: 1800,
                    revealProgress: 0.5,
                    system: .imperial
                )
                #expect(mid.numericAnimationValue == 900)

                let end = DiveTankMinimizedGasSummary.minimizedGasConsumedTally(
                    totalConsumedPSI: 1800,
                    revealProgress: 1,
                    system: .imperial
                )
                #expect(end.numericAnimationValue == 1800)
                #expect(end.pressureValueText == "1,800")
            }
            @Test func diveActivityManualCreation_makeBlank_usesManualSourceAndNoSourceDiveId() {
                let dive = DiveActivityManualCreation.makeBlankActivity(
                    defaultTank: DefaultTankSize.al80.specification
                )
                #expect(dive.source == .manual)
                #expect(dive.sourceDiveId == nil)
                #expect(dive.durationMinutes == 0)
                #expect(dive.maxDepthMeters == 0)
                #expect(dive.profilePoints.isEmpty)
                #expect(dive.tankMaterial == "aluminum")
            }
            @Test func diveActivityManualCreation_sheetAccessibilityIdentifiers() {
                #expect(DiveActivityManualCreation.cancelAccessibilityIdentifier == "ManualDiveEntry.Cancel")
                #expect(DiveActivityManualCreation.doneAccessibilityIdentifier == "ManualDiveEntry.Done")
            }
            @Test func diveActivityManualCreation_makeBlank_appliesStartTimeAndSiteName() {
                let when = Date(timeIntervalSince1970: 1_700_000_000)
                let dive = DiveActivityManualCreation.makeBlankActivity(
                    startTime: when,
                    siteName: "Salt Pier"
                )
                #expect(dive.startTime == when)
                #expect(dive.siteName == "Salt Pier")
            }
            @Test @MainActor
            func diveActivityManualCreation_persist_linksExistingCatalogSite() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)
                let profile = UserProfile(appleUserIdentifier: "manual-existing-site", displayName: "Diver")
                context.insert(profile)

                let catalogSite = DiveSite(siteName: "Salt Pier", country: "Bonaire", waterType: .saltwater)
                context.insert(catalogSite)
                try context.save()

                let dive = DiveActivityManualCreation.makeBlankActivity()
                let outcome = DiveActivityManualCreation.persist(
                    dive,
                    siteSelection: .existingSite(id: catalogSite.id),
                    modelContext: context,
                    owner: profile
                )
                #expect(outcome.primaryInsertedDiveId == dive.id)
                #expect(dive.diveSiteID == catalogSite.id)
                #expect(dive.diveSiteID == catalogSite.id)
                #expect(dive.resolvedDiveWaterType == .saltwater)
            }
            @Test @MainActor
            func diveActivityManualCreation_persist_createsAndLinksNewCatalogSite() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)
                let profile = UserProfile(appleUserIdentifier: "manual-new-site", displayName: "Diver")
                context.insert(profile)
                try context.save()

                let draft = DiveSiteFormDraft(
                    siteName: "Cenote Dos Ojos",
                    country: "Mexico",
                    region: "Quintana Roo",
                    bodyOfWater: "",
                    latitudeText: "20.32480",
                    longitudeText: "-87.39320",
                    waterType: .freshwater
                )
                let dive = DiveActivityManualCreation.makeBlankActivity()
                let outcome = DiveActivityManualCreation.persist(
                    dive,
                    siteSelection: .newSite(draft),
                    modelContext: context,
                    owner: profile
                )
                #expect(outcome.primaryInsertedDiveId == dive.id)
                #expect(dive.resolvedLinkedSite?.siteName == "Cenote Dos Ojos")
                #expect(dive.resolvedLinkedSite?.resolvedWaterType == .freshwater)
                #expect(try context.fetchCount(FetchDescriptor<DiveSite>()) == 0)
                #expect(try context.fetchCount(FetchDescriptor<UserDiveSite>()) == 1)
            }
            @Test @MainActor
            func diveActivityManualCreation_persist_insertsOwnedDive() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)
                let profile = UserProfile(appleUserIdentifier: "manual-create-test", displayName: "Diver")
                context.insert(profile)
                try context.save()

                let dive = DiveActivityManualCreation.makeBlankActivity()
                let outcome = DiveActivityManualCreation.persist(dive, modelContext: context, owner: profile)
                #expect(outcome.primaryInsertedDiveId == dive.id)
                #expect(outcome.userMessage.hasPrefix(DiveActivityManualCreation.successMessagePrefix))

                let stored = try DiveActivityOwnership.activities(forOwnerProfileID: profile.id, modelContext: context)
                #expect(stored.count == 1)
                #expect(stored.first?.source == .manual)
                #expect(stored.first?.sourceDiveId == nil)
                #expect(stored.first?.ownerProfileID == profile.id)
            }
            @Test func diveActivityEditableCatalog_sourceAndImportFieldsAreNotEditable() {
                #expect(!DiveActivityEditableCatalog.isEditable(.source))
                #expect(!DiveActivityEditableCatalog.isEditable(.sourceDiveId))
                #expect(!DiveActivityEditableCatalog.isEditable(.rawImportVersion))
                let activity = DiveActivity(
                    source: .garminMK3,
                    sourceDiveId: "fit-123",
                    startTime: Date(),
                    durationMinutes: 40,
                    maxDepthMeters: 18,
                    rawImportVersion: "FIT 1.0"
                )
                let sourceSection = DiveActivityEditableCatalog.sections(for: .tank, detent: .large)
                    .first { $0.id == "source" }!
                #expect(DiveActivityEditableCatalog.editableFields(in: sourceSection, for: activity).isEmpty)
                #expect(DiveActivityEditableCatalog.headerAction(for: sourceSection, activity: activity) == .none)
            }
            @Test func diveActivityEditableCatalog_sacAndRmvAreNotEditable() {
                #expect(!DiveActivityEditableCatalog.isEditable(.avgSAC))
                #expect(!DiveActivityEditableCatalog.isEditable(.avgRMV))
                let activity = DiveActivity(
                    source: .manual,
                    startTime: Date(),
                    durationMinutes: 40,
                    maxDepthMeters: 18,
                    avgSAC: 20,
                    avgRMV: 16
                )
                let consumption = DiveActivityEditableCatalog.sections(for: .tank, detent: .large)
                    .first { $0.id == "consumption" }!
                #expect(DiveActivityEditableCatalog.editableFields(in: consumption, for: activity).isEmpty)
                #expect(DiveActivityEditableCatalog.headerAction(for: consumption, activity: activity) == .none)
            }
            @Test func diveActivityEditableCatalog_sectionHeaderActions() {
                let manualDive = DiveActivity(
                    source: .manual,
                    startTime: Date(),
                    durationMinutes: 40,
                    maxDepthMeters: 18
                )
                let mapSections = DiveActivityEditableCatalog.sections(for: .map, detent: .large)
                let diveConditions = mapSections.first { $0.id == "diveConditions" }!
                let buddies = mapSections.first { $0.id == "buddies" }!
                let equipment = DiveActivityEditableCatalog.sections(for: .tank, detent: .large)
                    .first { $0.id == "equipment" }!

                #expect(DiveActivityEditableCatalog.headerAction(for: diveConditions, activity: manualDive) == .editForm)
                #expect(DiveActivityEditableCatalog.headerAction(for: buddies, activity: manualDive) == .add)
                let marineLife = mapSections.first { $0.id == "marineLife" }!
                #expect(DiveActivityEditableCatalog.headerAction(for: marineLife, activity: manualDive) == .add)
                #expect(
                    mapSections.map(\.id) == ["diveConditions", "buddies", "marineLife", "notes"]
                )
                #expect(DiveActivityEditableCatalog.headerAction(for: equipment, activity: manualDive) == .manageEquipment)

                #expect(DiveActivityEditableCatalog.isEditable(.durationMinutes, for: manualDive))
                #expect(!DiveActivityEditableCatalog.isEditable(.durationMinutes, for: DiveActivity(
                    source: .garminMK3,
                    startTime: Date(),
                    durationMinutes: 40,
                    maxDepthMeters: 18
                )))
                #expect(DiveActivityEditableCatalog.isEditable(.startTime, for: manualDive))
                #expect(DiveActivityEditableCatalog.isEditable(.diveNumber, for: manualDive))
            }
            @Test func diveActivityEditableCatalog_overviewPanelHidesDiveSummaryAndTankDiagnostics() {
                let mapSections = DiveActivityEditableCatalog.sections(for: .map, detent: .large)
                #expect(!mapSections.contains { $0.id == "dive" })

                let tankMedium = DiveActivityEditableCatalog.sections(for: .tank, detent: .large)
                let tankLarge = DiveActivityEditableCatalog.sections(for: .tank, detent: .large)
                #expect(!tankMedium.contains { $0.id == "profileGas" })
                #expect(!tankLarge.contains { $0.id == "profileGas" })
                #expect(!tankLarge.contains { $0.id == "record" })
            }
            @Test func diveActivityEditableCatalog_mapStatsBoxEdit_resolvesHiddenDiveSection() {
                let manual = DiveActivity(
                    source: .manual,
                    startTime: Date(),
                    durationMinutes: 40,
                    maxDepthMeters: 18
                )
                #expect(DiveActivityEditableCatalog.mapStatsBoxShowsEditButton(for: manual))

                let context = DiveActivitySectionEditContext(
                    sectionID: DiveActivityEditableCatalog.mapDiveSummarySection.id,
                    tab: .map,
                    panelDetent: .large
                )
                let section = context.resolvedSection()
                #expect(section?.id == "dive")
                #expect(section?.fieldIDs.contains(.maxDepthMeters) == true)
                #expect(
                    DiveActivityEditableCatalog.editableFields(in: DiveActivityEditableCatalog.mapDiveSummarySection, for: manual)
                        .contains(.durationMinutes)
                )
            }
            @Test func diveActivityEditableCatalog_mapNotesUsesDedicatedEditor() throws {
                let mapSections = DiveActivityEditableCatalog.sections(for: .map, detent: .large)
                let tankSections = DiveActivityEditableCatalog.sections(for: .tank, detent: .large)

                let notesSection = try #require(mapSections.first { $0.id == "notes" })
                let gasSection = try #require(tankSections.first { $0.id == "gas" })

                #expect(DiveActivityEditableCatalog.usesDedicatedNotesEditor(section: notesSection, tab: .map))
                #expect(!DiveActivityEditableCatalog.usesDedicatedNotesEditor(section: gasSection, tab: .tank))
                #expect(!DiveActivityEditableCatalog.usesDedicatedNotesEditor(section: notesSection, tab: .tank))
            }
            @Test func diveActivityEditableCatalog_mapDiveSummaryAndConditionsUseOverviewPanelModal() throws {
                let mapSections = DiveActivityEditableCatalog.sections(for: .map, detent: .large)
                let tankLarge = DiveActivityEditableCatalog.sections(for: .tank, detent: .large)
                let conditions = try #require(mapSections.first { $0.id == "diveConditions" })
                let gas = try #require(tankLarge.first { $0.id == "gas" })
                let weights = try #require(tankLarge.first { $0.id == "weights" })
                let operatorSection = try #require(tankLarge.first { $0.id == "operator" })
                let source = try #require(tankLarge.first { $0.id == "source" })

                #expect(
                    DiveActivityEditableCatalog.usesOverviewPanelModalEditor(
                        section: DiveActivityEditableCatalog.mapDiveSummarySection
                    )
                )
                #expect(DiveActivityEditableCatalog.usesOverviewPanelModalEditor(section: conditions))
                #expect(DiveActivityEditableCatalog.usesOverviewPanelModalEditor(section: gas))
                #expect(DiveActivityEditableCatalog.usesOverviewPanelModalEditor(section: weights))
                #expect(DiveActivityEditableCatalog.usesOverviewPanelModalEditor(section: operatorSection))
                #expect(!DiveActivityEditableCatalog.usesOverviewPanelModalEditor(section: source))
            }
            @Test func diveActivityEditableCatalog_manualEntryOnlyFields_blockedForImports() {
                let imported = DiveActivity(
                    source: .macDive,
                    startTime: Date(),
                    durationMinutes: 40,
                    maxDepthMeters: 18
                )
                for field in DiveActivityEditableCatalog.manualEntryOnlyFieldIDs {
                    #expect(!DiveActivityEditableCatalog.isEditable(field, for: imported))
                }
                let manual = DiveActivity(
                    source: .manual,
                    startTime: Date(),
                    durationMinutes: 40,
                    maxDepthMeters: 18
                )
                for field in DiveActivityEditableCatalog.manualEntryOnlyFieldIDs {
                    #expect(DiveActivityEditableCatalog.isEditable(field, for: manual))
                }
            }
            @Test func diveActivityEditableCatalog_mapDiveConditions_mergesWaterTempAndConditions() {
                let mapSections = DiveActivityEditableCatalog.sections(for: .map, detent: .large)
                #expect(mapSections.contains { $0.id == "diveConditions" && $0.title == "Dive Conditions" })
                #expect(!mapSections.contains { $0.id == "environment" })
                #expect(!mapSections.contains { $0.id == "conditions" })
                let diveConditions = mapSections.first { $0.id == "diveConditions" }
                #expect(diveConditions?.fieldIDs.contains(.waterTempAvgCelsius) == true)
                #expect(diveConditions?.fieldIDs.contains(.diveVisibility) == true)
            }
            @Test func diveActivityEditableCatalog_mapAndTankSectionsAreDistinct() {
                let mapIDs = Set(
                    DiveActivityEditableCatalog.sections(for: .map, detent: .large).flatMap(\.fieldIDs)
                )
                let tankIDs = Set(
                    DiveActivityEditableCatalog.sections(for: .tank, detent: .large).flatMap(\.fieldIDs)
                )
                #expect(!mapIDs.contains(.siteName))
                #expect(!mapIDs.contains(.locationName))
                #expect(!mapIDs.contains(.source))
                #expect(!mapIDs.contains(.recordID))
                #expect(!mapIDs.contains(.diveOperatorName))
                #expect(mapIDs.contains(.notes))
                #expect(!mapIDs.contains(.tankPressureStartPSI))
                #expect(tankIDs.contains(.tankPressureStartPSI))
                #expect(tankIDs.contains(.source))
                #expect(!tankIDs.contains(.recordID))
                #expect(tankIDs.contains(.diveOperatorName))
                #expect(!tankIDs.contains(.startTime))
            }
            @Test func diveActivityEditableCatalog_tankLargeDetentSections_includeOperatorAndSource() {
                let tankLarge = DiveActivityEditableCatalog.sections(for: .tank, detent: .large)
                #expect(tankLarge.contains { $0.id == "operator" })
                #expect(tankLarge.contains { $0.id == "source" })
                let tankMinimized = DiveActivityEditableCatalog.sections(for: .tank, detent: .minimized)
                #expect(!tankMinimized.contains { $0.id == "operator" })
                #expect(!tankMinimized.contains { $0.id == "source" })
            }
            @Test func diveActivityTankPanelSummary_remainingPressureFillFraction_clampsAndNilRules() {
                let third = DiveActivityTankPanelSummary.remainingPressureFillFraction(startPSI: 3000, endPSI: 1000)!
                #expect(abs(third - (1000.0 / 3000.0)) < 1e-9)

                #expect(DiveActivityTankPanelSummary.remainingPressureFillFraction(startPSI: nil, endPSI: 1000) == nil)
                #expect(DiveActivityTankPanelSummary.remainingPressureFillFraction(startPSI: 3000, endPSI: nil) == nil)
                #expect(DiveActivityTankPanelSummary.remainingPressureFillFraction(startPSI: 0, endPSI: 0) == nil)
                #expect(DiveActivityTankPanelSummary.remainingPressureFillFraction(startPSI: -100, endPSI: 500) == nil)
                #expect(DiveActivityTankPanelSummary.remainingPressureFillFraction(startPSI: 3000, endPSI: -1) == nil)

                #expect(DiveActivityTankPanelSummary.remainingPressureFillFraction(startPSI: 3000, endPSI: 4500) == 1)
                #expect(DiveActivityTankPanelSummary.remainingPressureFillFraction(startPSI: 3000, endPSI: 0) == 0)
            }
            @Test func diveActivityTankPanelSummary_profilePressureStats_countsAndBounds() {
                let a = DiveProfilePoint(timestamp: Date(timeIntervalSince1970: 100), depthMeters: 1, tankPressurePSI: 3_000)
                let b = DiveProfilePoint(timestamp: Date(timeIntervalSince1970: 200), depthMeters: 2, tankPressurePSI: nil)
                let c = DiveProfilePoint(timestamp: Date(timeIntervalSince1970: 300), depthMeters: 3, tankPressurePSI: 2_800)

                let s = DiveActivityTankPanelSummary.profilePressureStats(from: [a, b, c])
                #expect(s.sampleCount == 2)
                #expect(s.minPSI == 2_800)
                #expect(s.maxPSI == 3_000)

                let empty = DiveActivityTankPanelSummary.profilePressureStats(from: [])
                #expect(empty.sampleCount == 0)
                #expect(empty.minPSI == nil)
                #expect(empty.maxPSI == nil)
            }
            @Test func diveActivityTimePresentation_timeOnlyOmitsCalendarDate() {
                let instant = Date(timeIntervalSinceReferenceDate: 0)
                let date = DiveActivityTimePresentation.formatLongDateOnly(instant, timeZoneOffsetSeconds: 0)
                let time = DiveActivityTimePresentation.formatTimeOnly(instant, timeZoneOffsetSeconds: 0)
                #expect(!time.isEmpty)
                #expect(!time.contains("2001"))
                #expect(!time.contains("January"))
                #expect(date.contains("2001"))
            }
            @Test func diveActivityTimeZoneResolution_prefersPreviewCatalogSiteCoordinates() {
                let catalog = DiveSite(siteName: "Cedar Pass", latCoords: 20.37539, longCoords: -87.0398)
                let activity = DiveActivity(
                    source: .macDive,
                    startTime: Date(),
                    durationMinutes: 60,
                    maxDepthMeters: 10,
                    siteName: "Cedar Pass"
                )
                let coordinate = DiveActivityTimeZoneResolution.coordinateForLookup(
                    on: activity,
                    catalogSites: [catalog]
                )
                #expect(coordinate?.latitude == 20.37539)
                #expect(coordinate?.longitude == -87.0398)
            }
            @Test @MainActor
            func diveActivityTimeZoneResolution_fillsMissingOffsetFromCoordinates() async throws {
                var comps = DateComponents()
                comps.calendar = Calendar(identifier: .gregorian)
                comps.timeZone = TimeZone(secondsFromGMT: 0)
                comps.year = 2024
                comps.month = 8
                comps.day = 23
                comps.hour = 22
                comps.minute = 22
                comps.second = 27
                let start = try #require(comps.date)
                let activity = DiveActivity(
                    source: .macDive,
                    startTime: start,
                    timeZoneOffsetSeconds: nil,
                    durationMinutes: 64,
                    maxDepthMeters: 11.5,
                    entryCoordinate: DiveCoordinate(latitude: 12.12201, longitude: -68.29050)
                )
                let tz = try #require(TimeZone(identifier: "America/Kralendijk"))
                await DiveActivityTimeZoneResolution.resolveMissingOffset(
                    for: activity,
                    resolver: FixedGeocodingTimeZoneResolver(timeZone: tz)
                )
                #expect(activity.timeZoneOffsetSeconds == -4 * 3600)
                var localCal = Calendar(identifier: .gregorian)
                localCal.timeZone = tz
                #expect(localCal.component(.hour, from: activity.startTime) == 18)
            }
            @Test func diveActivityTimePresentation_formatUTCDateTime_usesZulu() {
                let instant = Date(timeIntervalSince1970: 0)
                let label = DiveActivityTimePresentation.formatUTCDateTime(instant)
                #expect(label.hasSuffix("Z"))
            }
            @Test func diveActivityTimePresentation_formatTimeZoneOffsetLabel_formatsHoursAndMinutes() {
                #expect(DiveActivityTimePresentation.formatTimeZoneOffsetLabel(offsetSeconds: -4 * 3600) == "UTC-4:00")
                #expect(DiveActivityTimePresentation.formatTimeZoneOffsetLabel(offsetSeconds: 5 * 3600 + 30 * 60) == "UTC+5:30")
                #expect(DiveActivityTimePresentation.formatTimeZoneOffsetLabel(offsetSeconds: nil) == "Not set (device timezone)")
            }
            @Test func diveActivityTimePresentation_usesStoredOffset() {
                let instant = Date(timeIntervalSince1970: 0)
                let formatted = DiveActivityTimePresentation.formatDateTime(instant, timeZoneOffsetSeconds: -4 * 3600)
                #expect(!formatted.isEmpty)
            }
            @Test func diveActivityTankDefaults_respectsUserDefaults() {
                let defaults = UserDefaults(suiteName: "GoDiveMVPTests.DefaultTank")!
                defaults.removePersistentDomain(forName: "GoDiveMVPTests.DefaultTank")
                defaults.set(DefaultTankSize.st120.rawValue, forKey: AppUserSettings.defaultTankSizeKey)

                let spec = DiveActivityTankDefaults.resolvedSpecification(userDefaults: defaults)
                #expect(spec.size == .st120)
                #expect(DiveQuantityFormatting.tankVolumeDisplay(system: .imperial, specification: spec) == "120 cu ft")
                #expect(DiveSACRMVCalculation.ratedTankVolumeLiters(from: nil, userDefaults: defaults) == spec.ratedVolumeSurfaceLiters)

                let activity = DiveActivity(
                    source: .manual,
                    startTime: Date(),
                    durationMinutes: 1,
                    maxDepthMeters: 1
                )
                #expect(activity.gasDetailsTankTypeLine(defaultSpecification: spec) == "steel")
                #expect(activity.gasDetailsTankVolumeLine(displayUnits: .metric, defaultSpecification: spec) == "3398 L")
            }
            @Test func diveActivityEditableCatalog_includesWeightsSectionOnTankTab() {
                let sections = DiveActivityEditableCatalog.sections(for: .tank, detent: .large)
                #expect(sections.contains { $0.id == "weights" })
                let weights = sections.first { $0.id == "weights" }
                #expect(weights?.fieldIDs == [.diveWaterType, .diverWeightKilograms])
            }
}
