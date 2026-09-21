import SwiftUI
import MetalKit
import SolarSystem

/// NASA rotation periods, scaled to the requested 24 hours = 10 seconds.
/// Negative periods preserve retrograde rotation. Earth is exactly 10 seconds.
struct PlanetariumGlobeStyle {
    let index: Float
    let texture: String
    let rotationHours: Double
    let tilt: Float
    init?(body: SolarSystemBody) {
        switch body {
        case .mercury: (index, texture, rotationHours, tilt) = (0, "mercury", 1407.6, 0.03)
        case .venus: (index, texture, rotationHours, tilt) = (1, "venus_atmosphere", -5832.5, 2.6)
        case .earth: (index, texture, rotationHours, tilt) = (2, "earth_daymap", 24, 23.4)
        case .mars: (index, texture, rotationHours, tilt) = (3, "mars", 24.6, 25.2)
        case .jupiter: (index, texture, rotationHours, tilt) = (4, "jupiter", 9.9, 3.1)
        case .saturn: (index, texture, rotationHours, tilt) = (5, "saturn", 10.7, 26.7)
        case .uranus: (index, texture, rotationHours, tilt) = (6, "uranus", -17.2, 82.2)
        case .neptune: (index, texture, rotationHours, tilt) = (7, "neptune", 16.1, 28.3)
        default: return nil
        }
    }
    var rotationSeconds: Double { abs(rotationHours) / 24 * 10 }
    func angle(at elapsed: Double) -> Float {
        Float((elapsed / (rotationHours / 24 * 10)).truncatingRemainder(dividingBy: 1) * 2 * .pi)
    }
}

struct PlanetariumGlobe: UIViewRepresentable {
    let body: SolarSystemBody
    var appearance: (() -> PlanetariumPlanetAppearance?)? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeCoordinator() -> PlanetariumGlobeRenderer? { try? PlanetariumGlobeRenderer(body: body) }
    func makeUIView(context: Context) -> MTKView {
        let view = PlanetariumGlobeSurface(frame: .zero, device: context.coordinator?.resources.device)
        view.colorPixelFormat = .bgra8Unorm_srgb
        view.clearColor = MTLClearColorMake(0, 0, 0, 0)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.preferredFramesPerSecond = 30
        view.isUserInteractionEnabled = false
        view.delegate = context.coordinator
        return view
    }
    func updateUIView(_ view: MTKView, context: Context) {
        context.coordinator?.setBody(body)
        context.coordinator?.appearanceProvider = appearance
        context.coordinator?.animationsEnabled = !reduceMotion
        (view as? PlanetariumGlobeSurface)?.reduceMotion = reduceMotion
    }
    static func dismantleUIView(_ view: MTKView, coordinator: PlanetariumGlobeRenderer?) {
        view.isPaused = true
        view.delegate = nil
    }
}

/// Uses the native window lifecycle, including hosting in auxiliary windows.
/// A paused miniature still renders a first frame after layout.
private final class PlanetariumGlobeSurface: MTKView {
    var reduceMotion = false { didSet { refreshPlayback() } }
    private var observers: [NSObjectProtocol] = []
    override init(frame: CGRect, device: MTLDevice?) {
        super.init(frame: frame, device: device)
        for name in [UIApplication.didBecomeActiveNotification, UIApplication.willResignActiveNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                guard let self else { return }
                if note.name == UIApplication.willResignActiveNotification { self.isPaused = true }
                else { self.refreshPlayback() }
            })
        }
    }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { observers.forEach(NotificationCenter.default.removeObserver) }
    override func didMoveToWindow() { super.didMoveToWindow(); refreshPlayback() }
    override func layoutSubviews() {
        super.layoutSubviews()
        if isPaused && window != nil { draw() }
    }
    func refreshPlayback() {
        isPaused = window == nil || UIApplication.shared.applicationState != .active || reduceMotion
        if isPaused && window != nil { setNeedsLayout() }
    }
}

