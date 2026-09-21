import XCTest
import SwiftUI
import SatelliteForecast
import SatelliteKit
import simd
import StarryNight
import MetalKit
import CoreMotion
import SolarSystem
@testable import SatelliteForecastImpl

final class PlanetariumTests: XCTestCase {
    func testCenturyPlanetGeometryAgainstHorizons() throws {
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Documentation/DesignReview/Planetarium/CenturyAccuracy")
        let rows = try JSONDecoder().decode([[Double]].self, from: Data(contentsOf: folder.appendingPathComponent("monthly-reference.json")))
        XCTAssertEqual(rows.count, 7*2401)
        let bodies: [Int:SolarSystemBody] = [199:.mercury,299:.venus,499:.mars,599:.jupiter,699:.saturn,799:.uranus,899:.neptune]
        let ratios: [Int:Double] = [199:2438.26/2440.53,299:1,499:3376.2/3396.19,599:66854/71492,699:54364/60268,799:24973/25559,899:24341/24764]
        var report: [String:[String:Double]] = [:]
        for row in rows {
            let id = Int(row[0]), date = row[1], body = try XCTUnwrap(bodies[Int(row[0])])
            let g = PlanetariumPlanetAppearance.geometry(body: body, date: date)
            let frame = PlanetariumEquatorialFrame(date: date)
            let direction = simd_normalize(frame.ofDate(SIMD3<Double>(g.direction)))
            let pole = frame.ofDate(SIMD3<Double>(g.pole))
            let north = simd_normalize(SIMD3<Double>(0,0,1)-direction*direction.z)
            let east = simd_normalize(simd_cross(SIMD3<Double>(0,0,1),direction))
            let angle = atan2(simd_dot(pole,east),simd_dot(pole,north))*180 / .pi
            let angleError = abs((angle-row[5]+540).truncatingRemainder(dividingBy:360)-180)
            let latitude = atan(tan(row[3] * .pi/180)*pow(ratios[id]!,2))*180 / .pi
            let openingError = abs(Double(g.appearance.opening)*180 / .pi-latitude)
            let phaseError = abs(Double(g.appearance.illuminatedFraction)*100-row[2])
            let ra = row[6] * .pi/180, dec = row[7] * .pi/180
            let expected = SIMD3(cos(dec)*cos(ra),cos(dec)*sin(ra),sin(dec))
            let positionError = atan2(simd_length(simd_cross(SIMD3<Double>(g.direction),expected)),simd_dot(SIMD3<Double>(g.direction),expected))*180 / .pi
            XCTAssertLessThan(phaseError,0.02,"\(body) \(date) phase percentage points")
            XCTAssertLessThan(openingError,0.01,"\(body) \(date) opening degrees")
            XCTAssertLessThan(angleError,0.06,"\(body) \(date) pole angle degrees")
            XCTAssertLessThan(positionError,0.02,"\(body) \(date) astrometric position degrees")
            if body == .saturn {
                XCTAssertLessThan(openingError,0.001)
                XCTAssertLessThan(angleError,0.005)
            }
            var result = report[String(describing: body)] ?? [:]
            for (key,value) in [("phasePercentagePoints",phaseError),("openingDegrees",openingError),("poleAngleDegrees",angleError),("positionDegrees",positionError)] {
                if value > (result[key] ?? -1) { result[key] = value; result[key+"JD"] = date }
            }
            report[String(describing: body)] = result
        }
        try JSONSerialization.data(withJSONObject: report,options:[.prettyPrinted,.sortedKeys]).write(to: folder.appendingPathComponent("measured-errors.json"))
    }


    func testPlanetPhaseAndPoleAgainstHorizons() throws {
        // Independent JPL Horizons observer tables (Earth center, quantities
        // 10/14/16/17/24, queried 2026-09-20); angles are true-of-date.
        let fixtures: [(SolarSystemBody, Double, Float, Float, Float, Float)] = [
            (.mercury,2458999.5,49.32356,2.702886,355.5955,265.65),
            (.mercury,2459360.5,17.68447,2.996113,351.7093,264.24),
            (.venus,2458999.5,0.86624,-2.438388,353.2608,252.24),
            (.venus,2459360.5,96.18081,-1.452403,355.0444,263.65),
            (.venus,2461303.5,24.70668,7.081113,20.1461,297.39),
            (.saturn,2458999.5,99.83800,24.841684,6.7600,77.28),
            (.saturn,2460757.5,99.99279,0.051359,4.6449,54.91),
            (.saturn,2461303.5,99.97953,-9.739151,3.1337,76.81)
        ]
        for (body,date,percent,latitude,poleAngle,sunAngle) in fixtures {
            let g = PlanetariumPlanetAppearance.geometry(body: body, date: date)
            XCTAssertEqual(g.appearance.illuminatedFraction*100, percent, accuracy: 0.12, "\(body) \(date)")
            let ratio: Float = body == .saturn ? 54364/60268 : 1
            let opening = atan(tan(latitude * .pi/180)*ratio*ratio)*180 / .pi
            XCTAssertEqual(g.appearance.opening*180 / .pi, opening, accuracy: 0.12, "\(body)")
            let north = simd_normalize(SIMD3<Float>(0,0,1)-g.direction*g.direction.z)
            let east = simd_normalize(simd_cross(SIMD3<Float>(0,0,1),g.direction))
            let angle = atan2(simd_dot(g.pole,east),simd_dot(g.pole,north))*180 / .pi
            let delta = (angle-poleAngle+540).truncatingRemainder(dividingBy: 360)-180
            XCTAssertEqual(delta, 0, accuracy: 0.35, "\(body) position angle")
            let relativeSun = atan2(-g.appearance.sunDirection.x,g.appearance.sunDirection.y)*180 / .pi
            let sunDelta = (relativeSun+poleAngle-sunAngle+720+180).truncatingRemainder(dividingBy: 360)-180
            XCTAssertEqual(sunDelta, 0, accuracy: 0.4, "\(body) bright limb")
        }
    }

