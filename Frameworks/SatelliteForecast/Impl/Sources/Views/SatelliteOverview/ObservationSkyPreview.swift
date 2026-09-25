import SwiftUI
import SatelliteForecast
import SatelliteKit

/// The app's all-sky projection, atmosphere, Milky Way and point-source renderer.
/// The sky is prepared once at culmination; only the small path overlay animates.
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
            let side = min(geometry.size.width - 42, geometry.size.height - 20)
            let rect = CGRect(x: 0, y: 0, width: side, height: side)
            let samples = samples
            let points = samples.map { SkyChartUtils.point(at: AziEle($0.position.azim, max(0, $0.position.elev)), rect: rect) }
            ZStack {
                ScreenFactory(session: session).background(.init(observer: observer,
                    basicChartConfigs: .init(showAzimuthTexts: false, azimuthMarkInterval: 90,
                        azimuthMarkLength: 0, showDirections: false, showsAttitude: false),
                    configs: .init(stars: .limitedMagnitude(4.5), showConstellationLines: false,
                        showStarNames: false, bodySymbol: .none), quality: .full,
                    starManager: session.catalog, constellationLabel: { _ in EmptyView() },
                    annotationView: { _ in EmptyView() }, starTapped: { _ in }))
                    .environment(\.backgroundSkyJulianDateKey, pass.culmination.julianDate.roundJulianDate(.toMins(1)))
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: paused)) { timeline in
                    let progress = reviewProgress ?? (paused ? 0.58 : min(1, max(0, timeline.date.timeIntervalSince(started))
                        .truncatingRemainder(dividingBy: 15) / 12))
                    Canvas { context, _ in
                        drawOrbit(context: &context, points: points, samples: samples, progress: progress)
                    }
                    .clipShape(Circle())
                }
                endpoint(pass.rise, rect: rect)
                endpoint(pass.set, rect: rect)
            }
            .frame(width: side, height: side)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .environment(\.colorScheme, .dark)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Pass animation preview. Solid trail: traveled in the preview. Dotted trail: still ahead. Gray: in Earth’s shadow.", bundle: .module))
        .onChange(of: isActive) { _, active in if active { started = Date() } }
        .onChange(of: scenePhase) { _, phase in if phase == .active { started = Date() } }
    }

    private func endpoint(_ position: Pass.DatePosition, rect: CGRect) -> some View {
        let point = SkyChartUtils.point(at: AziEle(position.azim, 0), rect: rect)
        let dx = point.x - rect.midX, dy = point.y - rect.midY
        let length = max(1, hypot(dx, dy))
        return Text(ObservationOpportunity.direction(position.azim))
            .font(.caption2.weight(.medium))
            .foregroundStyle(AppTheme.muted)
            .position(x: point.x + dx / length * 13, y: point.y + dy / length * 13)
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
