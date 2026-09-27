import SwiftUI
import SatelliteKit
import simd

/// A native raster in the final camera, generated once per size/pass/observer.
/// Animation only redraws the satellite overlay, never this photographic sky.
struct ObservationSkyBackground: View {
    let projection: ObservationSkyProjection
    let observer: LatLonAlt
    let julianDate: Double
    let renderer: ChartRenderer
    @State private var image: UIImage?

    private struct Key: Hashable {
        let projection: ObservationSkyProjection
        let latitude: Double
        let longitude: Double
        let julianDate: Double
    }

    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable() }
            else { Color.clear }
        }
        .frame(width: projection.width, height: projection.height)
        .task(id: Key(projection: projection, latitude: observer.lat,
                      longitude: observer.lon, julianDate: julianDate)) {
            image = nil
            let rendered = await renderer.observationSky(projection: projection, observer: observer, julianDate: julianDate)
            guard !Task.isCancelled else { return }
            image = rendered
        }
    }
}

extension ChartRenderer {
    /// Draw from the original spherical NASA map, never from a flat sky chart.
    /// Reuses the app's catalog frame and diffuse galaxy source. The atmosphere is
    /// the round sky chart's (`SkyChartAtmosphere`), evaluated along each output
    /// pixel's sky ray at that ray's position in the chart, so both views agree.
    func observationSky(projection: ObservationSkyProjection, observer: LatLonAlt, julianDate: Double) -> UIImage? {
        guard projection.width > 0, projection.height > 0 else { return nil }
        let texture = MilkyWayBackground.texture
        let frame = MilkyWayBackground.Projection(observer: observer, julianDate: julianDate)
        let sun = SkyChartAtmosphere.sun(observer: observer, julianDate: julianDate)
        func smooth(_ low: Double, _ high: Double, _ value: Double) -> Double {
            let t = min(1, max(0, (value - low) / (high - low)))
            return t * t * (3 - 2 * t)
        }
        let daylight = smooth(-8, 12, sun.elev)
        let twilight = smooth(-18, -5, sun.elev) * (1 - smooth(0, 14, sun.elev))
        let presence = smooth(-18, -2, sun.elev)
        let atmosphere = ChartAtmosphere(sun: sun, daylight: daylight, twilight: twilight, presence: presence)
        let pixelsPerPoint = min(2, 1024 / max(projection.width, projection.height))
        let width = max(1, Int(projection.width * pixelsPerPoint))
        let height = max(1, Int(projection.height * pixelsPerPoint))
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            if Task.isCancelled { return nil }
            for x in 0..<width {
                let point = CGPoint(x: (Double(x) + 0.5) / pixelsPerPoint, y: (Double(y) + 0.5) / pixelsPerPoint)
                let ray = projection.direction(at: point)
                let facing = ray.x * projection.front.x + ray.y * projection.front.y
                guard ray.z > 0, facing >= 0 else { continue }
                let equatorial = frame.east * ray.x + frame.north * ray.y + frame.zenith * ray.z
                let galaxy = texture?.sample(MilkyWayBackground.textureCoordinates(MilkyWayBackground.galactic(equatorial))) ?? .zero
                let color = simd_min(SIMD3(repeating: 1), atmosphere.color(along: ray) + galaxy * (0.65 * (1 - daylight)))
                // Feather only a narrow band around the pass; share that boundary
                // with foreground stars and the widget's cached dome raster.
                let edge = projection.edgeFade(at: point)
                let alpha = edge * smooth(0, 0.02, ray.z) * smooth(0, 0.05, facing)
                let index = (y * width + x) * 4
                pixels[index] = UInt8(color.x * alpha * 255)
                pixels[index + 1] = UInt8(color.y * alpha * 255)
                pixels[index + 2] = UInt8(color.z * alpha * 255)
                pixels[index + 3] = UInt8(alpha * 255)
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cgImage = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                  bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { return nil }
        return UIImage(cgImage: cgImage, scale: pixelsPerPoint, orientation: .up)
    }
}

/// `SkyChartAtmosphere`'s layers as a function of sky direction. Each ray is placed
/// where the round chart would draw it (azimuthal equidistant, horizon at radius 1)
/// and the same gradient stops are composited source-over in premultiplied color.
private struct ChartAtmosphere {
    typealias Stop = (location: Double, color: SIMD3<Double>, alpha: Double)
    let sunPoint: SIMD2<Double>
    let zenith: [Stop]
    let violet: [Stop]
    let aureoles: [(radius: Double, color: SIMD3<Double>, strength: Double)]
    let presence: Double

    init(sun: AziEle, daylight: Double, twilight: Double, presence: Double) {
        self.presence = presence
        sunPoint = Self.chartPoint(azimuth: sun.azim * .pi / 180, elevation: sun.elev)
        zenith = [(0, SIMD3(0.025, 0.12, 0.34), presence * 0.9),
                  (0.65, SIMD3(0.055, 0.30, 0.68), daylight * 0.96),
                  (1, SIMD3(0.27, 0.59, 0.88), daylight)]
        violet = [(0.48, .zero, 0),
                  (0.76, SIMD3(0.27, 0.16, 0.65), twilight * 0.35),
                  (0.94, SIMD3(0.65, 0.27, 0.78), twilight * 0.8),
                  (1, SIMD3(0.82, 0.40, 0.74), twilight * 0.85)]
        aureoles = [(1.1, SIMD3(1, 0.38, 0.20), twilight * 0.88),
                    (0.6, SIMD3(1, 0.72, 0.40), twilight * 0.65)]
    }

    static func chartPoint(azimuth: Double, elevation: Double) -> SIMD2<Double> {
        SIMD2(sin(azimuth), cos(azimuth)) * ((90 - elevation) / 90)
    }

    /// Premultiplied gradient sample; SwiftUI interpolates stops the same way.
    private static func sample(_ stops: [Stop], at location: Double) -> SIMD4<Double> {
        func premultiplied(_ stop: Stop) -> SIMD4<Double> { SIMD4(stop.color * stop.alpha, stop.alpha) }
        guard let first = stops.first, location > first.location else { return premultiplied(stops[0]) }
        for (a, b) in zip(stops, stops.dropFirst()) where location <= b.location {
            let t = (location - a.location) / (b.location - a.location)
            return premultiplied(a) * (1 - t) + premultiplied(b) * t
        }
        return premultiplied(stops[stops.count - 1])
    }

    /// Opaque color for a ray above the horizon. The chart has no fill in deep
    /// night, so the arc keeps a dark blue base beneath its layers instead.
    func color(along ray: SIMD3<Double>) -> SIMD3<Double> {
        let elevation = asin(max(-1, min(1, ray.z))) * 180 / .pi
        let point = Self.chartPoint(azimuth: atan2(ray.x, ray.y), elevation: elevation)
        var color = SIMD3(0.010, 0.020, 0.062)
        func over(_ layer: SIMD4<Double>) {
            color = SIMD3(layer.x, layer.y, layer.z) + color * (1 - layer.w)
        }
        over(SIMD4(SIMD3(0.015, 0.025, 0.075) * presence, presence))
        let radius = simd_length(point)
        over(Self.sample(zenith, at: radius))
        over(Self.sample(violet, at: radius))
        let distance = simd_distance(point, sunPoint)
        for aureole in aureoles where aureole.strength > 0 {
            over(Self.sample([(0, aureole.color, aureole.strength), (0.24, aureole.color, aureole.strength * 0.48),
                              (0.6, aureole.color, aureole.strength * 0.12), (1, aureole.color, 0)],
                             at: distance / aureole.radius))
        }
        return color
    }
}
