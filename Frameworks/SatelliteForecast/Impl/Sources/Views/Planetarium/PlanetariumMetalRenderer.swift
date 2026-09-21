import MetalKit
import simd
import StarryNight
import Combine

/// Presentation timestamps measure displayed frames, excluding skipped draws and snapshots.
/// Only the small FPS readout observes this state; the sky UI does not refresh per frame.
@MainActor final class PlanetariumFrameRate: ObservableObject {
    @Published private(set) var framesPerSecond: Double?
    private(set) var enabled = false
    private var enabledSince = 0.0
    private var firstTimestamp: Double?
    private var lastTimestamp = 0.0
    private var intervals = 0

    func setEnabled(_ enabled: Bool, now: Double = CACurrentMediaTime()) {
        self.enabled = enabled
        enabledSince = now
        firstTimestamp = nil
        lastTimestamp = 0
        intervals = 0
        framesPerSecond = nil
    }

    func recordPresentation(at timestamp: Double) {
        guard enabled, timestamp.isFinite, timestamp > 0, timestamp >= enabledSince,
              timestamp > lastTimestamp else { return }
        lastTimestamp = timestamp
        guard let firstTimestamp else { self.firstTimestamp = timestamp; return }
        intervals += 1
        let elapsed = timestamp - firstTimestamp
        guard elapsed >= 1 else { return }
        framesPerSecond = Double(intervals) / elapsed
        self.firstTimestamp = timestamp
        intervals = 0
    }
}

struct PlanetariumUniforms {
    var right = SIMD4<Float>(1, 0, 0, 0)
    var up = SIMD4<Float>(0, 1, 0, 0)
    var forward = SIMD4<Float>(0, 0, -1, 0)
    var north = SIMD4<Float>(0, 0, 1, 0)
    var east = SIMD4<Float>(0, 1, 0, 0)
    var zenith = SIMD4<Float>(1, 0, 0, 0)
    var sun = SIMD4<Float>(0, -1, 0, -90)
    var viewport = SIMD4<Float>(1, 1, 0.6, 65)
    var effects = SIMD4<Float>.zero
}
struct PlanetariumStarInstance {
    var positionMagnitude: SIMD4<Float>
    var colorWavelength: SIMD4<Float>
    init(_ star: Star) {
        positionMagnitude = SIMD4(SIMD3<Float>(simd_normalize(star.coordinate)), Float(star.magnitude))
        // Same spectral color and wavelength table as the reference renderer.
        switch star.spectralClass?.uppercased().first {
        case "O": colorWavelength = SIMD4(0.6, 0.7, 1, 400 * 10e-9)
        case "B": colorWavelength = SIMD4(0.7, 0.8, 1, 450 * 10e-9)
        case "A": colorWavelength = SIMD4(0.9, 0.9, 1, 500 * 10e-9)
        case "F": colorWavelength = SIMD4(1, 1, 0.9, 550 * 10e-9)
        case "G": colorWavelength = SIMD4(1, 1, 0.7, 600 * 10e-9)
        case "K": colorWavelength = SIMD4(1, 0.8, 0.6, 650 * 10e-9)
        case "M": colorWavelength = SIMD4(1, 0.6, 0.4, 700 * 10e-9)
        default: colorWavelength = SIMD4(1, 1, 1, 550 * 10e-9)
        }
    }
}

/// Keep in sync with the steady intensity and culling threshold in star_vertex.
/// Scintillation affects appearance, but must not flicker labels or tap targets.
enum PlanetariumStarVisibility {
    static func isVisible(magnitude: Double, altitude: Float, fieldOfView: Double, daylight: Float) -> Bool {
        guard magnitude.isFinite, altitude >= 0 else { return false }
        let flux = pow(10.0, -0.4 * magnitude)
        let exposure = 2.8 * pow(max(1, 105 / max(fieldOfView, 1e-4)), 1.75)
        let importance = 1 - SkyChartAtmosphere.transition(-0.5, 3.5, magnitude)
        let extinction = exp(-0.16 / max(0.08, Double(altitude)))
        let intensity = flux * exposure * extinction * Double(1 - daylight) * (1.15 + importance * 2.8)
        return intensity >= 0.004
    }
}
struct PlanetariumLineVertex {
    var position: SIMD4<Float>
    var color: SIMD4<Float>
    // Position along the entire star-to-star edge, not its spherical subdivision.
    var profile = SIMD4<Float>(0.5, 0, 0, 0)
}
struct PlanetariumSprite {
    var positionSize: SIMD4<Float>
    var tint = SIMD4<Float>(repeating: 1)
    var uvRect = SIMD4<Float>(0, 0, 1, 1)
    var options = SIMD4<Float>(0, 1, 0, 0)
}

