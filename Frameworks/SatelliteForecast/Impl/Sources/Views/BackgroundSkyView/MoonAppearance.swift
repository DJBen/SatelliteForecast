import UIKit
import SwiftUI
import ImageIO
import CoreImage
import simd
import SatelliteKit
import SolarSystem

/// Small spherical Moon, using the existing NASA lunar ephemeris and IAU pole /
/// prime-meridian model. This is chart imagery, not an eclipse or terrain model.
enum MoonAppearance {
    static func coordinate(julianDate: Double, observer: LatLonAlt) -> AziEle {
        let direction = lunarCel(julianDays: julianDate) - geo2eci(julianDays: julianDate, geodetic: observer)
        return azel(time: Date(julianDate: julianDate), site: LatLon(observer), cele: RADec(direction))
    }

    struct Geometry {
        let coordinate: AziEle
        let right: SIMD3<Double>
        let down: SIMD3<Double>
        let towardViewer: SIMD3<Double>
        let light: SIMD3<Double>
        let sunElevation: Double
        let body: simd_double3x3

        var illuminatedFraction: Double { (1 + max(-1, min(1, light.z))) / 2 }

        init(julianDate: Double, observer: LatLonAlt) {
            let moon = lunarCel(julianDays: julianDate) // km, equatorial frame
            let sun = SolarSystemBody.sun.eci(julianDay: julianDate) * 149_597_870.7
            let site = geo2eci(julianDays: julianDate, geodetic: observer)
            let direction = simd_normalize(moon - site)
            coordinate = azel(time: Date(julianDate: julianDate), site: LatLon(observer), cele: RADec(direction))
            let frame = MilkyWayBackground.Projection(observer: observer, julianDate: julianDate)
            let a = coordinate.azim * deg2rad, h = coordinate.elev * deg2rad
            let upward = -sin(h) * cos(a) * frame.north - sin(h) * sin(a) * frame.east + cos(h) * frame.zenith
            let azimuthal = -sin(a) * frame.north + cos(a) * frame.east
            // Local orthonormal chart axes. A simple Sun–Moon screen chord is
            // incorrect for this all-sky projection, especially near the rim.
            right = upward * sin(a) - azimuthal * cos(a)
            down = upward * cos(a) + azimuthal * sin(a)
            towardViewer = -direction
            let solarDirection = simd_normalize(sun - moon)
            light = SIMD3(simd_dot(solarDirection, right), simd_dot(solarDirection, down),
                          simd_dot(solarDirection, towardViewer))
            sunElevation = SkyChartAtmosphere.sun(observer: observer, julianDate: julianDate).elev
            body = MoonAppearance.bodyFrame(julianDate: julianDate)
        }
    }

    /// IAU_MOON trigonometric orientation model from NASA/JPL NAIF pck00011.
    /// Includes the periodic pole and prime-meridian terms (optical libration).
    static func bodyFrame(julianDate: Double) -> simd_double3x3 {
        let d = julianDate - 2451545, t = d / 36525
        let phases = [125.045, 250.089, 260.008, 176.625, 357.529, 311.589, 134.963,
                      276.617, 34.226, 15.134, 119.743, 239.961, 25.053]
        let rates = [-1935.5364525, -3871.072905, 475263.3328725, 487269.629985,
                     35999.0509575, 964468.49931, 477198.869325, 12006.300765,
                     63863.5132425, -5806.6093575, 131.84064, 6003.1503825, 473327.79642]
        let raTerms = [-3.8787, -0.1204, 0.0700, -0.0172, 0, 0.0072, 0, 0, 0, -0.0052, 0, 0, 0.0043]
        let decTerms = [1.5419, 0.0239, -0.0278, 0.0068, 0, -0.0029, 0.0009, 0, 0, 0.0008, 0, 0, -0.0009]
        let wTerms = [3.5610, 0.1208, -0.0642, 0.0158, 0.0252, -0.0066, -0.0047,
                      -0.0046, 0.0028, 0.0052, 0.0040, 0.0019, -0.0044]
        var ra = 269.9949 + 0.0031 * t
        var dec = 66.5392 + 0.0130 * t
        var w = 38.3213 + 13.17635815 * d - 1.4e-12 * d * d
        for i in phases.indices {
            let angle = (phases[i] + rates[i] * t) * deg2rad
            ra += raTerms[i] * sin(angle)
            dec += decTerms[i] * cos(angle)
            w += wTerms[i] * sin(angle)
        }
        ra *= deg2rad; dec *= deg2rad; w *= deg2rad
        let pole = SIMD3(cos(dec) * cos(ra), cos(dec) * sin(ra), sin(dec))
        let node = SIMD3(-sin(ra), cos(ra), 0)
        let perpendicular = simd_cross(pole, node)
        return simd_double3x3(columns: (node * cos(w) + perpendicular * sin(w),
                                       -node * sin(w) + perpendicular * cos(w), pole))
    }

