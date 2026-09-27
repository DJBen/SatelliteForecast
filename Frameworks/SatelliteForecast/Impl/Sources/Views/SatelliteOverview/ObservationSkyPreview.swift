import SwiftUI
import SatelliteForecast
import SatelliteKit
import SolarSystem

/// A side-on view of the app's sky dome, with a shared projection for the
/// existing sky renderer and the pass. Only the precomputed track animates.
struct ObservationSkyPreview: View {
    let preview: ObservationPreview
    let observer: LatLonAlt
    let session: AppSession
    /// Home keeps the sky above the pass, dissolving toward the top edge.
    var extendsSkyUpward = false
    var isActive = true
    var reviewProgress: Double? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var started = Date()

    private var paused: Bool { reduceMotion || SnapshotEnvironment.isEnabled || !isActive || scenePhase != .active }
    private var pass: Pass { preview.snapshots.pass }
    private var samples: [SatelliteSnapshot] {
        preview.snapshots.snapshots.filter { $0.julianDate >= pass.rise.julianDate && $0.julianDate <= pass.set.julianDate }
    }

    var body: some View {
        GeometryReader { geometry in
            let samples = samples
            let projection = ObservationSkyProjection(pass: pass, samples: samples, size: geometry.size,
                extendsUpward: extendsSkyUpward)
            let points = samples.map { projection.point(azimuth: $0.position.azim, elevation: $0.position.elev) }
            ZStack(alignment: .topLeading) {
                ObservationSkyBackground(projection: projection, observer: observer,
                    julianDate: pass.culmination.julianDate, renderer: session.renderer)
                // Project positions, not point-source artwork: bright stars retain
                // the chart's compact spectral glow instead of becoming stretched.
                Canvas { context, _ in
                    guard pass.sunElevationAtTransit < -6 else { return }
                    let traits = UITraitCollection(userInterfaceStyle: .dark)
                    context.withCGContext { cg in
                        for star in session.catalog.stars(maximumMagnitude: 2.5) {
                            let coordinate = azel(time: Date(julianDate: pass.culmination.julianDate),
                                site: LatLon(observer), cele: RADec(star.coordinate))
                            guard let point = projection.visiblePoint(azimuth: coordinate.azim, elevation: coordinate.elev) else { continue }
                            // Stars dissolve at the frame edges together with the sky behind them.
                            let fade = projection.edgeFade(at: point)
                            guard fade > 0.02 else { continue }
                            SkyChartTheme.drawPointSource(in: cg, at: point,
                                radius: BackgroundSkyConfigs.StarMagToDisplayRadiusMappingFunction.default.apply(star.magnitude),
                                color: SkyChartTheme.starColor(spectralClass: star.spectralClass, traitCollection: traits)
                                    .withAlphaComponent(fade),
                                magnitude: star.magnitude)
                        }
                    }
                }
                .clipped()
                // Keep resolved Moon/planet disks round rather than warping their
                // artwork with the diffuse sky texture. They share the same projection.
                ForEach(BackgroundSkyConfigs().visibleBodies, id: \.self) { body in
                    PlanetaryBodyView(planetaryBody: body, label: .none, magFunction: .default,
                        referenceDate: pass.culmination.julianDate, observer: observer,
                        sunElevation: pass.sunElevationAtTransit,
                        projectedPosition: { coordinate, _ in
                            // A disk centered on the horizon reads as risen even while
                            // the body is still below it; require it to clear the horizon.
                            guard coordinate.elev >= Self.minimumBodyElevation else { return nil }
                            return projection.visiblePoint(azimuth: coordinate.azim, elevation: coordinate.elev)
                        })
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                Canvas { context, _ in
                    var horizon = Path()
                    for step in 0...120 {
                        let azimuth = pass.rise.azim + projection.arc * Double(step) / 120
                        let point = projection.point(azimuth: azimuth, elevation: 0)
                        if step == 0 { horizon.move(to: point) } else { horizon.addLine(to: point) }
                    }
                    context.stroke(horizon, with: .color(AppTheme.muted.opacity(0.5)),
                        style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [1, 5]))
                }
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: paused)) { timeline in
                    let progress = reviewProgress ?? (paused ? 0.58 : min(1, max(0, timeline.date.timeIntervalSince(started))
                        .truncatingRemainder(dividingBy: 15) / 12))
                    Canvas { context, _ in
                        drawOrbit(context: &context, points: points, samples: samples, progress: progress)
                    }
                }
                endpoint(pass.rise, projection: projection)
                endpoint(pass.set, projection: projection)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .environment(\.colorScheme, .dark)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Pass animation preview. Solid trail: traveled in the preview. Dotted trail: still ahead. Gray: in Earth’s shadow.", bundle: .module))
        .onChange(of: isActive) { _, active in if active { started = Date() } }
        .onChange(of: scenePhase) { _, phase in if phase == .active { started = Date() } }
    }

    private static let minimumBodyElevation = 2.0

