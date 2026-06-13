//
//  ReferenceEphemeridesTests.swift
//  SatellitePasses
//
//  Propagator regression suite. Five real satellites spanning the SGP4 (near-Earth)
//  and SDP4 (deep-space) regimes are propagated from their TLE epochs and checked
//  against golden Earth-Centered-Inertial positions and geodetic sub-points.
//
//  The five satellites (TLEs from celestrak.org, epoch 2026-06-12/13):
//
//    Case 1  ISS (ZARYA)        25544  i=51.63°  e=0.00049  n=15.49 rev/day  → SGP4
//    Case 2  NOAA 19            33591  i=98.95°  e=0.00145  n=14.13 rev/day  → SGP4
//    Case 3  HST                20580  i=28.47°  e=0.00020  n=15.29 rev/day  → SGP4
//    Case 4  IRIDIUM 106        41917  i=86.40°  e=0.00018  n=14.35 rev/day  → SGP4
//    Case 5  GPS BIIR-5 (PRN22) 26407  i=54.85°  e=0.01211  n= 2.01 rev/day  → SDP4
//
//  Period ≥ 225 min selects the deep-space SDP4/DeepSDP4 propagator; only case 5
//  (period ≈ 718 min) crosses that threshold, so it is the only case exercising the
//  luni-solar / resonance machinery. Cases 1–4 stay entirely in the near-Earth SGP4
//  path.
//
//  Golden values were captured from the reference propagator. Tolerances
//  (10 m in ECI position, 2 millidegrees in latitude/longitude, 10 m in altitude)
//  sit far above the ~1e-6 cross-platform libm noise documented in
//  ElementsGroundTrackTests and far below any physically meaningful propagation
//  error, so they lock in the algorithms without being bit-exact.
//

import XCTest
@preconcurrency import SatelliteKit
@testable import SatellitePasses

final class ReferenceEphemeridesTests: XCTestCase {

    /// One propagated instant: minutes after TLE epoch, ECI position (km) and geodetic sub-point.
    private struct Sample {
        let t: Double
        let x, y, z: Double
        let lat, lon, alt: Double
    }

    /// 10 m in position, 2 millidegrees in lat/lon, 10 m in altitude.
    private let posTol = 0.010      // km
    private let angTol = 0.002      // degrees
    private let altTol = 0.010      // km

    /// Propagate `tle` and assert every golden `Sample` matches within tolerance.
    private func assertEphemeris(_ tle: String, _ samples: [Sample],
                                 file: StaticString = #filePath, line: UInt = #line) throws {
        let sat = Satellite(withTLE: try Elements(raw: tle))
        for s in samples {
            let p = try sat.position(minsAfterEpoch: s.t)
            let g = try sat.geoPosition(minsAfterEpoch: s.t)
            XCTAssertEqual(p.x, s.x, accuracy: posTol, "x @ t=\(s.t)", file: file, line: line)
            XCTAssertEqual(p.y, s.y, accuracy: posTol, "y @ t=\(s.t)", file: file, line: line)
            XCTAssertEqual(p.z, s.z, accuracy: posTol, "z @ t=\(s.t)", file: file, line: line)
            XCTAssertEqual(g.lat, s.lat, accuracy: angTol, "lat @ t=\(s.t)", file: file, line: line)
            XCTAssertEqual(g.lon, s.lon, accuracy: angTol, "lon @ t=\(s.t)", file: file, line: line)
            XCTAssertEqual(g.alt, s.alt, accuracy: altTol, "alt @ t=\(s.t)", file: file, line: line)
        }
    }

    // MARK: - Case 1 — ISS (ZARYA), near-circular LEO (SGP4)

    func testCase1_ISS_LEO() throws {
        try assertEphemeris("""
        ISS (ZARYA)
        1 25544U 98067A   26163.80312907  .00008495  00000+0  16106-3 0  9990
        2 25544  51.6335 321.7912 0004900 178.5917 181.5086 15.49196054571074
        """, [
            Sample(t:   0.0, x:  5344.199618320776, y: -4206.775964269839, z:    0.023507498217989344,
                   lat:  0.00019927655475125353, lon: 131.5375568655635,  alt: 423.14475968136594),
            Sample(t: 120.0, x:  1155.1337854831436, y:  4286.221169813386, z: 5137.273465928225,
                   lat: 49.347950502786496,        lon: 214.58122864362105, alt: 423.65190130312203),
            Sample(t: 600.0, x: -4336.28662130212,   y:  5056.613155624998, z: 1331.8432380725824,
                   lat: 11.376157101016426,        lon: 149.95017437692343, alt: 415.81199896105863),
        ])
    }