/// Spatial cells and disjoint magnitude tiers. Each star is submitted at most once.
/// Buckets use conservative spherical caps, including at the poles / RA seam.
struct PlanetariumStarTiers {
    struct Cell {
        let id: Int
        let center: SIMD3<Float>
        var stars: [Star]
        let tiers: [Double: [Star]]
        func stars(at limit: Double) -> [Star] { tiers[limit] ?? [] }
    }
    let bright: [Star]
    let cells: [Cell]
    init(stars: [Star]) {
        var bright: [Star] = []
        var groups: [Int: [Star]] = [:]
        var seen = Set<Int>()
        for star in stars where seen.insert(star.id).inserted {
            if star.magnitude <= 3.5 { bright.append(star); continue }
            let v = simd_normalize(star.coordinate)
            let longitude = (atan2(v.y, v.x) + 2 * .pi).truncatingRemainder(dividingBy: 2 * .pi)
            let latitude = asin(max(-1, min(1, v.z)))
            let column = min(23, Int(longitude / (.pi / 12)))
            let row = min(11, max(0, Int((latitude + .pi / 2) / (.pi / 12))))
            groups[row * 24 + column, default: []].append(star)
        }
        self.bright = bright
        cells = groups.sorted { $0.key < $1.key }.map { key, value in
            let longitude = (Double(key % 24) + 0.5) * .pi / 12
            let latitude = (Double(key / 24) + 0.5) * .pi / 12 - .pi / 2
            return Cell(id: key, center: SIMD3(Float(cos(latitude) * cos(longitude)), Float(cos(latitude) * sin(longitude)), Float(sin(latitude))), stars: value, tiers: Dictionary(uniqueKeysWithValues: [6.5, 7.5, 9.0].map { limit in
                (limit, value.filter { $0.magnitude <= limit })
            }))
        }
    }
    static func magnitudeLimit(fieldOfView: Double) -> Double {
        fieldOfView < 25 ? 9 : (fieldOfView < 45 ? 7.5 : 6.5)
    }
    func visibleCells(forward: SIMD3<Float>, diagonalHalfAngle: Float) -> [Cell] {
        let threshold = cos(min(.pi, diagonalHalfAngle + 15 * .pi / 180))
        return cells.filter { simd_dot($0.center, forward) >= threshold }
    }
    func visibleFaintStars(forward: SIMD3<Float>, diagonalHalfAngle: Float, fieldOfView: Double) -> [Star] {
        visibleCells(forward: forward, diagonalHalfAngle: diagonalHalfAngle)
            .flatMap { $0.stars(at: Self.magnitudeLimit(fieldOfView: fieldOfView)) }
    }

}

@MainActor final class PlanetariumMetalRenderer: NSObject, MTKViewDelegate {
    let frameRate = PlanetariumFrameRate()
    let device: MTLDevice
    let queue: MTLCommandQueue
    private let backgroundPipeline: MTLRenderPipelineState
    private let starPipeline: MTLRenderPipelineState
    private let motionTrailPipeline: MTLRenderPipelineState
    private var motionTrailBuffer: MTLBuffer?
    private var moonOrbitBuffer: MTLBuffer?
    private let linePipeline: MTLRenderPipelineState
    private let spritePipeline: MTLRenderPipelineState
    let milkyWay: [MTLTexture]
    var uniforms = PlanetariumUniforms()
    private var brightBuffer: MTLBuffer?
    private var faintBuffer: MTLBuffer?
    private var constellationBuffer: MTLBuffer?
    private var passBuffer: MTLBuffer?
    var sprites: [(PlanetariumSprite, MTLTexture)] = []
    var showLines = true
    var passElapsedSeconds: Float = 0
    var beforeDraw: (() -> Void)?
    private let startTime = CACurrentMediaTime()
    private let inFlight = DispatchSemaphore(value: 3)

