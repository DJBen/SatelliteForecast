import UIKit
import MetalKit
import CoreMotion
import Combine
import SatelliteForecast
import SatelliteKit
import SolarSystem
import StarryNight
import simd

struct PlanetariumSelection: Equatable {
    let id: String
    var name: String
    var detail: String
    var coordinates: String
    var planet: SolarSystemBody? = nil
}

/// Owns input and ephemerides; every pixel of the sky is rendered by Metal.
@MainActor final class PlanetariumController: NSObject, ObservableObject {
    let view = MTKView()
    @Published private(set) var fieldOfView = 65.0
    @Published private(set) var motionAvailable = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var selection: PlanetariumSelection?
    private(set) var renderer: PlanetariumMetalRenderer?
    private let motion = CMMotionManager()
    private var context: PassViewContext?
    private var catalogTask: Task<Void, Never>?
    private var selectionTask: Task<Void, Never>?
    private var tiers = PlanetariumStarTiers(stars: [])
    private var renderedStars: [Star] = []
    private var lastRegionForward = SIMD3<Float>(repeating: 0)
    private var lastTier = -1.0
    private var lastAspect = 0.0
    private var loadedDeepCatalog = false
    private var lastSkyDate = -Double.infinity
    private var azimuth = 0.0
    private var elevation = 20.0
    private var panOffset = SIMD2<Double>.zero
    private var motionRoll = 0.0
    private var satelliteDirection = SIMD3<Float>(0, 0, -1)
    private var satelliteVisible = false
    private var satelliteIlluminated = true
    private var showLabels = true
    private var showConstellationLines = true
    private struct ConstellationFigure {
        let center: SIMD3<Float>
        let edges: [(SIMD3<Float>, SIMD3<Float>)]
    }
    private var constellationFigures: [ConstellationFigure] = []
    private(set) var constellationFocus = PlanetariumConstellationFocus()
    var animationClock: () -> Double = { CACurrentMediaTime() }
    private var lastAnimationTime: Double?
    private var lastFigure: Int?
    private var lastFigureProgress: Float = -1
    private var constellationLabels: [(SIMD3<Float>, MTLTexture, CGFloat)] = []
    private var cardinals: [(SIMD3<Float>, MTLTexture)] = []
    private var planets: [Body] = []
    private var markerTexture: MTLTexture?
    private var glowTexture: MTLTexture?
    private var satelliteLabel: MTLTexture?
    private var selectionDirection: SIMD3<Float>?
    private var selectedEquatorial: SIMD3<Float>?
    private var selectedPlanetName: String?
    private var north = SIMD3<Float>(0, 0, 1)
    private var east = SIMD3<Float>(0, 1, 0)
    private var zenith = SIMD3<Float>(1, 0, 0)
    private var forward = SIMD3<Float>(0, 0, -1)
    private var right = SIMD3<Float>(1, 0, 0)
    private var up = SIMD3<Float>(0, 1, 0)

    private struct Body {
        let planet: SolarSystemBody
        let name: String
        let direction: SIMD3<Float>
        let detail: String
        let magnitude: Double
        let texture: MTLTexture?
        let label: MTLTexture?
        let color: SIMD4<Float>
        let moon: Bool
        let sun: Bool
        let rotation: Float
    }