    @MainActor
    func testGPUPhysicalPlanetPhasesAndRings() throws {
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Documentation/DesignReview/Planetarium/PhysicalPhases")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        func image(_ body: SolarSystemBody, _ appearance: PlanetariumPlanetAppearance) throws -> UIImage {
            let texture = try XCTUnwrap(PlanetariumGlobeRenderer.skyTexture(body: body, appearance: appearance))
            let w = texture.width, h = texture.height
            var bytes = [UInt8](repeating: 0, count: w*h*4)
            texture.getBytes(&bytes, bytesPerRow: w*4, from: MTLRegionMake2D(0,0,w,h), mipmapLevel: 0)
            let provider = try XCTUnwrap(CGDataProvider(data: Data(bytes) as CFData))
            let cg = try XCTUnwrap(CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w*4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: [.byteOrder32Little,CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)],
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
            return UIImage(cgImage: cg)
        }
        // Independent area oracle: sphere illumination must occupy (1+cos phase)/2
        // of the projected disk, with no permanently illuminated night hemisphere.
        for cosine: Float in [-0.8,0,0.8] {
            let rendered = try image(.venus, .init(opening: 0, sunDirection: SIMD3(sqrt(1-cosine*cosine),0,cosine)))
            let bytes = try pixels(rendered)
            var disk = 0, lit = 0
            for i in stride(from: 0, to: bytes.count, by: 4) where bytes[i+3] > 250 {
                disk += 1
                if max(bytes[i],max(bytes[i+1],bytes[i+2])) > 8 { lit += 1 }
            }
            XCTAssertEqual(Double(lit)/Double(disk), Double((1+cosine)/2), accuracy: 0.015)
        }
        let faceOn = try image(.saturn, .init(opening: .pi/2, sunDirection: SIMD3(0,0,1)))
        let bytes = try pixels(faceOn)
        let row = 256, width = 512
        // Globe radius is 102.4px; outer A-ring is 232.4px. The old 1.91 ratio
        // would have ended before x=460, which must now lie inside the A ring.
        XCTAssertGreaterThan(bytes[(row*width+475)*4+3], 100)
        XCTAssertLessThan(bytes[(row*width+493)*4+3], 5)
        XCTAssertLessThan(bytes[(row*width+460)*4+3], 40, "Cassini division remains distinct")
        let cases: [(String,SolarSystemBody,Double)] = [
            ("Venus crescent · 2026-09-20",.venus,2461303.5),
            ("Venus thin crescent · 2020-05-30",.venus,2458999.5),
            ("Venus gibbous · 2021-05-26",.venus,2459360.5),
            ("Mercury half · 2020-05-30",.mercury,2458999.5),
            ("Saturn open · 2020-05-30",.saturn,2458999.5),
            ("Saturn edge-on · 2025-03-23",.saturn,2460757.5),
            ("Saturn south face · 2026-09-20",.saturn,2461303.5),
            ("Mars · 2026-09-20",.mars,2461303.5)
        ]
        let images = try cases.map { try image($0.1, PlanetariumPlanetAppearance.geometry(body: $0.1,date: $0.2).appearance) }
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let gallery = UIGraphicsImageRenderer(size: CGSize(width: 1200,height: 660), format: format).image { ctx in
            UIColor.black.setFill(); ctx.fill(CGRect(x: 0,y: 0,width: 1200,height: 660))
            for (i,image) in images.enumerated() {
                let x = (i%4)*300, y = (i/4)*330
                image.draw(in: CGRect(x: x,y: y,width: 300,height: 300))
                cases[i].0.draw(at: CGPoint(x: x+8,y: y+305),withAttributes: [.foregroundColor:UIColor.white,.font:UIFont.systemFont(ofSize: 13)])
            }
        }
        try gallery.pngData()!.write(to: directory.appendingPathComponent("phases-and-rings-dark.png"))
    }


    func testStarLabelStabilityAndCollisionHysteresis() {
        var layout = PlanetariumLabelLayout()
        let bounds = CGRect(x: 0, y: 0, width: 440, height: 956)
        func candidate(_ id: Int, _ x: CGFloat) -> PlanetariumLabelLayout.Candidate {
            .init(id: id, rect: CGRect(x: x, y: 300, width: 60, height: 18))
        }
        XCTAssertTrue(layout.layout([candidate(1, 100)], bounds: bounds, obstacles: [], budget: 1, time: 0).isEmpty)
        XCTAssertEqual(layout.layout([candidate(1, 100)], bounds: bounds, obstacles: [], budget: 1, time: 0.3).map(\.id), [1])
        // A brighter newcomer and small camera jitter cannot steal a readable incumbent's slot.
        for frame in 1...240 {
            let x = 100 + CGFloat(sin(Double(frame) * 0.2)) * 3
            let placed = layout.layout([candidate(2, 220), candidate(1, x)], bounds: bounds, obstacles: [], budget: 1, time: 0.3 + Double(frame)/60)
            XCTAssertEqual(placed.map(\.id), [1])
        }
        // Hard obstruction hides immediately; near-boundary jitter cannot flash it back on.
        let obstacle = CGRect(x: 150, y: 290, width: 50, height: 40)
        XCTAssertTrue(layout.layout([candidate(1, 100)], bounds: bounds, obstacles: [obstacle], budget: 1, time: 5).isEmpty)
        for frame in 1...120 {
            let x: CGFloat = frame.isMultiple(of: 2) ? 81 : 91
            XCTAssertTrue(layout.layout([candidate(1, x)], bounds: bounds, obstacles: [obstacle], budget: 1, time: 5 + Double(frame)/60).isEmpty)
        }
        _ = layout.layout([candidate(1, 60)], bounds: bounds, obstacles: [obstacle], budget: 1, time: 8)
        XCTAssertEqual(layout.layout([candidate(1, 60)], bounds: bounds, obstacles: [obstacle], budget: 1, time: 8.3).map(\.id), [1])
        // Exhaust a moving dense field: labels always fit and never overlap.
        layout.reset()
        for frame in 0...600 {
            let candidates = (0..<24).map { candidate($0, CGFloat($0 * 19) + CGFloat(sin(Double(frame)/20) * 30)) }
            let placed = layout.layout(candidates, bounds: bounds, obstacles: [obstacle], budget: 7, time: Double(frame)/60)
            XCTAssertLessThanOrEqual(placed.count, 7)
            for (index, label) in placed.enumerated() {
                XCTAssertTrue(bounds.contains(label.rect))
                XCTAssertFalse(label.rect.intersects(obstacle))
                for other in placed.dropFirst(index + 1) { XCTAssertFalse(label.rect.intersects(other.rect)) }
            }
        }
    }

    func testBrightStarNamesAreCachedAndMagnitudeRanked() async throws {
        let catalog = try await AppStarCatalog.load()
        let named = catalog.namedBrightStars
        XCTAssertEqual(named.count, 50)
        XCTAssertEqual(Set(named.map(\.id)).count, 50)
        XCTAssertEqual(named.first?.info?.properName, "Sirius")
        XCTAssertTrue(named.contains { $0.info?.properName == "Vega" })
        XCTAssertTrue(zip(named, named.dropFirst()).allSatisfy { $0.magnitude <= $1.magnitude })
        let expected = catalog.snapshot.stars.filter { $0.magnitude > -10 }
            .sorted { $0.magnitude == $1.magnitude ? $0.id < $1.id : $0.magnitude < $1.magnitude }.prefix(50)
        XCTAssertEqual(named.map(\.id), expected.map(\.id))
        XCTAssertTrue(named.allSatisfy { !($0.info?.displayName?.isEmpty ?? true) })
    }

    func testNaturalMoonHorizonsInterpolation() throws {
        // Independent Horizons UT / ICRF / geocentric LT query at the midpoint,
        // compared with interpolation between two separately requested samples.
        let table = try MoonEphemeris.parse("""
        $$SOE
        2459372.500000000, A.D. 2021-Jun-07 00:00:00.0000,  6.170799068299342E+08, -3.020735862566011E+08, -1.429758388362553E+08, -1.944186593362829E+01,  9.601064862595550E-01, -4.970527534005629E-01,
        2459372.511057292, A.D. 2021-Jun-07 00:15:55.3500,  6.170616547842402E+08, -3.020726557636695E+08, -1.429763018482131E+08, -1.876968415403061E+01,  9.924527750557601E-01, -4.699866938363697E-01,
        $$EOE
        """)
        let position = try XCTUnwrap(MoonEphemeris.interpolate(table, at: 2459372.505528646))
        let expected = SIMD3<Double>(6.170707005309910e8, -3.020731248745871e8, -1.429760735755105e8)
        XCTAssertLessThan(simd_length(position - expected), 1) // < 1 km at Io
        XCTAssertNil(MoonEphemeris.interpolate(table, at: 2459372.4))
        XCTAssertNil(MoonEphemeris.interpolate(table, at: 2459373))
        XCTAssertThrowsError(try MoonEphemeris.parse("API error"))
        XCTAssertThrowsError(try MoonEphemeris.parse("$$SOE\n1, date, nan, 0, 0, 0, 0, 0,\n$$EOE"))
        XCTAssertEqual(Set(PlanetariumMoon.all.map(\.id)).count, 21)
        XCTAssertEqual(PlanetariumMoon.all.filter { $0.parent == .saturn }.count, 8)
    }

    func testNaturalMoonLiveEphemerides() async throws {
        guard FileManager.default.fileExists(atPath: "/tmp/moon-ephemeris-validation") else { throw XCTSkip("Opt-in Horizons integration") }
        for moon in PlanetariumMoon.all {
            let data = try await MoonEphemerisStore.shared.load(moon, date: 2459372.5)
            let position = try XCTUnwrap(MoonEphemeris.interpolate(data.moon, at: 2459372.5))
            let parent = try XCTUnwrap(MoonEphemeris.interpolate(data.parent, at: 2459372.5))
            XCTAssertGreaterThan(simd_length(position-parent), moon.parentRadius)
            XCTAssertLessThan(simd_length(position-parent), 5_000_000)
            let dates = data.orbitDates(period: moon.period)
            XCTAssertEqual(dates.last! - dates.first!, moon.period, accuracy: 1e-8)
            XCTAssertEqual(data.moon.count, 193)
            XCTAssertEqual(data.parent.count, 193)
            XCTAssertTrue(data.contains(2459372.5))
        }
    }

    func testOffscreenStationBearing() {
        func bearing(_ d: SIMD3<Float>) -> Double? {
            PlanetariumGeometry.offscreenBearing(cameraDirection: d, aspect: 0.5, tangent: 0.6)
        }
        XCTAssertNil(bearing(SIMD3(0, 0, 1)))
        XCTAssertNil(bearing(SIMD3(0.29, 0.59, 1)))
        XCTAssertEqual(bearing(SIMD3(1, 0, 1))!, .pi / 2, accuracy: 0.001)
        XCTAssertEqual(bearing(SIMD3(-1, 0, -1))!, -.pi / 2, accuracy: 0.001)
        XCTAssertEqual(bearing(SIMD3(0, 1, 1))!, 0, accuracy: 0.001)
        XCTAssertEqual(abs(bearing(SIMD3(0, -1, 1))!), .pi, accuracy: 0.001)
        XCTAssertEqual(bearing(SIMD3(0, 0, -1))!, .pi / 2, accuracy: 0.001)
        XCTAssertEqual(PlanetariumGeometry.shortestTurn(from: 359, to: 1), 2)
        XCTAssertEqual(PlanetariumGeometry.shortestTurn(from: 1, to: 359), -2)
    }

    func testHorizontalFrameAndRoundTrip() {
        XCTAssertEqual(PlanetariumGeometry.direction(azimuth: 0, elevation: 0), SIMD3(0, 0, -1))
        XCTAssertEqual(PlanetariumGeometry.direction(azimuth: 90, elevation: 0).x, 1, accuracy: 0.00001)
        XCTAssertEqual(PlanetariumGeometry.direction(azimuth: 0, elevation: 90).y, 1, accuracy: 0.00001)
        for azimuth in stride(from: 0.0, to: 360, by: 7) {
            for elevation in [-89.0, -30, 0, 45, 89] {
                let v = PlanetariumGeometry.direction(azimuth: azimuth, elevation: elevation)
                let result = PlanetariumGeometry.angles(v)
                XCTAssertEqual(simd_length(v), 1, accuracy: 0.00001)
                XCTAssertEqual(result.azimuth, azimuth, accuracy: 0.001)
                XCTAssertEqual(result.elevation, elevation, accuracy: 0.001)
            }
        }
    }
    func testDisjointTiersAndSeamCulling() {
        func star(_ id: Int, _ magnitude: Double, _ ra: Double, _ dec: Double = 0) -> Star {
            let a = ra * .pi / 180, d = dec * .pi / 180
            return Star(id: id, magnitude: magnitude, coordinate: SIMD3(cos(d)*cos(a), cos(d)*sin(a), sin(d)), spectralClass: "G")
        }
        let stars = [star(1, 1, 180), star(2, 6, 359), star(3, 7, 1), star(4, 8, 2), star(5, 6, 180)]
        let tiers = PlanetariumStarTiers(stars: stars + [stars[0], stars[1]])
        XCTAssertEqual(tiers.bright.map(\.id), [1])
        let wide = tiers.visibleFaintStars(forward: SIMD3(1,0,0), diagonalHalfAngle: 0.3, fieldOfView: 65)
        XCTAssertEqual(Set(wide.map(\.id)), [2])
        let mid = tiers.visibleFaintStars(forward: SIMD3(1,0,0), diagonalHalfAngle: 0.3, fieldOfView: 35)
        XCTAssertEqual(Set(mid.map(\.id)), [2,3])
        let close = tiers.visibleFaintStars(forward: SIMD3(1,0,0), diagonalHalfAngle: 0.3, fieldOfView: 15)
        XCTAssertEqual(Set(close.map(\.id)), [2,3,4])
        let polar = PlanetariumStarTiers(stars: [star(6, 6, 180, 89)])
        XCTAssertEqual(polar.visibleFaintStars(forward: SIMD3(0,0,1), diagonalHalfAngle: 0.1, fieldOfView: 60).count, 1)
    }
    func testGroundOccludesLowObjects() {
        XCTAssertFalse(PlanetariumGeometry.isAboveGround(PlanetariumGeometry.direction(azimuth: 90, elevation: -1)))
        for azimuth in stride(from: 0.0, to: 360, by: 1) {
            let ridge = Double(PlanetariumGeometry.horizonHeight(azimuth: Float(azimuth * .pi / 180))) * 180 / .pi
            XCTAssertLessThan(ridge, 1.5, "Mountains must stay low")
            XCTAssertGreaterThan(ridge, 0)
            XCTAssertTrue(PlanetariumGeometry.isAboveGround(PlanetariumGeometry.direction(azimuth: azimuth, elevation: ridge + 0.01)))
            XCTAssertFalse(PlanetariumGeometry.isAboveGround(PlanetariumGeometry.direction(azimuth: azimuth, elevation: ridge - 0.01)))
        }
        XCTAssertTrue(PlanetariumGeometry.isAboveGround(PlanetariumGeometry.direction(azimuth: 180, elevation: 20)))
    }
    func testConstellationHandoffContractsBeforeSwitching() {
        var focus = PlanetariumConstellationFocus()
        for _ in 0..<20 { focus.update(candidate: 2, delta: 1 / 30) }
        XCTAssertEqual(focus.active, 2)
        XCTAssertEqual(focus.progress, 1)
        focus.update(candidate: 7, delta: 1 / 30)
        XCTAssertEqual(focus.active, 2)
        XCTAssertLessThan(focus.progress, 1)
        var previous = focus.progress
        while focus.active == 2 {
            focus.update(candidate: 7, delta: 1 / 30)
            XCTAssertLessThanOrEqual(focus.progress, previous)
            previous = focus.progress
        }
        XCTAssertEqual(focus.progress, 0, "Old geometry must disappear before the replacement")
        for _ in 0..<20 { focus.update(candidate: 7, delta: 1 / 30) }
        XCTAssertEqual(focus.active, 7)
        XCTAssertEqual(focus.progress, 1)
        for _ in 0..<20 { focus.update(candidate: nil, delta: 1 / 30) }
        XCTAssertNil(focus.active)
        focus.update(candidate: 3, delta: 0, reduceMotion: true)
        XCTAssertEqual(focus.active, 3)
        XCTAssertEqual(focus.progress, 1)
        focus.update(candidate: nil, delta: 0, reduceMotion: true)
        XCTAssertNil(focus.active)
        XCTAssertEqual(PlanetariumGeometry.horizonHeight(azimuth: 0), PlanetariumGeometry.horizonHeight(azimuth: 2 * .pi), accuracy: 0.00001)
    }

    func testPlanetRotationScaleAndDirection() throws {
        let earth = try XCTUnwrap(PlanetariumGlobeStyle(body: .earth))
        XCTAssertEqual(earth.rotationSeconds, 10)
        XCTAssertEqual(earth.angle(at: 2.5), .pi / 2, accuracy: 0.0001)
        XCTAssertEqual(earth.angle(at: 10), 0, accuracy: 0.0001)
        let venus = try XCTUnwrap(PlanetariumGlobeStyle(body: .venus))
        XCTAssertEqual(venus.rotationSeconds, 2430.208333, accuracy: 0.001)
        XCTAssertLessThan(venus.angle(at: 1), 0)
        XCTAssertLessThan(try XCTUnwrap(PlanetariumGlobeStyle(body: .uranus)).angle(at: 1), 0)
        XCTAssertEqual(try XCTUnwrap(PlanetariumGlobeStyle(body: .jupiter)).rotationSeconds, 4.125, accuracy: 0.001)
        XCTAssertNil(PlanetariumGlobeStyle(body: .sun))
    }

    func testMetalLayoutMatchesShaders() {
        XCTAssertEqual(MemoryLayout<PlanetariumUniforms>.stride, 9 * 16)
        XCTAssertEqual(MemoryLayout<PlanetariumStarInstance>.stride, 32)
        XCTAssertEqual(MemoryLayout<PlanetariumLineVertex>.stride, 48)
        XCTAssertEqual(MemoryLayout<PlanetariumSprite>.stride, 64)
    }
}

@MainActor
extension PlanetariumTests {
    func testFrameRateCountsPresentedFramesAndResets() {
        let monitor = PlanetariumFrameRate()
        monitor.recordPresentation(at: 1)
        XCTAssertNil(monitor.framesPerSecond, "Hidden readout does no sampling")
        monitor.setEnabled(true, now: 1)
        for frame in 0...60 { monitor.recordPresentation(at: 1 + Double(frame) / 60) }
        XCTAssertEqual(monitor.framesPerSecond ?? 0, 60, accuracy: 0.01)
        // Half as many presentations over the next second must report 30, not the display's target rate.
        for frame in 1...30 { monitor.recordPresentation(at: 2 + Double(frame) / 30) }
        XCTAssertEqual(monitor.framesPerSecond ?? 0, 30, accuracy: 0.01)
        monitor.setEnabled(false, now: 3)
        monitor.recordPresentation(at: 4)
        XCTAssertNil(monitor.framesPerSecond)
        monitor.setEnabled(true, now: 10)
        monitor.recordPresentation(at: 5) // Late callback from the prior session.
        for frame in 0...60 { monitor.recordPresentation(at: 10 + Double(frame) / 60) }
        XCTAssertEqual(monitor.framesPerSecond ?? 0, 60, accuracy: 0.01,
            "Resuming must discard the background interval and old callbacks")
    }

    func testMetalPipelinesAndTexturesLoad() throws {
        let controller = PlanetariumController()
        XCTAssertNil(controller.errorMessage)
        let renderer = try XCTUnwrap(controller.renderer)
        XCTAssertEqual(renderer.milkyWay.count, 2)
        for tile in renderer.milkyWay {
            XCTAssertEqual(tile.width, 8192)
            XCTAssertEqual(tile.height, 8192)
            XCTAssertEqual(tile.mipmapLevelCount, 14)
            XCTAssertEqual(tile.pixelFormat, .astc_6x6_srgb)
        }
        XCTAssertLessThan(renderer.milkyWay.reduce(0) { $0 + $1.allocatedSize }, 85 * 1024 * 1024)
        controller.stop()
    }

    func testAnimatedStationCentering() async throws {
        let catalog = try await AppStarCatalog.load()
        let fixture = try Fixture(catalog: catalog)
        let pass = try XCTUnwrap(fixture.passes.first { $0.pass.visibility == .visible })
        let date = pass.pass.culmination.julianDate
        let controller = PlanetariumController()
        controller.view.frame = CGRect(x: 0, y: 0, width: 440, height: 956)
        controller.configure(context: .init(passIndex: 0, satelliteInfo: fixture.info, satelliteCommonName: "ISS",
            category: .iss, julianDateRange: fixture.range, observer: fixture.observer, passSnapshots: pass,
            starManager: catalog, julianDateProvider: { date }), julianDate: date)
        defer { controller.stop() }
        controller.focusSatellite()
        let renderer = try XCTUnwrap(controller.renderer)
        let target = renderer.uniforms.forward
        let angles = PlanetariumGeometry.angles(SIMD3(target.x, target.y, target.z))
        controller.pointCamera(azimuth: angles.azimuth + 150, elevation: 0)
        let start = renderer.uniforms.forward
        var time = 100.0
        controller.animationClock = { time }
        controller.animateToSatellite()
        controller.updateNavigation()
        XCTAssertEqual(renderer.uniforms.forward, start)
        time += 0.35
        controller.updateNavigation()
        XCTAssertGreaterThan(simd_distance(renderer.uniforms.forward, start), 0.1)
        XCTAssertGreaterThan(simd_distance(renderer.uniforms.forward, target), 0.1)
        time += 0.4
        controller.updateNavigation()
        XCTAssertLessThan(simd_distance(renderer.uniforms.forward, target), 0.0001)
        controller.animateToSatellite()
        controller.pointCamera(azimuth: 20, elevation: 30)
        let manual = renderer.uniforms.forward
        time += 1
        controller.updateNavigation()
        XCTAssertEqual(renderer.uniforms.forward, manual, "Manual pointing cancels the camera animation")
    }

