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
    private let startTime = CACurrentMediaTime()
    private let inFlight = DispatchSemaphore(value: 2)

    init(body: SolarSystemBody) throws {
        resources = try Self.shared.get()
        guard let style = PlanetariumGlobeStyle(body: body) else { throw NSError(domain: "PlanetariumGlobe", code: 3) }
        self.style = style
        super.init()
    }
    func setBody(_ body: SolarSystemBody) {
        if let style = PlanetariumGlobeStyle(body: body) { self.style = style }
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    func draw(in view: MTKView) {
        guard inFlight.wait(timeout: .now()) == .success else { return }
        guard let drawable = view.currentDrawable, let pass = view.currentRenderPassDescriptor,
              let command = resources.queue.makeCommandBuffer() else { inFlight.signal(); return }
        encode(command, pass: pass, elapsed: animationsEnabled ? CACurrentMediaTime() - startTime : 0)
        let semaphore = inFlight
        command.addCompletedHandler { _ in semaphore.signal() }
        command.present(drawable)
        command.commit()
    }
    func encode(_ command: MTLCommandBuffer, pass: MTLRenderPassDescriptor, elapsed: Double) {
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return }
        var parameters = SIMD4<Float>(style.index, style.angle(at: elapsed), style.tilt * .pi / 180, 0)
        encoder.setRenderPipelineState(resources.pipeline)
        encoder.setFragmentBytes(&parameters, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
        encoder.setFragmentTexture(resources.textures[style.texture], index: 0)
        encoder.setFragmentTexture(resources.textures["earth_clouds"], index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()
    }
}