    override init() {
        super.init()
        view.backgroundColor = .black
        do {
            let renderer = try PlanetariumMetalRenderer(view: view)
            self.renderer = renderer
            renderer.beforeDraw = { [weak self] in self?.prepareFrame() }
        } catch { errorMessage = error.localizedDescription }
        view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(pan(_:))))
        view.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(pinch(_:))))
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tap(_:))))
        view.accessibilityLabel = AppLocalization.text("3D sky. Drag to look around, pinch to zoom, tap a star or planet for details.")
        motionAvailable = motion.isDeviceMotionAvailable
    }

    func configure(context: PassViewContext, julianDate: Double) {
        guard self.context == nil, let renderer else { return }
        self.context = context
        tiers = PlanetariumStarTiers(stars: context.starManager.snapshot.stars)
        renderer.setBrightStars(tiers.bright)
        markerTexture = renderer.texture(Self.markerImage())
        glowTexture = renderer.texture(Self.glowImage())
        satelliteLabel = renderer.texture(Self.labelImage(context.satelliteCommonName, color: .cyan))
        for constellation in context.starManager.allConstellations() {
            let image = Self.labelImage(constellation.localizedName.uppercased(), color: UIColor(red: 0.64, green: 0.76, blue: 0.91, alpha: 0.72))
            if let texture = renderer.texture(image) {
                constellationLabels.append((SIMD3<Float>(constellation.center), texture, image.size.width))
            }
            var edges: [(SIMD3<Float>, SIMD3<Float>)] = []
            for line in context.starManager.constellationLines(for: constellation) {
                guard let a = context.starManager.star(withId: line.star1Id), let b = context.starManager.star(withId: line.star2Id) else { continue }
                edges.append((simd_normalize(SIMD3<Float>(a.coordinate)), simd_normalize(SIMD3<Float>(b.coordinate))))
            }
            if !edges.isEmpty {
                constellationFigures.append(.init(center: simd_normalize(SIMD3<Float>(constellation.center)), edges: edges))
            }
        }
        var passVertices: [PlanetariumLineVertex] = []
        for (a, b) in zip(context.passSnapshots.snapshots, context.passSnapshots.snapshots.dropFirst()) {
            for snapshot in [a, b] {
                let direction = PlanetariumGeometry.direction(azimuth: snapshot.position.azim, elevation: snapshot.position.elev)
                let color = a.isIlluminated ? SIMD4<Float>(0.37, 0.96, 0.82, 0.9) : SIMD4<Float>(0.5, 0.6, 0.68, 0.4)
                passVertices.append(.init(position: SIMD4(direction, 0), color: color))
            }
        }
        renderer.setPass(passVertices)
        for (a, title) in [(0.0, "N"), (90, "E"), (180, "S"), (270, "W")] {
            if let texture = renderer.texture(Self.labelImage(title, color: .white)) {
                cardinals.append((PlanetariumGeometry.direction(azimuth: a, elevation: 1.5), texture))
            }
        }
        let culmination = context.passSnapshots.pass.culmination
        azimuth = culmination.azim; elevation = min(65, max(15, culmination.elev - 12))
        updateCamera()
        updateTime(julianDate)
    }

    func updateTime(_ date: Double) {
        guard let context else { return }
        if abs(date - lastSkyDate) * 86400 >= 10 {
            rebuildEphemerides(date, context: context)
            lastSkyDate = date
        }
        if let snapshot = try? context.satelliteInfo.generateSnapshot(julianDate: date, observer: context.observer) {
            satelliteDirection = PlanetariumGeometry.direction(azimuth: snapshot.position.azim, elevation: snapshot.position.elev)
            let pass = context.passSnapshots.pass
            satelliteVisible = snapshot.position.elev >= 0 && date >= pass.rise.julianDate && date <= pass.set.julianDate
            satelliteIlluminated = snapshot.isIlluminated
        } else { satelliteVisible = false }
    }

    private func rebuildEphemerides(_ date: Double, context: PassViewContext) {
        guard let renderer else { return }
        let frame = MilkyWayBackground.Projection(observer: context.observer, julianDate: date)
        north = SIMD3<Float>(frame.north); east = SIMD3<Float>(frame.east); zenith = SIMD3<Float>(frame.zenith)
        renderer.uniforms.north = SIMD4(north, 0)
        renderer.uniforms.east = SIMD4(east, 0)
        renderer.uniforms.zenith = SIMD4(zenith, 0)
        let sun = SkyChartAtmosphere.sun(observer: context.observer, julianDate: date)
        renderer.uniforms.sun = SIMD4(PlanetariumGeometry.direction(azimuth: sun.azim, elevation: sun.elev), Float(sun.elev))
        renderer.uniforms.effects.x = Float(SkyChartAtmosphere.transition(-8, 12, sun.elev))
        renderer.uniforms.effects.y = Float(SkyChartAtmosphere.transition(-18, -5, sun.elev) * (1 - SkyChartAtmosphere.transition(0, 14, sun.elev)))
        let previous = planets
        planets = SolarSystemBody.allCases.filter { ![.earth, .earthMoonBarycenter, .moon].contains($0) }.map { body in
            let coordinate = azel(time: Date(julianDate: date), site: LatLon(context.observer), cele: RADec(body.eci(julianDay: date)))
            let name = AppLocalization.text(String(describing: body).capitalized)
            let label = previous.first { $0.name == name }?.label ?? renderer.texture(Self.labelImage(name, color: UIColor(white: 0.86, alpha: 0.9)))
            let distance = body.distance(to: .earth, julianDate: date)
            let magnitude = body.apparentMagnitude(julianDay: date) ?? 6
            return Body(planet: body, name: name, direction: PlanetariumGeometry.direction(azimuth: coordinate.azim, elevation: coordinate.elev),
                        detail: body == .sun ? AppLocalization.text("Sun · Our nearest star") : AppLocalization.format("Planet · %.2f AU from Earth", distance),
                        magnitude: magnitude, texture: glowTexture, label: label,
                        color: body == .mars ? SIMD4(1, 0.55, 0.3, 1) : SIMD4(1, 0.94, 0.8, 1),
                        moon: false, sun: body == .sun, rotation: 0)
        }
        let moon = MoonAppearance.Geometry(julianDate: date, observer: context.observer)
        let moonImage = MoonAppearance.image(geometry: moon, dimension: 128)
        planets.append(Body(planet: .moon, name: AppLocalization.text("Moon"), direction: PlanetariumGeometry.direction(azimuth: moon.coordinate.azim, elevation: moon.coordinate.elev),
                            detail: AppLocalization.format("Moon · %.0f%% illuminated", moon.illuminatedFraction * 100), magnitude: -12,
                            texture: moonImage.flatMap { renderer.texture($0) },
                            label: previous.first { $0.moon }?.label ?? renderer.texture(Self.labelImage(AppLocalization.text("Moon"), color: .white)),
                            color: SIMD4(repeating: Float(moon.illuminatedFraction)), moon: true, sun: false,
                            rotation: Float((180 - moon.coordinate.azim) * .pi / 180)))
        if let selectedEquatorial { selectionDirection = local(selectedEquatorial) }
        if let selectedPlanetName, let body = planets.first(where: { $0.name == selectedPlanetName }) {
            selectionDirection = body.direction
            selection?.detail = body.detail
        }
        if let direction = selectionDirection { selection?.coordinates = coordinateText(direction) }
        updateStarRegion(force: true)
    }

    private func local(_ v: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3(simd_dot(v, east), simd_dot(v, zenith), -simd_dot(v, north))
    }
    private func equatorial(_ v: SIMD3<Float>) -> SIMD3<Float> { v.x * east + v.y * zenith - v.z * north }

    private func updateStarRegion(force: Bool = false) {
        guard let renderer else { return }
        let eq = equatorial(forward)
        let aspect = max(0.1, view.bounds.width / max(1, view.bounds.height))
        let tier = PlanetariumStarTiers.magnitudeLimit(fieldOfView: fieldOfView)
        guard force || tier != lastTier || abs(aspect - lastAspect) > 0.01 || simd_dot(eq, lastRegionForward) < cos(3 * .pi / 180) else { return }
        let diagonal = atan(tan(fieldOfView * .pi / 360) * sqrt(1 + aspect * aspect))
        let faint = tiers.visibleFaintStars(forward: eq, diagonalHalfAngle: Float(diagonal), fieldOfView: fieldOfView)
        renderedStars = tiers.bright + faint
        renderer.setFaintStars(faint)
        lastRegionForward = eq; lastTier = tier; lastAspect = aspect
        if tier > 6.5 && !loadedDeepCatalog && catalogTask == nil {
            catalogTask = Task { [weak self] in
                do {
                    let snapshot = try await StarCatalog().snapshot(maximumMagnitude: 9)
                    try Task.checkCancellation()
                    guard let self else { return }
                    self.tiers = PlanetariumStarTiers(stars: snapshot.stars)
                    self.loadedDeepCatalog = true
                    self.catalogTask = nil
                    self.updateStarRegion(force: true)
                } catch { self?.catalogTask = nil }
            }
        }
    }

    private func prepareFrame() {
        updateNavigation()
        guard let renderer else { return }
        updateStarRegion()
        updateConstellationFocus()
        var sprites: [(PlanetariumSprite, MTLTexture)] = []
        let scale = max(1, view.contentScaleFactor)
        func append(_ direction: SIMD3<Float>, _ texture: MTLTexture?, width: CGFloat, tint: SIMD4<Float> = SIMD4(repeating: 1), rotation: Float = 0, overlay: Bool = false) {
            guard let texture, direction.y >= 0, projected(direction, margin: 80, ignoresGround: overlay) != nil else { return }
            var sprite = PlanetariumSprite(positionSize: SIMD4(direction, Float(width * scale)), tint: tint)
            sprite.options = SIMD4(0, Float(texture.height) / Float(texture.width), rotation, overlay ? 1 : 0)
            sprites.append((sprite, texture))
        }
        if showLabels && renderer.uniforms.sun.w < 0 {
            for (direction, texture, width) in constellationLabels {
                append(local(direction), texture, width: min(150, width / 2))
            }
        }
        for (direction, texture) in cardinals { append(direction, texture, width: 20) }
        for body in planets {
            if body.moon {
                let diskPixels = view.bounds.height * 0.009 / (2 * tan(fieldOfView * .pi / 360))
                let scatter = body.color.x * 0.4 * (1 - renderer.uniforms.effects.x)
                append(body.direction, glowTexture, width: max(24, diskPixels * 7), tint: SIMD4(repeating: scatter))
                append(body.direction, body.texture, width: max(3, diskPixels), rotation: body.rotation + Float(motionRoll))
            } else {
                let width: CGFloat = body.sun ? 34 : CGFloat(max(3, min(19, 8 - body.magnitude)))
                let opacity: Float = body.sun ? 1 : 1 - renderer.uniforms.effects.x * 0.97
                append(body.direction, body.texture, width: width, tint: body.color * opacity)
            }
            if body.magnitude < 6 || fieldOfView < 45 {
                let labelDirection = simd_normalize(body.direction - up * Float(0.028 * fieldOfView / 65))
                append(labelDirection, body.label, width: CGFloat(body.label?.width ?? 60) / 2)
            }
        }
        if satelliteVisible {
            let color = satelliteIlluminated ? SIMD4<Float>(0.35, 1, 0.85, 1) : SIMD4<Float>(0.5, 0.65, 0.75, 0.6)
            append(satelliteDirection, glowTexture, width: 32, tint: color, overlay: true)
            append(satelliteDirection, markerTexture, width: 28, tint: color, overlay: true)
            append(simd_normalize(satelliteDirection + up * Float(0.045 * fieldOfView / 65)), satelliteLabel,
                   width: min(180, CGFloat(satelliteLabel?.width ?? 180) / 2))
        }
        if let selectionDirection {
            append(selectionDirection, markerTexture, width: 38, tint: SIMD4(0.7, 0.9, 1, 1))
        }
        renderer.sprites = sprites
    }

    private func projected(_ direction: SIMD3<Float>, margin: CGFloat = 0, ignoresGround: Bool = false) -> CGPoint? {
        let z = simd_dot(direction, forward)
        guard z > 0, direction.y >= 0, ignoresGround || PlanetariumGeometry.isAboveGround(direction) else { return nil }
        let tangent = Float(tan(fieldOfView * .pi / 360))
        let aspect = Float(view.bounds.width / max(1, view.bounds.height))
        let x = simd_dot(direction, right) / (z * tangent * aspect)
        let y = simd_dot(direction, up) / (z * tangent)
        let point = CGPoint(x: CGFloat(x + 1) * view.bounds.width / 2, y: CGFloat(1 - y) * view.bounds.height / 2)
        return view.bounds.insetBy(dx: -margin, dy: -margin).contains(point) ? point : nil
    }

    func setOverlays(labels: Bool, lines: Bool) {
        showLabels = labels
        showConstellationLines = lines
        // Keep the pipeline enabled while its last figure contracts on toggle-off.
    }

    private func updateConstellationFocus() {
        guard let renderer else { return }
        let time = animationClock()
        let delta = lastAnimationTime.map { time - $0 } ?? 1 / 30
        lastAnimationTime = time
        let daytime = renderer.uniforms.sun.w >= 0
        let candidate: Int? = showConstellationLines && !daytime ? constellationFigures.indices
            .filter { PlanetariumGeometry.isAboveGround(local(constellationFigures[$0].center)) }
            .max { simd_dot(local(constellationFigures[$0].center), forward) < simd_dot(local(constellationFigures[$1].center), forward) }
            .flatMap { simd_dot(local(constellationFigures[$0].center), forward) > 0 ? $0 : nil } : nil
        constellationFocus.update(candidate: candidate, delta: delta, reduceMotion: daytime || UIAccessibility.isReduceMotionEnabled)
        let progress = constellationFocus.easedProgress
        guard lastFigure != constellationFocus.active || lastFigureProgress != progress else { return }
        lastFigure = constellationFocus.active; lastFigureProgress = progress
        guard let index = constellationFocus.active, progress > 0 else { renderer.setConstellations([]); return }
        var vertices: [PlanetariumLineVertex] = []
        for (a, b) in constellationFigures[index].edges {
            for i in 0..<12 {
                for t in [Float(i) / 12, Float(i + 1) / 12] {
                    let contracted = 0.5 + (t - 0.5) * progress
                    let direction = simd_normalize(a * (1 - contracted) + b * contracted)
                    vertices.append(.init(position: SIMD4(direction, 1), color: SIMD4(0.68, 0.80, 1, 0.36 * progress),
                        profile: SIMD4(t, 0, 0, 0)))
                }
            }
        }
        renderer.setConstellations(vertices)
    }
    func zoom(by factor: Double) {
        fieldOfView = max(12, min(100, fieldOfView * factor))
        renderer?.uniforms.viewport.z = Float(tan(fieldOfView * .pi / 360))
        renderer?.uniforms.viewport.w = Float(fieldOfView)
        updateStarRegion(force: true)
    }
    @Published private(set) var stationBearing: Double?
    private var cameraPan: (start: Double, azimuth: Double, elevation: Double)?

    func animateToSatellite() {
        setMotionEnabled(false)
        if UIAccessibility.isReduceMotionEnabled { focusSatellite(); return }
        cameraPan = (animationClock(), azimuth, elevation)
    }

    /// Advance with rendered frames, including previews hosted in a separate window.
    func updateNavigation() {
        if let pan = cameraPan {
            let t = min(1, max(0, (animationClock() - pan.start) / 0.7))
            let eased = t * t * (3 - 2 * t)
            let target = PlanetariumGeometry.angles(satelliteDirection)
            azimuth = pan.azimuth + PlanetariumGeometry.shortestTurn(from: pan.azimuth, to: target.azimuth) * eased
            elevation = pan.elevation + (target.elevation - pan.elevation) * eased
            panOffset = .zero
            updateCamera()
            if t >= 1 { cameraPan = nil }
        }
        let bearing = satelliteVisible ? PlanetariumGeometry.offscreenBearing(
            cameraDirection: SIMD3(simd_dot(satelliteDirection, right), simd_dot(satelliteDirection, up), simd_dot(satelliteDirection, forward)),
            aspect: Float(view.bounds.width / max(1, view.bounds.height)),
            tangent: Float(tan(fieldOfView * .pi / 360))) : nil
        if stationBearing != bearing {
            // Metal may draw during layout; publish after that view update completes.
            DispatchQueue.main.async { [weak self] in self?.stationBearing = bearing }
        }
    }

    func focusSatellite() {
        let angles = PlanetariumGeometry.angles(satelliteDirection)
        pointCamera(azimuth: angles.azimuth, elevation: angles.elevation)
    }
    func pointCamera(azimuth: Double, elevation: Double) {
        cameraPan = nil
        self.azimuth = azimuth; self.elevation = elevation; panOffset = .zero; motionRoll = 0
        updateCamera()
        updateStarRegion(force: true)
    }
    func setMotionEnabled(_ enabled: Bool) {
        if enabled { cameraPan = nil }
        motion.stopDeviceMotionUpdates()
        if !enabled {
            azimuth += panOffset.x; elevation += panOffset.y; panOffset = .zero; motionRoll = 0
            updateCamera()
        }
        guard enabled, motion.isDeviceMotionAvailable else { return }
        panOffset = .zero
        motion.deviceMotionUpdateInterval = 1 / 30
        let frames = CMMotionManager.availableAttitudeReferenceFrames()
        let reference: CMAttitudeReferenceFrame = frames.contains(.xTrueNorthZVertical) ? .xTrueNorthZVertical : .xMagneticNorthZVertical
        motion.startDeviceMotionUpdates(using: reference, to: .main) { [weak self] data, error in
            guard let self else { return }
            guard let data, error == nil else { self.motionAvailable = false; return }
            self.motionAvailable = true
            // Core Motion's matrix transforms reference -> device; rows express
            // device axes in north/west/up. Optical axis is -device Z.
            let r = data.attitude.rotationMatrix
            let f = SIMD3<Float>(Float(r.m32), Float(-r.m33), Float(r.m31))
            let angles = PlanetariumGeometry.angles(f)
            self.azimuth = angles.azimuth; self.elevation = angles.elevation
            var screenUp = SIMD3<Float>(Float(-r.m22), Float(r.m23), Float(-r.m21))
            switch self.view.window?.windowScene?.interfaceOrientation {
            case .landscapeLeft: screenUp = SIMD3(Float(r.m12), Float(-r.m13), Float(r.m11))
            case .landscapeRight: screenUp = SIMD3(Float(-r.m12), Float(r.m13), Float(-r.m11))
            case .portraitUpsideDown: screenUp = -screenUp
            default: break
            }
            let eastOnScreen = simd_normalize(simd_cross(f, SIMD3<Float>(0, 1, 0)))
            let upright = simd_normalize(simd_cross(eastOnScreen, f))
            self.motionRoll = Double(atan2(simd_dot(screenUp, eastOnScreen), simd_dot(screenUp, upright)))
            self.updateCamera()
        }
    }
    func setActive(_ active: Bool, gyroscope: Bool) {
        view.isPaused = !active
        setMotionEnabled(active && gyroscope)
    }
    func stop() {
        cameraPan = nil
        motion.stopDeviceMotionUpdates(); view.isPaused = true
        catalogTask?.cancel(); catalogTask = nil
        selectionTask?.cancel(); selectionTask = nil
    }
    func clearSelection() {
        selectionTask?.cancel(); selectionTask = nil
        selection = nil; selectionDirection = nil; selectedEquatorial = nil; selectedPlanetName = nil
    }
    private func updateCamera() {
        forward = PlanetariumGeometry.direction(azimuth: azimuth + panOffset.x, elevation: max(-89.5, min(89.5, elevation + panOffset.y)))
        let horizontalRight = simd_normalize(simd_cross(forward, SIMD3<Float>(0, 1, 0)))
        let upright = simd_normalize(simd_cross(horizontalRight, forward))
        up = upright * Float(cos(motionRoll)) + horizontalRight * Float(sin(motionRoll))
        right = simd_normalize(simd_cross(forward, up))
        renderer?.uniforms.forward = SIMD4(forward, 0)
        renderer?.uniforms.right = SIMD4(right, 0)
        renderer?.uniforms.up = SIMD4(up, 0)
        renderer?.uniforms.viewport.z = Float(tan(fieldOfView * .pi / 360))
        renderer?.uniforms.viewport.w = Float(fieldOfView)
    }
    @objc private func pan(_ gesture: UIPanGestureRecognizer) {
        cameraPan = nil
        let delta = gesture.translation(in: view); gesture.setTranslation(.zero, in: view)
        let scale = fieldOfView / max(1, view.bounds.height)
        panOffset.x -= delta.x * scale; panOffset.y += delta.y * scale
        panOffset.y = max(-89.5 - elevation, min(89.5 - elevation, panOffset.y))
        updateCamera()
    }
    @objc private func pinch(_ gesture: UIPinchGestureRecognizer) { zoom(by: 1 / gesture.scale); gesture.scale = 1 }
    @objc private func tap(_ gesture: UITapGestureRecognizer) { select(at: gesture.location(in: view)) }

    /// Hit tests the same projection and active catalog tiers as the renderer.
    func select(at point: CGPoint) {
        selectionTask?.cancel()
        selectionTask = nil
        var bestDistance: CGFloat = 26
        var bestStar: Star?
        var bestBody: Body?
        for star in renderedStars {
            let direction = local(SIMD3<Float>(star.coordinate))
            guard let p = projected(direction), (renderer?.uniforms.effects.x ?? 0) < 0.85 else { continue }
            let distance = hypot(p.x - point.x, p.y - point.y)
            if distance < bestDistance { bestDistance = distance; bestStar = star }
        }
        for body in planets {
            guard let p = projected(body.direction) else { continue }
            let distance = hypot(p.x - point.x, p.y - point.y)
            if distance < bestDistance { bestDistance = distance; bestBody = body; bestStar = nil }
        }
        if let body = bestBody {
            selectedEquatorial = nil
            selectionDirection = body.direction; selectedPlanetName = body.name
            selection = .init(id: body.name, name: body.name, detail: body.detail, coordinates: coordinateText(body.direction), planet: body.planet)
        } else if let star = bestStar {
            // Publish the complete card once, after metadata resolution. Preserve
            // the previous card while loading so its glass container never collapses.
            selectionTask = Task { [weak self] in
                guard let self, let context = self.context else { return }
                let info = try? await context.starManager.starInfo(forId: star.id)
                guard !Task.isCancelled else { return }
                let direction = self.local(SIMD3<Float>(star.coordinate))
                let name = info?.properName ?? info?.bayer ?? info?.hipId.map { "HIP \($0)" }
                    ?? AppLocalization.format("Star %@", String(star.id))
                let detail = AppLocalization.format("Star · magnitude %.1f", star.magnitude)
                    + (star.spectralClass.map { " · \($0)" } ?? "")
                self.selectedPlanetName = nil
                self.selectedEquatorial = SIMD3<Float>(star.coordinate)
                self.selectionDirection = direction
                self.selection = .init(id: "star-\(star.id)", name: name, detail: detail, coordinates: self.coordinateText(direction))
            }
        } else {
            clearSelection()
        }
    }

    private func coordinateText(_ direction: SIMD3<Float>) -> String {
        let angles = PlanetariumGeometry.angles(direction)
        return AppLocalization.format("%.0f° azimuth · %.0f° altitude", angles.azimuth, angles.elevation)
    }
    private static func labelImage(_ title: String, color: UIColor) -> UIImage {
        let font = UIFont.systemFont(ofSize: 22, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (title as NSString).size(withAttributes: attributes)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: ceil(size.width) + 8, height: 32), format: format).image { _ in
            (title as NSString).draw(at: CGPoint(x: 4, y: 2), withAttributes: attributes)
        }
    }
    private static func glowImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 128, height: 128), format: format).image { c in
            let colors = [UIColor.white.cgColor, UIColor(white: 1, alpha: 0.4).cgColor, UIColor.clear.cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.12, 1])!
            c.cgContext.drawRadialGradient(gradient, startCenter: CGPoint(x: 64, y: 64), startRadius: 0,
                endCenter: CGPoint(x: 64, y: 64), endRadius: 64, options: [])
        }
    }
    private static func markerImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 96, height: 96), format: format).image { c in
            c.cgContext.setStrokeColor(UIColor.white.cgColor); c.cgContext.setLineWidth(3)
            for i in 0..<4 {
                let angle = CGFloat(i) * .pi / 2
                c.cgContext.addArc(center: CGPoint(x: 48, y: 48), radius: 30, startAngle: angle + 0.15, endAngle: angle + .pi / 2 - 0.15, clockwise: false)
                c.cgContext.strokePath()
            }
        }
    }
}
