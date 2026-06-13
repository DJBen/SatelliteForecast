//
//  ISSPassSydneyTests.swift
//  SatellitePasses
//
//  End-to-end ephemeris / pass-finding test cross-checked against an authoritative
//  external source: https://www.heavens-above.com
//
//  Satellite : ISS (ZARYA), NORAD 25544 — TLE epoch 2026-06-12 19:16:30 UTC
//              (orbital elements taken from heavens-above.com/orbit.aspx?satid=25544,
//               reformatted into a column-correct standard TLE)
//  Observer  : Sydney, Australia — 33.8688°S, 151.2093°E, 20 m
//
//  Reference visible pass (heavens-above, 2026-06-14, brightness -3.0 mag):
//
//      Event               Time (UTC)   Alt    Azimuth        Range
//      Rises               07:46:28      0°    303° (WNW)     2357 km
//      Reaches altitude 10 07:48:35     10°    297° (WNW)     1500 km
//      Maximum altitude    07:51:52     49°    221° (SW)       553 km
//      Enters shadow       07:54:27     15°    148° (SSE)     1226 km
//
//  The reconstructed TLE + SatellitePasses' SGP4 propagation reproduce this pass to within
//  ~10 s in time, ~0.3° in rise azimuth, ~2° in culmination altitude/azimuth and ~10 km in range
//  (heavens-above reports altitudes/azimuths rounded to whole degrees).
//

import XCTest
@preconcurrency import SatelliteKit
@testable import SatellitePasses

final class ISSPassSydneyTests: XCTestCase {

    static let issTLE = """
    ISS (ZARYA)
    1 25544U 98067A   26163.80312906  .00000000  00000-0  16106-3 0  9994
    2 25544  51.6335 321.7912 0004900 178.5917 181.5086 15.49196054    48
    """

    /// Sydney observer: latitude°, longitude°, altitude (km).
    static let observer = LatLonAlt(-33.8688, 151.2093, 0.020)

    /// Window bracketing the 2026-06-14 pass (rise 07:46, set ~07:53 UTC).
    static let windowStart = "2026-06-14T07:40:00+0000"
    static let windowEnd   = "2026-06-14T08:00:00+0000"

