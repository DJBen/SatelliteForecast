/*╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
  ║ SatKitTests.swift                                                                                ║
  ║                                                                                                  ║
  ║ Created by Gavin Eadie on Jan07/17 ... Copyright 2017-20 Ramsay Consulting. All rights reserved. ║
  ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝*/

// swiftlint statement_position

import XCTest
@testable import SatelliteKit

/// Vector magnitude helper (the old `SIMD3.magnitude()` convenience was removed; this avoids
/// depending on the Apple-only `simd` module so the test compiles on Linux too).
private func magnitude(_ v: SIMD3<Double>) -> Double {
    (v.x * v.x + v.y * v.y + v.z * v.z).squareRoot()
}

class SwiftTests: XCTestCase {

    func testProp1() {

        do {
            let tle = try TLE("ISS (ZARYA)",
                              "1 25544U 98067A   18039.95265046  .00001678  00000-0  32659-4 0  9999",
                              "2 25544  51.6426 297.9871 0003401  86.7895 100.1959 15.54072469 98577")

            print(Satellite(withTLE: tle).debugDescription())

            print("mean altitude    (Kms): \((tle.a₀ - 1.0) * EarthConstants.Rₑ)")

            let propagator = selectPropagator(tle: tle)

            let pv1 = try propagator.getPVCoordinates(minsAfterEpoch: 10.0)
            print(pv1.debugDescription())
            print(String(format: "radius1 %10.1f", magnitude(pv1.position)))

            let pv2 = try propagator.getPVCoordinates(minsAfterEpoch: 10.0 + 1.0/60.0)
            print(pv2.debugDescription())
            print(String(format: "radius2 %10.1f", magnitude(pv2.position)))
            print(String(format: "r2 - r1 %10.1f", magnitude(pv2.position - pv1.position)))

            let pv3 = try propagator.getPVCoordinates(minsAfterEpoch: 10.0 + 2.0/60.0)
            print(pv3.debugDescription())
            print(String(format: "radius3 %10.1f", magnitude(pv3.position)))
            print(String(format: "r3 - r2 %10.1f", magnitude(pv3.position - pv2.position)))

        } catch {

            print(error)

        }

    }

    func testProp2() {

        do {
            let tle = try TLE("INTELSAT 39 (IS-39)",
                              "1 44476U 19049B   19348.07175972  .00000049  00000-0  00000+0 0  9993",
                              "2 44476   0.0178 355.6330 0000615 323.6584 210.9460  1.00270455  1345")

            print(Satellite(withTLE: tle).debugDescription())

            print("mean altitude    (Kms): \((tle.a₀ - 1.0) * EarthConstants.Rₑ)")

            let propagator = selectPropagator(tle: tle)

            let pv1 = try propagator.getPVCoordinates(minsAfterEpoch: 10.0)
            print(pv1.debugDescription())
            print(String(format: "radius1 %10.1f", magnitude(pv1.position)))

            let pv2 = try propagator.getPVCoordinates(minsAfterEpoch: 10.0 + 1.0/60.0)
            print(pv2.debugDescription())
            print(String(format: "radius2 %10.1f", magnitude(pv2.position)))
            print(String(format: "r2 - r1 %10.1f", magnitude(pv2.position - pv1.position)))

            let pv3 = try propagator.getPVCoordinates(minsAfterEpoch: 10.0 + 2.0/60.0)
            print(pv3.debugDescription())
            print(String(format: "radius3 %10.1f", magnitude(pv3.position)))
            print(String(format: "r3 - r2 %10.1f", magnitude(pv3.position - pv2.position)))

        } catch {

            print(error)

        }

    }

    func testAzEl() {

        let jdate = Date().julianDate
        print("  Julian Ddate: \(jdate)")

        let moonCele = lunarGeo(julianDays: jdate)
        print(" Moon (Dec/RA): \(moonCele)°")

        let azelx = azel(time: Date(), site: LatLon(+42.0, -84.0), cele: moonCele)
        print("       (Az/El): \(azelx)°")

    }

    func testConversion() {

        let sat = Satellite(
            "ISS (ZARYA)",
            "1 25544U 98067A   18039.95265046  .00001678  00000-0  32659-4 0  9999",
            "2 25544  51.6426 297.9871 0003401  86.7895 100.1959 15.54072469 98577")

        XCTAssertEqual(JD.epoch2000,
                       sat.minsAfterEpoch(sat.julianDay(JD.epoch2000)),
                       accuracy: 1e-7)

        XCTAssertEqual(999.9,
                       sat.julianDay(sat.minsAfterEpoch(999.9)),
                       accuracy: 1e-10)

    }

}