/// Small orthographic 3D sphere rendered in Metal. Resources are shared across
/// selections; only the selected 48-point view draws, with no mesh or scene graph.
final class PlanetariumGlobeRenderer: NSObject, MTKViewDelegate {
    final class Resources {
        let device: MTLDevice
        let queue: MTLCommandQueue
        let pipeline: MTLRenderPipelineState
        let textures: [String: MTLTexture]
        init() throws {
            guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
                throw NSError(domain: "PlanetariumGlobe", code: 1)
            }
            self.device = device; self.queue = queue
            let library = try device.makeDefaultLibrary(bundle: .module)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "background_vertex")
            descriptor.fragmentFunction = library.makeFunction(name: "planet_icon_fragment")
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
            pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
            let loader = MTKTextureLoader(device: device)
            var loaded: [String: MTLTexture] = [:]
            for name in ["mercury", "venus_atmosphere", "earth_daymap", "earth_clouds", "mars", "jupiter", "saturn", "uranus", "neptune"] {
                guard let url = Bundle.module.url(forResource: "planet-icon-" + name, withExtension: "jpg") else {
                    throw NSError(domain: "PlanetariumGlobe", code: 2)
                }
                loaded[name] = try loader.newTexture(URL: url, options: [.SRGB: true, .generateMipmaps: true])
            }
            textures = loaded
        }
    }
    private static let shared = Result { try Resources() }
    let resources: Resources
    private(set) var style: PlanetariumGlobeStyle
    var animationsEnabled = true
    var appearanceProvider: (() -> PlanetariumPlanetAppearance?)?
    private let startTime = CACurrentMediaTime()
    private let inFlight = DispatchSemaphore(value: 2)

    init(body: SolarSystemBody) throws {
        resources = try Self.shared.get()
        guard let style = PlanetariumGlobeStyle(body: body) else { throw NSError(domain: "PlanetariumGlobe", code: 3) }
        self.style = style
        super.init()
    }
    /// Reuse the Metal sphere material for a resolved sky disk (256px).
    static func skyTexture(body: SolarSystemBody, opening: Float = asin(0.36), appearance: PlanetariumPlanetAppearance? = nil) -> MTLTexture? {
        guard let renderer = try? PlanetariumGlobeRenderer(body: body) else { return nil }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: 512, height: 512, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        guard let texture = renderer.resources.device.makeTexture(descriptor: descriptor),
              let command = renderer.resources.queue.makeCommandBuffer() else { return nil }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        renderer.encode(command, pass: pass, elapsed: 0, opening: opening, appearance: appearance)
        command.commit(); command.waitUntilCompleted()
        return command.status == .completed ? texture : nil
    }
    static func diskRadius(index: Float) -> Float { index == 5 ? 0.40 : 0.76 }
    static func diskRadius(body: SolarSystemBody) -> Double { body == .saturn ? 0.40 : 0.76 }

    func setBody(_ body: SolarSystemBody) {
        if let style = PlanetariumGlobeStyle(body: body) { self.style = style }
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    func draw(in view: MTKView) {
        guard inFlight.wait(timeout: .now()) == .success else { return }
        guard let drawable = view.currentDrawable, let pass = view.currentRenderPassDescriptor,
              let command = resources.queue.makeCommandBuffer() else { inFlight.signal(); return }
        encode(command, pass: pass, elapsed: animationsEnabled ? CACurrentMediaTime() - startTime : 0, appearance: appearanceProvider?())
        let semaphore = inFlight
        command.addCompletedHandler { _ in semaphore.signal() }
        command.present(drawable)
        command.commit()
    }
    func encode(_ command: MTLCommandBuffer, pass: MTLRenderPassDescriptor, elapsed: Double, opening: Float? = nil, appearance: PlanetariumPlanetAppearance? = nil) {
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return }
        var parameters = SIMD4<Float>(style.index, style.angle(at: elapsed), appearance?.rotation ?? (opening == nil ? style.tilt * .pi / 180 : 0), appearance?.opening ?? opening ?? asin(0.36))
        var light = SIMD4<Float>(appearance?.sunDirection ?? simd_normalize(SIMD3(-0.45, 0.55, 1)), 0)
        // Saturn's polar/equatorial radii and main A-ring edge are physical ratios.
        var shape = SIMD4<Float>(style.index == 5 ? 54364 / 60268 : 1, Self.diskRadius(index: style.index), 0, 0)
        encoder.setRenderPipelineState(resources.pipeline)
        encoder.setFragmentBytes(&parameters, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
        encoder.setFragmentBytes(&light, length: MemoryLayout<SIMD4<Float>>.stride, index: 1)
        encoder.setFragmentBytes(&shape, length: MemoryLayout<SIMD4<Float>>.stride, index: 2)
        encoder.setFragmentTexture(resources.textures[style.texture], index: 0)
        encoder.setFragmentTexture(resources.textures["earth_clouds"], index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()
    }
}

/// Mean IAU poles in the J2000 equatorial frame (degrees/Julian century).
/// NASA NAIF pck00011.tpc; Jupiter's sub-0.01-degree pole nutations are omitted.
/// This controls viewing inclination, not the illustrative texture longitude.
enum PlanetariumPlanetOrientation {
    static func pole(_ body: SolarSystemBody, at date: Double) -> SIMD3<Float> {
        let t = (date - 2451545) / 36525
        let ra: Double, dec: Double
        switch body {
        case .mercury: (ra, dec) = (281.0103 - 0.0328*t, 61.4155 - 0.0049*t)
        case .venus: (ra, dec) = (272.76, 67.16)
        case .earth: (ra, dec) = (-0.641*t, 90 - 0.557*t)
        case .mars:
            func angle(_ base: Double, _ rate: Double) -> Double { (base + rate*t) * .pi / 180 }
            ra = 317.269202 - 0.10927547*t
                + 0.000068*sin(angle(198.991226, 19139.4819985))
                + 0.000238*sin(angle(226.292679, 38280.8511281))
                + 0.000052*sin(angle(249.663391, 57420.7251593))
                + 0.000009*sin(angle(266.183510, 76560.6367950))
                + 0.419057*sin(angle(79.398797, 0.5042615))
            dec = 54.432516 - 0.05827105*t
                + 0.000051*cos(angle(122.433576, 19139.9407476))
                + 0.000141*cos(angle(43.058401, 38280.8753272))
                + 0.000031*cos(angle(57.663379, 57420.7517205))
                + 0.000005*cos(angle(79.476401, 76560.6495004))
                + 1.591274*cos(angle(166.325722, 0.5042615))
        case .jupiter: (ra, dec) = (268.056595 - 0.006499*t, 64.495303 + 0.002413*t)
        case .saturn: (ra, dec) = (40.589 - 0.036*t, 83.537 - 0.004*t)
        case .uranus: (ra, dec) = (257.311, -15.175)
        case .neptune:
            let n = (357.85 + 52.316*t) * Double.pi / 180
            (ra, dec) = (299.36 + 0.70*sin(n), 43.46 - 0.51*cos(n))
        default: (ra, dec) = (0, 90)
        }
        let a = ra * .pi / 180, d = dec * .pi / 180
        return SIMD3(Float(cos(d)*cos(a)), Float(cos(d)*sin(a)), Float(sin(d)))
    }
    static func opening(pole: SIMD3<Float>, direction: SIMD3<Float>) -> Float {
        asin(max(-1, min(1, -simd_dot(pole, direction))))
    }
    static func radius(_ body: SolarSystemBody) -> Double {
        switch body {
        case .mercury: 2439.7
        case .venus: 6051.8
        case .mars: 3396.2
        case .jupiter: 71492
        case .saturn: 60268
        case .uranus: 25559
        case .neptune: 24764
        default: 0
        }
    }
}

/// Earth-view geometry shared by sky disks and selected globes. The local disk
/// basis has the projected IAU pole up, right perpendicular to it, and +Z toward
/// the observer. Sun direction in that same basis determines the terminator.
struct PlanetariumPlanetAppearance: Equatable {
    let opening: Float
    let sunDirection: SIMD3<Float>
    var rotation: Float = 0
    var illuminatedFraction: Float { (1 + sunDirection.z) / 2 }

    struct Geometry {
        let direction: SIMD3<Float>
        let pole: SIMD3<Float>
        let distanceAU: Double
        let appearance: PlanetariumPlanetAppearance
    }

    static func sunDirection(date: Double) -> SIMD3<Float> {
        let v = -SolarSystemBody.earth.heliocentricEclipticCoordinate(julianDay: date)
        let e = 23.439291111 * Double.pi / 180
        return SIMD3<Float>(simd_normalize(SIMD3(v.x, cos(e)*v.y-sin(e)*v.z, sin(e)*v.y+cos(e)*v.z)))
    }

    static func geometry(body: SolarSystemBody, date: Double, observerAU: SIMD3<Double> = .zero) -> Geometry {
        // VSOP87A is J2000 ecliptic. Keep positions and IAU poles in J2000,
        // including the light travel delay to the planet (~80 min for Saturn).
        func equatorial(_ v: SIMD3<Double>) -> SIMD3<Double> {
            let e = 23.439291111 * Double.pi / 180
            return SIMD3(v.x, cos(e)*v.y - sin(e)*v.z, sin(e)*v.y + cos(e)*v.z)
        }
        let earth = equatorial(SolarSystemBody.earth.heliocentricEclipticCoordinate(julianDay: date)) + observerAU
        var emission = date
        var planet = equatorial(body.heliocentricEclipticCoordinate(julianDay: emission))
        for _ in 0..<3 {
            emission = date - simd_length(planet - earth) * 499.004783836 / 86400
            planet = equatorial(body.heliocentricEclipticCoordinate(julianDay: emission))
        }
        let vector = planet - earth
        let distance = simd_length(vector)
        let direction = SIMD3<Float>(simd_normalize(vector))
        let pole = PlanetariumPlanetOrientation.pole(body, at: emission)
        let towardObserver = -direction
        let projectedPole = pole - direction * simd_dot(pole, direction)
        let vertical = simd_length_squared(projectedPole) > 1e-10 ? simd_normalize(projectedPole) :
            simd_normalize(simd_cross(towardObserver, SIMD3<Float>(1,0,0)))
        let horizontal = simd_normalize(simd_cross(vertical, towardObserver))
        let sun = SIMD3<Float>(simd_normalize(-planet))
        return Geometry(direction: direction, pole: pole, distanceAU: distance,
            appearance: .init(opening: PlanetariumPlanetOrientation.opening(pole: pole, direction: direction),
                sunDirection: SIMD3(simd_dot(sun, horizontal), simd_dot(sun, vertical), simd_dot(sun, towardObserver))))
    }
}

/// IAU 2006 Fukushima–Williams bias/precession angles (IERS TN36, eq. 5.40).
/// J2000 equatorial vectors and the observer's equator-of-date must not be mixed.
/// Mean-of-date: short-period nutation and stellar aberration are not included.
struct PlanetariumEquatorialFrame {
    private let rotation: simd_double3x3
    init(date: Double) {
        let t = (date - 2451545) / 36525
        func angle(_ coefficients: [Double]) -> Double {
            coefficients.reversed().reduce(0) { $0*t + $1 } * .pi / (180*3600)
        }
        let gamma = angle([-0.052928,10.556378,0.4932044,-0.00031238,-0.000002788,0.000000026])
        let phi = angle([84381.412819,-46.811016,0.0511268,0.00053289,-0.000000440,-0.0000000176])
        let psi = angle([-0.041775,5038.481484,1.5584175,-0.00018522,-0.000026452,-0.0000000148])
        let epsilon = angle([84381.406,-46.836769,-0.0001831,0.0020034,-0.000000576,-0.0000000434])
        let x = SIMD3<Double>(1,0,0), z = SIMD3<Double>(0,0,1)
        let q = simd_quatd(angle: epsilon, axis: x) * simd_quatd(angle: psi, axis: z)
            * simd_quatd(angle: -phi, axis: x) * simd_quatd(angle: -gamma, axis: z)
        rotation = simd_double3x3(q)
    }
    func ofDate(_ j2000: SIMD3<Double>) -> SIMD3<Double> { rotation * j2000 }
    func j2000(_ ofDate: SIMD3<Double>) -> SIMD3<Double> { rotation.transpose * ofDate }
}
