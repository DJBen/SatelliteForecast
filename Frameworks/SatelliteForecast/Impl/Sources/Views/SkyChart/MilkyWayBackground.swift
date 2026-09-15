import UIKit
import simd
import SatelliteKit

/// A starless, illustrative diffuse sky in Galactic coordinates. This is not a
/// photometric survey: only its celestial registration is astronomical.
enum MilkyWayBackground {
    // ICRS → Galactic rotation (Hipparcos canonical pole/node angles).
    // Reference: https://github.com/liberfa/erfa/blob/master/src/icrs2g.c
    static func galactic(_ equatorial: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(
            simd_dot(equatorial, SIMD3(-0.0548755604162154, -0.8734370902348850, -0.4838350155487132)),
            simd_dot(equatorial, SIMD3(0.4941094278755837, -0.4448296299600112, 0.7469822444972189)),
            simd_dot(equatorial, SIMD3(-0.8676661490190047, -0.1980763734312015, 0.4559837761750669))
        )
    }

    struct Projection {
        let north: SIMD3<Double>
        let east: SIMD3<Double>
        let zenith: SIMD3<Double>

        init(observer: LatLonAlt, julianDate: Double) {
            let latitude = observer.lat * deg2rad
            let sidereal = siteMeanSiderealTime(julianDate: julianDate, observer.lon) * deg2rad
            // Same local sidereal frame as SatelliteKit.azel, computed once per image.
            north = SIMD3(-sin(latitude) * cos(sidereal), -sin(latitude) * sin(sidereal), cos(latitude))
            east = SIMD3(-sin(sidereal), cos(sidereal), 0)
            zenith = SIMD3(cos(latitude) * cos(sidereal), cos(latitude) * sin(sidereal), sin(latitude))
        }

        func equatorial(at horizontal: AziEle) -> SIMD3<Double> {
            let a = horizontal.azim * deg2rad
            let h = horizontal.elev * deg2rad
            return north * (cos(h) * cos(a)) + east * (cos(h) * sin(a)) + zenith * sin(h)
        }
    }

    /// Smooth, periodic texture on the celestial sphere: no points or baked-in stars.
    static func radiance(_ direction: SIMD3<Double>) -> (intensity: Double, warmth: Double) {
        let l = atan2(direction.y, direction.x)
        let b = asin(max(-1, min(1, direction.z)))
        let core = exp(-pow(l / 0.55, 2) - pow(b / 0.23, 2))
        let broad = exp(-pow(b / 0.19, 2))
        let narrow = exp(-pow(b / 0.075, 2))
        // Integer longitude frequencies keep the ±π seam continuous.
        let clouds = 0.70 + 0.16 * sin(9 * l + 13 * b + 1.8 * sin(3 * l))
            + 0.09 * sin(23 * l - 31 * b + sin(7 * l))
            + 0.05 * sin(47 * l + 67 * b)
        let laneLatitude = b - 0.022 * sin(3 * l) - 0.012 * sin(11 * l)
        let dust = exp(-pow(laneLatitude / 0.028, 2)) * (0.55 + 0.20 * cos(2 * l))
        let glow = (0.20 * broad + 0.38 * narrow + 0.62 * core) * clouds * (1 - dust)
        return (min(1, max(0, glow)), core)
    }

    /// Bounded low-frequency raster. Rotation/zoom reuse the enclosing sky image;
    /// this runs with stars on ChartRenderer's actor, never per animation frame.
    static func image(size: CGSize, observer: LatLonAlt, julianDate: Double, dark: Bool) -> UIImage? {
        guard size.width > 0, size.height > 0, julianDate.isFinite,
              observer.lat.isFinite, observer.lon.isFinite else { return nil }
        let dimension = min(512, max(96, Int(max(size.width, size.height))))
        let scale = Double(dimension) / max(size.width, size.height)
        let width = max(1, Int(size.width * scale))
        let height = max(1, Int(size.height * scale))
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        let projection = Projection(observer: observer, julianDate: julianDate)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            if Task.isCancelled { return nil }
            for x in 0..<width {
                let horizontal = SkyChartUtils.aziEle(at: CGPoint(x: Double(x) + 0.5, y: Double(y) + 0.5), in: rect)
                guard horizontal.elev >= 0 else { continue }
                let light = radiance(galactic(projection.equatorial(at: horizontal)))
                let alpha = light.intensity * (dark ? 0.55 : 0.16)
                let rgb = dark ? SIMD3(0.55 + 0.15 * light.warmth, 0.61 + 0.05 * light.warmth, 0.76 - 0.15 * light.warmth)
                    : SIMD3(0.25, 0.30, 0.43)
                let i = (y * width + x) * 4
                pixels[i] = UInt8(rgb.x * alpha * 255)
                pixels[i + 1] = UInt8(rgb.y * alpha * 255)
                pixels[i + 2] = UInt8(rgb.z * alpha * 255)
                pixels[i + 3] = UInt8(alpha * 255)
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cgImage = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