    init(view: MTKView) throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw NSError(domain: "Planetarium", code: 1, userInfo: [NSLocalizedDescriptionKey: AppLocalization.text("Metal is unavailable on this device.")])
        }
        self.device = device; self.queue = queue
        view.device = device
        view.colorPixelFormat = .bgra8Unorm_srgb
        view.preferredFramesPerSecond = 60
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        let library = try device.makeDefaultLibrary(bundle: .module)
        func pipeline(_ vertex: String, _ fragment: String, blend: Bool) throws -> MTLRenderPipelineState {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: vertex)
            descriptor.fragmentFunction = library.makeFunction(name: fragment)
            let color = descriptor.colorAttachments[0]!
            color.pixelFormat = view.colorPixelFormat
            color.isBlendingEnabled = blend
            color.sourceRGBBlendFactor = .one
            color.destinationRGBBlendFactor = .oneMinusSourceAlpha
            color.sourceAlphaBlendFactor = .one
            color.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            return try device.makeRenderPipelineState(descriptor: descriptor)
        }
        backgroundPipeline = try pipeline("background_vertex", "background_fragment", blend: false)
        starPipeline = try pipeline("star_vertex", "star_fragment", blend: true)
        motionTrailPipeline = try pipeline("motion_trail_vertex", "motion_trail_fragment", blend: true)
        linePipeline = try pipeline("line_vertex", "line_fragment", blend: true)
        spritePipeline = try pipeline("sprite_vertex", "sprite_fragment", blend: true)
        let loader = MTKTextureLoader(device: device)
        // Two native-resolution ASTC tiles also support the simulator's 8K
        // limit, without a 512 MB RGBA decode or runtime compression.
        milkyWay = try (0..<2).map { tile in
            guard let url = Bundle.module.url(forResource: "planetarium-milkyway-\(tile)", withExtension: "ktx") else {
                throw NSError(domain: "Planetarium", code: 3, userInfo: [NSLocalizedDescriptionKey: AppLocalization.text("Unable to load the sky textures.")])
            }
            return try loader.newTexture(URL: url, options: [.allocateMipmaps: false, .generateMipmaps: false])
        }
        super.init()
        view.delegate = self
    }

    func texture(_ image: UIImage) -> MTLTexture? {
        guard let cg = image.cgImage,
              let context = CGContext(data: nil, width: cg.width, height: cg.height, bitsPerComponent: 8,
                  bytesPerRow: cg.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        // UIKit may optimize monochrome glyphs to grayscale; normalize to RGBA
        // so MetalKit can load selection reticles as well as colored labels.
        context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        guard let rgba = context.makeImage() else { return nil }
        return try? MTKTextureLoader(device: device).newTexture(cgImage: rgba, options: [.SRGB: true])
    }
    private func buffer<T>(_ values: [T]) -> MTLBuffer? {
        guard !values.isEmpty else { return nil }
        return values.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { return nil }
            return device.makeBuffer(bytes: base, length: bytes.count, options: .storageModeShared)
        }
    }
    private var faintCellBuffers: [String: MTLBuffer] = [:]
    private var activeFaintCellBuffers: [MTLBuffer] = []
    private var regionalBuffers: [PlanetariumStarRegionKey: (buffer: MTLBuffer?, stamp: Int)] = [:]
    private var activeRegionalBuffers: [MTLBuffer] = []
    private var regionalBufferClock = 0
    private(set) var regionalUploadCount = 0
    var regionalBufferCount: Int { regionalBuffers.count }
    private(set) var starCellUploadCount = 0

    func resetStarCellCache() {
        // Buffers are immutable; submitted Metal command buffers retain old
        // resources until completion, so catalog replacement cannot overwrite them.
        faintCellBuffers.removeAll()
        activeFaintCellBuffers.removeAll()
        starCellUploadCount = 0
        regionalBuffers.removeAll()
        activeRegionalBuffers.removeAll()
        regionalUploadCount = 0
    }

    func setRegionalStars(_ regions: [PlanetariumStarRegion]) {
        let active = Set(regions.map(\.key))
        activeRegionalBuffers = regions.compactMap { region in
            regionalBufferClock += 1
            if let cached = regionalBuffers[region.key] {
                regionalBuffers[region.key] = (cached.buffer, regionalBufferClock)
                return cached.buffer
            }
            let uploaded = buffer(region.stars.map(PlanetariumStarInstance.init))
            regionalBuffers[region.key] = (uploaded, regionalBufferClock)
            if uploaded != nil { regionalUploadCount += 1 }
            return uploaded
        }
        // Pin active buffers, retain only a bounded recent history. Metal command
        // buffers retain evicted resources until their in-flight draws complete.
        var bytes = regionalBuffers.values.reduce(0) { $0 + ($1.buffer?.length ?? 0) }
        let evictable = regionalBuffers.filter { !active.contains($0.key) }.sorted { $0.value.stamp < $1.value.stamp }
        for entry in evictable {
            guard regionalBuffers.count > 256 || bytes > 4 * 1024 * 1024 else { break }
            bytes -= entry.value.buffer?.length ?? 0
            regionalBuffers.removeValue(forKey: entry.key)
        }
    }
    func setFaintStarCells(_ cells: [PlanetariumStarTiers.Cell], limit: Double) {
        faintBuffer = nil
        activeFaintCellBuffers = cells.compactMap { cell in
            let key = "\(cell.id):\(limit)"
            if let cached = faintCellBuffers[key] { return cached }
            guard let cached = buffer(cell.stars(at: limit).map(PlanetariumStarInstance.init)) else { return nil }
            faintCellBuffers[key] = cached
            starCellUploadCount += 1
            return cached
        }
    }
    func setBrightStars(_ stars: [Star]) { brightBuffer = buffer(stars.map(PlanetariumStarInstance.init)) }
    func setFaintStars(_ stars: [Star]) { activeFaintCellBuffers = []; faintBuffer = buffer(stars.map(PlanetariumStarInstance.init)) }
    func setConstellations(_ vertices: [PlanetariumLineVertex]) { constellationBuffer = buffer(vertices) }
    var motionTrailPointCount: Int { (motionTrailBuffer?.length ?? 0) / MemoryLayout<PlanetariumLineVertex>.stride }
    func setMotionTrails(_ vertices: [PlanetariumLineVertex]) { motionTrailBuffer = buffer(vertices) }
    func setMoonOrbits(_ vertices: [PlanetariumLineVertex]) { moonOrbitBuffer = buffer(vertices) }
    func setPass(_ vertices: [PlanetariumLineVertex]) { passBuffer = buffer(vertices) }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        // Never block the UI behind an overloaded GPU. All submitted buffers are
        // immutable, and Metal retains them until their command buffer completes.
        guard inFlight.wait(timeout: .now()) == .success else { return }
        guard let descriptor = view.currentRenderPassDescriptor, let drawable = view.currentDrawable,
              let command = queue.makeCommandBuffer(), let encoder = command.makeRenderCommandEncoder(descriptor: descriptor) else {
            inFlight.signal(); return
        }
        beforeDraw?()
        encode(encoder, size: view.drawableSize,
               scale: Float(view.drawableSize.width / max(1, view.bounds.width)),
               time: Float(CACurrentMediaTime() - startTime))
        encoder.endEncoding()
        if frameRate.enabled {
            let monitor = frameRate
            #if targetEnvironment(simulator)
            // Simulator Metal does not expose drawable presentation callbacks.
            // Count completed screen frames there; snapshots still do not count.
            command.addCompletedHandler { [weak monitor] command in
                guard command.status == .completed else { return }
                let timestamp = CACurrentMediaTime()
                Task { @MainActor in monitor?.recordPresentation(at: timestamp) }
            }
            #else
            drawable.addPresentedHandler { [weak monitor] drawable in
                let timestamp = drawable.presentedTime
                Task { @MainActor in monitor?.recordPresentation(at: timestamp) }
            }
            #endif
        }
        command.present(drawable)
        let semaphore = inFlight
        command.addCompletedHandler { _ in semaphore.signal() }
        command.commit()
    }

    private func encode(_ encoder: MTLRenderCommandEncoder, size: CGSize, scale: Float, time: Float) {
        var u = uniforms
        u.viewport.x = Float(size.width); u.viewport.y = Float(size.height)
        u.effects.z = time
        u.effects.w = scale
        encoder.setCullMode(.none)
        encoder.setRenderPipelineState(backgroundPipeline)
        encoder.setFragmentBytes(&u, length: MemoryLayout<PlanetariumUniforms>.stride, index: 0)
        encoder.setFragmentTexture(milkyWay[0], index: 1)
        encoder.setFragmentTexture(milkyWay[1], index: 2)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.setVertexBytes(&u, length: MemoryLayout<PlanetariumUniforms>.stride, index: 1)
        encoder.setRenderPipelineState(starPipeline)
        for buffer in [brightBuffer, faintBuffer].compactMap({ $0 }) + activeFaintCellBuffers + activeRegionalBuffers {
            encoder.setVertexBuffer(buffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6,
                instanceCount: buffer.length / MemoryLayout<PlanetariumStarInstance>.stride)
        }
        encoder.setRenderPipelineState(linePipeline)
        var flowTime = SIMD2<Float>(UIAccessibility.isReduceMotionEnabled ? -1 : time, passElapsedSeconds)
        encoder.setFragmentBytes(&flowTime, length: MemoryLayout<SIMD2<Float>>.stride, index: 1)
        for buffer in [showLines ? constellationBuffer : nil, passBuffer].compactMap({ $0 }) {
            encoder.setVertexBuffer(buffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6,
                instanceCount: buffer.length / (2 * MemoryLayout<PlanetariumLineVertex>.stride))
        }
        var bodyFlowTime = SIMD2<Float>(flowTime.x, 0)
        encoder.setFragmentBytes(&bodyFlowTime, length: MemoryLayout<SIMD2<Float>>.stride, index: 1)
        for buffer in [motionTrailBuffer, moonOrbitBuffer].compactMap({ $0 }) {
            encoder.setRenderPipelineState(linePipeline)
            encoder.setVertexBuffer(buffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6,
                instanceCount: buffer.length / (2 * MemoryLayout<PlanetariumLineVertex>.stride))
        }
        encoder.setRenderPipelineState(spritePipeline)
        for (var sprite, texture) in sprites {
            encoder.setVertexBytes(&sprite, length: MemoryLayout<PlanetariumSprite>.stride, index: 0)
            encoder.setFragmentTexture(texture, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        }
    }

    /// Deterministic GPU readback for rendering regression tests and review.
    /// Uses exactly the same pipelines and draw submissions as the live view.
    func snapshot(size: CGSize, scale: Float = 3, time: Float = 0) async throws -> UIImage {
        beforeDraw?()
        let width = Int(size.width), height = Int(size.height)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb,
            width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget]
        descriptor.storageMode = .shared
        guard let output = device.makeTexture(descriptor: descriptor), let command = queue.makeCommandBuffer() else {
            throw NSError(domain: "Planetarium", code: 4)
        }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = output
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else {
            throw NSError(domain: "Planetarium", code: 5)
        }
        encode(encoder, size: size, scale: scale, time: time)
        encoder.endEncoding()
        await withCheckedContinuation { continuation in
            command.addCompletedHandler { _ in continuation.resume() }
            command.commit()
        }
        if let error = command.error { throw error }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        output.getBytes(&pixels, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        return UIImage(cgImage: image)
    }

}
