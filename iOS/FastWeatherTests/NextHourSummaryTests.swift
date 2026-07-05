//
//  NextHourSummaryTests.swift
//  FastWeatherTests
//
//  Tests for RadarService.buildNextHourSummary — the one-sentence Next Hour
//  precipitation narration. Pure function over (minutes, mm/hr, active)
//  samples, so it can be exercised without any network.
//

import XCTest
@testable import WeatherFast

final class NextHourSummaryTests: XCTestCase {

    private let service = RadarService.shared

    /// Per-minute samples like the WeatherKit path (61 entries, 0–60 min).
    private func minuteSamples(activeRanges: [ClosedRange<Int>],
                               mmPerHr: Double = 2.0) -> [(minutes: Int, mmPerHr: Double, active: Bool)] {
        (0...60).map { minute in
            let active = activeRanges.contains { $0.contains(minute) }
            return (minutes: minute, mmPerHr: active ? mmPerHr : 0, active: active)
        }
    }

    // MARK: - No precipitation

    func testAllDryReturnsNoPrecipitationSentence() {
        let summary = service.buildNextHourSummary(samples: minuteSamples(activeRanges: []),
                                                   windowMinutes: 60)
        XCTAssertEqual(summary, "No precipitation expected in the next hour.")
    }

    func testAllDryTwoHourWindowNamesHours() {
        // 15-minute Open-Meteo-style samples over 2 hours
        let samples = stride(from: 0, through: 120, by: 15).map {
            (minutes: $0, mmPerHr: 0.0, active: false)
        }
        let summary = service.buildNextHourSummary(samples: samples, windowMinutes: 120)
        XCTAssertEqual(summary, "No precipitation expected in the next 2 hours.")
    }

    func testSingleSampleReturnsNil() {
        let samples = [(minutes: 0, mmPerHr: 0.0, active: false)]
        XCTAssertNil(service.buildNextHourSummary(samples: samples, windowMinutes: 60))
    }

    func testEmptySamplesReturnsNil() {
        XCTAssertNil(service.buildNextHourSummary(samples: [], windowMinutes: 60))
    }

    // MARK: - Precipitation starting later

    func testOnsetAndDurationPhrasing() {
        // Rain from minute 11 through minute 45 → starts in ~11, lasts ~35 (ends at 46)
        let summary = service.buildNextHourSummary(samples: minuteSamples(activeRanges: [11...45]),
                                                   windowMinutes: 60)
        XCTAssertNotNil(summary)
        XCTAssertTrue(summary!.hasPrefix("Precipitation starting in about 11 minutes"),
                      "unexpected phrasing: \(summary!)")
        XCTAssertTrue(summary!.contains("lasting about 35 minutes"),
                      "unexpected phrasing: \(summary!)")
    }

    func testOnsetContinuingThroughWindow() {
        // Rain starts at minute 40 and never stops within the hour
        let summary = service.buildNextHourSummary(samples: minuteSamples(activeRanges: [40...60]),
                                                   windowMinutes: 60)
        XCTAssertNotNil(summary)
        XCTAssertTrue(summary!.contains("starting in about 40 minutes"),
                      "unexpected phrasing: \(summary!)")
        XCTAssertTrue(summary!.contains("continuing through the next hour"),
                      "unexpected phrasing: \(summary!)")
    }

    func testHeaviestMentionedForModeratePeakAfterOnset() {
        // Onset minute 10; peak (8 mm/hr = heavy) at minute 25
        var samples = minuteSamples(activeRanges: [10...50], mmPerHr: 1.0)
        samples[25].mmPerHr = 8.0
        let summary = service.buildNextHourSummary(samples: samples, windowMinutes: 60)
        XCTAssertNotNil(summary)
        XCTAssertTrue(summary!.contains("Heaviest about 25 minutes from now"),
                      "unexpected phrasing: \(summary!)")
    }

    func testLightRainDoesNotMentionHeaviest() {
        // Uniform light rain — no "Heaviest" clause for a flat light shower
        let summary = service.buildNextHourSummary(samples: minuteSamples(activeRanges: [10...30],
                                                                          mmPerHr: 0.5),
                                                   windowMinutes: 60)
        XCTAssertNotNil(summary)
        XCTAssertFalse(summary!.contains("Heaviest"), "unexpected phrasing: \(summary!)")
    }

    // MARK: - Precipitation now

