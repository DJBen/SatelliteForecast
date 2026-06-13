//
//  SIMDCompat.swift
//  SatellitePasses
//
//  Minimal stand-ins for the Apple `simd` framework helpers used here, for platforms
//  (e.g. Linux) where the `simd` module is unavailable. `SIMD3` itself ships with the
//  Swift standard library and works everywhere, so only the free functions need replacing.
//

#if !canImport(simd)

@inlinable
func simd_dot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
    a.x * b.x + a.y * b.y + a.z * b.z
}

@inlinable
func simd_length(_ v: SIMD3<Double>) -> Double {
    (v.x * v.x + v.y * v.y + v.z * v.z).squareRoot()
}

@inlinable
func simd_length_squared(_ v: SIMD3<Double>) -> Double {
    v.x * v.x + v.y * v.y + v.z * v.z
}

#endif
