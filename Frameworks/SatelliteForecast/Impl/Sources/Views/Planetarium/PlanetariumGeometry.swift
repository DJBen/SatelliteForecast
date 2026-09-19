import Foundation
import simd

/// Local right-handed frame: east +X, zenith +Y, north -Z. Angles in degrees.
enum PlanetariumGeometry {
    /// Screen-space bearing, without perspective sign inversion behind the camera.
    static func offscreenBearing(cameraDirection d: SIMD3<Float>, aspect: Float, tangent: Float) -> Double? {
        guard aspect > 0, tangent > 0 else { return nil }
        if d.z > 0, abs(d.x) <= d.z * tangent * aspect, abs(d.y) <= d.z * tangent { return nil }
        let x = d.x / aspect, y = -d.y
        // Exactly behind has no unique bearing; consistently choose right.
        return abs(x) + abs(y) < 0.00001 ? .pi / 2 : Double(atan2(x, -y))
    }

    static func shortestTurn(from: Double, to: Double) -> Double {
        let difference = (to - from).truncatingRemainder(dividingBy: 360)
        return difference > 180 ? difference - 360 : (difference < -180 ? difference + 360 : difference)
    }

    /// Periodic, low mountain skyline in radians; mirrored exactly in Metal.
    static func horizonHeight(azimuth: Float) -> Float {
        let ridge = abs(sin(azimuth * 7 + 0.6))
        return 0.006 + 0.008 * ridge + 0.004 * sin(azimuth * 13 + 1.1)
            + 0.002 * sin(azimuth * 29) + 0.001 * sin(azimuth * 61 + 0.4)
    }

    /// Keep the mountain skyline consistent with Metal.
    /// Keep CPU selection consistent with Metal's ground clipping.
    static func isAboveGround(_ direction: SIMD3<Float>) -> Bool {
        direction.y.isFinite && asin(max(-1, min(1, direction.y))) >= horizonHeight(azimuth: atan2(direction.x, -direction.z))
    }

    static func direction(azimuth: Double, elevation: Double) -> SIMD3<Float> {
        let a = azimuth * .pi / 180, e = elevation * .pi / 180
        return SIMD3(Float(sin(a) * cos(e)), Float(sin(e)), Float(-cos(a) * cos(e)))
    }

    static func angles(_ direction: SIMD3<Float>) -> (azimuth: Double, elevation: Double) {
        let v = simd_normalize(direction)
        return ((atan2(Double(v.x), Double(-v.z)) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360),
                asin(Double(max(-1, min(1, v.y)))) * 180 / .pi)
    }
}

/// Serial handoff: the outgoing constellation fully contracts before the next
/// appears, so two constellations never draw simultaneously.
struct PlanetariumConstellationFocus {
    private(set) var active: Int?
    private(set) var progress: Float = 0

    mutating func update(candidate: Int?, delta: Double, reduceMotion: Bool = false) {
        if reduceMotion { active = candidate; progress = candidate == nil ? 0 : 1; return }
        let step = Float(max(0, min(delta, 0.05)))
        if active != candidate, active != nil {
            progress = max(0, progress - step / 0.24)
            if progress == 0 { active = nil }
        } else {
            if active == nil { active = candidate }
            progress = active == nil ? 0 : min(1, progress + step / 0.36)
        }
    }

    var easedProgress: Float { progress * progress * (3 - 2 * progress) }
}
