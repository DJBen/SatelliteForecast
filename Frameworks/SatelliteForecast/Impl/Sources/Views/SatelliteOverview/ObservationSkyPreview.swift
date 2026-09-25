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
            let projection = ObservationSkyProjection(pass: pass, samples: samples, size: geometry.size)
            let points = samples.map { projection.point(azimuth: $0.position.azim, elevation: $0.position.elev) }
            ZStack(alignment: .topLeading) {
                ScreenFactory(session: session).background(.init(observer: observer,
                    basicChartConfigs: .init(showAzimuthTexts: false, azimuthMarkInterval: 90,
                        azimuthMarkLength: 0, showDirections: false, showsAttitude: false),
                    configs: .init(stars: .none, showConstellationLines: false,
                        showStarNames: false, visibleBodies: [], bodySymbol: .none), quality: .full,
                    allowsStarInteraction: false,
                    starManager: session.catalog, constellationLabel: { _ in EmptyView() },
                    annotationView: { _ in EmptyView() }, starTapped: { _ in }))
                    .environment(\.backgroundSkyJulianDateKey, pass.culmination.julianDate.roundJulianDate(.toMins(1)))
                    .frame(width: geometry.size.width, height: geometry.size.width)
                    .drawingGroup()
                    .layerEffect(ShaderLibrary.bundle(.module).observationSkyDome(
                        .float4(Float(geometry.size.width), Float(geometry.size.height),
                                Float(projection.extent), Float(projection.horizonDepth)),
                        .float4(Float(projection.right.x), Float(projection.right.y),
                                Float(projection.front.x), Float(projection.front.y)),
                        .float4(Float(projection.baseline), Float(projection.verticalScale),
                                Float(ObservationSkyProjection.tilt), Float(projection.halfWidth))),
                        maxSampleOffset: CGSize(width: geometry.size.width, height: geometry.size.width))
                    .frame(height: geometry.size.height, alignment: .top)
                    .clipped()
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
                            SkyChartTheme.drawPointSource(in: cg, at: point,
                                radius: BackgroundSkyConfigs.StarMagToDisplayRadiusMappingFunction.default.apply(star.magnitude),
                                color: SkyChartTheme.starColor(spectralClass: star.spectralClass, traitCollection: traits),
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
                            projection.visiblePoint(azimuth: coordinate.azim, elevation: coordinate.elev)
                        })
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                Canvas { context, _ in
                    var horizon = Path()
                    for step in 0...120 {
                        let x = -projection.extent + 2 * projection.extent * Double(step) / 120
                        let depth = sqrt(max(0, 1 - x * x))
                        let point = projection.point(right: x, front: depth, up: 0)
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
        for lit in [false, true] {
            for ahead in [false, true] {
                var path = Path()
                var connected = false
                for i in 0..<(points.count - 1) {
                    guard samples[i].isIlluminated == lit, (ahead ? i >= index : i <= index) else { connected = false; continue }
                    let from = ahead && i == index ? cursor : points[i]
                    let to = !ahead && i == index ? cursor : points[i + 1]
                    if !connected { path.move(to: from) }
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

/// Orthographic sky dome viewed from 12° above the horizon. Orient its horizontal
/// axis from rise to set, then fit the pass vertically. The shader uses its inverse
/// to sample the existing azimuth/elevation sky texture; celestial positions and
/// the track therefore retain the same orientation. This is an overview, not an
/// angular scale (the detailed chart remains available on tap).
struct ObservationSkyProjection {
    static let tilt = 12.0 * Double.pi / 180
    let size: CGSize
    let right: SIMD2<Double>
    let front: SIMD2<Double>
    let extent: Double
    let horizonDepth: Double
    let verticalScale: Double
    let baseline: Double
    var halfWidth: Double { max(1, (size.width - 30) / 2) }

    init(pass: Pass, samples: [SatelliteSnapshot], size: CGSize) {
        self.size = size
        func horizontal(_ azimuth: Double) -> SIMD2<Double> {
            let a = azimuth * .pi / 180
            return SIMD2(sin(a), cos(a))
        }
        let rise = horizontal(pass.rise.azim), set = horizontal(pass.set.azim)
        let delta = set - rise
        let length = hypot(delta.x, delta.y)
        right = length > 0.0001 ? delta / length : SIMD2(rise.y, -rise.x)
        var normal = SIMD2(-right.y, right.x)
        let peak = horizontal(pass.culmination.azim)
        if normal.x * peak.x + normal.y * peak.y < 0 { normal = -normal }
        front = normal
        extent = max(0.1, length / 2)
        horizonDepth = rise.x * normal.x + rise.y * normal.y
        let horizon = horizonDepth
        let highest = samples.map { sample -> Double in
            let e = max(0, sample.position.elev) * .pi / 180
            let h = horizontal(sample.position.azim) * cos(e)
            let depth = h.x * normal.x + h.y * normal.y
            return cos(Self.tilt) * sin(e) - sin(Self.tilt) * (depth - horizon)
        }.max() ?? 1
        let horizonBulge = max(0, sin(Self.tilt) * (1 - horizon))
        let scale = max(1, size.height - 60) / max(0.15, highest + horizonBulge)
        verticalScale = scale
        baseline = size.height - 32 - scale * horizonBulge
    }

    func visiblePoint(azimuth: Double, elevation: Double) -> CGPoint? {
        let a = azimuth * .pi / 180, e = elevation * .pi / 180
        let h = SIMD2(sin(a), cos(a)) * cos(e)
        let depth = h.x * front.x + h.y * front.y
        // Match the shader's front-facing hemisphere; do not fold a planet from
        // the back of the dome over unrelated foreground stars.
        guard elevation >= 0, depth * cos(Self.tilt) + sin(e) * sin(Self.tilt) >= 0 else { return nil }
        return point(azimuth: azimuth, elevation: elevation)
    }

    func point(azimuth: Double, elevation: Double) -> CGPoint {
        let a = azimuth * .pi / 180, e = max(0, elevation) * .pi / 180
        let h = SIMD2(sin(a), cos(a)) * cos(e)
        return point(right: h.x * right.x + h.y * right.y,
                     front: h.x * front.x + h.y * front.y, up: sin(e))
    }

    func point(right x: Double, front depth: Double, up z: Double) -> CGPoint {
        CGPoint(x: size.width / 2 + x / extent * halfWidth,
                y: baseline + verticalScale * (sin(Self.tilt) * (depth - horizonDepth) - cos(Self.tilt) * z))
    }
}