    // MARK: - Case 2 — NOAA 19, sun-synchronous near-polar LEO (SGP4)

    func testCase2_NOAA19_SunSync() throws {
        try assertEphemeris("""
        NOAA 19
        1 33591U 09005A   26163.80292576  .00000023  00000+0  36263-4 0  9990
        2 33591  98.9520 234.6745 0014465  46.2692 313.9675 14.13473616893860
        """, [
            Sample(t:   0.0, x: -4175.506049308098,  y: -5891.707259754263, z:    0.035419082761210266,
                   lat:  0.0002826866623558219, lon:  44.49404769458613,  alt: 843.1554884477282),
            Sample(t: 120.0, x: -2644.9344559901942, y: -1994.3725680050002, z: 6403.496075643191,
                   lat: 62.78546689638668,      lon: 356.7550179216996,   alt: 848.3225637172418),
            Sample(t: 600.0, x: -2517.957079688059,  y: -4898.819284745771, z: -4685.50416040443,
                   lat: -40.55403290380442,     lon: 262.20607526514084,  alt: 862.217476205622),
        ])
    }

    // MARK: - Case 3 — Hubble Space Telescope, low-inclination LEO (SGP4)

    func testCase3_HST_LowIncl() throws {
        try assertEphemeris("""
        HST
        1 20580U 90037B   26163.25344175  .00006001  00000+0  18892-3 0  9990
        2 20580  28.4709 114.2921 0001952  91.9422 268.1398 15.30693075787818
        """, [
            Sample(t:   0.0, x: -2818.1049795373433, y:  6243.651224541191, z:    0.012188940980135692,
                   lat:  0.00010258539513577521, lon: 122.46772113226473, alt: 472.03790941343595),
            Sample(t: 120.0, x: -4932.645732014523,  y: -3495.4307037519343, z: 3209.290141813904,
                   lat: 28.110203407296016,      lon: 193.41590422796446, alt: 471.1829099140723),
            Sample(t: 600.0, x: -1599.0647551893917, y: -6330.27150950375,  z: 2060.8054435544555,
                   lat: 17.62054257030655,       lon: 113.58805744644826, alt: 470.43281612448754),
        ])
    }

    // MARK: - Case 4 — IRIDIUM 106, near-polar LEO (SGP4)

    func testCase4_Iridium106_Polar() throws {
        try assertEphemeris("""
        IRIDIUM 106
        1 41917U 17003A   26163.83960875  .00000008  00000+0 -42962-5 0  9993
        2 41917  86.3962  90.3736 0001791  82.9896 277.1503 14.34217543492583
        """, [
            Sample(t:   0.0, x: -46.68045807653164, y: 7158.542489660548,  z:    0.034299772240345965,
                   lat:  0.00027616120003498,   lon: 246.95117643102213, alt: 780.557688462779),
            Sample(t: 120.0, x: -437.09872112904867, y: 2431.3844081666525, z: 6707.437953603003,
                   lat: 69.8919776912018,       lon: 226.68683061535978, alt: 788.5985094779453),
            Sample(t: 600.0, x:  53.92350463871461,  y: 7050.814808015253,  z: -1245.0045626845024,
                   lat: -10.072388659073521,    lon:  95.72869230304036,  alt: 782.6053866987213),
        ])
    }

    // MARK: - Case 5 — GPS BIIR-5 (PRN 22), deep-space MEO (SDP4)

    func testCase5_GPS_DeepSpace() throws {
        try assertEphemeris("""
        GPS BIIR-5  (PRN 22)
        1 26407U 00040A   26163.32110391  .00000084  00000+0  00000+0 0  9991
        2 26407  54.8520 215.3556 0121076 302.4522  67.8911  2.00557597189850
        """, [
            Sample(t:   0.0, x: -19363.496555746395, y: -17478.719063165638, z:  4326.861195648402,
                   lat:  9.433009320713458,  lon: 205.82177466251812, alt: 20064.30289151818),
            Sample(t: 120.0, x:   1539.719401799747, y: -16820.720377953417, z: 20748.73396067187,
                   lat: 50.89663981988451,  lon: 228.89833954880646, alt: 20389.486626868806),
            Sample(t: 600.0, x: -20701.39390906556,  y:   -769.3822355473113, z: -16118.947386950986,
                   lat: -37.93185650107453, lon:  15.468137278890254, alt: 19877.977239281154),
        ])
    }
}