    private func julian(_ iso: String) -> Double {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: iso)!.julianDate
    }

    /// Seconds between two julian dates.
    private func secondsBetween(_ a: Double, _ b: Double) -> Double {
        abs(a - b) * TimeConstants.day2sec
    }

    // MARK: - TLE / orbital elements

    func testTLEParsesToExpectedElements() throws {
        let elements = try Elements(raw: Self.issTLE)
        XCTAssertEqual(elements.noradIndex, 25544)
        XCTAssertEqual(elements.i₀ * rad2deg, 51.6335, accuracy: 1e-3)   // inclination
        XCTAssertEqual(elements.Ω₀ * rad2deg, 321.7912, accuracy: 1e-3)  // RAAN
        XCTAssertEqual(elements.e₀, 0.0004900, accuracy: 1e-7)           // eccentricity
    }

    // MARK: - Pass geometry cross-checked against heavens-above

    func testReferencePassMatchesHeavensAbove() throws {
        let info = SatelliteInfo(elements: try Elements(raw: Self.issTLE))

        let coarse = try info.generateSnapshots(
            observer: Self.observer,
            julianDateRange: julian(Self.windowStart)...julian(Self.windowEnd),
            interval: 30
        )
        let passes = try info.findPasses(observer: Self.observer, coarseSnapshots: coarse, minElevation: 10)

        // Exactly one ISS pass crosses the sky in this 20-minute window.
        XCTAssertEqual(passes.count, 1)
        let passSnapshots = try XCTUnwrap(passes.first)
        let pass = passSnapshots.pass

        // Event ordering and horizon crossings.
        XCTAssertLessThan(pass.rise.julianDate, pass.culmination.julianDate)
        XCTAssertLessThan(pass.culmination.julianDate, pass.set.julianDate)
        XCTAssertEqual(pass.rise.elev, 0, accuracy: 0.5)   // rise is the horizon crossing
        XCTAssertEqual(pass.set.elev, 0, accuracy: 0.5)    // set is the horizon crossing

        // Rise: heavens-above 07:46:28 UTC, azimuth 303° (WNW).
        XCTAssertEqual(secondsBetween(pass.rise.julianDate, julian("2026-06-14T07:46:28+0000")), 0, accuracy: 60)
        XCTAssertEqual(pass.rise.azim, 303, accuracy: 3)

        // Culmination: heavens-above 07:51:52 UTC, altitude 49°, azimuth 221° (SW), range 553 km.
        XCTAssertEqual(secondsBetween(pass.culmination.julianDate, julian("2026-06-14T07:51:52+0000")), 0, accuracy: 60)
        XCTAssertEqual(pass.culmination.elev, 49, accuracy: 3)
        XCTAssertEqual(pass.culmination.azim, 221, accuracy: 5)

        let culminationSnapshot = try XCTUnwrap(
            passSnapshots.snapshots.min {
                abs($0.julianDate - pass.culmination.julianDate) < abs($1.julianDate - pass.culmination.julianDate)
            }
        )
        XCTAssertEqual(culminationSnapshot.distance, 553, accuracy: 40)   // km
        XCTAssertTrue(culminationSnapshot.isIlluminated)                  // sunlit at culmination

        // heavens-above lists this as a visible pass (mag -3.0): satellite lit, sky dark.
        XCTAssertLessThan(pass.sunElevationAtTransit, -6)                 // past civil twilight
        XCTAssertEqual(pass.visibility, .visible)
        XCTAssertTrue(pass.hasAnyIllumination(aboveElevation: 10))
    }

    // MARK: - Ephemeris invariants over the pass

    func testSnapshotInvariants() throws {
        let info = SatelliteInfo(elements: try Elements(raw: Self.issTLE))

        let snapshots = try info.generateSnapshots(
            observer: Self.observer,
            julianDateRange: julian(Self.windowStart)...julian(Self.windowEnd),
            interval: 30
        )

        XCTAssertGreaterThan(snapshots.count, 0)

        var previousJulianDate = -Double.infinity
        var sawAboveHorizon = false
        for snapshot in snapshots {
            XCTAssertGreaterThan(snapshot.julianDate, previousJulianDate, "snapshots must be chronological")
            previousJulianDate = snapshot.julianDate

            XCTAssertTrue((-90.0...90.0).contains(snapshot.position.elev), "elevation in range")
            XCTAssertTrue((0.0..<360.0).contains(snapshot.position.azim), "azimuth in [0,360)")

            // Slant range is always positive and below the geometric maximum to a 420 km orbit
            // (≈13 200 km, observer and satellite on opposite sides of the Earth).
            XCTAssertGreaterThan(snapshot.distance, 350)
            XCTAssertLessThan(snapshot.distance, 13_200)

            // While the satellite is above the horizon it can be no farther than the horizon
            // slant range for this altitude (≈2360 km, matching heavens-above's 2357 km at rise).
            if snapshot.position.elev > 0 {
                sawAboveHorizon = true
                XCTAssertLessThan(snapshot.distance, 2500)
            }
        }
        XCTAssertTrue(sawAboveHorizon, "the window should contain the pass")
    }

    // MARK: - Ground track invariants

    func testGroundTrackInvariants() throws {
        let elements = try Elements(raw: Self.issTLE)
        let track = try elements.generateGroundTrack(
            julianDateRange: julian("2026-06-14T07:46:00+0000")...julian("2026-06-14T07:54:00+0000"),
            interval: 30 * TimeConstants.sec2day
        )

        XCTAssertEqual(track.count, 16)
        for point in track {
            // Sub-satellite latitude can never exceed the orbital inclination (51.6335°).
            XCTAssertLessThanOrEqual(abs(point.coordinate.lat), 51.7)
            XCTAssertTrue((0.0...360.0).contains(point.coordinate.lon))
            // Geodetic altitude stays near the ISS apogee/perigee band (416–422 km).
            XCTAssertEqual(point.coordinate.alt, 419, accuracy: 25)
        }
        // The track advances monotonically in time.
        XCTAssertTrue(zip(track, track.dropFirst()).allSatisfy { $0.julianDate < $1.julianDate })
    }
}
