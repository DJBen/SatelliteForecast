import SwiftUI
import SatelliteKit
import ImageIO
import simd

/// The app's arc sky, drawn every frame on the GPU by `observationSky` in
/// ObservationSkyShader.metal. The widget's dome keeps the CPU raster below
/// (`ChartRenderer.observationSky`), which evaluates the same model.
struct ObservationSkyBackground: View {
    let projection: ObservationSkyProjection
    let observer: LatLonAlt
    let julianDate: Double

    /// Loaded once; the shader samples it with the CPU path's 5-texel box blur.
    private static let galaxy: Image? = {
        guard let url = Bundle.module.url(forResource: "milkyway-galactic", withExtension: "jpg"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 1024
              ] as CFDictionary) else { return nil }
        return Image(decorative: image, scale: 1)
    }()

    var body: some View {
        if let galaxy = Self.galaxy {
            Rectangle()
                .colorEffect(ShaderLibrary.bundle(.module).observationSky(
                    .floatArray(parameters), .floatArray(projection.skyBoundary.map { Float($0) }), .image(galaxy)))
                .frame(width: projection.width, height: projection.height)
        } else {
            Color.clear.frame(width: projection.width, height: projection.height)
        }
    }

    /// Order matches `enum Parameter` in ObservationSkyShader.metal.
    private var parameters: [Float] {
        let frame = MilkyWayBackground.Projection(observer: observer, julianDate: julianDate)
        let atmosphere = ChartAtmosphere(sun: SkyChartAtmosphere.sun(observer: observer, julianDate: julianDate))
        let values: [Double] = [
            projection.width, projection.height, projection.scale, projection.originY, ObservationSkyProjection.pitch,
            projection.right.x, projection.right.y, projection.front.x, projection.front.y,
            frame.east.x, frame.east.y, frame.east.z, frame.north.x, frame.north.y, frame.north.z,
            frame.zenith.x, frame.zenith.y, frame.zenith.z,
            atmosphere.sunPoint.x, atmosphere.sunPoint.y, atmosphere.daylight, atmosphere.twilight, atmosphere.presence,
            projection.bleed, projection.extendsUpward ? 1 : 0, projection.peak
        ]
        return values.map { Float($0) }
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
        let atmosphere = ChartAtmosphere(sun: sun)
        let daylight = atmosphere.daylight
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
/// ObservationSkyShader.metal repeats these stops for the app's GPU arc.
struct ChartAtmosphere {
    typealias Stop = (location: Double, color: SIMD3<Double>, alpha: Double)
    let daylight: Double
    let twilight: Double
    let presence: Double
    let sunPoint: SIMD2<Double>
    private let zenith: [Stop]
    private let violet: [Stop]
    private let aureoles: [(radius: Double, stops: [Stop])]

    init(sun: AziEle) {
        daylight = SkyChartAtmosphere.transition(-8, 12, sun.elev)
        twilight = SkyChartAtmosphere.transition(-18, -5, sun.elev) * (1 - SkyChartAtmosphere.transition(0, 14, sun.elev))
        presence = SkyChartAtmosphere.transition(-18, -2, sun.elev)
        sunPoint = Self.chartPoint(azimuth: sun.azim * .pi / 180, elevation: sun.elev)
        zenith = [(0, SIMD3(0.025, 0.12, 0.34), presence * 0.9),
                  (0.65, SIMD3(0.055, 0.30, 0.68), daylight * 0.96),
                  (1, SIMD3(0.27, 0.59, 0.88), daylight)]
        violet = [(0.48, .zero, 0),
                  (0.76, SIMD3(0.27, 0.16, 0.65), twilight * 0.35),
                  (0.94, SIMD3(0.65, 0.27, 0.78), twilight * 0.8),
                  (1, SIMD3(0.82, 0.40, 0.74), twilight * 0.85)]
        let twilight = twilight
        aureoles = [(1.1, SIMD3(1, 0.38, 0.20), twilight * 0.88), (0.6, SIMD3(1, 0.72, 0.40), twilight * 0.65)]
            .filter { $0.2 > 0 }
            .map { radius, color, strength in
                (radius, [(0, color, strength), (0.24, color, strength * 0.48), (0.6, color, strength * 0.12), (1, color, 0)])
            }
    }

    static func chartPoint(azimuth: Double, elevation: Double) -> SIMD2<Double> {
        SIMD2(sin(azimuth), cos(azimuth)) * ((90 - elevation) / 90)
    }

    /// Premultiplied gradient sample; SwiftUI interpolates stops the same way.
    private static func sample(_ stops: [Stop], at location: Double) -> SIMD4<Double> {
        func premultiplied(_ stop: Stop) -> SIMD4<Double> { SIMD4(stop.color * stop.alpha, stop.alpha) }
        guard location > stops[0].location else { return premultiplied(stops[0]) }
        for index in 1..<stops.count where location <= stops[index].location {
            let a = stops[index - 1], b = stops[index]
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
        for aureole in aureoles {
            over(Self.sample(aureole.stops, at: distance / aureole.radius))
        }
        return color
    }
}