    private func endpoint(_ position: Pass.DatePosition, projection: ObservationSkyProjection) -> some View {
        let point = projection.point(azimuth: position.azim, elevation: 0)
        return Text(ObservationOpportunity.direction(position.azim))
            .font(.caption2.weight(.medium))
            .foregroundStyle(AppTheme.muted)
            .position(x: point.x, y: point.y + 19)
    }

    private func drawOrbit(context: inout GraphicsContext, points: [CGPoint], samples: [SatelliteSnapshot], progress: Double) {
        guard points.count > 1, let first = samples.first, let last = samples.last else { return }
        let time = first.julianDate + progress * (last.julianDate - first.julianDate)
        let index = min(samples.firstIndex(where: { $0.julianDate >= time }).map { max(0, $0 - 1) } ?? (samples.count - 2), samples.count - 2)
        let fraction = min(1, max(0, (time - samples[index].julianDate) / max(1e-9, samples[index + 1].julianDate - samples[index].julianDate)))
        let cursor = CGPoint(x: points[index].x + (points[index + 1].x - points[index].x) * fraction,
                             y: points[index].y + (points[index + 1].y - points[index].y) * fraction)
        let traits = UITraitCollection(userInterfaceStyle: .dark)
        func color(_ lit: Bool) -> Color { Color(uiColor: SkyChartTheme.satellitePathColor(illuminated: lit, traitCollection: traits)) }
        // Group by illumination and preview time. Dashes never encode illumination.
        // The dotted track always covers the whole pass from fixed sample points so the dash
        // phase stays put while the solid elapsed portion is painted over it up to the cursor.
        for ahead in [true, false] {
            for lit in [false, true] {
                var path = Path()
                var connected = false
                for i in 0..<(points.count - 1) {
                    guard samples[i].isIlluminated == lit, ahead || i <= index else { connected = false; continue }
                    let to = !ahead && i == index ? cursor : points[i + 1]
                    if !connected { path.move(to: points[i]) }
                    path.addLine(to: to)
                    connected = true
                }
                if !ahead && lit {
                    context.drawLayer { glow in
                        glow.addFilter(.blur(radius: 4))
                        glow.stroke(path, with: .color(color(lit).opacity(0.35)), lineWidth: 4)
                    }
                }
                let stroke = StrokeStyle(lineWidth: ahead ? 2.2 : 2.8, lineCap: .round, dash: ahead ? [2, 5] : [])
                context.stroke(path, with: .color(.black.opacity(0.5)),
                    style: StrokeStyle(lineWidth: stroke.lineWidth + 2, lineCap: .round, dash: stroke.dash))
                context.stroke(path, with: .color(color(lit)), style: stroke)
            }
        }
        // Two small directional arrowheads retain the annotated design's motion cue.
        for ratio in [0.25, 0.73] {
            let i = min(points.count - 2, Int(Double(points.count - 1) * ratio))
            let a = points[i], b = points[i + 1]
            let angle = atan2(b.y - a.y, b.x - a.x)
            var arrow = Path()
            arrow.move(to: CGPoint(x: a.x - 6 * cos(angle - 0.5), y: a.y - 6 * sin(angle - 0.5)))
            arrow.addLine(to: a)
            arrow.addLine(to: CGPoint(x: a.x - 6 * cos(angle + 0.5), y: a.y - 6 * sin(angle + 0.5)))
            context.stroke(arrow, with: .color(color(samples[i].isIlluminated)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        }
        let lit = samples[index].isIlluminated
        if lit {
            context.drawLayer { glow in
                glow.addFilter(.blur(radius: 5))
                glow.fill(Path(ellipseIn: CGRect(x: cursor.x - 7, y: cursor.y - 7, width: 14, height: 14)), with: .color(color(true).opacity(0.8)))
            }
        }
        context.fill(Path(ellipseIn: CGRect(x: cursor.x - 3.5, y: cursor.y - 3.5, width: 7, height: 7)), with: .color(lit ? .white : color(false)))
    }
}

/// A conformal sky view centered on the minor rise-to-set arc. Stereographic
/// projection uses ONE scale for both axes, preserving local celestial shapes.
/// The diffuse sky is rendered directly from spherical source data in this view;
/// no intermediate circular chart, hemisphere folding or vertical stretch is used.
struct ObservationSkyProjection: Hashable, Sendable {
    static let pitch = -18.0 * Double.pi / 180
    let width: Double
    let height: Double
    let arc: Double
    let centerAzimuth: Double
    let right: SIMD2<Double>
    let front: SIMD2<Double>
    let scale: Double
    let originY: Double
    /// Upper envelope of the projected pass, sampled once per horizontal point.
    private let skyBoundary: [Double]
    /// Fill the sky above the pass too, fading out toward the top edge.
    let extendsUpward: Bool
    var size: CGSize { CGSize(width: width, height: height) }

    static func minorArc(from rise: Double, to set: Double) -> Double {
        let turn = PlanetariumGeometry.shortestTurn(from: rise, to: set)
        // Exactly opposite directions have two equal semicircles, never a longer
        // arc. Pick one consistently instead of changing with culmination azimuth.
        return abs(turn) == 180 ? 180 : turn
    }

    init(pass: Pass, samples: [SatelliteSnapshot], size: CGSize, extendsUpward: Bool = false) {
        width = size.width; height = size.height
        self.extendsUpward = extendsUpward
        arc = Self.minorArc(from: pass.rise.azim, to: pass.set.azim)
        centerAzimuth = pass.rise.azim + arc / 2
        let a = centerAzimuth * .pi / 180
        let front = SIMD2(sin(a), cos(a))
        let right = SIMD2(cos(a), -sin(a)) * (arc < 0 ? -1.0 : 1.0)
        self.front = front; self.right = right
        let rise = Self.project(azimuth: pass.rise.azim, elevation: 0, front: front, right: right)
        let set = Self.project(azimuth: pass.set.azim, elevation: 0, front: front, right: right)
        let peak = Self.project(azimuth: pass.culmination.azim, elevation: pass.culmination.elev, front: front, right: right)
        let path = samples.map { Self.project(azimuth: $0.position.azim, elevation: max(0, $0.position.elev), front: front, right: right) }
        let widest = max(0.2, max(abs(rise.x), max(abs(set.x), path.map { abs($0.x) }.max() ?? 0)))
        let bottom = min(rise.y, set.y)
        let top = max(peak.y, path.map(\.y).max() ?? peak.y)
        let scale = min(max(1, size.width - 30) / (2 * widest), max(1, size.height - 66) / max(0.1, top - bottom))
        self.scale = scale
        let originY = size.height - 36 + bottom * scale
        self.originY = originY
        let projected = path.map { SIMD2(size.width / 2 + $0.x * scale, originY - $0.y * scale) }
        skyBoundary = (0...Int(ceil(size.width))).map { x in
            var upper = size.height
            for (a, b) in zip(projected, projected.dropFirst()) {
                guard Double(x) >= min(a.x, b.x), Double(x) <= max(a.x, b.x) else { continue }
                let t = abs(b.x - a.x) < 0.001 ? 0 : (Double(x) - a.x) / (b.x - a.x)
                upper = min(upper, a.y + (b.y - a.y) * t)
            }
            return upper
        }
    }

    private static func project(azimuth: Double, elevation: Double, front: SIMD2<Double>, right: SIMD2<Double>) -> SIMD2<Double> {
        let a = azimuth * .pi / 180, e = elevation * .pi / 180
        let h = SIMD2(sin(a), cos(a)) * cos(e)
        let depth = h.x * front.x + h.y * front.y, z = sin(e)
        let denominator = max(0.0001, 1 + depth * cos(pitch) + z * sin(pitch))
        return SIMD2((h.x * right.x + h.y * right.y) / denominator,
                     (z * cos(pitch) - depth * sin(pitch)) / denominator)
    }

    /// Keep the photographic sky close to the pass, with a narrow feather across
    /// the arc. The shared raster gives home and widgets the same limited bleed;
    /// foreground stars use the same fade, without recoloring the atmosphere.
    func edgeFade(at point: CGPoint) -> Double {
        func smooth(_ low: Double, _ high: Double, _ value: Double) -> Double {
            let t = min(1, max(0, (value - low) / (high - low)))
            return t * t * (3 - 2 * t)
        }
        let x = min(skyBoundary.count - 1, max(0, Int(point.x)))
        let bleed = max(4, width * 0.04)
        var vertical = smooth(-bleed, bleed, point.y - skyBoundary[x])
        if extendsUpward {
            // Straight sides up from the horizon; the top dissolves by the pass's peak.
            let peak = max(bleed, skyBoundary.min() ?? height)
            vertical = max(vertical, smooth(0, peak, point.y))
        }
        return vertical
            * smooth(0, width * 0.08, min(point.x, width - point.x))
            * smooth(0, height * 0.08, height - point.y)
    }

    func point(azimuth: Double, elevation: Double) -> CGPoint {
        let p = Self.project(azimuth: azimuth, elevation: elevation, front: front, right: right)
        return CGPoint(x: width / 2 + p.x * scale, y: originY - p.y * scale)
    }

    func visiblePoint(azimuth: Double, elevation: Double) -> CGPoint? {
        guard elevation >= 0,
              abs(PlanetariumGeometry.shortestTurn(from: centerAzimuth, to: azimuth)) <= 90.0001 else { return nil }
        let p = point(azimuth: azimuth, elevation: elevation)
        guard p.x >= 0, p.x <= width, p.y >= 0, p.y <= height else { return nil }
        return p
    }

    /// Screen pixel → unit local direction (east, north, zenith), for direct
    /// spherical-texture sampling. This also supplies the atmospheric ray.
    func direction(at point: CGPoint) -> SIMD3<Double> {
        let x = (point.x - width / 2) / scale, y = (originY - point.y) / scale
        let denominator = 1 + x * x + y * y
        let r = 2 * x / denominator, u = 2 * y / denominator
        let f = (1 - x * x - y * y) / denominator
        let depth = f * cos(Self.pitch) - u * sin(Self.pitch)
        let horizontal = right * r + front * depth
        return SIMD3(horizontal.x, horizontal.y, f * sin(Self.pitch) + u * cos(Self.pitch))
    }
}
