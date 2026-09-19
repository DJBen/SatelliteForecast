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
        let star = try XCTUnwrap(catalog.snapshot.stars.first { star in
            let position = azel(time: Date(julianDate: date), site: LatLon(fixture.observer), cele: RADec(star.coordinate))
            return star.magnitude < 3 && position.elev > 20 && position.elev < 75
        })
        let coordinate = azel(time: Date(julianDate: date), site: LatLon(fixture.observer), cele: RADec(star.coordinate))
        controller.pointCamera(azimuth: coordinate.azim, elevation: coordinate.elev)
        controller.select(at: CGPoint(x: 220, y: 478))
        XCTAssertNil(controller.selection, "No provisional star card before metadata is ready")
        for _ in 0..<100 where controller.selection == nil { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(controller.selection?.id, "star-\(star.id)")
        let resolved = controller.selection
        controller.select(at: CGPoint(x: 220, y: 478))
        XCTAssertEqual(controller.selection, resolved, "Keep the ready card during a replacement lookup")
        controller.clearSelection()
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertNil(controller.selection, "Cancelled lookup must not resurrect a dismissed card")
        controller.clearSelection()
        XCTAssertNil(controller.selection)
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
        try "ready".write(toFile: marker + "-ready", atomically: true, encoding: .utf8)
        for _ in 0..<3000 {
            if !FileManager.default.fileExists(atPath: marker) { return }
            let commandURL = URL(fileURLWithPath: "/tmp/planetarium-camera.json")
            if let data = try? Data(contentsOf: commandURL),
               let values = try? JSONSerialization.jsonObject(with: data) as? [String: Double] {
                controller.setMotionEnabled(false)
                controller.pointCamera(azimuth: values["azimuth"] ?? 90, elevation: values["elevation"] ?? 5)
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
        controller.zoom(by: 0.0001)
        XCTAssertEqual(controller.fieldOfView, 12)
        _ = try await renderer.snapshot(size: size, scale: 1)
        controller.zoom(by: 10000)
        XCTAssertEqual(controller.fieldOfView, 100)
        controller.setActive(false, gyroscope: true)
        XCTAssertTrue(controller.view.isPaused)
        controller.setActive(true, gyroscope: false)
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