    func testPanningNearPoles() throws {
        let controller = PlanetariumController()
        defer { controller.stop() }
        controller.view.frame = CGRect(x: 0, y: 0, width: 440, height: 956)
        let renderer = try XCTUnwrap(controller.renderer)
        for elevation in [-89.5, -89, 0, 89, 89.5] {
            controller.pointCamera(azimuth: 125, elevation: elevation)
            let before = renderer.uniforms.right
            controller.panBy(CGPoint(x: 20, y: 0))
            let f = renderer.uniforms.forward
            let angles = PlanetariumGeometry.angles(SIMD3(f.x, f.y, f.z))
            XCTAssertEqual(PlanetariumGeometry.shortestTurn(from: 125, to: angles.azimuth),
                           -20 * controller.fieldOfView / 956, accuracy: 0.002)
            XCTAssertLessThan(simd_distance(before, renderer.uniforms.right), 0.03, "No polar spin amplification")
            controller.panBy(CGPoint(x: 0, y: elevation < 0 ? -200 : 200))
            let clampedRight = renderer.uniforms.right
            controller.panBy(CGPoint(x: 0, y: elevation < 0 ? -200 : 200))
            XCTAssertLessThan(simd_distance(clampedRight, renderer.uniforms.right), 0.00001, "Dragging across pole must not flip azimuth")
            XCTAssertTrue(renderer.uniforms.forward.x.isFinite)
        }
    }

    func testPanMomentum() throws {
        func coast(fps: Int) throws -> SIMD4<Float> {
            let controller = PlanetariumController()
            defer { controller.stop() }
            controller.view.frame = CGRect(x: 0, y: 0, width: 440, height: 956)
            let renderer = try XCTUnwrap(controller.renderer)
            var time = 0.0
            controller.animationClock = { time }
            controller.pointCamera(azimuth: 359, elevation: 25)
            controller.panBy(CGPoint(x: 10, y: 5))
            let start = renderer.uniforms.forward
            controller.finishPan(velocity: CGPoint(x: 900, y: 180))
            XCTAssertTrue(controller.isPanningWithMomentum)
            for frame in 1...(fps * 2) {
                time = Double(frame) / Double(fps)
                controller.updateNavigation()
            }
            XCTAssertGreaterThan(simd_distance(start, renderer.uniforms.forward), 0.1)
            XCTAssertFalse(controller.isPanningWithMomentum, "Coasting settles")
            return renderer.uniforms.forward
        }
        XCTAssertLessThan(simd_distance(try coast(fps: 30), try coast(fps: 120)), 0.002,
                          "Coast distance is stable across refresh rates")
        let controller = PlanetariumController()
        defer { controller.stop() }
        controller.view.frame = CGRect(x: 0, y: 0, width: 440, height: 956)
        var time = 0.0
        controller.animationClock = { time }
        controller.panBy(.zero)
        controller.finishPan(velocity: CGPoint(x: 800, y: 0))
        controller.panBy(.zero)
        XCTAssertFalse(controller.isPanningWithMomentum, "New drag stops old inertia")
        controller.finishPan(velocity: CGPoint(x: 800, y: 0))
        controller.zoom(by: 0.8)
        XCTAssertFalse(controller.isPanningWithMomentum)
        controller.finishPan(velocity: CGPoint(x: 800, y: 0))
        controller.setMotionEnabled(true)
        XCTAssertFalse(controller.isPanningWithMomentum)
        controller.setMotionEnabled(false)
        controller.finishPan(velocity: CGPoint(x: 800, y: 0))
        controller.setActive(false)
        XCTAssertFalse(controller.isPanningWithMomentum)
        controller.setActive(true)
        controller.finishPan(velocity: CGPoint(x: 800, y: 0))
        time += 1
        controller.updateNavigation()
        XCTAssertFalse(controller.isPanningWithMomentum, "No jump after a stalled frame")
    }

    func testDeviceFollowLowPassResponseAndJitter() throws {
        func direction(_ degrees: Double) -> SIMD3<Float> {
            SIMD3(Float(sin(degrees * .pi / 180)), 0, -Float(cos(degrees * .pi / 180)))
        }
        func heading(_ pose: simd_quatf) -> Double {
            let f = pose.act(SIMD3<Float>(0, 0, -1))
            return Double(atan2(f.x, -f.z)) * 180 / .pi
        }
        var responses: [Double] = []
        for rate in [30, 60, 120] {
            var filter = PlanetariumMotionFilter()
            _ = filter.update(forward: direction(0), up: SIMD3(0, 1, 0), timestamp: 0)
            var result: simd_quatf?
            for sample in 1...rate {
                result = filter.update(forward: direction(90), up: SIMD3(0, 1, 0), timestamp: Double(sample)/Double(rate))
                let angle = heading(try XCTUnwrap(result))
                XCTAssertGreaterThan(angle, 0)
                XCTAssertLessThan(angle, 90)
            }
            responses.append(heading(try XCTUnwrap(result)))
        }
        XCTAssertEqual(responses[0], 90 * (1 - exp(-4)), accuracy: 0.01)
        XCTAssertEqual(responses[0], responses[1], accuracy: 0.01)
        XCTAssertEqual(responses[1], responses[2], accuracy: 0.01)
        var filter = PlanetariumMotionFilter()
        var inputPower = 0.0, outputPower = 0.0
        for sample in 0...240 {
            let time = Double(sample)/60
            let input = sin(time * 2 * .pi * 8) // 1° hand tremor at 8 Hz
            let pose = try XCTUnwrap(filter.update(forward: direction(input), up: SIMD3(0, 1, 0), timestamp: time))
            if sample > 60 { inputPower += input * input; outputPower += pow(heading(pose), 2) }
        }
        XCTAssertLessThan(sqrt(outputPower/inputPower), 0.15)
        filter.reset()
        _ = filter.update(forward: direction(359), up: SIMD3(0, 1, 0), timestamp: 0)
        let north = try XCTUnwrap(filter.update(forward: direction(1), up: SIMD3(0, 1, 0), timestamp: 1/60))
        XCTAssertLessThan(abs(heading(north)), 1.01, "Follow the short path across north")
        let resumed = try XCTUnwrap(filter.update(forward: direction(90), up: SIMD3(0, 1, 0), timestamp: 2))
        XCTAssertEqual(heading(resumed), 90, accuracy: 0.001)
        XCTAssertNil(filter.update(forward: .zero, up: .zero, timestamp: 3))
        filter.reset()
        let zenith = try XCTUnwrap(filter.update(forward: SIMD3(0, 1, 0), up: SIMD3(0, 0, 1), timestamp: 4))
        XCTAssertLessThan(simd_distance(zenith.act(SIMD3(0, 0, -1)), SIMD3(0, 1, 0)), 0.00001)
    }

    func testMotionToManualHandoff() throws {
        XCTAssertNotNil(UIImage(systemName: "location.north.line"))
        XCTAssertNotNil(UIImage(systemName: "location.north.line.fill"))
        let controller = PlanetariumController()
        defer { controller.stop() }
        controller.view.frame = CGRect(x: 0, y: 0, width: 440, height: 956)
        let renderer = try XCTUnwrap(controller.renderer)
        controller.setMotionEnabled(true)
        let direction = PlanetariumGeometry.direction(azimuth: 125, elevation: 35)
        let right = simd_normalize(simd_cross(direction, SIMD3<Float>(0, 1, 0)))
        let upright = simd_normalize(simd_cross(right, direction))
        controller.updateMotionOrientation(forward: direction, screenUp: upright * 0.8 + right * 0.6)
        let before = renderer.uniforms
        controller.panBy(.zero)
        XCTAssertFalse(controller.motionEnabled)
        XCTAssertLessThan(simd_distance(before.forward, renderer.uniforms.forward), 0.00001)
        XCTAssertLessThan(simd_distance(SIMD4(upright, 0), renderer.uniforms.up), 0.00001, "Dragging levels the device tilt")
        controller.panBy(CGPoint(x: 30, y: 15))
        let manual = renderer.uniforms
        XCTAssertGreaterThan(simd_distance(before.forward, manual.forward), 0.01)
        controller.updateMotionOrientation(forward: SIMD3(0, 0, -1), screenUp: SIMD3(0, 1, 0))
        XCTAssertEqual(renderer.uniforms.forward, manual.forward, "Late motion updates cannot override the drag")
        controller.setActive(false)
        controller.setActive(true)
        XCTAssertFalse(controller.motionEnabled, "Returning to the app must not reenable motion after a drag")
        controller.setMotionEnabled(true)
        controller.setActive(false)
        XCTAssertTrue(controller.motionEnabled, "Background suspension preserves the requested mode")
        controller.setActive(true)
        controller.updateMotionOrientation(forward: direction, screenUp: upright)
        XCTAssertTrue(controller.motionEnabled)
        XCTAssertLessThan(simd_distance(renderer.uniforms.forward, SIMD4(direction, 0)), 0.00001)
    }

    func testSatelliteTrackAndMarkerAgree() async throws {
        let fixture = try Fixture(catalog: await AppStarCatalog.load())
        let pass = try XCTUnwrap(fixture.passes.max { $0.pass.culmination.elev < $1.pass.culmination.elev }).pass
        let track = try PlanetariumSatelliteTrack(info: fixture.info, observer: fixture.observer,
                                                  range: pass.rise.julianDate...pass.set.julianDate)
        let vertices = track.vertices
        XCTAssertEqual(vertices.count, (track.samples.count - 1) * 2)
        XCTAssertNil(track.sample(at: pass.rise.julianDate - 1))
        for index in stride(from: 0, to: track.samples.count - 1, by: 7) {
            let a = track.samples[index], b = track.samples[index + 1]
            XCTAssertLessThanOrEqual((b.date-a.date)*86400, 1.001)
            for t: Float in [0, 0.25, 0.5, 0.75, 1] {
                let date = a.date + Double(t) * (b.date-a.date)
                let marker = try XCTUnwrap(track.sample(at: date))
                let v0 = vertices[index*2].position, v1 = vertices[index*2+1].position
                let expected = simd_normalize(SIMD3(v0.x,v0.y,v0.z)*(1-t)+SIMD3(v1.x,v1.y,v1.z)*t)
                XCTAssertLessThan(simd_distance(marker.direction, expected), 0.000001,
                                  "Marker lies on the actual rendered segment, including intermediate times")
                let truth = try fixture.info.generateSnapshot(julianDate: date, observer: fixture.observer)
                let actual = PlanetariumGeometry.direction(azimuth: truth.position.azim, elevation: truth.position.elev)
                XCTAssertLessThan(simd_distance(marker.direction, actual), 0.00003,
                                  "Shared track stays close to independently propagated orbit")
            }
        }
    }

