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
    /// Reuses the app's catalog frame, diffuse galaxy source and planetarium
    /// atmosphere palette, evaluated along each final output pixel's sky ray.
    func observationSky(projection: ObservationSkyProjection, observer: LatLonAlt, julianDate: Double) -> UIImage? {
        guard projection.width > 0, projection.height > 0 else { return nil }
        let texture = MilkyWayBackground.texture
        let frame = MilkyWayBackground.Projection(observer: observer, julianDate: julianDate)
        let sun = SkyChartAtmosphere.sun(observer: observer, julianDate: julianDate)
        let a = sun.azim * .pi / 180, e = sun.elev * .pi / 180
        let sunRay = SIMD3(sin(a) * cos(e), cos(a) * cos(e), sin(e))
        func smooth(_ low: Double, _ high: Double, _ value: Double) -> Double {
            let t = min(1, max(0, (value - low) / (high - low)))
            return t * t * (3 - 2 * t)
        }
        let daylight = smooth(-8, 12, sun.elev)
        let twilight = smooth(-18, -5, sun.elev) * (1 - smooth(0, 14, sun.elev))
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
                // Same directional night/twilight palette as the in-app planetarium.
                let horizon = exp(-ray.z * 5)
                let glow = pow(max(0, simd_dot(ray, sunRay)), 12)
                let night = SIMD3(0.0015, 0.003, 0.012) * (1 - horizon) + SIMD3(0.018, 0.030, 0.053) * horizon
                let day = SIMD3(0.025, 0.16, 0.42) * (1 - horizon) + SIMD3(0.37, 0.60, 0.82) * horizon
                let sky = night * (1 - daylight) + day * daylight
                    + twilight * horizon * SIMD3(0.18, 0.06, 0.12)
                    + glow * twilight * SIMD3(0.65, 0.22, 0.06)
                let color = simd_min(SIMD3(repeating: 1), sky + galaxy * (0.65 * (1 - daylight)))
                let edge = smooth(0, 18, min(point.x, projection.width - point.x))
                    * smooth(0, 22, min(point.y, projection.height - point.y))
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