    static let texture: MilkyWayBackground.Texture? = {
        guard let url = Bundle.module.url(forResource: "lunar-albedo", withExtension: "jpg"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return MilkyWayBackground.Texture(image: image)
    }()

    static func image(geometry: Geometry, dimension: Int = 96, emissionOnly: Bool = false) -> UIImage? {
        let dimension = min(128, max(16, dimension))
        let daylight = SkyChartAtmosphere.transition(-6, 2, geometry.sunElevation)
        // Earth is nearly full as seen from a crescent Moon. Deliberately lifted
        // for legibility at 24 pt; this is not a calibrated radiance prediction.
        let earthshine = 0.13 * pow(1 - geometry.illuminatedFraction, 2) * (1 - daylight)
        var pixels = [UInt8](repeating: 0, count: dimension * dimension * 4)
        for y in 0..<dimension {
            for x in 0..<dimension {
                let px = (Double(x) + 0.5) * 2 / Double(dimension) - 1
                let py = (Double(y) + 0.5) * 2 / Double(dimension) - 1
                let r2 = px * px + py * py
                guard r2 < 1 else { continue }
                let z = sqrt(1 - r2)
                let normal = SIMD3(px, py, z)
                let surface = geometry.right * px + geometry.down * py + geometry.towardViewer * z
                let local = geometry.body.transpose * surface
                let uv = SIMD2(0.5 + atan2(local.y, local.x) / (2 * .pi),
                               0.5 - asin(max(-1, min(1, local.z))) / .pi)
                let albedo = texture?.sample(uv) ?? SIMD3(repeating: 0.65)
                let incidence = simd_dot(normal, geometry.light)
                let lit = SkyChartAtmosphere.transition(-0.015, 0.015, incidence)
                // Gentle lunar limb shading retains maria at full phase.
                let sunlight = lit * (0.22 + 0.78 * pow(max(0, incidence), 0.3))
                let brightness = sunlight * 1.45 + (1 - lit) * earthshine * (0.65 + 0.35 * z)
                let coverage = min(1, (1 - sqrt(r2)) * Double(dimension) / 2)
                // In daylight the unlit side lets the foreground sky show through.
                let alpha = emissionOnly
                    ? coverage * sunlight * (1 - daylight * 0.85)
                    : coverage * (1 - daylight * (1 - lit))
                let rgb = emissionOnly ? SIMD3(0.94, 0.97, 1.0)
                    : simd_clamp(albedo * brightness * 1.2, SIMD3(repeating: 0), SIMD3(repeating: 1))
                let index = (y * dimension + x) * 4
                pixels[index] = UInt8(rgb.x * alpha * 255)
                pixels[index + 1] = UInt8(rgb.y * alpha * 255)
                pixels[index + 2] = UInt8(rgb.z * alpha * 255)
                pixels[index + 3] = UInt8(alpha * 255)
            }
        }
        guard let data = CGDataProvider(data: Data(pixels) as CFData),
              let cg = CGImage(width: dimension, height: dimension, bitsPerComponent: 8, bitsPerPixel: 32,
                  bytesPerRow: dimension * 4, space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: data, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { return nil }
        return UIImage(cgImage: cg)
    }

    private static let bloomContext = CIContext(options: [.cacheIntermediates: false])

    /// Camera-style scattered light from the illuminated surface only. Padding
    /// lets the bloom extend beyond the Moon without enlarging its solid disk.
    static func photograph(geometry: Geometry, dimension: Int = 96) -> UIImage? {
        let dimension = min(128, max(16, dimension))
        guard let disk = image(geometry: geometry, dimension: dimension),
              let emission = image(geometry: geometry, dimension: dimension, emissionOnly: true) else { return nil }
        let extent = CGRect(x: 0, y: 0, width: dimension * 3, height: dimension * 3)
        let diskRect = CGRect(x: dimension, y: dimension, width: dimension, height: dimension)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: extent.size, format: format)
        let source = renderer.image { _ in emission.draw(in: diskRect) }
        guard let input = CIImage(image: source) else { return renderer.image { _ in disk.draw(in: diskRect) } }
        // Wide faint atmospheric scatter, soft bloom, and a concentrated glow.
        let wings: [(Double, Int)] = [(0.45, 8), (0.16, 4), (0.045, 2)]
        let base = renderer.image { _ in disk.draw(in: diskRect) }
        var composite = CIImage(color: .clear).cropped(to: extent)
        for (width, exposure) in wings {
            let blurred = input.applyingFilter("CIGaussianBlur",
                parameters: [kCIInputRadiusKey: Double(dimension) * width]).cropped(to: extent)
            // Keep all layers in Core Image's floating-point pipeline. Converting
            // each wing to 8-bit before lifting it produces rings in faint halos.
            for _ in 0..<exposure {
                composite = blurred.applyingFilter("CIScreenBlendMode",
                    parameters: [kCIInputBackgroundImageKey: composite])
            }
        }
        guard let cg = bloomContext.createCGImage(composite, from: extent) else { return base }
        let halo = UIImage(cgImage: cg)
        let near = input.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: Double(dimension) * 0.045])
        let nearImage = bloomContext.createCGImage(near, from: extent).map { UIImage(cgImage: $0) }
        return renderer.image { _ in
            halo.draw(in: extent)
            disk.draw(in: diskRect)
            // A small amount of near-field scatter crosses the limb; keep the
            // dark face legible instead of washing the entire disk to gray.
            nearImage?.draw(in: extent, blendMode: .screen, alpha: 0.6)
        }
    }

}