    func testPreviewTrackingAndContinuousSkyRotation() async throws {
        let fixture = try Fixture(catalog: await AppStarCatalog.load())
        let pass = try XCTUnwrap(fixture.passes.first { $0.pass.visibility == .visible })
        let date = pass.pass.culmination.julianDate
        let controller = PlanetariumController()
        controller.view.frame = CGRect(x: 0, y: 0, width: 440, height: 956)
        controller.configure(context: .init(passIndex: 0, satelliteInfo: fixture.info, satelliteCommonName: "ISS",
            category: .iss, julianDateRange: fixture.range, observer: fixture.observer, passSnapshots: pass,
            starManager: fixture.catalog, julianDateProvider: { date }), julianDate: date)
        defer { controller.stop() }
        controller.setMotionEnabled(false)
        controller.view.isPaused = true
        let renderer = try XCTUnwrap(controller.renderer)
        let initialEast = renderer.uniforms.east
        controller.updateTime(date + 0.1 / 86400)
        XCTAssertGreaterThan(simd_distance(initialEast, renderer.uniforms.east), 0.000001,
                             "The sky must advance within the old ten-second update interval")

        let star = try XCTUnwrap(fixture.catalog.namedBrightStars.first {
            let p = azel(time: Date(julianDate: date), site: LatLon(fixture.observer), cele: RADec(PlanetariumEquatorialFrame(date: date).ofDate($0.coordinate)))
            return p.elev > 25 && p.elev < 65
        })
        controller.updateTime(date)
        let position = azel(time: Date(julianDate: date), site: LatLon(fixture.observer), cele: RADec(PlanetariumEquatorialFrame(date: date).ofDate(star.coordinate)))
        controller.pointCamera(azimuth: position.azim, elevation: position.elev)
        controller.select(at: CGPoint(x: 220, y: 478))
        for _ in 0..<100 where controller.selection == nil { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(controller.selection?.id, "star-\(star.id)")
        controller.panBy(CGPoint(x: 65, y: 45))
        let anchor = try XCTUnwrap(controller.selectedScreenPosition)
        XCTAssertGreaterThan(abs(anchor.x - 220), 20)
        for seconds in [0.2, 2.0, 11.0, 60.0, -30.0] {
            controller.updateTime(date + seconds / 86400, trackingSelection: true)
            let point = try XCTUnwrap(controller.selectedScreenPosition)
            XCTAssertEqual(point.x, anchor.x, accuracy: 0.1)
            XCTAssertEqual(point.y, anchor.y, accuracy: 0.1)
        }
        controller.clearSelection()
        var clock = 100.0
        controller.animationClock = { clock }
        controller.setPreviewPlayback(playing: true, date: date, end: date + 30 / 86400)
        let before = renderer.uniforms.east
        clock += 1.0 / 60
        renderer.beforeDraw?()
        XCTAssertGreaterThan(simd_distance(before, renderer.uniforms.east), 0.000001)
        XCTAssertEqual(try XCTUnwrap(controller.previewDate), date + (10.0 / 60) / 86400, accuracy: 1e-8)
        clock += 10
        renderer.beforeDraw?()
        XCTAssertEqual(try XCTUnwrap(controller.previewDate), date + 30 / 86400, accuracy: 1e-8)
        controller.setPreviewPlayback(playing: false, date: date, end: date + 30 / 86400)
        XCTAssertNil(controller.previewDate)

        for hour in 0..<24 {
            let lunarDate = date + Double(hour) / 24
            let moon = MoonAppearance.coordinate(julianDate: lunarDate, observer: fixture.observer)
            guard moon.elev > 25 && moon.elev < 70 else { continue }
            controller.updateTime(lunarDate)
            controller.pointCamera(azimuth: moon.azim, elevation: moon.elev)
            controller.select(at: CGPoint(x: 220, y: 478))
            XCTAssertEqual(controller.selection?.planet, .moon)
            controller.zoom(by: 1 / controller.fieldOfView)
            controller.panBy(CGPoint(x: 50, y: -30))
            let moonAnchor = try XCTUnwrap(controller.selectedScreenPosition)
            for step in 1...120 {
                controller.updateTime(lunarDate + Double(step) / 60 / 86400, trackingSelection: true)
                let point = try XCTUnwrap(controller.selectedScreenPosition)
                XCTAssertEqual(point.x, moonAnchor.x, accuracy: 0.5)
                XCTAssertEqual(point.y, moonAnchor.y, accuracy: 0.5)
            }
            let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Documentation/DesignReview/Planetarium/PreviewTracking")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let image = try await renderer.snapshot(size: CGSize(width: 1320, height: 2868), scale: 3)
            try image.pngData()!.write(to: folder.appendingPathComponent("tracked-moon-dark.png"))
            return
        }
        XCTFail("Fixture must include an above-horizon Moon")
    }

    func testMoonSelectionCanBeReplacedInHostedView() async throws {
        let fixture = try Fixture(catalog: await AppStarCatalog.load())
        let pass = try XCTUnwrap(fixture.passes.first { $0.pass.visibility == .visible })
        let context = PassViewContext(passIndex: 0, satelliteInfo: fixture.info, satelliteCommonName: "ISS",
            category: .iss, julianDateRange: fixture.range, observer: fixture.observer, passSnapshots: pass,
            starManager: fixture.catalog, julianDateProvider: { pass.pass.culmination.julianDate })
        let controller = PlanetariumController()
        let host = UIHostingController(rootView: PlanetariumView(context: context, controller: controller)
            .environment(\.colorScheme, .dark))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 440, height: 956)
        window.overrideUserInterfaceStyle = .dark
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { controller.stop(); window.isHidden = true; window.rootViewController = nil }
        try await Task.sleep(for: .milliseconds(300))
        controller.setMotionEnabled(false)
        for hour in 0..<24 {
            let date = pass.pass.culmination.julianDate + Double(hour) / 24
            let moon = MoonAppearance.coordinate(julianDate: date, observer: fixture.observer)
            guard moon.elev > 25 && moon.elev < 70,
                  SkyChartAtmosphere.sun(observer: fixture.observer, julianDate: date).elev < -8 else { continue }
            controller.updateTime(date)
            controller.pointCamera(azimuth: moon.azim, elevation: moon.elev)
            let center = CGPoint(x: controller.view.bounds.midX, y: controller.view.bounds.midY)
            controller.select(at: center)
            XCTAssertEqual(controller.selection?.planet, .moon)
            try await Task.sleep(for: .milliseconds(300))
            let target = window.hitTest(controller.view.convert(center, to: window), with: nil)
            XCTAssertTrue(target === controller.view || target?.isDescendant(of: controller.view) == true,
                          "Sky taps must reach Metal with the Moon card visible; got \(String(describing: target))")
            let star = try XCTUnwrap(fixture.catalog.namedBrightStars.first {
                let p = azel(time: Date(julianDate: date), site: LatLon(fixture.observer), cele: RADec(PlanetariumEquatorialFrame(date: date).ofDate($0.coordinate)))
                return p.elev > 25 && p.elev < 70
            })
            let p = azel(time: Date(julianDate: date), site: LatLon(fixture.observer), cele: RADec(PlanetariumEquatorialFrame(date: date).ofDate(star.coordinate)))
            controller.pointCamera(azimuth: p.azim, elevation: p.elev)
            controller.select(at: center)
            for _ in 0..<100 where controller.selection?.planet != nil { try await Task.sleep(for: .milliseconds(10)) }
            XCTAssertEqual(controller.selection?.id, "star-\(star.id)")
            // Repeat without dismissing the card, at close zoom with playback running.
            controller.setPreviewPlayback(playing: true, date: date, end: date + 60 / 86400)
            controller.zoom(by: 1 / controller.fieldOfView)
            for _ in 0..<3 {
                let now = try XCTUnwrap(controller.previewDate)
                let lunar = MoonAppearance.coordinate(julianDate: now, observer: fixture.observer)
                controller.pointCamera(azimuth: lunar.azim, elevation: lunar.elev)
                controller.select(at: center)
                XCTAssertEqual(controller.selection?.planet, .moon)
                try await Task.sleep(for: .milliseconds(100))
                let starDate = try XCTUnwrap(controller.previewDate)
                let starPosition = azel(time: Date(julianDate: starDate),
                    site: LatLon(fixture.observer), cele: RADec(PlanetariumEquatorialFrame(date: starDate).ofDate(star.coordinate)))
                controller.pointCamera(azimuth: starPosition.azim, elevation: starPosition.elev)
                controller.select(at: center)
                for _ in 0..<100 where controller.selection?.planet != nil {
                    try await Task.sleep(for: .milliseconds(10))
                }
                XCTAssertEqual(controller.selection?.id, "star-\(star.id)")
            }
            return
        }
        XCTFail("Need a night-time Moon fixture")
    }