    func testRainingNowWithEndTime() {
        // Wet from now through minute 20, dry after
        let summary = service.buildNextHourSummary(samples: minuteSamples(activeRanges: [0...20]),
                                                   windowMinutes: 60)
        XCTAssertEqual(summary, "Precipitation now, easing off in about 21 minutes.")
    }

    func testRainingNowContinuing() {
        let summary = service.buildNextHourSummary(samples: minuteSamples(activeRanges: [0...60]),
                                                   windowMinutes: 60)
        XCTAssertEqual(summary, "Precipitation now, continuing through the next hour.")
    }

    // MARK: - 15-minute resolution (Open-Meteo style)

    func testFifteenMinuteResolutionOnset() {
        // Steps of 15 min over 2 hours; active at 30 and 45 minutes
        let samples = stride(from: 0, through: 120, by: 15).map { m in
            (minutes: m, mmPerHr: (m == 30 || m == 45) ? 2.0 : 0.0,
             active: m == 30 || m == 45)
        }
        let summary = service.buildNextHourSummary(samples: samples, windowMinutes: 120)
        XCTAssertNotNil(summary)
        XCTAssertTrue(summary!.contains("starting in about 30 minutes"),
                      "unexpected phrasing: \(summary!)")
        XCTAssertTrue(summary!.contains("lasting about 30 minutes"),
                      "unexpected phrasing: \(summary!)")
    }

    func testHourPlusMinutesPhrasing() {
        // Onset at 75 minutes in a 2-hour window → "about 1 hour 15 minutes"
        let samples = stride(from: 0, through: 120, by: 15).map { m in
            (minutes: m, mmPerHr: m >= 75 ? 2.0 : 0.0, active: m >= 75)
        }
        let summary = service.buildNextHourSummary(samples: samples, windowMinutes: 120)
        XCTAssertNotNil(summary)
        XCTAssertTrue(summary!.contains("about 1 hour 15 minutes"),
                      "unexpected phrasing: \(summary!)")
    }
}

// MARK: - Intensity floor (docs/NOWCAST_CENTRE_AUTHORITY_SPEC.md)

/// Classification tests for the WeatherKit intensity floor. Values mirror the
/// instrumented harness runs: radar phantoms measured 0.05-0.07 mm/h; real
/// storms 3.6-10.4 mm/h. The floor (0.2) must reject the former class and
/// preserve the latter, and must be a no-op when the feature flag is off.
final class IntensityFloorTests: XCTestCase {

    func testPhantomDrizzleRejectedWhenFloorOn() {
        // The east-Madison class: condition says rain, trace intensity.
        XCTAssertFalse(RadarService.wkPrecipActive(typeSaysPrecip: true,
                                                   mmPerHr: 0.05, floorEnabled: true))
        XCTAssertFalse(RadarService.wkPrecipActive(typeSaysPrecip: true,
                                                   mmPerHr: 0.07, floorEnabled: true))
    }

    func testRealRainPreservedWhenFloorOn() {
        XCTAssertTrue(RadarService.wkPrecipActive(typeSaysPrecip: true,
                                                  mmPerHr: 3.6, floorEnabled: true))
        XCTAssertTrue(RadarService.wkPrecipActive(typeSaysPrecip: true,
                                                  mmPerHr: 10.4, floorEnabled: true))
    }

    func testFloorBoundaryIsInclusive() {
        XCTAssertTrue(RadarService.wkPrecipActive(typeSaysPrecip: true,
                                                  mmPerHr: 0.2, floorEnabled: true))
        XCTAssertFalse(RadarService.wkPrecipActive(typeSaysPrecip: true,
                                                   mmPerHr: 0.19, floorEnabled: true))
    }

    func testFlagOffRestoresTypeOnlyBehavior() {
        // With the floor off, any precipitation type counts — byte-for-byte the
        // pre-fix behavior, regardless of intensity.
        XCTAssertTrue(RadarService.wkPrecipActive(typeSaysPrecip: true,
                                                  mmPerHr: 0.0, floorEnabled: false))
        XCTAssertTrue(RadarService.wkPrecipActive(typeSaysPrecip: true,
                                                  mmPerHr: 0.05, floorEnabled: false))
    }

    func testDryTypeNeverActivatesRegardlessOfIntensity() {
        // Intensity noise during clear conditions must never count as rain.
        XCTAssertFalse(RadarService.wkPrecipActive(typeSaysPrecip: false,
                                                   mmPerHr: 5.0, floorEnabled: true))
        XCTAssertFalse(RadarService.wkPrecipActive(typeSaysPrecip: false,
                                                   mmPerHr: 5.0, floorEnabled: false))
    }
}
