import UIKit
import MetalKit
import CoreMotion
import Combine
import SatelliteForecast
import SatelliteKit
import SolarSystem
import StarryNight
import simd

@MainActor final class PlanetariumNavigationState: ObservableObject {
    @Published var bearing: Double?
}

@MainActor final class PlanetariumSelectionState: ObservableObject {
    @Published var value: PlanetariumSelection?
}

struct PlanetariumSelection: Equatable {
    let id: String
    var name: String
    var detail: String
    var coordinates: String
    var planet: SolarSystemBody? = nil
    var moonID: Int? = nil
}

/// One source for the rendered track, moving marker, and time boundary.
struct PlanetariumSatelliteTrack {
    struct Sample {
        let date: Double
        let direction: SIMD3<Float>
        let illuminated: Bool
    }
    let samples: [Sample]
    init(info: SatelliteInfo, observer: LatLonAlt, range: ClosedRange<Double>) throws {
        let count = max(1, Int(ceil((range.upperBound - range.lowerBound) * 86400)))
        samples = try (0...count).map { index in
            let date = range.lowerBound + (range.upperBound - range.lowerBound) * Double(index) / Double(count)
            let snapshot = try info.generateSnapshot(julianDate: date, observer: observer)
            return Sample(date: date, direction: PlanetariumGeometry.direction(azimuth: snapshot.position.azim, elevation: snapshot.position.elev),
                          illuminated: snapshot.isIlluminated)
        }
    }
    func sample(at date: Double) -> Sample? {
        guard let first = samples.first, let last = samples.last, date >= first.date, date <= last.date else { return nil }
        var low = 0, high = samples.count - 1
        while high - low > 1 {
            let mid = (low + high) / 2
            if samples[mid].date <= date { low = mid } else { high = mid }
        }
        let a = samples[low], b = samples[high]
        let t = Float((date - a.date) / max(1e-12, b.date - a.date))
        return Sample(date: date, direction: simd_normalize(a.direction + (b.direction - a.direction) * t),
                      illuminated: t < 0.5 ? a.illuminated : b.illuminated)
    }
    var vertices: [PlanetariumLineVertex] {
        var result: [PlanetariumLineVertex] = []
        var distance: Float = 0
        guard let first = samples.first else { return [] }
        for (a, b) in zip(samples, samples.dropFirst()) {
            let length = atan2(simd_length(simd_cross(a.direction, b.direction)), simd_dot(a.direction, b.direction))
            let color = a.illuminated ? SIMD4<Float>(0.37, 0.96, 0.82, 0.9) : SIMD4<Float>(0.5, 0.6, 0.68, 0.4)
            result.append(.init(position: SIMD4(a.direction, 0), color: color,
                                profile: SIMD4(distance, 1, Float((a.date-first.date)*86400), 0)))
            distance += length
            result.append(.init(position: SIMD4(b.direction, 0), color: color,
                                profile: SIMD4(distance, 1, Float((b.date-first.date)*86400), 0)))
        }
        return result
    }
}

/// Owns input and ephemerides; every pixel of the sky is rendered by Metal.
@MainActor final class PlanetariumController: NSObject, ObservableObject {
    let view = MTKView()
    private(set) var fieldOfView = 65.0
    @Published private(set) var motionAvailable = false
    @Published private(set) var motionEnabled = false
    private var motionSession = 0
    private var active = true
    @Published private(set) var errorMessage: String?
    let selectionState = PlanetariumSelectionState()
    private(set) var selection: PlanetariumSelection? {
        didSet {
            if oldValue != selection { selectionState.value = selection }
            if oldValue?.planet != selection?.planet {
                if let context, lastSkyDate.isFinite {
                    rebuildMotionTrails(date: lastSkyDate, observer: context.observer)
                } else { renderer?.setMotionTrails([]) }
            }
        }
    }
    private(set) var renderer: PlanetariumMetalRenderer?
    private let motion = CMMotionManager()
    private var motionFilter = PlanetariumMotionFilter()
    private var context: PassViewContext?
    private var catalogTask: Task<Void, Never>?
    private var selectionTask: Task<Void, Never>?
    private var moonTextureTask: Task<Void, Never>?
    private var detailedMoonTexture: MTLTexture?
    private var lastMoonTextureDate = -Double.infinity
    private var tiers = PlanetariumStarTiers(stars: [])
    private var renderedStars: [Star] = []
    private var lastRegionForward = SIMD3<Float>(repeating: 0)
    private var lastTier = -1.0
    private var lastRegionDiagonal = -Double.infinity
    private var activeStarCells: [Int] = []
    private var lastAspect = 0.0
    private var loadedDeepCatalog = false
    private var lastMotionTrailDate = -Double.infinity
    private var lastSkyDate = -Double.infinity
    private var lastMoonOrbitDate = -Double.infinity
    private var moonOrbitKey = ""
    private var currentSkyDate = -Double.infinity
    private var ephemerisInterval = 10.0
    private var bodyMotion: [SolarSystemBody: (start: SIMD3<Float>, end: SIMD3<Float>)] = [:]
    private var previewPlayback: (date: Double, clock: Double, end: Double)?
    var previewDate: Double? {
        guard let playback = previewPlayback else { return nil }
        return min(playback.end, playback.date + max(0, animationClock() - playback.clock) * 10 / 86400)
    }
    func setPreviewPlayback(playing: Bool, date: Double, end: Double, trackingSelection: Bool = true) {
        previewPlayback = playing ? (date, animationClock(), end) : nil
        updateTime(date, trackingSelection: trackingSelection)
    }
    var selectedScreenPosition: CGPoint? { selectionDirection.flatMap { projected($0) } }