    func testSelectingCatalogStarAndMoon() async throws {
        let catalog = try await AppStarCatalog.load()
        let fixture = try Fixture(catalog: catalog)
        let pass = try XCTUnwrap(fixture.passes.first { $0.pass.visibility == .visible })
        let date = pass.pass.culmination.julianDate
        let controller = PlanetariumController()
        controller.view.frame = CGRect(x: 0, y: 0, width: 440, height: 956)
        controller.configure(context: .init(passIndex: 0, satelliteInfo: fixture.info, satelliteCommonName: "ISS",
            category: .iss, julianDateRange: fixture.range, observer: fixture.observer, passSnapshots: pass,
            starManager: catalog, julianDateProvider: { date }), julianDate: date)
        defer { controller.stop() }
        let renderer = try XCTUnwrap(controller.renderer)
        XCTAssertEqual(renderer.motionTrailPointCount, 0, "Unselected planets and Moon have no trail")
        let star = try XCTUnwrap(catalog.snapshot.stars.first { star in
            let position = azel(time: Date(julianDate: date), site: LatLon(fixture.observer), cele: RADec(PlanetariumEquatorialFrame(date: date).ofDate(star.coordinate)))
            return star.magnitude < 3 && position.elev > 20 && position.elev < 75
        })
        let coordinate = azel(time: Date(julianDate: date), site: LatLon(fixture.observer), cele: RADec(PlanetariumEquatorialFrame(date: date).ofDate(star.coordinate)))
        controller.pointCamera(azimuth: coordinate.azim, elevation: coordinate.elev)
        controller.select(at: CGPoint(x: 220, y: 478))
        XCTAssertNil(controller.selection, "No provisional star card before metadata is ready")
        for _ in 0..<100 where controller.selection == nil { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(controller.selection?.id, "star-\(star.id)")
        XCTAssertEqual(renderer.motionTrailPointCount, 0, "A star selection must not reveal planetary trails")
        let resolved = controller.selection
        controller.select(at: CGPoint(x: 220, y: 478))
        XCTAssertEqual(controller.selection, resolved, "Keep the ready card during a replacement lookup")
        controller.clearSelection()
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertNil(controller.selection, "Cancelled lookup must not resurrect a dismissed card")
        controller.clearSelection()
        XCTAssertNil(controller.selection)
        let candidates: [SolarSystemBody] = [.mercury, .venus, .mars, .jupiter, .saturn, .uranus, .neptune]
        var testedPlanet = false
        for body in candidates {
            let position = azel(time: Date(julianDate: date), site: LatLon(fixture.observer), cele: RADec(body.eci(julianDay: date)))
            guard position.elev > 10 else { continue }
            controller.pointCamera(azimuth: position.azim, elevation: position.elev)
            controller.select(at: CGPoint(x: 220, y: 478))
            XCTAssertEqual(controller.selection?.planet, body)
            XCTAssertEqual(renderer.motionTrailPointCount, 2920, "Only one selected planet's annual trail")
            controller.clearSelection()
            XCTAssertEqual(renderer.motionTrailPointCount, 0)
            testedPlanet = true
            break
        }
        XCTAssertTrue(testedPlanet, "Fixture must exercise a visible planet")
        // Find a lunar epoch above the horizon without depending on today's sky.
        for hour in 0..<24 {
            let lunarDate = date + Double(hour) / 24
            let moon = MoonAppearance.coordinate(julianDate: lunarDate, observer: fixture.observer)
            if moon.elev > 20 {
                controller.updateTime(lunarDate)
                controller.pointCamera(azimuth: moon.azim, elevation: moon.elev)
                controller.select(at: CGPoint(x: 220, y: 478))
                XCTAssertEqual(controller.selection?.name, "Moon")
                XCTAssertTrue(controller.selection?.detail.contains("illuminated") == true)
                XCTAssertEqual(renderer.motionTrailPointCount, 2688, "Only the selected Moon trail")
                controller.clearSelection()
                XCTAssertEqual(renderer.motionTrailPointCount, 0, "Dismissal clears the trail immediately")
                controller.updateTime(lunarDate + 0.01)
                XCTAssertEqual(renderer.motionTrailPointCount, 0, "Time refresh must not restore hidden trails")
                return
            }
        }
        XCTFail("Fixture should have an above-horizon Moon")
    }

    /// Opt-in real MTKView review; capture using simulator tools in dark mode.
    func testInteractivePlanetarium() async throws {
        let marker = "/tmp/satellite-planetarium-review"
        guard FileManager.default.fileExists(atPath: marker) else { throw XCTSkip("Interactive review not requested") }
        let fixture = try Fixture(catalog: await AppStarCatalog.load())
        let savedLabels = UserDefaults.standard.object(forKey: "planetariumLabels")
        let savedLines = UserDefaults.standard.object(forKey: "planetariumLines")
        defer {
            UserDefaults.standard.set(savedLabels, forKey: "planetariumLabels")
            UserDefaults.standard.set(savedLines, forKey: "planetariumLines")
        }
        UserDefaults.standard.set(true, forKey: "planetariumLabels")
        UserDefaults.standard.set(true, forKey: "planetariumLines")
        let moonReview = FileManager.default.fileExists(atPath: "/tmp/satellite-planetarium-moon")
        let pass = try XCTUnwrap(fixture.passes.first { $0.pass.visibility == .visible && $0.pass.sunElevationAtTransit < -10 && (moonReview || $0.pass.culmination.elev > 40) })
        let context = PassViewContext(passIndex: 0, satelliteInfo: fixture.info, satelliteCommonName: "International space station",
            category: .iss, julianDateRange: fixture.range, observer: fixture.observer,
            passSnapshots: pass, starManager: fixture.catalog, julianDateProvider: { fixture.now.julianDate })
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.overrideUserInterfaceStyle = .dark
        let controller = PlanetariumController()
        if FileManager.default.fileExists(atPath: "/tmp/satellite-planetarium-entrance") {
            window.rootViewController = UIHostingController(rootView: NavigationStack { fixture.factory.pass(context) }.environment(\.motionManagerKey, CMMotionManager()).preferredColorScheme(.dark))
        } else {
            window.rootViewController = UIHostingController(rootView: PlanetariumView(context: context, controller: controller))
        }
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        try await Task.sleep(for: .seconds(1))
        if moonReview {
            let date = (pass.pass.rise.julianDate + pass.pass.set.julianDate) / 2
            let moon = MoonAppearance.coordinate(julianDate: date, observer: fixture.observer)
            controller.setMotionEnabled(false)
            controller.pointCamera(azimuth: moon.azim, elevation: moon.elev)
            controller.zoom(by: 0.35)
            controller.select(at: CGPoint(x: controller.view.bounds.midX, y: controller.view.bounds.midY))
        }
        if let name = try? String(contentsOfFile: "/tmp/planetarium-system", encoding: .utf8),
           let body = SolarSystemBody.allCases.first(where: { String(describing: $0) == name.trimmingCharacters(in: .whitespacesAndNewlines) }) {
            let date = (pass.pass.rise.julianDate + pass.pass.set.julianDate) / 2
            let observerAU = PlanetariumEquatorialFrame(date: date).j2000(geo2eci(julianDays: date, geodetic: fixture.observer)) / 149597870.7
            let direction = PlanetariumPlanetAppearance.geometry(body: body, date: date, observerAU: observerAU).direction
            let coordinate = azel(time: Date(julianDate: date), site: LatLon(fixture.observer), cele: RADec(PlanetariumEquatorialFrame(date: date).ofDate(SIMD3<Double>(direction))))
            controller.setMotionEnabled(false)
            controller.pointCamera(azimuth: coordinate.azim, elevation: coordinate.elev)
            controller.zoom(by: 0.3 / controller.fieldOfView)
            controller.select(at: CGPoint(x: controller.view.bounds.midX, y: controller.view.bounds.midY))
        }
        var reviewDate = (pass.pass.rise.julianDate + pass.pass.set.julianDate) / 2
        try "ready".write(toFile: marker + "-ready", atomically: true, encoding: .utf8)
        for _ in 0..<3000 {
            if !FileManager.default.fileExists(atPath: marker) { return }
            let positions = controller.visibleNaturalMoonPositions.mapValues { ["x": $0.x, "y": $0.y] }
            if let json = try? JSONEncoder().encode(positions) {
                try? json.write(to: URL(fileURLWithPath: "/tmp/planetarium-moons-visible.json"), options: .atomic)
            }
            let commandURL = URL(fileURLWithPath: "/tmp/planetarium-camera.json")
            if let data = try? Data(contentsOf: commandURL),
               let values = try? JSONSerialization.jsonObject(with: data) as? [String: Double] {
                controller.setMotionEnabled(false)
                if let date = values["date"] { reviewDate = date; controller.updateTime(date) }
                if let index = values["bodyIndex"], Int(index) >= 0, Int(index) < SolarSystemBody.allCases.count {
                    let body = SolarSystemBody.allCases[Int(index)]
                    let epoch = PlanetariumEquatorialFrame(date: reviewDate)
                    let observerAU = epoch.j2000(geo2eci(julianDays: reviewDate, geodetic: fixture.observer)) / 149597870.7
                    let direction = body == .sun ? PlanetariumPlanetAppearance.sunDirection(date: reviewDate) : PlanetariumPlanetAppearance.geometry(body: body, date: reviewDate, observerAU: observerAU).direction
                    let coordinate = azel(time: Date(julianDate: reviewDate), site: LatLon(fixture.observer), cele: RADec(epoch.ofDate(SIMD3<Double>(direction))))
                    controller.pointCamera(azimuth: coordinate.azim, elevation: coordinate.elev)
                    controller.select(at: CGPoint(x: controller.view.bounds.midX, y: controller.view.bounds.midY))
                }
                if let azimuth = values["azimuth"] {
                    controller.pointCamera(azimuth: azimuth, elevation: values["elevation"] ?? 5)
                }
                if let fov = values["fov"] { controller.zoom(by: fov / controller.fieldOfView) }
                try? FileManager.default.removeItem(at: commandURL)
            }
            try await Task.sleep(for: .milliseconds(200))
        }
    }
}

@MainActor
extension PlanetariumTests {
    private func pixels(_ image: UIImage) throws -> [UInt8] {
        let cg = try XCTUnwrap(image.cgImage)
        var data = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        let context = try XCTUnwrap(CGContext(data: &data, width: cg.width, height: cg.height,
            bitsPerComponent: 8, bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        return data
    }

    private func difference(_ lhs: UIImage, _ rhs: UIImage) throws -> Double {
        let a = try pixels(lhs), b = try pixels(rhs)
        XCTAssertEqual(a.count, b.count)
        return Double(zip(a, b).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }) / Double(a.count)
    }

    private func saveReview(_ image: UIImage, _ name: String) throws {
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Documentation/DesignReview/Planetarium/SelectionGlobes")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try XCTUnwrap(image.pngData()).write(to: directory.appendingPathComponent(name + ".png"))
        let attachment = XCTAttachment(image: image)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testGPUConstellationStrokeWidthAndNearPlaneClipping() async throws {
        let view = MTKView(frame: CGRect(x: 0, y: 0, width: 200, height: 134))
        let renderer = try PlanetariumMetalRenderer(view: view)
        view.isPaused = true
        renderer.uniforms.north = SIMD4(0, 0, -1, 0)
        renderer.uniforms.east = SIMD4(1, 0, 0, 0)
        renderer.uniforms.zenith = SIMD4(0, 1, 0, 0)
        let color = SIMD4<Float>(0.4, 0.61, 0.86, 0.52)
        renderer.setConstellations([
            .init(position: SIMD4(-0.3, 0.2, -1, 1), color: color),
            .init(position: SIMD4(0.3, 0.2, -1, 1), color: color)
        ])
        renderer.showLines = false
        let baseline = try await renderer.snapshot(size: CGSize(width: 600, height: 400))
        renderer.showLines = true
        let strokes = try await renderer.snapshot(size: CGSize(width: 600, height: 400))
        let a = try pixels(baseline), b = try pixels(strokes)
        let rows = (0..<400).filter { row in
            let offset = (row * 600 + 300) * 4
            return (0..<3).contains { abs(Int(a[offset + $0]) - Int(b[offset + $0])) > 3 }
        }
        XCTAssertGreaterThanOrEqual(rows.count, 4, "Retina stroke must be thicker than a one-pixel line")
        XCTAssertLessThanOrEqual(rows.count, 8, "AA stroke must stay bounded in screen space")
        renderer.setConstellations([
            .init(position: SIMD4(-0.3, 0.2, 1, 1), color: color),
            .init(position: SIMD4(0.3, 0.2, 1, 1), color: color)
        ])
        let behind = try await renderer.snapshot(size: CGSize(width: 600, height: 400))
        XCTAssertLessThan(try difference(baseline, behind), 0.001, "Behind-camera lines must not draw wedges")
        renderer.setConstellations([
            .init(position: SIMD4(-0.3, 0.2, 0.3, 1), color: color),
            .init(position: SIMD4(0.3, 0.2, -0.3, 1), color: color)
        ])
        let crossing = try await renderer.snapshot(size: CGSize(width: 600, height: 400))
        XCTAssertLessThan(try difference(baseline, crossing), 2, "Near-plane crossing remains a narrow stroke")
    }

    func testObservedPlanetInclinationsAndSkyChartBackground() async throws {
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Documentation/DesignReview/Planetarium/ObservedInclinations")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let bodies: [SolarSystemBody] = [.mercury, .venus, .mars, .jupiter, .saturn, .uranus, .neptune]
        let date = 2461302.5 // 2026-09-19
        var images: [UIImage] = []
        for body in bodies {
            let direction = SIMD3<Float>(simd_normalize(body.eci(julianDay: date)))
            let pole = PlanetariumPlanetOrientation.pole(body, at: date)
            XCTAssertEqual(simd_length(pole), 1, accuracy: 0.00001)
            let opening = PlanetariumPlanetOrientation.opening(pole: pole, direction: direction)
            XCTAssertTrue(opening.isFinite)
            let texture = try XCTUnwrap(PlanetariumGlobeRenderer.skyTexture(body: body, opening: opening))
            let dimension = texture.width
            var bytes = [UInt8](repeating: 0, count: dimension*dimension*4)
            texture.getBytes(&bytes, bytesPerRow: dimension*4, from: MTLRegionMake2D(0, 0, dimension, dimension), mipmapLevel: 0)
            let provider = try XCTUnwrap(CGDataProvider(data: Data(bytes) as CFData))
            let cg = try XCTUnwrap(CGImage(width: dimension, height: dimension, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: dimension*4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: [.byteOrder32Little, CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)],
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
            images.append(UIImage(cgImage: cg))
        }
        XCTAssertEqual(PlanetariumPlanetOrientation.opening(pole: SIMD3(0,1,0), direction: SIMD3(0,0,1)), 0)
        XCTAssertEqual(PlanetariumPlanetOrientation.opening(pole: SIMD3(0,0,1), direction: SIMD3(0,0,-1)), .pi/2)
        // Saturn's equinox should be almost edge-on; 2017's rings were wide open.
        func saturnOpening(_ jd: Double) -> Float {
            PlanetariumPlanetOrientation.opening(pole: PlanetariumPlanetOrientation.pole(.saturn, at: jd),
                direction: SIMD3<Float>(simd_normalize(SolarSystemBody.saturn.eci(julianDay: jd))))
        }
        XCTAssertLessThan(abs(saturnOpening(2460757.5)), 0.02)
        XCTAssertGreaterThan(abs(saturnOpening(2458028.5)), 0.4)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let gallery = UIGraphicsImageRenderer(size: CGSize(width: 1024, height: 600), format: format).image { ctx in
            UIColor.black.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 600))
            for (i, image) in images.enumerated() {
                let x = (i % 4)*256, y = (i / 4)*300
                image.draw(in: CGRect(x: x, y: y, width: 256, height: 256))
                String(describing: bodies[i]).draw(at: CGPoint(x: x+20, y: y+260), withAttributes: [.foregroundColor: UIColor.white])
            }
        }
        try gallery.pngData()!.write(to: directory.appendingPathComponent("planet-openings-2026-dark.png"))
        let background = try XCTUnwrap(MilkyWayBackground.image(size: CGSize(width: 512, height: 512),
            observer: LatLonAlt(37.49, -122.23, 0), julianDate: 2459372.8, dark: true))
        let chart = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 512), format: format).image { ctx in
            UIColor.black.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 512, height: 512))
            background.draw(at: .zero)
        }
        try chart.pngData()!.write(to: directory.appendingPathComponent("sky-chart-background-dark.png"))
    }

    func testGPUPlanetNightSidePreservesDaytimeAtmosphere() async throws {
        let view = MTKView(frame: CGRect(x: 0,y: 0,width: 256,height: 256))
        let renderer = try PlanetariumMetalRenderer(view: view)
        view.isPaused = true
        let direction = simd_normalize(SIMD3<Float>(0,1,-1))
        renderer.uniforms.forward = SIMD4(direction,0)
        renderer.uniforms.up = SIMD4(simd_normalize(SIMD3<Float>(0,1,1)),0)
        renderer.uniforms.right = SIMD4(1,0,0,0)
        renderer.uniforms.sun = SIMD4(simd_normalize(SIMD3<Float>(1,1,1)),45)
        renderer.uniforms.effects.x = 1
        let size = CGSize(width: 256,height: 256)
        let background = try await renderer.snapshot(size: size, scale: 1)
        let texture = try XCTUnwrap(PlanetariumGlobeRenderer.skyTexture(body: .venus,
            appearance: .init(opening: 0,sunDirection: SIMD3(0,0,-1))))
        var sprite = PlanetariumSprite(positionSize: SIMD4(direction,160))
        sprite.options = SIMD4(0,1,0,2)
        renderer.sprites = [(sprite,texture)]
        let planet = try await renderer.snapshot(size: size, scale: 1)
        let a = try pixels(background), b = try pixels(planet)
        for y in 124..<132 {
            for x in 124..<132 {
                for channel in 0..<3 {
                    let i = (y*256+x)*4+channel
                    XCTAssertEqual(Double(a[i]), Double(b[i]), accuracy: 2, "Daytime atmosphere remains in front of the unlit disk")
                }
            }
        }
    }

    func testGPUPlanetGlobes() async throws {
        let bodies: [SolarSystemBody] = [.mercury, .venus, .earth, .mars, .jupiter, .saturn, .uranus, .neptune]
        var thumbnails: [UIImage] = []
        for body in bodies {
            let renderer = try PlanetariumGlobeRenderer(body: body)
            XCTAssertEqual(renderer.resources.textures.count, 9)
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: 144, height: 144, mipmapped: false)
            descriptor.usage = [.renderTarget]; descriptor.storageMode = .shared
            let target = try XCTUnwrap(renderer.resources.device.makeTexture(descriptor: descriptor))
            func capture(_ time: Double) async throws -> UIImage {
                let pass = MTLRenderPassDescriptor()
                pass.colorAttachments[0].texture = target
                pass.colorAttachments[0].loadAction = .clear
                pass.colorAttachments[0].storeAction = .store
                let command = try XCTUnwrap(renderer.resources.queue.makeCommandBuffer())
                renderer.encode(command, pass: pass, elapsed: time)
                await withCheckedContinuation { continuation in
                    command.addCompletedHandler { _ in continuation.resume() }; command.commit()
                }
                XCTAssertNil(command.error)
                var bytes = [UInt8](repeating: 0, count: 144 * 144 * 4)
                target.getBytes(&bytes, bytesPerRow: 144 * 4, from: MTLRegionMake2D(0, 0, 144, 144), mipmapLevel: 0)
                let provider = try XCTUnwrap(CGDataProvider(data: Data(bytes) as CFData))
                let cg = try XCTUnwrap(CGImage(width: 144, height: 144, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 576,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: [.byteOrder32Little, CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)],
                    provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
                return UIImage(cgImage: cg)
            }
            let first = try await capture(0)
            let rotated = try await capture(renderer.style.rotationSeconds / 4)
            // Uranus's nearly featureless cloud map is not a reliable visual
            // rotation oracle; its signed period is tested separately.
            if body != .uranus {
                XCTAssertGreaterThan(try difference(first, rotated), 0.1, "Surface features must rotate in 3D")
            }
            thumbnails.append(first)
        }
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let gallery = UIGraphicsImageRenderer(size: CGSize(width: 640, height: 360), format: format).image { context in
            UIColor.black.setFill(); context.fill(CGRect(x: 0, y: 0, width: 640, height: 360))
            for (index, image) in thumbnails.enumerated() {
                let x = (index % 4) * 160, y = (index / 4) * 180
                image.draw(in: CGRect(x: x + 8, y: y, width: 144, height: 144))
                String(describing: bodies[index]).capitalized.draw(at: CGPoint(x: x + 30, y: y + 146), withAttributes: [.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 16)])
            }
        }
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Documentation/DesignReview/Planetarium/SelectionGlobes")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try XCTUnwrap(gallery.pngData()).write(to: directory.appendingPathComponent("globe-materials-dark.png"))
    }

    func testGPUStarTwinkleStability() async throws {
        let view = MTKView(frame: CGRect(x: 0, y: 0, width: 240, height: 480))
        let renderer = try PlanetariumMetalRenderer(view: view)
        view.isPaused = true
        renderer.uniforms.forward = SIMD4(0.6, 0.8, 0, 0)
        renderer.uniforms.right = SIMD4(0, 0, 1, 0)
        renderer.uniforms.up = SIMD4(-0.8, 0.6, 0, 0)
        let size = CGSize(width: 240, height: 480)
        let faint = Star(id: 1, magnitude: 6, coordinate: SIMD3(0.8, 0.6, 0), spectralClass: "G")
        let empty = try await renderer.snapshot(size: size, scale: 1, time: 0)
        renderer.setFaintStars([faint])
        let first = try await renderer.snapshot(size: size, scale: 1, time: 0)
        let later = try await renderer.snapshot(size: size, scale: 1, time: 0.37)
        XCTAssertNotEqual(try pixels(empty), try pixels(first), "The test star must actually render")
        XCTAssertEqual(try pixels(first), try pixels(later), "Unresolved faint stars must stay steady")
        renderer.setFaintStars([])
        let bright = Star(id: 2, magnitude: 0, coordinate: SIMD3(0.8, 0.6, 0), spectralClass: "G")
        let hidden = Star(id: 3, magnitude: 0, coordinate: SIMD3(-0.8, -0.6, 0), spectralClass: "G")
        renderer.setBrightStars([bright])
        let before = try await renderer.snapshot(size: size, scale: 1, time: 0)
        let twinkled = try await renderer.snapshot(size: size, scale: 1, time: 0.37)
        XCTAssertNotEqual(try pixels(before), try pixels(twinkled), "Bright-star scintillation remains subtle but active")
        renderer.setBrightStars([hidden, bright])
        let reordered = try await renderer.snapshot(size: size, scale: 1, time: 0.37)
        XCTAssertEqual(try pixels(twinkled), try pixels(reordered), "Culling must not reset a star's twinkle phase")
    }

    func testGPUFlowingBodyTrails() async throws {
        let view = MTKView(frame: CGRect(x: 0, y: 0, width: 600, height: 400))
        let renderer = try PlanetariumMetalRenderer(view: view)
        view.isPaused = true
        renderer.uniforms.east = SIMD4(1, 0, 0, 0)
        renderer.uniforms.zenith = SIMD4(0, 1, 0, 0)
        let samples: [(SIMD3<Float>, Double)?] = (-30...30).map {
            (simd_normalize(SIMD3(Float($0) / 50, 0.2, 1)), Double($0))
        }
        let vertices = PlanetariumController.flowingTrail(samples, color: SIMD3(0.75, 0.83, 0.96))
        XCTAssertEqual(vertices.count, 120)
        XCTAssertEqual(vertices.first?.profile.z, -30)
        XCTAssertEqual(vertices.last?.profile.z, 30)
        let baseline = try await renderer.snapshot(size: CGSize(width: 600, height: 400))
        renderer.setMotionTrails(vertices)
        let first = try await renderer.snapshot(size: CGSize(width: 600, height: 400), time: 0)
        let second = try await renderer.snapshot(size: CGSize(width: 600, height: 400), time: 0.7)
        XCTAssertGreaterThan(try difference(first, second), 0.005, "Highlight animates")
        let a = try pixels(baseline), b = try pixels(first)
        func coveredColumns(_ range: Range<Int>) -> Int {
            range.filter { x in
                (0..<400).contains { y in
                    (0..<3).contains { c in abs(Int(a[(y*600+x)*4+c])-Int(b[(y*600+x)*4+c])) > 8 }
                }
            }.count
        }
        XCTAssertGreaterThan(coveredColumns(140..<290), coveredColumns(310..<460) * 2,
                             "Past is continuous; future has separated dots")
        renderer.setMotionTrails([])
        let cleared = try await renderer.snapshot(size: CGSize(width: 600, height: 400))
        XCTAssertLessThan(try difference(baseline, cleared), 0.001)
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Documentation/DesignReview/Planetarium/BodyTrailFlow")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try first.pngData()!.write(to: folder.appendingPathComponent("past-solid-future-dotted.png"))
        let broken = PlanetariumController.flowingTrail([samples[0], samples[1], nil, samples[3], samples[4]], color: SIMD3(repeating: 1))
        XCTAssertEqual(broken.count, 4, "Never connect across an occultation")
    }

    func testGPUCachedStarCells() async throws {
        let catalog = try await AppStarCatalog.load()
        let tiers = PlanetariumStarTiers(stars: catalog.snapshot.stars)
        let view = MTKView(frame: CGRect(x: 0, y: 0, width: 440, height: 880))
        let renderer = try PlanetariumMetalRenderer(view: view)
        view.isPaused = true
        XCTAssertEqual(view.preferredFramesPerSecond, 60)
        let cells = tiers.visibleCells(forward: SIMD3(0, 0, 1), diagonalHalfAngle: 0.6)
        let stars = cells.flatMap { $0.stars(at: 6.5) }
        XCTAssertFalse(stars.isEmpty)
        renderer.setFaintStars(stars)
        let original = try await renderer.snapshot(size: CGSize(width: 440, height: 880))
        renderer.setFaintStarCells(cells, limit: 6.5)
        let cached = try await renderer.snapshot(size: CGSize(width: 440, height: 880))
        XCTAssertLessThan(try difference(original, cached), 0.002, "Caching preserves star rendering")
        let uploads = renderer.starCellUploadCount
        XCTAssertGreaterThan(uploads, 0)
        renderer.setFaintStarCells(cells, limit: 6.5)
        renderer.setFaintStarCells([], limit: 6.5)
        renderer.setFaintStarCells(cells, limit: 6.5)
        XCTAssertEqual(renderer.starCellUploadCount, uploads, "Revisiting sky cells does not reallocate/upload stars")
        for cell in tiers.cells {
            for limit in [6.5, 7.5, 9.0] {
                XCTAssertEqual(cell.stars(at: limit).map(\.id), cell.stars.filter { $0.magnitude <= limit }.map(\.id))
            }
        }
    }

    func testCameraUpdatesDoNotInvalidateScreen() throws {
        let controller = PlanetariumController()
        defer { controller.stop() }
        var updates = 0
        let subscription = controller.objectWillChange.sink { updates += 1 }
        defer { subscription.cancel() }
        controller.zoom(by: 0.9)
        controller.panBy(CGPoint(x: 20, y: 10))
        controller.navigation.bearing = 0.5
        controller.selectionState.value = .init(id: "test", name: "test", detail: "", coordinates: "")
        XCTAssertEqual(updates, 0, "Camera, arrow, and card updates must not invalidate the entire screen")
    }

    func testGPUCloseGalaxyGrain() async throws {
        let view = MTKView(frame: CGRect(x: 0, y: 0, width: 440, height: 880))
        let renderer = try PlanetariumMetalRenderer(view: view)
        view.isPaused = true
        renderer.uniforms.zenith = SIMD4(-0.05487556, -0.87343709, -0.48383502, 0)
        renderer.uniforms.east = SIMD4(0.49410943, -0.44482963, 0.74698224, 0)
        renderer.uniforms.north = SIMD4(-0.86766615, -0.19807637, 0.45598378, 0)
        let d = PlanetariumGeometry.direction(azimuth: 90, elevation: 65)
        let right = simd_normalize(simd_cross(d, SIMD3<Float>(0, 1, 0)))
        renderer.uniforms.forward = SIMD4(d, 0)
        renderer.uniforms.right = SIMD4(right, 0)
        renderer.uniforms.up = SIMD4(simd_normalize(simd_cross(right, d)), 0)
        renderer.uniforms.viewport.z = tan(8 * .pi / 360)
        renderer.uniforms.viewport.w = 8
        let image = try await renderer.snapshot(size: CGSize(width: 440, height: 880), scale: 1)
        let bytes = try pixels(image)
        var grain = 0.0, count = 0.0
        for y in 2..<878 { for x in 2..<438 { for c in 0..<3 {
            func value(_ x: Int, _ y: Int) -> Double { Double(bytes[(y*440+x)*4+c]) }
            let mean = (value(x-2,y)+value(x+2,y)+value(x,y-2)+value(x,y+2))*0.25
            grain += abs(value(x,y)-mean); count += 1
        }}}
        let label = (try? String(contentsOfFile: "/tmp/galaxy-grain-label", encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)) ?? "smooth"
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Documentation/DesignReview/Planetarium/GalaxyGrain")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try image.pngData()!.write(to: folder.appendingPathComponent("\(label)-8-degrees-dark.png"))
        try JSONSerialization.data(withJSONObject: ["fineGrain":grain/count]).write(to: folder.appendingPathComponent("\(label)-metrics.json"))
        print("Close galaxy spatial grain: \(grain/count)")
        // Original unfiltered close-up measured 1.176; keep magnified grain suppressed.
        XCTAssertLessThan(grain/count, 0.25)
    }

    func testGPUMilkyWaySamplingStability() async throws {
        let view = MTKView(frame: CGRect(x: 0, y: 0, width: 240, height: 480))
        let renderer = try PlanetariumMetalRenderer(view: view)
        view.isPaused = true
        // Place the galactic plane high above the horizon. No catalog stars,
        // atmosphere animation, water, labels, or sprites contaminate the metric.
        renderer.uniforms.zenith = SIMD4(-0.05487556, -0.87343709, -0.48383502, 0)
        renderer.uniforms.east = SIMD4(0.49410943, -0.44482963, 0.74698224, 0)
        renderer.uniforms.north = SIMD4(-0.86766615, -0.19807637, 0.45598378, 0)
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Documentation/DesignReview/Planetarium/GalaxyStability")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let label = (try? String(contentsOfFile: "/tmp/milkyway-filter-label", encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)) ?? "filtered"
        let size = CGSize(width: 240, height: 480)
        var residual = 0.0, spatial = 0.0
        var previousError: [Int]?
        for frame in 0..<8 {
            let direction = PlanetariumGeometry.direction(azimuth: 90 + Double(frame)*0.025, elevation: 65)
            let right = simd_normalize(simd_cross(direction, SIMD3<Float>(0, 1, 0)))
            renderer.uniforms.forward = SIMD4(direction, 0)
            renderer.uniforms.right = SIMD4(right, 0)
            renderer.uniforms.up = SIMD4(simd_normalize(simd_cross(right, direction)), 0)
            renderer.uniforms.viewport.z = tan(65 * .pi / 360)
            let native = try await renderer.snapshot(size: size, scale: 1, time: Float(frame))
            let high = try await renderer.snapshot(size: CGSize(width: 960, height: 1920), scale: 4, time: Float(frame))
            let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
            let reference = UIGraphicsImageRenderer(size: size, format: format).image { context in
                context.cgContext.interpolationQuality = .high
                high.draw(in: CGRect(origin: .zero, size: size))
            }
            let a = try pixels(native), b = try pixels(reference)
            let error = a.indices.filter { $0 % 4 != 3 }.map { Int(a[$0])-Int(b[$0]) }
            spatial += error.reduce(0.0) { $0 + Double(abs($1)) } / Double(error.count)
            if let previousError {
                residual += zip(error, previousError).reduce(0.0) { $0 + Double(abs($1.0-$1.1)) } / Double(error.count)
            }
            previousError = error
            if frame == 0 {
                try native.pngData()!.write(to: folder.appendingPathComponent("\(label)-native-dark.png"))
                try reference.pngData()!.write(to: folder.appendingPathComponent("\(label)-reference-dark.png"))
                let held = try await renderer.snapshot(size: size, scale: 1, time: 30)
                XCTAssertEqual(try difference(native, held), 0, "The galaxy itself must not fluctuate with time")
            }
        }
        let metrics = ["spatialError": spatial/8, "temporalResidual": residual/7]
        try JSONSerialization.data(withJSONObject: metrics, options: .prettyPrinted).write(to: folder.appendingPathComponent("\(label)-metrics.json"))
        print("Milky Way sampling metrics: \(metrics)")
        XCTAssertLessThan(spatial/8, 0.42, "Filtering should remain close to a supersampled image")
        XCTAssertLessThan(residual/7, 0.21, "Subpixel camera motion must not revive unresolved grain")
    }

    func testGPUWaterSamplingAndTemporalStability() async throws {
        let view = MTKView(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
        let renderer = try PlanetariumMetalRenderer(view: view)
        view.isPaused = true
        let size = CGSize(width: 300, height: 600)
        let first = try await renderer.snapshot(size: size, scale: 1, time: 4)
        let high = try await renderer.snapshot(size: CGSize(width: 900, height: 1800), scale: 3, time: 4)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let downsampled = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            high.draw(in: CGRect(origin: .zero, size: size))
        }
        let lowPixels = try pixels(first), highPixels = try pixels(downsampled)
        // The first 35 water rows are the worst case for horizon undersampling.
        var error = 0.0
        for y in 300..<335 {
            for x in 0..<300 {
                for channel in 0..<3 {
                    let index = (y * 300 + x) * 4 + channel
                    error += Double(abs(Int(lowPixels[index]) - Int(highPixels[index])))
                }
            }
        }
        let horizonError = error / (35 * 300 * 3)
        XCTAssertLessThan(horizonError, 2.0, "Distant water should converge toward supersampled pixels, without moire")
        let nextFrame = try await renderer.snapshot(size: size, scale: 1, time: 4 + 1.0 / 30)
        let later = try await renderer.snapshot(size: size, scale: 1, time: 5)
        XCTAssertLessThan(try difference(first, nextFrame), 0.6, "Waves must not sparkle between 30 Hz frames")
        XCTAssertGreaterThan(try difference(first, later), 0.01, "Filtered waves should still animate")
        try saveReview(first, "10-water-native-sampling")
        try saveReview(downsampled, "11-water-supersampled")
        print("Water GPU validation: horizon mean error = \(horizonError) / 255")
    }

    func testGPUStarVisibilityMatchesDaylightAndZoom() async throws {
        let view = MTKView(frame: CGRect(x: 0, y: 0, width: 240, height: 480))
        view.overrideUserInterfaceStyle = .dark
        let renderer = try PlanetariumMetalRenderer(view: view)
        view.isPaused = true
        renderer.uniforms.forward = SIMD4(0.6, 0.8, 0, 0)
        renderer.uniforms.right = SIMD4(0, 0, 1, 0)
        renderer.uniforms.up = SIMD4(-0.8, 0.6, 0, 0)
        renderer.uniforms.sun = SIMD4(0, 0.15, -0.99, 9)
        let size = CGSize(width: 240, height: 480)
        for (magnitude, daylight, fov, visible) in [
            (0.0, Float(0.9), 65.0, true),
            (6.0, Float(0.9), 65.0, false),
            (6.0, Float(0.9), 10.0, true),
            (0.0, Float(1), 10.0, false),
            (6.0, Float(0), 65.0, true)
        ] {
            renderer.uniforms.effects.x = daylight
            renderer.uniforms.viewport.w = Float(fov)
            renderer.setBrightStars([])
            let empty = try pixels(await renderer.snapshot(size: size, scale: 1))
            renderer.setBrightStars([Star(id: 1, magnitude: magnitude,
                coordinate: SIMD3(0.8, 0.6, 0), spectralClass: "G")])
            let rendered = try pixels(await renderer.snapshot(size: size, scale: 1))
            XCTAssertEqual(empty != rendered, visible, "GPU visibility for mag \(magnitude), daylight \(daylight), FOV \(fov)")
            XCTAssertEqual(PlanetariumStarVisibility.isVisible(magnitude: magnitude, altitude: 0.8,
                fieldOfView: fov, daylight: daylight), visible)
        }
    }

    func testDaytimeStarLabelsAndSelectionMatchRendering() async throws {
        let fixture = try Fixture(catalog: await AppStarCatalog.load())
        let pass = try XCTUnwrap(fixture.passes.first)
        let date = try XCTUnwrap((0..<288).map { fixture.now.julianDate + Double($0) / 288 }.first {
            let sun = SkyChartAtmosphere.sun(observer: fixture.observer, julianDate: $0)
            return sun.elev > 8 && sun.elev < 10
        })
        let star = try XCTUnwrap(fixture.catalog.namedBrightStars.first {
            let position = azel(time: Date(julianDate: date), site: LatLon(fixture.observer),
                cele: RADec(PlanetariumEquatorialFrame(date: date).ofDate($0.coordinate)))
            return $0.magnitude < 2 && position.elev > 25 && position.elev < 75
        })
        let controller = PlanetariumController()
        controller.view.frame = CGRect(x: 0, y: 0, width: 440, height: 956)
        controller.view.overrideUserInterfaceStyle = .dark
        controller.configure(context: .init(passIndex: 0, satelliteInfo: fixture.info, satelliteCommonName: "ISS",
            category: .iss, julianDateRange: fixture.range, observer: fixture.observer, passSnapshots: pass,
            starManager: fixture.catalog, julianDateProvider: { date }), julianDate: date)
        defer { controller.stop() }
        controller.setMotionEnabled(false)
        controller.setOverlays(labels: true, lines: false)
        controller.view.isPaused = true
        let renderer = try XCTUnwrap(controller.renderer)
        XCTAssertGreaterThan(renderer.uniforms.sun.w, 0)
        XCTAssertGreaterThan(renderer.uniforms.effects.x, 0.85, "Exercise the former daytime tap cutoff")
        let position = azel(time: Date(julianDate: date), site: LatLon(fixture.observer),
            cele: RADec(PlanetariumEquatorialFrame(date: date).ofDate(star.coordinate)))
        controller.pointCamera(azimuth: position.azim, elevation: position.elev)
        for _ in 0..<30 {
            renderer.beforeDraw?()
            if controller.visibleStarLabelIDs.contains(star.id) { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertTrue(controller.visibleStarLabelIDs.contains(star.id), "A rendered daytime star must be eligible for a name")
        controller.select(at: CGPoint(x: 220, y: 478))
        for _ in 0..<100 where controller.selection == nil { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(controller.selection?.id, "star-\(star.id)")
        XCTAssertFalse(try XCTUnwrap(controller.selection).name.isEmpty)
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Documentation/DesignReview/Planetarium/DaytimeStars")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Let the label's entrance animation finish before recording evidence.
        try await Task.sleep(for: .milliseconds(500))
        let image = try await renderer.snapshot(size: CGSize(width: 1320, height: 2868), scale: 3)
        try image.pngData()!.write(to: directory.appendingPathComponent("daytime-star-selected-dark.png"))
        let camera = ["date": date, "azimuth": position.azim, "elevation": position.elev, "fov": controller.fieldOfView]
        try JSONEncoder().encode(camera).write(to: directory.appendingPathComponent("camera.json"))
        controller.setOverlays(labels: false, lines: false)
        renderer.beforeDraw?()
        XCTAssertEqual(controller.visibleStarLabelCount, 0)
        controller.clearSelection()
        controller.select(at: CGPoint(x: 220, y: 478))
        for _ in 0..<100 where controller.selection == nil { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(controller.selection?.id, "star-\(star.id)", "Hiding labels must not disable selection")

        controller.clearSelection()
        controller.setOverlays(labels: true, lines: false)
        renderer.uniforms.effects.x = 1
        renderer.beforeDraw?()
        XCTAssertEqual(controller.visibleStarLabelCount, 0, "Fully faded stars must not leave labels")
        controller.select(at: CGPoint(x: 220, y: 478))
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertNil(controller.selection, "Fully faded stars must not leave invisible tap targets")
    }

    func testGPUStarNameVisibility() async throws {
        let fixture = try Fixture(catalog: await AppStarCatalog.load())
        let pass = try XCTUnwrap(fixture.passes.first { $0.pass.visibility == .visible && $0.pass.sunElevationAtTransit < -10 })
        let date = pass.pass.culmination.julianDate
        let controller = PlanetariumController()
        controller.view.frame = CGRect(x: 0, y: 0, width: 440, height: 956)
        controller.configure(context: .init(passIndex: 0, satelliteInfo: fixture.info, satelliteCommonName: "ISS",
            category: .iss, julianDateRange: fixture.range, observer: fixture.observer, passSnapshots: pass,
            starManager: fixture.catalog, julianDateProvider: { date }), julianDate: date)
        defer { controller.stop() }
        controller.setMotionEnabled(false)
        controller.setOverlays(labels: true, lines: true)
        controller.view.isPaused = true
        let renderer = try XCTUnwrap(controller.renderer)
        let star = try XCTUnwrap(fixture.catalog.namedBrightStars.first {
            let c = azel(time: Date(julianDate: date), site: LatLon(fixture.observer), cele: RADec(PlanetariumEquatorialFrame(date: date).ofDate($0.coordinate)))
            return c.elev > 25 && c.elev < 75
        })
        let position = azel(time: Date(julianDate: date), site: LatLon(fixture.observer), cele: RADec(PlanetariumEquatorialFrame(date: date).ofDate(star.coordinate)))
        controller.pointCamera(azimuth: position.azim, elevation: position.elev)
        controller.zoom(by: 20 / controller.fieldOfView)
        for _ in 0..<15 {
            renderer.beforeDraw?()
            try await Task.sleep(for: .milliseconds(100))
        }
        let close = try await renderer.snapshot(size: CGSize(width: 1320, height: 2868), scale: 3)
        XCTAssertGreaterThan(controller.visibleStarLabelCount, 0)
        XCTAssertLessThanOrEqual(controller.visibleStarLabelCount, 7)
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Documentation/DesignReview/Planetarium/Typography")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try close.pngData()!.write(to: folder.appendingPathComponent("zoomed-star-names-dark.png"))
        // A small viewport with none of the global top 50 must still name its own bright stars.
        let topIDs = Set(fixture.catalog.namedBrightStars.map(\.id))
        let localStar = try XCTUnwrap(fixture.catalog.snapshot.stars.first {
            guard !topIDs.contains($0.id), $0.magnitude > 3, $0.magnitude < 5 else { return false }
            let p = azel(time: Date(julianDate: date), site: LatLon(fixture.observer), cele: RADec(PlanetariumEquatorialFrame(date: date).ofDate($0.coordinate)))
            return p.elev > 30 && p.elev < 70
        })
        let localPosition = azel(time: Date(julianDate: date), site: LatLon(fixture.observer), cele: RADec(PlanetariumEquatorialFrame(date: date).ofDate(localStar.coordinate)))
        controller.pointCamera(azimuth: localPosition.azim, elevation: localPosition.elev)
        controller.zoom(by: 0.5 / controller.fieldOfView)
        for _ in 0..<30 {
            renderer.beforeDraw?()
            if controller.visibleStarLabelIDs.contains(localStar.id) { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertTrue(controller.visibleStarLabelIDs.contains(localStar.id),
                      "Zoom must label locally bright stars outside the global top 50")
        XCTAssertLessThanOrEqual(controller.visibleStarLabelCount, 7)
        // Exercise the actual renderer/candidate refresh, not only the layout helper.
        // Small moving viewports must retain their central readable star across refreshes.
        for frame in 0..<120 {
            let jitter = sin(Double(frame) * 0.18) * 0.002
            controller.pointCamera(azimuth: localPosition.azim + jitter, elevation: localPosition.elev + jitter)
            renderer.beforeDraw?()
            XCTAssertTrue(controller.visibleStarLabelIDs.contains(localStar.id), "A readable incumbent flickered during camera jitter")
            try await Task.sleep(for: .milliseconds(20))
        }
        let localImage = try await renderer.snapshot(size: CGSize(width: 1320, height: 2868), scale: 3)
        try localImage.pngData()!.write(to: folder.appendingPathComponent("viewport-star-names-dark.png"))
        controller.zoom(by: 100 / controller.fieldOfView)
        renderer.beforeDraw?()
        XCTAssertLessThanOrEqual(controller.visibleStarLabelCount, 3)
        controller.setOverlays(labels: false, lines: false)
        renderer.beforeDraw?()
        XCTAssertEqual(controller.visibleStarLabelCount, 0)
        controller.setOverlays(labels: true, lines: true)
        for hour in 1...24 {
            let next = date + Double(hour) / 24
            if SkyChartAtmosphere.sun(observer: fixture.observer, julianDate: next).elev >= 12 {
                controller.updateTime(next)
                renderer.beforeDraw?()
                XCTAssertEqual(controller.visibleStarLabelCount, 0)
                return
            }
        }
        XCTFail("Fixture must include daylight")
    }

    func testGPUZoomRotationOverlaysAndSatelliteTime() async throws {
        let fixture = try Fixture(catalog: await AppStarCatalog.load())
        let pass = try XCTUnwrap(fixture.passes.first { $0.pass.visibility == .visible && $0.pass.culmination.elev > 40 })
        let date = pass.pass.culmination.julianDate
        let controller = PlanetariumController()
        controller.view.frame = CGRect(x: 0, y: 0, width: 440, height: 956)
        controller.configure(context: .init(passIndex: 0, satelliteInfo: fixture.info, satelliteCommonName: "ISS",
            category: .iss, julianDateRange: fixture.range, observer: fixture.observer, passSnapshots: pass,
            starManager: fixture.catalog, julianDateProvider: { date }), julianDate: date)
        defer { controller.stop() }
        let renderer = try XCTUnwrap(controller.renderer)
        controller.view.isPaused = true
        var clock = 0.0
        controller.animationClock = { clock }
        func settle() {
            for _ in 0..<24 { clock += 0.05; renderer.beforeDraw?() }
        }

        let size = CGSize(width: 440, height: 956)
        controller.focusSatellite()
        settle()
        let first = try await renderer.snapshot(size: size, scale: 1)
        controller.updateTime(date + 20 / 86400)
        let later = try await renderer.snapshot(size: size, scale: 1)
        XCTAssertGreaterThan(try difference(first, later), 0.05, "Satellite propagation must move the indicator")
        controller.setOverlays(labels: false, lines: false)
        settle()
        let clean = try await renderer.snapshot(size: size, scale: 1)
        XCTAssertGreaterThan(try difference(later, clean), 0.15, "Both overlay toggles affect rendered pixels")
        // Daylight hides both overlays without changing the user's preferences.
        let daytime = try XCTUnwrap((0..<24).map { date + Double($0) / 24 }.first {
            SkyChartAtmosphere.sun(observer: fixture.observer, julianDate: $0).elev > 20
        })
        controller.updateTime(daytime)
        controller.pointCamera(azimuth: 0, elevation: 35)
        controller.setOverlays(labels: true, lines: true)
        settle()
        let dayEnabled = try await renderer.snapshot(size: size, scale: 1, time: 4)
        XCTAssertNil(controller.constellationFocus.active)
        controller.setOverlays(labels: false, lines: false)
        settle()
        let dayDisabled = try await renderer.snapshot(size: size, scale: 1, time: 4)
        XCTAssertLessThan(try difference(dayEnabled, dayDisabled), 0.001, "Daytime contains no constellation overlays")
        let evidence = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Documentation/DesignReview/Planetarium/Daytime")
        try FileManager.default.createDirectory(at: evidence, withIntermediateDirectories: true)
        try XCTUnwrap(dayEnabled.pngData()).write(to: evidence.appendingPathComponent("daytime-overlays-hidden-dark-ui.png"))
        controller.setOverlays(labels: true, lines: true)
        controller.updateTime(date)
        controller.focusSatellite()
        settle()
        XCTAssertNotNil(controller.constellationFocus.active, "Enabled constellations return after sunset")
        controller.setOverlays(labels: false, lines: false)
        controller.pointCamera(azimuth: 0, elevation: 20)
        settle()
        let north = try await renderer.snapshot(size: size, scale: 1)
        controller.pointCamera(azimuth: 360, elevation: 20)
        settle()
        let wrapped = try await renderer.snapshot(size: size, scale: 1)
        XCTAssertLessThan(try difference(north, wrapped), 0.02, "360° camera wrap is continuous")
        controller.zoom(by: 0.000001)
        XCTAssertEqual(controller.fieldOfView, 0.005)
        _ = try await renderer.snapshot(size: size, scale: 1)
        controller.zoom(by: 100000)
        XCTAssertEqual(controller.fieldOfView, 100)
        controller.setActive(false)
        XCTAssertTrue(controller.view.isPaused)
        controller.setActive(true)
        XCTAssertFalse(controller.view.isPaused)
        controller.stop()
        XCTAssertTrue(controller.view.isPaused)
    }

    func testGPUReviewGallery() async throws {
        let fixture = try Fixture(catalog: await AppStarCatalog.load())
        let pass = try XCTUnwrap(fixture.passes.first { $0.pass.visibility == .visible && $0.pass.sunElevationAtTransit < -10 })
        let date = pass.pass.culmination.julianDate
        let controller = PlanetariumController()
        controller.view.frame = CGRect(x: 0, y: 0, width: 440, height: 956)
        controller.configure(context: .init(passIndex: 0, satelliteInfo: fixture.info, satelliteCommonName: "ISS",
            category: .iss, julianDateRange: fixture.range, observer: fixture.observer, passSnapshots: pass,
            starManager: fixture.catalog, julianDateProvider: { date }), julianDate: date)
        defer { controller.stop() }
        let renderer = try XCTUnwrap(controller.renderer)
        controller.view.isPaused = true
        var clock = 0.0
        controller.animationClock = { clock }
        func settle() {
            for _ in 0..<24 { clock += 0.05; renderer.beforeDraw?() }
        }

        let size = CGSize(width: 880, height: 1912)
        // The galactic center, registered against the same observer and epoch.
        let center = SIMD3<Double>(-0.05487556, -0.87343709, -0.48383502)
        let core = azel(time: Date(julianDate: date), site: LatLon(fixture.observer), cele: RADec(center))
        controller.pointCamera(azimuth: core.azim, elevation: core.elev)
        settle()
        try saveReview(try await renderer.snapshot(size: size, scale: 2), "01-milky-way-wide-dark")
        controller.zoom(by: 0.35)
        try await Task.sleep(for: .milliseconds(500))
        settle()
        try saveReview(try await renderer.snapshot(size: size, scale: 2), "02-milky-way-zoom-dark")
        controller.zoom(by: 65 / controller.fieldOfView)
        controller.setOverlays(labels: false, lines: false)
        for azimuth in stride(from: 0.0, to: 360, by: 90) {
            controller.pointCamera(azimuth: azimuth, elevation: 5)
            settle()
            try saveReview(try await renderer.snapshot(size: size, scale: 2), "03-horizon-\(Int(azimuth))-dark")
        }
        for elevation in [-20.0, -60, -89] {
            controller.pointCamera(azimuth: 90, elevation: elevation)
            settle()
            try saveReview(try await renderer.snapshot(size: size, scale: 2), "water-\(Int(-elevation))-dark")
        }
        let moon = MoonAppearance.coordinate(julianDate: date, observer: fixture.observer)
        controller.pointCamera(azimuth: moon.azim, elevation: moon.elev)
        controller.zoom(by: 0.35)
        settle()
        try saveReview(try await renderer.snapshot(size: size, scale: 2), "04-moon-dark")
        // Noon sky in the dark-mode planetarium: confirm sun / atmosphere pipeline.
        for hour in 0..<24 {
            let day = date + Double(hour) / 24
            let sun = SkyChartAtmosphere.sun(observer: fixture.observer, julianDate: day)
            if sun.elev > 20 {
                controller.updateTime(day)
                controller.zoom(by: 65 / controller.fieldOfView)
                controller.pointCamera(azimuth: sun.azim - 12, elevation: sun.elev - 8)
                settle()
                try saveReview(try await renderer.snapshot(size: size, scale: 2), "05-atmosphere-and-flare-dark-ui")
                return
            }
        }
        XCTFail("Expected a daytime epoch")
    }
}

extension PlanetariumTests {
    private func regionalViewport(longitude: Double, latitude: Double, roll: Double = 0,
                                  fov: Double = 20, aspect: Double = 0.46) -> PlanetariumStarViewport {
        let a = longitude * .pi / 180, e = latitude * .pi / 180, r = roll * .pi / 180
        let forward = SIMD3<Float>(Float(cos(e)*cos(a)), Float(cos(e)*sin(a)), Float(sin(e)))
        let right = SIMD3<Float>(Float(-sin(a)), Float(cos(a)), 0)
        let up = simd_cross(forward, right)
        return .init(forward: forward, right: right * Float(cos(r)) + up * Float(sin(r)),
                     up: up * Float(cos(r)) - right * Float(sin(r)), fieldOfView: fov, aspect: aspect)
    }

    func testRegionalQueriesCoverViewportAndDeduplicate() async throws {
        // Full-sky loading is an independent TEST oracle, never the production deep-loading path.
        let all = try await StarCatalog().snapshot(maximumMagnitude: 9).stars.filter { $0.magnitude > 6.5 }
        let catalog = PlanetariumRegionalStarCatalog()
        let cases: [(Double, Double, Double, Double, Double, Double)] = [
            (0, 0, 0, 44, 0.46, 7.5), (359.9, 0, 30, 24, 0.46, 9),
            (179.9, 0, 70, 24, 2.2, 9), (0, 90, 0, 20, 0.46, 9),
            (130, -90, 130, 20, 2.2, 9), (47, 89.9, 90, 1, 0.46, 9),
            (280, -89.9, 35, 1, 2.2, 9), (125, 45, 47, 24, 0.46, 9)
        ]
        var measurements: [[String: Double]] = []
        for (longitude, latitude, roll, fov, aspect, limit) in cases {
            let viewport = regionalViewport(longitude: longitude, latitude: latitude, roll: roll, fov: fov, aspect: aspect)
            let keys = try await catalog.regions(in: viewport.padded(), magnitude: limit)
            XCTAssertEqual(Set(keys).count, keys.count)
            XCTAssertLessThan(keys.count, 1000, "A viewport must not request the whole sky")
            var loaded: [Star] = []
            for offset in stride(from: 0, to: keys.count, by: 8) {
                loaded += try await catalog.load(Array(keys[offset..<min(offset + 8, keys.count)])).flatMap(\.stars)
            }
            let ids = Set(loaded.map(\.id))
            XCTAssertEqual(ids.count, loaded.count, "Cells and magnitude layers must not duplicate stars")
            XCTAssertTrue(loaded.allSatisfy { $0.magnitude > 6.5 && $0.magnitude <= limit })
            // Independent pinhole projection; do not reuse the region intersection predicate.
            let expected = all.filter { star in
                guard star.magnitude <= limit else { return false }
                let d = simd_normalize(star.coordinate), z = simd_dot(d, viewport.forward)
                return z > 0 && abs(simd_dot(d, viewport.right)) <= z * tan(viewport.horizontalHalfAngle) &&
                    abs(simd_dot(d, viewport.up)) <= z * tan(viewport.verticalHalfAngle)
            }
            XCTAssertTrue(Set(expected.map(\.id)).isSubset(of: ids), "Missing viewport stars at \(longitude), \(latitude), roll \(roll)")
            measurements.append(["loadedAdditionalStars": Double(loaded.count), "visibleAdditionalStars": Double(expected.count), "allSkyAdditionalStars": Double(all.count), "queriedCells": Double(keys.count), "fieldOfView": fov, "aspect": aspect])
            print("REGIONAL stars: loaded=\(loaded.count) visible=\(expected.count) global=\(all.count) cells=\(keys.count) FOV=\(fov)")
        }
        try JSONEncoder().encode(measurements).write(to: URL(fileURLWithPath: "/tmp/satellite-regional-loading.json"))
        // Target a real faint star at telescope zoom and exactly on viewport edges/corners.
        let target = try XCTUnwrap(all.first { $0.magnitude > 8 })
        let d = simd_normalize(target.coordinate)
        let longitude = atan2(d.y, d.x) * 180 / .pi, latitude = asin(d.z) * 180 / .pi
        for offset in [-0.004, 0.0, 0.004] {
            let view = regionalViewport(longitude: longitude + offset, latitude: latitude, fov: 0.01, aspect: 2.2)
            let keys = try await catalog.regions(in: view, magnitude: 9)
            let stars = try await catalog.load(keys).flatMap(\.stars)
            XCTAssertTrue(stars.contains { $0.id == target.id }, "Sub-cell fields of view must retain stars")
        }
    }

    func testRegionalCacheCancellationAndBounds() async throws {
        let catalog = PlanetariumRegionalStarCatalog(cellBudget: 32, starBudget: 1000)
        let view = regionalViewport(longitude: 0, latitude: 30, fov: 10)
        let keys = try await catalog.regions(in: view, magnitude: 9)
        let firstKeys = Array(keys.prefix(8))
        let first = try await catalog.load(firstKeys)
        let queryCount = await catalog.queryCount
        let repeatLoad = try await catalog.load(firstKeys)
        let repeatedQueries = await catalog.queryCount
        XCTAssertEqual(first.flatMap(\.stars).map(\.id), repeatLoad.flatMap(\.stars).map(\.id))
        XCTAssertEqual(queryCount, repeatedQueries, "Revisiting cached (including empty) cells does no SQLite reads")
        let cancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await catalog.load(keys)
        }
        do { _ = try await cancelled.value; XCTFail("Cancelled requests must stop before querying") }
        catch is CancellationError { }
        let afterCancellation = await catalog.queryCount
        XCTAssertEqual(afterCancellation, queryCount)
        for longitude in stride(from: 0.0, through: 300, by: 60) {
            let region = try await catalog.regions(in: regionalViewport(longitude: longitude, latitude: 0), magnitude: 9)
            _ = try await catalog.load(region)
        }
        let cellCount = await catalog.cachedCellCount, starCount = await catalog.cachedStarCount
        XCTAssertLessThanOrEqual(cellCount, 32)
        XCTAssertLessThanOrEqual(starCount, 1000)
    }

    func testRegionalViewportReuseCoversRollZoomAndSeams() throws {
        let index = try PlanetariumStarRegionIndex()
        XCTAssertEqual(index.cells.count, 122 + 842 + 5882)
        XCTAssertEqual(Set(index.cells.map(\.id)).count, index.cells.count)
        for latitude in [-90.0, 0, 90] {
            let view = regionalViewport(longitude: 359.9, latitude: latitude, fov: 20)
            let padded = view.padded()
            XCTAssertTrue(padded.contains(view))
            XCTAssertTrue(padded.contains(regionalViewport(longitude: 0.1, latitude: latitude, fov: 20)))
            XCTAssertFalse(padded.contains(regionalViewport(longitude: 359.9, latitude: latitude, roll: 90, fov: 20)))
            XCTAssertFalse(padded.contains(regionalViewport(longitude: 359.9, latitude: latitude, fov: 30)))
            let rotated = regionalViewport(longitude: 359.9, latitude: latitude, roll: 90, fov: 20)
            XCTAssertTrue(rotated.padded().contains(rotated))
        }
    }
}

@MainActor
extension PlanetariumTests {
    func testRegionalControllerRejectsObsoleteLoads() async throws {
        let fixture = try Fixture(catalog: await AppStarCatalog.load())
        let pass = try XCTUnwrap(fixture.passes.first)
        let controller = PlanetariumController()
        controller.view.frame = CGRect(x: 0, y: 0, width: 440, height: 956)
        controller.configure(context: .init(passIndex: 0, satelliteInfo: fixture.info, satelliteCommonName: "ISS",
            category: .iss, julianDateRange: fixture.range, observer: fixture.observer, passSnapshots: pass,
            starManager: fixture.catalog, julianDateProvider: { fixture.now.julianDate }), julianDate: fixture.now.julianDate)
        defer { controller.stop() }
        controller.setMotionEnabled(false)
        controller.view.isPaused = true
        controller.zoom(by: 10 / controller.fieldOfView)
        for azimuth in stride(from: 0.0, through: 300, by: 30) {
            controller.pointCamera(azimuth: azimuth, elevation: 40)
            controller.renderer?.beforeDraw?()
            await Task.yield()
        }
        controller.pointCamera(azimuth: 200, elevation: 45)
        controller.renderer?.beforeDraw?()
        for _ in 0..<300 {
            if !controller.requestedStarRegions.isEmpty && controller.loadedStarRegions == Set(controller.requestedStarRegions) { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertFalse(controller.requestedStarRegions.isEmpty)
        XCTAssertEqual(controller.loadedStarRegions, Set(controller.requestedStarRegions), "Only the final camera request can publish")
        XCTAssertEqual(controller.renderedStarIDs.count, Set(controller.renderedStarIDs).count)
        let renderer = try XCTUnwrap(controller.renderer)
        let u = renderer.uniforms
        func eq(_ v: SIMD4<Float>) -> SIMD3<Float> {
            v.x * SIMD3(u.east.x, u.east.y, u.east.z) + v.y * SIMD3(u.zenith.x, u.zenith.y, u.zenith.z)
                - v.z * SIMD3(u.north.x, u.north.y, u.north.z)
        }
        let finalView = PlanetariumStarViewport(forward: eq(u.forward), right: eq(u.right), up: eq(u.up),
            fieldOfView: controller.fieldOfView, aspect: 440.0 / 956)
        let expectedKeys = try await controller.regionalCatalog.regions(in: finalView.padded(), magnitude: 9)
        XCTAssertEqual(Set(expectedKeys), controller.loadedStarRegions, "The last camera, not a cancelled camera, supplies the cells")
        let uploads = renderer.regionalUploadCount
        for _ in 0..<30 { renderer.beforeDraw?() }
        XCTAssertEqual(renderer.regionalUploadCount, uploads, "Steady views do not upload again")
        controller.setActive(false)
        controller.setActive(true)
        controller.zoom(by: 65 / controller.fieldOfView)
        renderer.beforeDraw?()
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertTrue(controller.loadedStarRegions.isEmpty)
        XCTAssertTrue(controller.requestedStarRegions.isEmpty, "Zooming out after resume must remove deeper tiers")
    }
}

@MainActor
extension PlanetariumTests {
    func testGPURegionalBuffersMatchFlatRenderingAndEvict() async throws {
        let view = MTKView(frame: CGRect(x: 0, y: 0, width: 240, height: 480))
        view.overrideUserInterfaceStyle = .dark
        let renderer = try PlanetariumMetalRenderer(view: view)
        view.isPaused = true
        renderer.uniforms.forward = SIMD4(0.6, 0.8, 0, 0)
        renderer.uniforms.right = SIMD4(0, 0, 1, 0)
        renderer.uniforms.up = SIMD4(-0.8, 0.6, 0, 0)
        renderer.uniforms.viewport.w = 10
        let size = CGSize(width: 240, height: 480)
        let star = Star(id: 1, magnitude: 7, coordinate: SIMD3(0.8, 0.6, 0), spectralClass: "G")
        renderer.setFaintStars([star])
        let flat = try await renderer.snapshot(size: size, scale: 1)
        renderer.setFaintStars([])
        let region = PlanetariumStarRegion(key: .init(cell: 1, magnitude: 9), stars: [star])
        renderer.setRegionalStars([region])
        let cached = try await renderer.snapshot(size: size, scale: 1)
        XCTAssertEqual(try pixels(flat), try pixels(cached), "Regional buffers must preserve the exact star rendering")
        let uploads = renderer.regionalUploadCount
        renderer.setRegionalStars([])
        renderer.setRegionalStars([region])
        XCTAssertEqual(renderer.regionalUploadCount, uploads)
        for id in 2...300 {
            renderer.setRegionalStars([.init(key: .init(cell: UInt64(id), magnitude: 9), stars: [star])])
        }
        XCTAssertLessThanOrEqual(renderer.regionalBufferCount, 256)
        let afterEviction = try await renderer.snapshot(size: size, scale: 1)
        XCTAssertEqual(try pixels(flat), try pixels(afterEviction), "Eviction must never remove an active draw buffer")
    }
}
