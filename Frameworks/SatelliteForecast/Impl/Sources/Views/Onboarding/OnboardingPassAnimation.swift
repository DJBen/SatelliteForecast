import SwiftUI
import SatelliteForecast
import SatelliteKit

/// A recorded orbit, propagated locally: onboarding never depends on location or network access.
struct OnboardingPassExample: Sendable {
    let pass: PassSnapshots
    let samples: [SatelliteSnapshot]
    static let observer = LatLonAlt(37.486743, -122.226560, 0)

    static func load() throws -> Self {
        // Saved ISS elements, epoch September 13, 2026. Replay the September 9 evening pass.
        let info = try SatelliteInfo(elements: Elements("ISS (ZARYA)",
            "1 25544U 98067A   26256.62713074  .00005522  00000+0  10793-3 0  9997",
            "2 25544  51.6309 222.3825 0004920 137.6518 222.4851 15.49103177585466"))
        let start = Date(timeIntervalSince1970: 1789002000).julianDate // 2026-09-10 01:00 UTC
        let snapshots = try info.generateSnapshots(observer: observer, julianDateRange: start...(start + 1))
        let passes = try info.findPasses(observer: observer, coarseSnapshots: snapshots)
        guard let pass = passes.first(where: {
            $0.pass.visibility == .visible && ($0.pass.highestIlluminated?.elev ?? 0) > 45
                && $0.pass.sunElevationAtTransit < -10
        }) else { throw ExampleError.noVisiblePass }
        let samples = try info.generateSnapshots(observer: observer,
            julianDateRange: pass.pass.rise.julianDate...pass.pass.set.julianDate, interval: 1)
        return Self(pass: pass, samples: samples)
    }
    enum ExampleError: Error { case noVisiblePass }
}

struct OnboardingPassAnimation: View {
    let session: AppSession
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @State private var example: OnboardingPassExample?
    @State private var failed = false
    @State private var started = Date()

    private var paused: Bool {
        reduceMotion || SnapshotEnvironment.isEnabled || !isActive || scenePhase != .active
    }

    var body: some View {
        Group {
            if let example {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: paused)) { timeline in
                    let duration = (example.pass.pass.set.julianDate - example.pass.pass.rise.julianDate) * 86400
                    let elapsed = max(0, timeline.date.timeIntervalSince(started))
                    let progress = paused ? 0.5 : min(elapsed.truncatingRemainder(dividingBy: duration / 40 + 3) * 40 / duration, 1)
                    let julianDate = example.pass.pass.rise.julianDate + progress * duration / 86400
                    VStack(spacing: 12) {
                        VStack(spacing: 4) {
                            Text("ISS · San Francisco Bay", bundle: .module)
                                .font(.headline)
                            Text(reduceMotion ? "Recorded pass" : "Recorded pass · 40× replay", bundle: .module)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        GeometryReader { geometry in
                            // Direction labels extend beyond the circular chart bounds.
                            let side = min(geometry.size.width, max(0, geometry.size.height - 48))
                            let rect = CGRect(x: 0, y: 0, width: side, height: side)
                            ZStack {
                                ScreenFactory(session: session).background(BackgroundSkyViewContext(
                                    observer: OnboardingPassExample.observer,
                                    basicChartConfigs: .init(), configs: .preset, quality: .full,
                                    starManager: session.catalog, constellationLabel: { _ in EmptyView() },
                                    annotationView: { _ in EmptyView() }, starTapped: { _ in }))
                                    .environment(\.backgroundSkyJulianDateKey, julianDate.roundJulianDate(.toMins(1)))
                                orbit(example, progress: progress, rect: rect)
                            }
                            .frame(width: side, height: side)
                            .padding(.vertical, 24)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        HStack {
                            Text(Date(julianDate: julianDate).formatted(Date.FormatStyle(
                                date: .abbreviated, time: .standard, locale: locale,
                                timeZone: TimeZone(identifier: "America/Los_Angeles")!)))
                            Spacer()
                            let sample = example.samples[min(Int(progress * Double(example.samples.count - 1)), example.samples.count - 1)]
                            Text("\(Int(sample.position.elev.rounded()))°")
                        }
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("Recorded ISS pass over San Francisco Bay", bundle: .module))
                }
            } else if failed {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles").font(.largeTitle)
                    Text("Pass preview unavailable", bundle: .module).font(.caption)
                }
            } else {
                ProgressView().tint(.white)
            }
        }
        .environment(\.colorScheme, .dark)
        .allowsHitTesting(false)
        .task {
            guard example == nil else { return }
            let task = Task.detached(priority: .userInitiated) { try OnboardingPassExample.load() }
            do {
                let result = try await withTaskCancellationHandler {
                    try await task.value
                } onCancel: { task.cancel() }
                try Task.checkCancellation()
                example = result
                started = Date()
            } catch is CancellationError {
                // Leaving onboarding should cancel propagation quietly.
            } catch { failed = true }
        }
        .onChange(of: isActive) { _, active in if active { started = Date() } }
        .onChange(of: scenePhase) { _, phase in if phase == .active { started = Date() } }
    }

    private func orbit(_ example: OnboardingPassExample, progress: Double, rect: CGRect) -> some View {
        Canvas { context, _ in
            let points = example.samples.map {
                SkyChartUtils.point(at: AziEle($0.position.azim, max(0, $0.position.elev)), rect: rect)
            }
            guard points.count > 1 else { return }
            var track = Path(); track.addLines(points)
            context.stroke(track, with: .color(.white.opacity(0.2)), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
            let offset = progress * Double(points.count - 1)
            let index = min(Int(offset), points.count - 2)
            let fraction = offset - Double(index)
            let position = CGPoint(x: points[index].x + (points[index + 1].x - points[index].x) * fraction,
                                   y: points[index].y + (points[index + 1].y - points[index].y) * fraction)
            let color: Color = example.samples[index].isIlluminated ? AppTheme.accent : .gray
            var trail = Path(); trail.addLines(Array(points.prefix(index + 1)) + [position])
            context.stroke(trail, with: .color(AppTheme.accent.opacity(0.8)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            context.drawLayer { glow in
                glow.addFilter(.blur(radius: 7))
                glow.fill(Path(ellipseIn: CGRect(x: position.x - 10, y: position.y - 10, width: 20, height: 20)), with: .color(color.opacity(0.7)))
            }
            context.fill(Path(ellipseIn: CGRect(x: position.x - 4, y: position.y - 4, width: 8, height: 8)), with: .color(.white))
        }
        .clipShape(Circle())
    }
}