/// A bounded cache keeps scrolling pass lists from repeatedly rasterizing moons.
actor MoonImageRenderer {
    static let shared = MoonImageRenderer()
    struct Key: Hashable {
        let julianDate: Double
        let observer: LatLonAlt
    }
    private var images: [Key: UIImage] = [:]
    private var order: [Key] = []
    func image(for key: Key) -> UIImage? {
        if let image = images[key] { return image }
        guard !Task.isCancelled,
              let image = MoonAppearance.photograph(geometry: .init(julianDate: key.julianDate, observer: key.observer)) else { return nil }
        if order.count >= 64 { images.removeValue(forKey: order.removeFirst()) }
        order.append(key)
        images[key] = image
        return image
    }
}

struct MoonDiskView: View {
    let julianDate: Double
    let observer: LatLonAlt
    let radius: CGFloat
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().interpolation(.high)
                    .frame(width: radius * 6, height: radius * 6)
            }
            else { Color.clear }
        }
        .frame(width: radius * 2, height: radius * 2)
        .task(id: MoonImageRenderer.Key(julianDate: julianDate, observer: observer)) {
            let result = await MoonImageRenderer.shared.image(for: .init(julianDate: julianDate, observer: observer))
            guard !Task.isCancelled else { return }
            image = result
        }
        .accessibilityLabel(Text("Moon", bundle: .module))
    }
}
