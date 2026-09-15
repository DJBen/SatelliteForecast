import SwiftUI
import SatelliteKit
import SolarSystem

/// A chart-scale interpretation of Earthshine's blue scattering, warm solar
/// aureole and camera optics (DJBen/earth-shine, lib/atmosphere.ts and
/// native/CAMERA-OPTICS.md). Artistic gradients, not a radiometric simulation.
/// All positions use the chart projection, so compass rotation stays aligned.
struct SkyChartAtmosphere: View {
    let sun: AziEle
    let showsSun: Bool

    static func sun(observer: LatLonAlt, julianDate: Double) -> AziEle {
        azel(time: Date(julianDate: julianDate), site: LatLon(observer),
             cele: RADec(SolarSystemBody.sun.eci(julianDay: julianDate)))
    }

    static func transition(_ low: Double, _ high: Double, _ value: Double) -> Double {
        let t = max(0, min(1, (value - low) / (high - low)))
        return t * t * (3 - 2 * t)
    }

    var body: some View {
        Canvas { context, size in
            guard sun.elev.isFinite, sun.azim.isFinite, size.width > 0, size.height > 0 else { return }
            let rect = CGRect(origin: .zero, size: size)
            let radius = SkyChartUtils.radius(fromRect: rect)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let disk = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                            width: radius * 2, height: radius * 2))
            let daylight = Self.transition(-8, 12, sun.elev)
            let twilight = Self.transition(-18, -5, sun.elev) * (1 - Self.transition(0, 14, sun.elev))
            let presence = Self.transition(-18, -2, sun.elev)
            guard presence > 0 else { return }
            context.clip(to: disk)

            // Give the sky its own dark base in both app appearances; otherwise
            // translucent twilight would expose a white ring in light mode.
            context.fill(disk, with: .color(Color(red: 0.015, green: 0.025, blue: 0.075).opacity(presence)))

            // Deep blue zenith, with a brighter, longer atmospheric path at the rim.
            context.fill(disk, with: .radialGradient(Gradient(stops: [
                .init(color: Color(red: 0.025, green: 0.12, blue: 0.34).opacity(presence * 0.9), location: 0),
                .init(color: Color(red: 0.055, green: 0.30, blue: 0.68).opacity(daylight * 0.96), location: 0.65),
                .init(color: Color(red: 0.27, green: 0.59, blue: 0.88).opacity(daylight), location: 1)
            ]), center: center, startRadius: 0, endRadius: radius))

            // Broad violet twilight around the horizon, fading smoothly inward.
            context.fill(disk, with: .radialGradient(Gradient(stops: [
                .init(color: .clear, location: 0.48),
                .init(color: Color(red: 0.27, green: 0.16, blue: 0.65).opacity(twilight * 0.35), location: 0.76),
                .init(color: Color(red: 0.65, green: 0.27, blue: 0.78).opacity(twilight * 0.8), location: 0.94),
                .init(color: Color(red: 0.82, green: 0.40, blue: 0.74).opacity(twilight * 0.85), location: 1)
            ]), center: center, startRadius: 0, endRadius: radius))

            let point = SkyChartUtils.point(at: sun, rect: rect)
            func glow(at point: CGPoint, radius: CGFloat, color: Color, strength: Double) {
                context.fill(disk, with: .radialGradient(Gradient(stops: [
                    .init(color: color.opacity(strength), location: 0),
                    .init(color: color.opacity(strength * 0.48), location: 0.24),
                    .init(color: color.opacity(strength * 0.12), location: 0.6),
                    .init(color: .clear, location: 1)
                ]), center: point, startRadius: 0, endRadius: radius))
            }
            // Scattering remains after the Sun sets; lens artifacts do not.
            glow(at: point, radius: radius * 1.1,
                 color: Color(red: 1, green: 0.38, blue: 0.20), strength: twilight * 0.88)
            glow(at: point, radius: radius * 0.6,
                 color: Color(red: 1, green: 0.72, blue: 0.40), strength: twilight * 0.65)
            guard showsSun else { return }
            // Fade in across the finite solar disk at the horizon.
            let flux = Self.transition(-0.27, 1.5, sun.elev)
            guard flux > 0 else { return }
            context.blendMode = .screen
            glow(at: point, radius: radius * 0.55, color: .orange, strength: flux * 0.6)
            glow(at: point, radius: radius * 0.23, color: Color(red: 1, green: 0.87, blue: 0.61), strength: flux * 0.9)
            // Soft six-blade diffraction rays, scaled to remain subtle in previews.
            for index in 0..<6 {
                var rayContext = context
                rayContext.translateBy(x: point.x, y: point.y)
                rayContext.rotate(by: .degrees(Double(index) * 60 + 15))
                let ray = Path(ellipseIn: CGRect(x: -radius * 0.28, y: -radius * 0.007,
                                               width: radius * 0.56, height: radius * 0.014))
                rayContext.fill(ray, with: .radialGradient(Gradient(colors: [.white.opacity(flux * 0.45), .clear]),
                    center: .zero, startRadius: 0, endRadius: radius * 0.28))
            }
            // Defocused colored reflections along the Sun–chart-center axis.
            for (offset, scale, color) in [(0.62, 0.045, Color.cyan), (1.22, 0.075, Color.teal), (1.58, 0.11, Color.purple)] {
                let ghost = CGPoint(x: point.x + (center.x - point.x) * offset,
                                    y: point.y + (center.y - point.y) * offset)
                glow(at: ghost, radius: radius * scale, color: color, strength: flux * 0.20)
            }
            glow(at: point, radius: max(5, radius * 0.045), color: .white, strength: flux)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