    private var azimuth = 0.0
    private var elevation = 20.0
    private var panOffset = SIMD2<Double>.zero
    private var motionRoll = 0.0
    private var satelliteTrack: PlanetariumSatelliteTrack?
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
    private var lastLineView: [SIMD4<Float>] = []
    private var constellationLabels: [(SIMD3<Float>, MTLTexture, CGFloat)] = []
    private var cardinals: [(SIMD3<Float>, MTLTexture)] = []
    private var planets: [Body] = []
    private var moonEphemerides: [Int: MoonEphemeris] = [:]
    private var moonLoadTask: Task<Void, Never>?
    private var moonRetryAfter = Date.distantPast
    private var moonSceneKey = ""
    private var naturalMoons: [NaturalMoonBody] = []
    private var naturalMoonTextures: [Int: MTLTexture] = [:]
    private var naturalMoonLabels: [Int: MTLTexture] = [:]
    private var resolvedPlanetAppearances: [SolarSystemBody: PlanetariumPlanetAppearance] = [:]
    private var planetGeometry: [SolarSystemBody: PlanetariumPlanetAppearance.Geometry] = [:]
    private var resolvedPlanetTextures: [SolarSystemBody: MTLTexture] = [:]
    private struct NaturalMoonBody {
        let moon: PlanetariumMoon
        let direction: SIMD3<Float>
        let parentDirection: SIMD3<Float>
        let angularDiameter: Double
        let distance: Double
    }
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
        var direction: SIMD3<Float>
        let detail: String
        let magnitude: Double
        var texture: MTLTexture?
        let label: MTLTexture?
        let color: SIMD4<Float>
        let moon: Bool
        let sun: Bool
        let rotation: Float
        var angularDiameter: Double = 0
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
        renderer.resetStarCellCache()
        activeStarCells = []
        renderer.setBrightStars(tiers.bright)
        markerTexture = renderer.texture(Self.markerImage())
        glowTexture = renderer.texture(Self.glowImage())
        satelliteLabel = renderer.texture(Self.labelImage(context.satelliteCommonName, color: .cyan))
        for constellation in context.starManager.allConstellations() {
            let image = Self.labelImage(constellation.localizedName.uppercased(with: .current), color: UIColor(red: 0.64, green: 0.76, blue: 0.91, alpha: 0.72))
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
        for star in context.starManager.namedBrightStars {
            if let name = star.info?.displayName,
               let texture = renderer.texture(Self.labelImage(name, color: UIColor(white: 0.82, alpha: 0.85), fontSize: 24)) {
                starLabelTextures[star.id] = texture
            }
        }
        let pass = context.passSnapshots.pass
        satelliteTrack = try? PlanetariumSatelliteTrack(info: context.satelliteInfo, observer: context.observer,
                                                       range: pass.rise.julianDate...pass.set.julianDate)
        renderer.setPass(satelliteTrack?.vertices ?? [])
        for (a, title) in [(0.0, "N"), (90, "E"), (180, "S"), (270, "W")] {
            if let texture = renderer.texture(Self.labelImage(title, color: .white, celestial: false)) {
                cardinals.append((PlanetariumGeometry.direction(azimuth: a, elevation: 1.5), texture))
            }
        }
        let culmination = context.passSnapshots.pass.culmination
        azimuth = culmination.azim; elevation = min(65, max(15, culmination.elev - 12))
        updateCamera()
        updateTime(julianDate)
    }

    func updateTime(_ date: Double, trackingSelection: Bool = false) {
        guard let context, date.isFinite else { return }
        if trackingSelection, selectionDirection != nil, motionEnabled { setMotionEnabled(false) }
        let previousSelection = selectionDirection
        currentSkyDate = date
        renderer?.passElapsedSeconds = Float((date - context.passSnapshots.pass.rise.julianDate) * 86400)
        let interval = fieldOfView < 2 ? 1.0 : 10.0
        if !lastSkyDate.isFinite || date < lastSkyDate || (date - lastSkyDate) * 86400 >= ephemerisInterval || interval != ephemerisInterval {
            ephemerisInterval = interval
            rebuildEphemerides(date, context: context)
            lastSkyDate = date
            cacheBodyMotion(date: date, context: context)
        }
        updateSkyFrame(date, context: context)
        let fraction = Float(max(0, min(1, (date - lastSkyDate) * 86400 / ephemerisInterval)))
        for index in planets.indices {
            guard let motion = bodyMotion[planets[index].planet] else { continue }
            planets[index].direction = local(simd_normalize(simd_mix(motion.start, motion.end, SIMD3(repeating: fraction))))
        }
        if let selectedEquatorial { selectionDirection = local(selectedEquatorial) }
        if let selectedPlanetName, let body = planets.first(where: { $0.name == selectedPlanetName }) {
            selectionDirection = body.direction
        }
        updateNaturalMoons()
        if trackingSelection, let before = previousSelection, let after = selectionDirection {
            // Rotate the whole basis to preserve even an off-center object's screen position.
            let rotation = simd_quatf(from: simd_normalize(before), to: simd_normalize(after))
            forward = simd_normalize(rotation.act(forward))
            up = simd_normalize(rotation.act(up))
            right = simd_normalize(simd_cross(forward, up))
            let angles = PlanetariumGeometry.angles(forward)
            azimuth = angles.azimuth; elevation = angles.elevation; panOffset = .zero
            let horizontal = simd_cross(forward, SIMD3<Float>(0, 1, 0))
            if simd_length_squared(horizontal) > 0.00000001 {
                let horizontalRight = simd_normalize(horizontal)
                let upright = simd_normalize(simd_cross(horizontalRight, forward))
                motionRoll = Double(atan2(simd_dot(up, horizontalRight), simd_dot(up, upright)))
            }
            writeCameraUniforms()
        }
        if let sample = satelliteTrack?.sample(at: date) {
            satelliteDirection = sample.direction
            satelliteVisible = sample.direction.y >= 0
            satelliteIlluminated = sample.illuminated
        } else { satelliteVisible = false }
    }

    private func updateSkyFrame(_ date: Double, context: PassViewContext) {
        let frame = MilkyWayBackground.Projection(observer: context.observer, julianDate: date)
        let epoch = PlanetariumEquatorialFrame(date: date)
        north = SIMD3<Float>(epoch.j2000(frame.north))
        east = SIMD3<Float>(epoch.j2000(frame.east))
        zenith = SIMD3<Float>(epoch.j2000(frame.zenith))
        renderer?.uniforms.north = SIMD4(north, 0)
        renderer?.uniforms.east = SIMD4(east, 0)
        renderer?.uniforms.zenith = SIMD4(zenith, 0)
    }

    private func cacheBodyMotion(date: Double, context: PassViewContext) {
        let endDate = date + ephemerisInterval / 86400
        let endFrame = MilkyWayBackground.Projection(observer: context.observer, julianDate: endDate)
        let futureMoon = MoonAppearance.Geometry(julianDate: endDate, observer: context.observer)
        let epoch = PlanetariumEquatorialFrame(date: endDate)
        let observerAU = epoch.j2000(geo2eci(julianDays: endDate, geodetic: context.observer)) / 149597870.7
        bodyMotion = Dictionary(uniqueKeysWithValues: planets.map { body in
            let end: SIMD3<Float>
            if body.moon {
                let direction = PlanetariumGeometry.direction(azimuth: futureMoon.coordinate.azim, elevation: futureMoon.coordinate.elev)
                let meanOfDate = Double(direction.x)*endFrame.east + Double(direction.y)*endFrame.zenith - Double(direction.z)*endFrame.north
                end = SIMD3<Float>(epoch.j2000(meanOfDate))
            } else if body.sun {
                end = PlanetariumPlanetAppearance.sunDirection(date: endDate)
            } else {
                end = PlanetariumPlanetAppearance.geometry(body: body.planet, date: endDate, observerAU: observerAU).direction
            }
            return (body.planet, (start: equatorial(body.direction), end: end))
        })
    }

