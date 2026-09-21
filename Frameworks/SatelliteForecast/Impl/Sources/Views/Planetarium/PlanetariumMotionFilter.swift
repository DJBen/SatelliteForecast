import Foundation
import simd

/// Low-pass the complete orientation, avoiding heading wrap and Euler-angle pole artifacts.
struct PlanetariumMotionFilter {
    private var orientation: simd_quatf?
    private var lastTimestamp: Double?
    let timeConstant: Double = 0.25

    mutating func reset() {
        orientation = nil
        lastTimestamp = nil
    }

    mutating func update(forward: SIMD3<Float>, up: SIMD3<Float>, timestamp: Double) -> simd_quatf? {
        guard timestamp.isFinite, forward.x.isFinite, forward.y.isFinite, forward.z.isFinite,
              up.x.isFinite, up.y.isFinite, up.z.isFinite, simd_length_squared(forward) > 0.0001 else { return nil }
        let f = simd_normalize(forward)
        let cross = simd_cross(f, up)
        guard simd_length_squared(cross) > 0.0001 else { return nil }
        let r = simd_normalize(cross)
        let u = simd_normalize(simd_cross(r, f))
        let target = simd_normalize(simd_quatf(simd_float3x3(columns: (r, u, -f))))
        if let previous = orientation, let lastTimestamp {
            let dt = timestamp - lastTimestamp
            guard dt > 0 else { return previous }
            // Resume with a fresh pose after interrupted delivery instead of replaying old motion.
            if dt < 0.5 {
                let alpha = Float(1 - exp(-dt / timeConstant))
                orientation = simd_normalize(simd_slerp(previous, target, alpha))
            } else {
                orientation = target
            }
        } else {
            orientation = target
        }
        lastTimestamp = timestamp
        return orientation
    }
}
