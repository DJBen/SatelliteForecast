import UIKit
import ImageIO
import simd
import SatelliteKit

/// NASA/Goddard SVS Gaia background, without the separate bright-star layer.
/// Faint source stars remain; this is not a model of observing visibility.
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

    /// NASA's Galactic plate carrée: center l=0, longitude increases leftward.
    static func textureCoordinates(_ direction: SIMD3<Double>) -> SIMD2<Double> {
        let u = 0.5 - atan2(direction.y, direction.x) / (2 * .pi)
        return SIMD2(u - floor(u), 0.5 - asin(max(-1, min(1, direction.z))) / .pi)
    }

    struct Texture {
        let width: Int
        let height: Int
        let pixels: [UInt8]

        init?(image: CGImage) {
            let width = image.width
            let height = image.height
            self.width = width
            self.height = height
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            let decoded = bytes.withUnsafeMutableBytes { buffer -> Bool in
                guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                    bitsPerComponent: 8, bytesPerRow: width * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
                context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
                return true
            }
            guard decoded else { return nil }
            pixels = bytes
        }

        // Separable spherical blur: wrap longitude and clamp latitude. Filtering
        // before reprojection prevents faint source stars from aliasing into grain.
        func smoothed(radius: Int) -> Texture {
            var input = pixels
            for horizontal in [true, false] {
                var output = input
                for y in 0..<height {
                    for x in 0..<width {
                        for channel in 0..<3 {
                            var sum = 0
                            for offset in -radius...radius {
                                let xx = horizontal ? (x + offset + width) % width : x
                                let yy = horizontal ? y : max(0, min(height - 1, y + offset))
                                sum += Int(input[(yy * width + xx) * 4 + channel])
                            }
                            output[(y * width + x) * 4 + channel] = UInt8(sum / (radius * 2 + 1))
                        }
                    }
                }
                input = output
            }
            return Texture(width: width, height: height, pixels: input)
        }

        private init(width: Int, height: Int, pixels: [UInt8]) {
            self.width = width; self.height = height; self.pixels = pixels
        }

        func sample(_ uv: SIMD2<Double>) -> SIMD3<Double> {
            let x = (uv.x - floor(uv.x)) * Double(width) - 0.5
            let y = max(0, min(Double(height - 1), uv.y * Double(height) - 0.5))
            let x0 = Int(floor(x)), y0 = Int(floor(y))
            let fx = x - floor(x), fy = y - floor(y)
            func pixel(_ column: Int, _ row: Int) -> SIMD3<Double> {
                let wrapped = (column % width + width) % width
                let i = (min(row, height - 1) * width + wrapped) * 4
                return SIMD3(Double(pixels[i]), Double(pixels[i + 1]), Double(pixels[i + 2])) / 255
            }
            let top = pixel(x0, y0) * (1 - fx) + pixel(x0 + 1, y0) * fx
            let bottom = pixel(x0, y0 + 1) * (1 - fx) + pixel(x0 + 1, y0 + 1) * fx
            return top * (1 - fy) + bottom * fy
        }
    }

    // Lazy, immutable decode shared across renders. No I/O on animation frames.
    static let texture: Texture? = {
        guard let url = Bundle.module.url(forResource: "milkyway-galactic", withExtension: "jpg"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 1024
              ] as CFDictionary) else { return nil }
        return Texture(image: image)?.smoothed(radius: 2)
    }()

    /// Bounded low-frequency raster. Rotation/zoom reuse the enclosing sky image;
    /// this runs with stars on ChartRenderer's actor, never per animation frame.
    static func image(size: CGSize, observer: LatLonAlt, julianDate: Double, dark: Bool) -> UIImage? {
        guard let texture, size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0, julianDate.isFinite,
              observer.lat.isFinite, observer.lon.isFinite else { return nil }
        let dimension = Int(min(512, max(96, max(size.width, size.height))))
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
                let light = texture.sample(textureCoordinates(galactic(projection.equatorial(at: horizontal))))
                let peak = max(light.x, max(light.y, light.z))
                let alpha = peak * (dark ? 0.65 : 0.18)
                // Convert black to transparency while preserving NASA's color ratios.
                let rgb = dark ? light / max(peak, 1e-10) : SIMD3(0.25, 0.30, 0.43)
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