    private func rebuildEphemerides(_ date: Double, context: PassViewContext) {
        guard let renderer else { return }
        updateSkyFrame(date, context: context)
        let sunDirection = local(PlanetariumPlanetAppearance.sunDirection(date: date))
        let sunElevation = PlanetariumGeometry.angles(sunDirection).elevation
        renderer.uniforms.sun = SIMD4(sunDirection, Float(sunElevation))
        renderer.uniforms.effects.x = Float(SkyChartAtmosphere.transition(-8, 12, sunElevation))
        renderer.uniforms.effects.y = Float(SkyChartAtmosphere.transition(-18, -5, sunElevation) * (1 - SkyChartAtmosphere.transition(0, 14, sunElevation)))
        let previous = planets
        let observerAU = PlanetariumEquatorialFrame(date: date).j2000(geo2eci(julianDays: date, geodetic: context.observer)) / 149597870.7
        for body in SolarSystemBody.allCases where PlanetariumPlanetOrientation.radius(body) > 0 {
            planetGeometry[body] = PlanetariumPlanetAppearance.geometry(body: body, date: date, observerAU: observerAU)
        }
        planets = SolarSystemBody.allCases.filter { ![.earth, .earthMoonBarycenter, .moon].contains($0) }.map { body in
            let direction = planetGeometry[body].map { local($0.direction) } ?? sunDirection
            let name = AppLocalization.text(String(describing: body).capitalized)
            let label = previous.first { $0.name == name }?.label ?? renderer.texture(Self.labelImage(name,
                color: body == .sun ? .white : UIColor(white: 0.86, alpha: 0.9),
                fontSize: body == .sun ? 30 : 26))
            let distance = body.distance(to: .earth, julianDate: date)
            let magnitude = body.apparentMagnitude(julianDay: date) ?? 6
            return Body(planet: body, name: name, direction: direction,
                        detail: body == .sun ? AppLocalization.text("Sun · Our nearest star") : AppLocalization.format("Planet · %.2f AU from Earth", distance),
                        magnitude: magnitude, texture: glowTexture, label: label,
                        color: body == .mars ? SIMD4(1, 0.55, 0.3, 1) : SIMD4(1, 0.94, 0.8, 1),
                        moon: false, sun: body == .sun, rotation: 0,
                        angularDiameter: 2 * atan(PlanetariumPlanetOrientation.radius(body) / max(1, distance * 149597870.7)))
        }
        let moon = MoonAppearance.Geometry(julianDate: date, observer: context.observer)
        let moonImage = detailedMoonTexture == nil ? MoonAppearance.image(geometry: moon, dimension: 128, exposure: 0.5) : nil
        if abs(date - lastMoonTextureDate) * 86400 >= 60 {
            lastMoonTextureDate = date
            moonTextureTask?.cancel()
            moonTextureTask = Task { [weak self] in
                let image = await Task.detached(priority: .userInitiated) {
                    MoonAppearance.image(geometry: moon, dimension: 1024, exposure: 0.5, detailed: true)
                }.value
                guard !Task.isCancelled, let self, let image, let texture = self.renderer?.texture(image) else { return }
                self.detailedMoonTexture = texture
                if let index = self.planets.firstIndex(where: { $0.moon }) {
                    self.planets[index].texture = texture
                }
            }
        }
        planets.append(Body(planet: .moon, name: AppLocalization.text("Moon"), direction: PlanetariumGeometry.direction(azimuth: moon.coordinate.azim, elevation: moon.coordinate.elev),
                            detail: AppLocalization.format("Moon · %.0f%% illuminated", moon.illuminatedFraction * 100), magnitude: -12,
                            texture: detailedMoonTexture ?? moonImage.flatMap { renderer.texture($0) },
                            label: previous.first { $0.moon }?.label ?? renderer.texture(Self.labelImage(AppLocalization.text("Moon"), color: .white)),
                            color: SIMD4(repeating: Float(moon.illuminatedFraction)), moon: true, sun: false,
                            rotation: Float((180 - moon.coordinate.azim) * .pi / 180)))
        if let selectedEquatorial { selectionDirection = local(selectedEquatorial) }
        if let selectedPlanetName, let body = planets.first(where: { $0.name == selectedPlanetName }) {
            selectionDirection = body.direction
            selection?.detail = body.detail
        }
        if let direction = selectionDirection { selection?.coordinates = coordinateText(direction) }
        if abs(date - lastMotionTrailDate) * 86400 >= 60 {
            rebuildMotionTrails(date: date, observer: context.observer)
            lastMotionTrailDate = date
        }
        updateStarRegion(force: true)
    }

    private func rebuildMotionTrails(date: Double, observer: LatLonAlt) {
        guard let body = selection?.planet, body != .sun, body != .earth else {
            renderer?.setMotionTrails([])
            return
        }
        // Dense ephemeris geometry; the shader controls visible dot spacing.
        // Keep the current epoch as an exact vertex joining past and future.
        let site = geo2eci(julianDays: date, geodetic: observer)
        let halfSteps = body == .moon ? 672 : 730
        let step = body == .moon ? 1.0 / 96 : 0.25
        let color: SIMD3<Float>
        switch body {
        case .moon: color = SIMD3(0.75, 0.83, 0.96)
        case .mars: color = SIMD3(0.93, 0.56, 0.39)
        case .uranus, .neptune: color = SIMD3(0.42, 0.74, 0.88)
        default: color = SIMD3(0.92, 0.79, 0.57)
        }
        var samples: [(SIMD3<Float>, Double)?] = []
        for offset in -halfSteps...halfSteps {
            let delta = Double(offset) * step
            let direction: SIMD3<Float>
            if body == .moon {
                direction = SIMD3<Float>(simd_normalize(PlanetariumEquatorialFrame(date: date + delta).j2000(lunarCel(julianDays: date + delta) - site)))
            } else {
                let observerAU = PlanetariumEquatorialFrame(date: date).j2000(site) / 149597870.7
                direction = PlanetariumPlanetAppearance.geometry(body: body, date: date + delta, observerAU: observerAU).direction
            }
            samples.append((direction, delta))
        }
        renderer?.setMotionTrails(Self.flowingTrail(samples, color: color))
    }

    /// Explicit segment pairs prevent bridges across occulted/missing samples.
    /// Arc length and relative epoch are shared with the ISS direction shader.
    static func flowingTrail(_ samples: [(SIMD3<Float>, Double)?], color: SIMD3<Float>) -> [PlanetariumLineVertex] {
        var vertices: [PlanetariumLineVertex] = []
        var previous: (SIMD3<Float>, Double)?
        var arc: Float = 0
        for sample in samples {
            guard let sample else { previous = nil; continue }
            defer { previous = sample }
            guard let previous else { continue }
            let length = atan2(simd_length(simd_cross(previous.0, sample.0)), simd_dot(previous.0, sample.0))
            guard length.isFinite else { continue }
            vertices.append(.init(position: SIMD4(previous.0, 1), color: SIMD4(color, 0.46),
                                  profile: SIMD4(arc, 2, Float(previous.1), 0)))
            arc += length
            vertices.append(.init(position: SIMD4(sample.0, 1), color: SIMD4(color, 0.46),
                                  profile: SIMD4(arc, 2, Float(sample.1), 0)))
        }
        return vertices
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
        let diagonal = atan(tan(fieldOfView * .pi / 360) * sqrt(1 + aspect * aspect))
        guard force || tier != lastTier || abs(aspect - lastAspect) > 0.01 ||
                abs(diagonal - lastRegionDiagonal) > 2 * .pi / 180 ||
                simd_dot(eq, lastRegionForward) < cos(3 * .pi / 180) else { return }
        let cells = tiers.visibleCells(forward: eq, diagonalHalfAngle: Float(diagonal))
        let ids = cells.map(\.id)
        if force || ids != activeStarCells || tier != lastTier {
            renderedStars = tiers.bright + cells.flatMap { $0.stars(at: tier) }
            renderer.setFaintStarCells(cells, limit: tier)
            activeStarCells = ids
        }
        lastRegionForward = eq; lastTier = tier; lastAspect = aspect; lastRegionDiagonal = diagonal
        if tier > 6.5 && !loadedDeepCatalog && catalogTask == nil {
            catalogTask = Task { [weak self] in
                do {
                    let snapshot = try await StarCatalog().snapshot(maximumMagnitude: 9)
                    try Task.checkCancellation()
                    guard let self else { return }
                    self.tiers = PlanetariumStarTiers(stars: snapshot.stars)
                    self.renderer?.resetStarCellCache()
                    self.activeStarCells = []
                    self.loadedDeepCatalog = true
                    self.catalogTask = nil
                    self.updateStarRegion(force: true)
                } catch { self?.catalogTask = nil }
            }
        }
    }

    private var starLabelTextures: [Int: MTLTexture] = [:]
    private var starLabelCandidates: [Star] = []
    private var starLabelLayout = PlanetariumLabelLayout()
    private var starLabelTask: Task<Void, Never>?
    private var lastStarLabelRefresh = -Double.infinity
    private(set) var visibleStarLabelIDs: [Int] = []

    /// Re-rank only a few times per second; metadata I/O stays on the catalog actor.
    private func updateStarLabelCandidates() {
        guard let context, let renderer else { return }
        let now = animationClock()
        if now - lastStarLabelRefresh >= 0.15 {
            lastStarLabelRefresh = now
            let source = fieldOfView > 70 ? context.starManager.namedBrightStars : renderedStars
            let retained = starLabelCandidates.filter { starLabelLayout.retainedIDs.contains($0.id) }
            let ranked = Array(source.filter {
                $0.magnitude.isFinite && $0.magnitude > -10 &&
                projected(local(SIMD3<Float>(simd_normalize($0.coordinate))), margin: -24) != nil
            }.sorted {
                $0.magnitude == $1.magnitude ? $0.id < $1.id : $0.magnitude < $1.magnitude
            }.prefix(24))
            let retainedIDs = Set(retained.map(\.id))
            starLabelCandidates = retained + ranked.filter { !retainedIDs.contains($0.id) }
        }
        guard starLabelTask == nil else { return }
        let missing = starLabelCandidates.filter { starLabelTextures[$0.id] == nil }
        guard !missing.isEmpty else { return }
        let catalog = context.starManager
        starLabelTask = Task { [weak self] in
            defer { self?.starLabelTask = nil }
            for star in missing {
                guard !Task.isCancelled else { return }
                let info = try? await catalog.starInfo(forId: star.id)
                guard !Task.isCancelled, let self else { return }
                guard let name = info?.displayName,
                      let texture = renderer.texture(Self.labelImage(name, color: UIColor(white: 0.82, alpha: 0.85), fontSize: 24)) else { continue }
                self.starLabelTextures[star.id] = texture
            }
            guard let self else { return }
            // Bound GPU memory while retaining every candidate for the current view.
            let visibleIDs = Set(self.starLabelCandidates.map(\.id))
            let evictable = self.starLabelTextures.keys.filter { !visibleIDs.contains($0) }.sorted()
            for id in evictable.prefix(max(0, self.starLabelTextures.count - 128)) {
                self.starLabelTextures.removeValue(forKey: id)
            }
        }
    }
    private(set) var visibleStarLabelCount = 0

    /// Camera-relative angle is computed at draw time, so the miniature follows
    /// panning/device roll without publishing per-frame SwiftUI state changes.
    func planetAppearance(for body: SolarSystemBody) -> PlanetariumPlanetAppearance? {
        guard let geometry = planetGeometry[body] else { return nil }
        let direction = local(geometry.direction)
        let pole = local(geometry.pole)
        let projectedPole = pole - direction * simd_dot(pole, direction)
        var appearance = geometry.appearance
        appearance.rotation = atan2(-simd_dot(projectedPole, right), simd_dot(projectedPole, up))
        return appearance
    }

    private func prepareFrame() {
        if let date = previewDate { updateTime(date, trackingSelection: true) }
        updateNavigation()
        guard let renderer else { return }
        updateStarRegion()
        updateNaturalMoons()
        updateConstellationFocus()
        // Resolve every planet independently of optional moon ephemeris downloads.
        if fieldOfView < 2 {
            for body in planets where body.angularDiameter > 0 && !body.moon && !body.sun && projected(body.direction, margin: 200) != nil {
                guard let appearance = planetGeometry[body.planet]?.appearance else { continue }
                let old = resolvedPlanetAppearances[body.planet]
                if old == nil || abs(appearance.opening - old!.opening) > 0.0001 || simd_distance(appearance.sunDirection, old!.sunDirection) > 0.0001 {
                    resolvedPlanetTextures[body.planet] = PlanetariumGlobeRenderer.skyTexture(body: body.planet, appearance: appearance)
                    resolvedPlanetAppearances[body.planet] = appearance
                }
            }
        }
        var sprites: [(PlanetariumSprite, MTLTexture)] = []
        let scale = max(1, view.contentScaleFactor)
        func append(_ direction: SIMD3<Float>, _ texture: MTLTexture?, width: CGFloat, tint: SIMD4<Float> = SIMD4(repeating: 1), rotation: Float = 0, overlay: Bool = false, planet: Bool = false, adaptiveLabel: Bool = false) {
            guard let texture, direction.y >= 0, projected(direction, margin: 80, ignoresGround: overlay) != nil else { return }
            var sprite = PlanetariumSprite(positionSize: SIMD4(direction, Float(width * scale)), tint: tint)
            sprite.options = SIMD4(0, Float(texture.height) / Float(texture.width), rotation, adaptiveLabel ? 3 : (planet ? 2 : (overlay ? 1 : 0)))
            sprites.append((sprite, texture))
        }
        var bodyLabelRects: [CGRect] = []
        func appendBodyLabel(_ direction: SIMD3<Float>, _ texture: MTLTexture?, width: CGFloat, fadesTowardEdge: Bool = false, adaptiveColor: Bool = false) {
            guard let texture, let center = projected(direction) else { return }
            let height = width * CGFloat(texture.height) / CGFloat(texture.width)
            let rect = CGRect(x: center.x-width/2, y: center.y-height/2, width: width, height: height).insetBy(dx: -4, dy: -3)
            guard view.bounds.contains(rect), !bodyLabelRects.contains(where: { $0.intersects(rect) }) else { return }
            bodyLabelRects.append(rect)
            var opacity: Float = 1
            if fadesTowardEdge {
                let dx = (center.x - view.bounds.midX) / max(1, view.bounds.width / 2)
                let dy = (center.y - view.bounds.midY) / max(1, view.bounds.height / 2)
                let distance = hypot(dx, dy)
                // Smooth screen-relative falloff stays consistent through zoom and rotation.
                opacity = Float(1 - 0.8 * SkyChartAtmosphere.transition(0.15, 1, Double(distance)))
            }
            // Sprite textures are premultiplied: fade RGB and alpha together.
            append(direction, texture, width: width, tint: SIMD4(repeating: opacity), adaptiveLabel: adaptiveColor)
        }
        for (direction, texture) in cardinals { append(direction, texture, width: 20) }
        for body in planets {
            if body.moon {
                let diskPixels = view.bounds.height * 0.009 / (2 * tan(fieldOfView * .pi / 360))
                let closeZoom = Float(1 - SkyChartAtmosphere.transition(2, 18, fieldOfView))
                let scatter = body.color.x * 0.4 * (1 - renderer.uniforms.effects.x) * (1 - closeZoom * 0.95)
                append(body.direction, glowTexture, width: max(24, diskPixels * 7), tint: SIMD4(repeating: scatter))
                append(body.direction, body.texture, width: max(3, diskPixels), tint: SIMD4(2 - 0.9 * closeZoom, 2 - 0.9 * closeZoom, 2 - 0.9 * closeZoom, 1), rotation: body.rotation + Float(motionRoll))
            } else if body.angularDiameter > 0 && fieldOfView < 2, let disk = resolvedPlanetTextures[body.planet] {
                let fraction = PlanetariumGlobeRenderer.diskRadius(body: body.planet)
                let pixels = view.bounds.height * body.angularDiameter / (2 * tan(fieldOfView * .pi / 360))
                let rotation = planetAppearance(for: body.planet)?.rotation ?? 0
                append(body.direction, disk, width: max(4, pixels / fraction), rotation: rotation, planet: true)
            } else {
                let width: CGFloat = body.sun ? 34 : CGFloat(max(3, min(19, 8 - body.magnitude)))
                let opacity: Float = body.sun ? 1 : 1 - renderer.uniforms.effects.x * 0.97
                append(body.direction, body.texture, width: width, tint: body.color * opacity)
            }
            if body.magnitude < 6 || fieldOfView < 45 {
                var labelOffset = body.moon ? max(0.006, 0.028 * fieldOfView / 65) : max(body.angularDiameter * 0.65, 0.028 * fieldOfView / 65)
                if body.sun {
                    let focal = view.bounds.height / (2 * tan(fieldOfView * .pi / 360))
                    let diskRadius = focal * tan(0.275 * .pi / 180)
                    let halfLabel = CGFloat(body.label?.height ?? 48) / 8
                    // Keep the label close; contrast adapts to the sky/glare behind it.
                    labelOffset = (max(17, diskRadius) + 10 + halfLabel) / max(1, focal)
                }
                let labelDirection = simd_normalize(body.direction - up * Float(labelOffset))
                appendBodyLabel(labelDirection, body.label, width: CGFloat(body.label?.width ?? 60) / 4, adaptiveColor: body.sun)
            }
        }
        for body in naturalMoons where naturalMoonVisible(body) {
            let pixels = view.bounds.height * body.angularDiameter / (2 * tan(fieldOfView * .pi / 360))
            append(body.direction, naturalMoonTextures[body.moon.id], width: max(3, pixels))
            if showLabels {
                let offset = max(body.angularDiameter * 0.7, 0.028 * fieldOfView / 65)
                appendBodyLabel(simd_normalize(body.direction - up * Float(offset)), naturalMoonLabels[body.moon.id],
                       width: CGFloat(naturalMoonLabels[body.moon.id]?.width ?? 60) / 4)
            }
        }
        if satelliteVisible {
            let color = satelliteIlluminated ? SIMD4<Float>(0.35, 1, 0.85, 1) : SIMD4<Float>(0.5, 0.65, 0.75, 0.6)
            append(satelliteDirection, glowTexture, width: 32, tint: color, overlay: true)
            append(satelliteDirection, markerTexture, width: 28, tint: color, overlay: true)
            appendBodyLabel(simd_normalize(satelliteDirection + up * Float(0.045 * fieldOfView / 65)), satelliteLabel,
                   width: min(180, CGFloat(satelliteLabel?.width ?? 180) / 4))
        }
        if showLabels && renderer.uniforms.sun.w < 0 {
            for (direction, texture, width) in constellationLabels {
                appendBodyLabel(local(direction), texture, width: min(150, width / 2), fadesTowardEdge: true)
            }
        }
        visibleStarLabelCount = 0
        visibleStarLabelIDs = []
        if showLabels && renderer.uniforms.sun.w < 0 {
            updateStarLabelCandidates()
            let budget = fieldOfView > 70 ? 3 : (fieldOfView > 35 ? 5 : 7)
            var labelDirections: [Int: SIMD3<Float>] = [:]
            let candidates = starLabelCandidates.compactMap { star -> PlanetariumLabelLayout.Candidate? in
                guard let texture = starLabelTextures[star.id] else { return nil }
                let direction = local(SIMD3<Float>(simd_normalize(star.coordinate)))
                let offset = Float(0.032 * fieldOfView / 65)
                let labelDirection = simd_normalize(direction - up * offset)
                guard let center = projected(labelDirection) else { return nil }
                labelDirections[star.id] = labelDirection
                let width = CGFloat(texture.width) / 4
                let height = CGFloat(texture.height) / 4
                return .init(id: star.id, rect: CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height))
            }
            let placements = starLabelLayout.layout(candidates, bounds: view.bounds,
                obstacles: bodyLabelRects, budget: budget, time: animationClock())
            for placement in placements {
                guard let direction = labelDirections[placement.id] else { continue }
                append(direction, starLabelTextures[placement.id], width: placement.rect.width,
                       tint: SIMD4(repeating: placement.opacity))
                visibleStarLabelIDs.append(placement.id)
            }
            visibleStarLabelCount = placements.count
        } else {
            starLabelLayout.reset()
        }

        if let selectionDirection, selection?.moonID == nil || naturalMoons.contains(where: { $0.moon.id == selection?.moonID && naturalMoonVisible($0) }) {
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
        let lineView = [renderer.uniforms.forward, renderer.uniforms.north, renderer.uniforms.east,
                        SIMD4(Float(view.bounds.width), Float(view.bounds.height), Float(fieldOfView), 0)]
        guard lastFigure != constellationFocus.active || lastFigureProgress != progress || lineView != lastLineView else { return }
        lastLineView = lineView
        lastFigure = constellationFocus.active; lastFigureProgress = progress
        guard let index = constellationFocus.active, progress > 0 else { renderer.setConstellations([]); return }
        var vertices: [PlanetariumLineVertex] = []
        for (a, b) in constellationFigures[index].edges {
            // Use the original star positions, not the contracting segment, so
            // the fade cannot oscillate as the line shrinks during a handoff.
            let visibility = constellationEdgeVisibility(local(a), local(b))
            guard visibility > 0 else { continue }
            for i in 0..<12 {
                for t in [Float(i) / 12, Float(i + 1) / 12] {
                    let contracted = 0.5 + (t - 0.5) * progress
                    let direction = simd_normalize(a * (1 - contracted) + b * contracted)
                    vertices.append(.init(position: SIMD4(direction, 1), color: SIMD4(0.68, 0.80, 1, 0.36 * progress * visibility),
                        profile: SIMD4(t, 0, 0, 0)))
                }
            }
        }
        renderer.setConstellations(vertices)
    }
    private func constellationEdgeVisibility(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        // Begin the close-up behavior below 30°, fully applying it at 18°.
        let closeZoom = Float(1 - SkyChartAtmosphere.transition(18, 30, fieldOfView))
        guard closeZoom > 0 else { return 1 }
        let za = simd_dot(a, forward), zb = simd_dot(b, forward)
        guard za > 0.005, zb > 0.005 else { return 1 - closeZoom }
        let tangent = Float(tan(fieldOfView * .pi / 360))
        let pa = SIMD2(simd_dot(a, right), simd_dot(a, up)) / za
        let pb = SIMD2(simd_dot(b, right), simd_dot(b, up)) / zb
        let aspect = Float(view.bounds.width / max(1, view.bounds.height))
        let span = simd_length(pa - pb) / (2 * tangent * max(0.01, min(1, aspect)))
        // Fade between 55% and 95% of the shorter viewport dimension.
        let fade = Float(SkyChartAtmosphere.transition(0.55, 0.95, Double(span)))
        return 1 - closeZoom * fade
    }

    func zoom(by factor: Double) {
        stopPanMomentum()
        fieldOfView = max(0.005, min(100, fieldOfView * factor))
        renderer?.uniforms.viewport.z = Float(tan(fieldOfView * .pi / 360))
        renderer?.uniforms.viewport.w = Float(fieldOfView)
        updateStarRegion()
    }
    let navigation = PlanetariumNavigationState()
    var stationBearing: Double? { navigation.bearing }
    private var panVelocity = SIMD2<Double>.zero
    private var momentumTime: Double?
    var isPanningWithMomentum: Bool { momentumTime != nil }
    private var cameraPan: (start: Double, azimuth: Double, elevation: Double)?

    func animateToSatellite() {
        stopPanMomentum()
        setMotionEnabled(false)
        if UIAccessibility.isReduceMotionEnabled { focusSatellite(); return }
        cameraPan = (animationClock(), azimuth, elevation)
    }

    /// Advance with rendered frames, including previews hosted in a separate window.
    func updateNavigation() {
        if let previous = momentumTime {
            let now = animationClock()
            let dt = now - previous
            if motionEnabled || !active || UIAccessibility.isReduceMotionEnabled || dt > 0.25 || dt < 0 {
                stopPanMomentum()
            } else {
                // StarryNight's 0.9 damping at 60 Hz, integrated in elapsed time
                // so 30/60/120 Hz displays coast for the same distance.
                let decay = exp(-6.32163094 * dt)
                let displacement = panVelocity * ((1 - decay) / 6.32163094)
                applyPanTranslation(CGPoint(x: displacement.x, y: displacement.y))
                panVelocity *= decay
                momentumTime = now
                if simd_length(panVelocity) < 8 { stopPanMomentum() }
            }
        }
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
            DispatchQueue.main.async { [weak self] in self?.navigation.bearing = bearing }
        }
    }

    func focusSatellite() {
        let angles = PlanetariumGeometry.angles(satelliteDirection)
        pointCamera(azimuth: angles.azimuth, elevation: angles.elevation)
    }
    func pointCamera(azimuth: Double, elevation: Double) {
        stopPanMomentum()
        cameraPan = nil
        self.azimuth = azimuth; self.elevation = elevation; panOffset = .zero; motionRoll = 0
        updateCamera()
        updateStarRegion(force: true)
    }
    func setMotionEnabled(_ enabled: Bool) {
        if motionEnabled != enabled { motionEnabled = enabled }
        motionSession += 1
        let session = motionSession
        if enabled { cameraPan = nil; stopPanMomentum() }
        motion.stopDeviceMotionUpdates()
        motionFilter.reset()
        if !enabled {
            azimuth += panOffset.x; elevation += panOffset.y; panOffset = .zero
            updateCamera()
        }
        guard enabled, active, motion.isDeviceMotionAvailable else { return }
        panOffset = .zero
        motion.deviceMotionUpdateInterval = 1 / 60
        let frames = CMMotionManager.availableAttitudeReferenceFrames()
        let reference: CMAttitudeReferenceFrame = frames.contains(.xTrueNorthZVertical) ? .xTrueNorthZVertical : .xMagneticNorthZVertical
        motion.startDeviceMotionUpdates(using: reference, to: .main) { [weak self] data, error in
            guard let self, self.motionEnabled, self.active, self.motionSession == session else { return }
            guard let data, error == nil else { self.motionAvailable = false; return }
            if !self.motionAvailable { self.motionAvailable = true }
            // Core Motion's matrix transforms reference -> device; rows express
            // device axes in north/west/up. Optical axis is -device Z.
            let r = data.attitude.rotationMatrix
            let f = SIMD3<Float>(Float(r.m32), Float(-r.m33), Float(r.m31))
            var screenUp = SIMD3<Float>(Float(-r.m22), Float(r.m23), Float(-r.m21))
            switch self.view.window?.windowScene?.interfaceOrientation {
            case .landscapeLeft: screenUp = SIMD3(Float(r.m12), Float(-r.m13), Float(r.m11))
            case .landscapeRight: screenUp = SIMD3(Float(-r.m12), Float(r.m13), Float(-r.m11))
            case .portraitUpsideDown: screenUp = -screenUp
            default: break
            }
            self.updateMotionOrientation(forward: f, screenUp: screenUp, timestamp: data.timestamp)
        }
    }

    func updateMotionOrientation(forward f: SIMD3<Float>, screenUp: SIMD3<Float>, timestamp: Double? = nil) {
        guard motionEnabled, active,
              let pose = motionFilter.update(forward: f, up: screenUp, timestamp: timestamp ?? animationClock()) else { return }
        forward = pose.act(SIMD3(0, 0, -1))
        up = pose.act(SIMD3(0, 1, 0))
        right = pose.act(SIMD3(1, 0, 0))
        let angles = PlanetariumGeometry.angles(forward)
        azimuth = angles.azimuth; elevation = angles.elevation
        let horizontal = simd_cross(forward, SIMD3<Float>(0, 1, 0))
        let eastOnScreen = simd_length_squared(horizontal) > 0.000001 ? simd_normalize(horizontal) : right
        let upright = simd_normalize(simd_cross(eastOnScreen, forward))
        motionRoll = Double(atan2(simd_dot(up, eastOnScreen), simd_dot(up, upright)))
        // Keep the filtered orthonormal basis through the zenith rather than reconstructing Euler angles.
        writeCameraUniforms()
    }

    func setActive(_ active: Bool) {
        self.active = active
        if !active { stopPanMomentum() }
        view.isPaused = !active
        setMotionEnabled(motionEnabled)
    }
    func stop() {
        previewPlayback = nil
        starLabelTask?.cancel(); starLabelTask = nil
        moonLoadTask?.cancel(); moonLoadTask = nil
        moonTextureTask?.cancel(); moonTextureTask = nil
        cameraPan = nil
        setActive(false)
        catalogTask?.cancel(); catalogTask = nil
        selectionTask?.cancel(); selectionTask = nil
    }
    func clearSelection() {
        selectionTask?.cancel(); selectionTask = nil
        selection = nil; selectionDirection = nil; selectedEquatorial = nil; selectedPlanetName = nil
    }
    /// Shared rendering/hit-test visibility, exposed internally for UI regression tests.
    var visibleNaturalMoonPositions: [Int: CGPoint] {
        Dictionary(uniqueKeysWithValues: naturalMoons.filter { naturalMoonVisible($0) }.compactMap { body in
            projected(body.direction).map { (body.moon.id, $0) }
        })
    }
    private func updateCamera() {
        forward = PlanetariumGeometry.direction(azimuth: azimuth + panOffset.x, elevation: max(-89.5, min(89.5, elevation + panOffset.y)))
        let horizontalRight = simd_normalize(simd_cross(forward, SIMD3<Float>(0, 1, 0)))
        let upright = simd_normalize(simd_cross(horizontalRight, forward))
        up = upright * Float(cos(motionRoll)) + horizontalRight * Float(sin(motionRoll))
        right = simd_normalize(simd_cross(forward, up))
        writeCameraUniforms()
    }
    private func writeCameraUniforms() {
        renderer?.uniforms.forward = SIMD4(forward, 0)
        renderer?.uniforms.right = SIMD4(right, 0)
        renderer?.uniforms.up = SIMD4(up, 0)
        renderer?.uniforms.viewport.z = Float(tan(fieldOfView * .pi / 360))
        renderer?.uniforms.viewport.w = Float(fieldOfView)
    }
    @objc private func pan(_ gesture: UIPanGestureRecognizer) {
        let delta = gesture.translation(in: view); gesture.setTranslation(.zero, in: view)
        switch gesture.state {
        case .began, .changed: panBy(delta)
        case .ended:
            panBy(delta)
            finishPan(velocity: gesture.velocity(in: view))
        case .cancelled, .failed: stopPanMomentum()
        default: break
        }
    }

    func panBy(_ delta: CGPoint) {
        stopPanMomentum()
        cameraPan = nil
        if motionEnabled { setMotionEnabled(false) }
        motionRoll = 0
        applyPanTranslation(delta)
    }

    func finishPan(velocity: CGPoint) {
        guard active, !motionEnabled, !UIAccessibility.isReduceMotionEnabled else { return }
        let v = SIMD2<Double>(velocity.x, velocity.y)
        let speed = simd_length(v)
        guard speed.isFinite, speed >= 8 else { stopPanMomentum(); return }
        panVelocity = v * (min(speed, 3000) / speed)
        momentumTime = animationClock()
    }

    func stopPanMomentum() {
        panVelocity = .zero
        momentumTime = nil
    }

    private func applyPanTranslation(_ delta: CGPoint) {
        // Bounded yaw/pitch avoids the 1/cos(elevation) azimuth amplification
        // caused by converting screen-tangent motion back to spherical angles.
        // The same rate applies to dragging and inertia, even near either pole.
        let scale = fieldOfView / max(1, view.bounds.height)
        azimuth = (azimuth + panOffset.x - delta.x * scale).truncatingRemainder(dividingBy: 360)
        elevation = max(-89.5, min(89.5, elevation + panOffset.y + delta.y * scale))
        panOffset = .zero
        updateCamera()
    }
    @objc private func pinch(_ gesture: UIPinchGestureRecognizer) { zoom(by: 1 / gesture.scale); gesture.scale = 1 }
    @objc private func tap(_ gesture: UITapGestureRecognizer) { select(at: gesture.location(in: view)) }

    /// Hit tests the same projection and active catalog tiers as the renderer.
    func select(at point: CGPoint) {
        stopPanMomentum()
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
        var bestMoon: NaturalMoonBody?
        for body in naturalMoons where naturalMoonVisible(body) {
            guard let p = projected(body.direction) else { continue }
            let distance = hypot(p.x - point.x, p.y - point.y)
            if distance < bestDistance { bestDistance = distance; bestMoon = body; bestBody = nil; bestStar = nil }
        }
        if let body = bestMoon {
            selectedEquatorial = nil; selectedPlanetName = nil
            selectionDirection = body.direction
            selection = .init(id: "moon-\(body.moon.id)", name: AppLocalization.text(body.moon.name),
                detail: AppLocalization.format("Moon of %@ · %.0f km radius", AppLocalization.text(String(describing: body.moon.parent).capitalized), body.moon.radius),
                coordinates: coordinateText(body.direction), moonID: body.moon.id)
        } else if let body = bestBody {
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
                self.selectedEquatorial = SIMD3<Float>(simd_normalize(star.coordinate))
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
    private static func labelImage(_ title: String, color: UIColor, celestial: Bool = true, fontSize: CGFloat = 26) -> UIImage {
        let base = UIFont.systemFont(ofSize: fontSize, weight: .regular)
        let font = celestial ? UIFont(descriptor: base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor, size: fontSize) : base
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (title as NSString).size(withAttributes: attributes)
        let format = UIGraphicsImageRendererFormat(); format.scale = 2
        return UIGraphicsImageRenderer(size: CGSize(width: ceil(size.width) + 8, height: ceil(font.lineHeight) + 4), format: format).image { _ in
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


@MainActor private extension PlanetariumController {
    private func naturalMoonVisible(_ body: NaturalMoonBody) -> Bool {
        guard fieldOfView < 2, (renderer?.uniforms.sun.w ?? 90) < 0,
              let p = projected(body.direction), let parent = projected(body.parentDirection, margin: 10000) else { return false }
        // At least eight points from the planet: avoid revealing unresolved dots
        // as a clump at broad zoom, and use the same rule for hit testing.
        return hypot(p.x - parent.x, p.y - parent.y) >= 8
    }

    func updateNaturalMoons() {
        guard let context, let renderer, currentSkyDate.isFinite else { return }
        if fieldOfView < 2, moonLoadTask == nil, Date() >= moonRetryAfter,
           let parent = planets.filter({ body in
               PlanetariumMoon.all.contains { $0.parent == body.planet } && projected(body.direction, margin: 200) != nil
           }).max(by: { simd_dot($0.direction, forward) < simd_dot($1.direction, forward) })?.planet {
            let needed = PlanetariumMoon.all.filter { $0.parent == parent && moonEphemerides[$0.id]?.contains(currentSkyDate) != true }
            if !needed.isEmpty {
                let date = currentSkyDate
                moonLoadTask = Task { [weak self] in
                    defer { self?.moonLoadTask = nil }
                    for moon in needed {
                        guard !Task.isCancelled else { return }
                        do {
                            let data = try await MoonEphemerisStore.shared.load(moon, date: date)
                            guard !Task.isCancelled, let self else { return }
                            self.moonEphemerides[moon.id] = data
                            self.moonSceneKey = ""
                        } catch {
                            self?.moonRetryAfter = Date().addingTimeInterval(120)
                            return
                        }
                    }
                }
            }
        }
        let key = "\(currentSkyDate)-\(fieldOfView < 2)-\(selection?.id ?? "")"
        guard key != moonSceneKey else { return }
        moonSceneKey = key
        naturalMoons = []
        if selection?.moonID != nil { selectionDirection = nil }
        let orbitKey = "\(selection?.id ?? "")-\(fieldOfView < 2)"
        let refreshOrbits = orbitKey != moonOrbitKey || abs(currentSkyDate - lastMoonOrbitDate) * 86400 >= 1
        var orbits: [PlanetariumLineVertex] = []
        let site = PlanetariumEquatorialFrame(date: currentSkyDate).j2000(geo2eci(julianDays: currentSkyDate, geodetic: context.observer))
        for moon in PlanetariumMoon.all {
            guard let table = moonEphemerides[moon.id],
                  let moonPosition = MoonEphemeris.interpolate(table.moon, at: currentSkyDate),
                  let parentPosition = MoonEphemeris.interpolate(table.parent, at: currentSkyDate) else { continue }
            let parentVector = parentPosition - site, moonVector = moonPosition - site
            let parentUnit = simd_normalize(parentVector)
            let parentDirection = local(SIMD3<Float>(parentUnit))
            let relative = moonPosition - parentPosition
            func occulted(_ offset: SIMD3<Double>) -> Bool {
                let depth = simd_dot(offset, parentUnit)
                return depth > 0 && simd_length(offset - parentUnit * depth) < moon.parentRadius
            }
            if let index = planets.firstIndex(where: { $0.planet == moon.parent }) {
                planets[index].direction = parentDirection
                planets[index].angularDiameter = 2 * atan(moon.parentRadius / simd_length(parentVector))
                if selection?.planet == moon.parent {
                    selectionDirection = parentDirection
                    selection?.coordinates = coordinateText(parentDirection)
                }
            }
            if !occulted(relative) {
                let body = NaturalMoonBody(moon: moon, direction: local(SIMD3<Float>(simd_normalize(moonVector))),
                    parentDirection: parentDirection, angularDiameter: 2 * atan(moon.radius / simd_length(moonVector)), distance: simd_length(moonVector))
                naturalMoons.append(body)
                if naturalMoonTextures[moon.id] == nil {
                    naturalMoonTextures[moon.id] = renderer.texture(MoonSurface.image(for: moon))
                    naturalMoonLabels[moon.id] = renderer.texture(Self.labelImage(AppLocalization.text(moon.name), color: UIColor(white: 0.8, alpha: 1)))
                }
                if selection?.moonID == moon.id {
                    selectionDirection = body.direction
                    selection?.coordinates = coordinateText(body.direction)
                }
            } else if selection?.moonID == moon.id { selectionDirection = nil }
            let selectedParent = selection?.planet == moon.parent
            guard refreshOrbits, fieldOfView < 2, selectedParent || selection?.moonID == moon.id else { continue }
            // Subtract the planet's motion from each ephemeris sample and anchor
            // one complete revolution on its present position. This is a local
            // orbit, not a months-long geocentric proper-motion trail.
            let samples: [(SIMD3<Float>, Double)?] = table.orbitDates(period: moon.period).map { date in
                guard let m = MoonEphemeris.interpolate(table.moon, at: date),
                      let p = MoonEphemeris.interpolate(table.parent, at: date), !occulted(m-p) else { return nil }
                return (SIMD3<Float>(simd_normalize(parentVector + m-p)), date - currentSkyDate)
            }
            orbits.append(contentsOf: Self.flowingTrail(samples, color: SIMD3(0.52, 0.74, 0.88)))
        }
        if refreshOrbits {
            renderer.setMoonOrbits(orbits)
            lastMoonOrbitDate = currentSkyDate
            moonOrbitKey = orbitKey
        }
    }
}
