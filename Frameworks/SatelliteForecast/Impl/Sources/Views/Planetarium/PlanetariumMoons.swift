import Foundation
import UIKit
import SolarSystem
import simd

/// JPL IDs, mean radii (km) and periods (days). Periods set sampling density only;
/// positions always come from Horizons, never from circular/mean-element orbits.
struct PlanetariumMoon: Equatable, Sendable {
    let id: Int
    let name: String
    let parent: SolarSystemBody
    let radius: Double
    let period: Double
    var parentID: Int { id / 100 * 100 + 99 }
    var parentRadius: Double {
        switch parent {
        case .mars: return 3396.2
        case .jupiter: return 71492
        case .saturn: return 60268
        case .uranus: return 25559
        default: return 24764
        }
    }
    static let all: [Self] = [
        .init(id: 401, name: "Phobos", parent: .mars, radius: 11.1, period: 0.31891),
        .init(id: 402, name: "Deimos", parent: .mars, radius: 6.2, period: 1.26244),
        .init(id: 501, name: "Io", parent: .jupiter, radius: 1821.6, period: 1.76914),
        .init(id: 502, name: "Europa", parent: .jupiter, radius: 1560.8, period: 3.55118),
        .init(id: 503, name: "Ganymede", parent: .jupiter, radius: 2631.2, period: 7.15455),
        .init(id: 504, name: "Callisto", parent: .jupiter, radius: 2410.3, period: 16.68902),
        .init(id: 606, name: "Titan", parent: .saturn, radius: 2574.7, period: 15.945448),
        .init(id: 605, name: "Rhea", parent: .saturn, radius: 763.8, period: 4.517503),
        .init(id: 608, name: "Iapetus", parent: .saturn, radius: 734.5, period: 79.331002),
        .init(id: 604, name: "Dione", parent: .saturn, radius: 561.4, period: 2.736916),
        .init(id: 603, name: "Tethys", parent: .saturn, radius: 531.1, period: 1.887802),
        .init(id: 602, name: "Enceladus", parent: .saturn, radius: 252.1, period: 1.370218),
        .init(id: 601, name: "Mimas", parent: .saturn, radius: 198.2, period: 0.942422),
        .init(id: 607, name: "Hyperion", parent: .saturn, radius: 135, period: 21.276658),
        .init(id: 703, name: "Titania", parent: .uranus, radius: 788.9, period: 8.70587),
        .init(id: 704, name: "Oberon", parent: .uranus, radius: 761.4, period: 13.46324),
        .init(id: 701, name: "Ariel", parent: .uranus, radius: 578.9, period: 2.52038),
        .init(id: 702, name: "Umbriel", parent: .uranus, radius: 584.7, period: 4.14418),
        .init(id: 705, name: "Miranda", parent: .uranus, radius: 235.8, period: 1.41348),
        .init(id: 801, name: "Triton", parent: .neptune, radius: 1353.4, period: 5.876994),
        .init(id: 808, name: "Proteus", parent: .neptune, radius: 210, period: 1.122315)
    ]
}

struct MoonVectorSample: Codable, Sendable {
    let date: Double
    let position: SIMD3<Double>
    let velocity: SIMD3<Double>
}

struct MoonEphemeris: Codable, Sendable {
    let moonID: Int
    let moon: [MoonVectorSample]
    let parent: [MoonVectorSample]
    func contains(_ date: Double) -> Bool {
        guard let first = moon.first, let last = moon.last else { return false }
        return date >= first.date && date <= last.date
    }
    /// Cubic Hermite interpolation preserves both position and velocity. Inputs
    /// are UT Julian dates; JPL handles conversion to its internal dynamical time.
    static func interpolate(_ samples: [MoonVectorSample], at date: Double) -> SIMD3<Double>? {
        guard samples.count >= 2, date >= samples[0].date, date <= samples.last!.date else { return nil }
        let index = min(samples.count - 2, max(0, Int((date - samples[0].date) / (samples[1].date - samples[0].date))))
        let a = samples[index], b = samples[index + 1]
        let dt = b.date - a.date, t = (date - a.date) / dt
        return (2*t*t*t - 3*t*t + 1)*a.position + (t*t*t - 2*t*t + t)*dt*86400*a.velocity
            + (-2*t*t*t + 3*t*t)*b.position + (t*t*t - t*t)*dt*86400*b.velocity
    }
    func orbitDates(period: Double) -> [Double] {
        guard let first = moon.first else { return [] }
        let start = first.date + period * 0.1
        return (0...128).map { start + period * Double($0) / 128 }
    }
    static func parse(_ text: String) throws -> [MoonVectorSample] {
        guard let start = text.range(of: "$$SOE"), let end = text.range(of: "$$EOE"), start.upperBound < end.lowerBound else { throw URLError(.cannotParseResponse) }
        let samples = try text[start.upperBound..<end.lowerBound].split(separator: "\n").map { line -> MoonVectorSample in
            let fields = line.split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
            guard fields.count >= 8, let date = Double(fields[0]) else { throw URLError(.cannotParseResponse) }
            let values = fields[2...7].compactMap(Double.init)
            guard values.count == 6, values.allSatisfy(\.isFinite) else { throw URLError(.cannotParseResponse) }
            return .init(date: date, position: SIMD3(values[0], values[1], values[2]), velocity: SIMD3(values[3], values[4], values[5]))
        }
        guard samples.count >= 2, zip(samples, samples.dropFirst()).allSatisfy({ $0.date < $1.date }) else { throw URLError(.cannotParseResponse) }
        return samples
    }
}

/// Serializes all requests across controllers, caches bounded windows on disk,
/// and backs off after errors. No observing location is sent to the service.
actor MoonEphemerisStore {
    static let shared = MoonEphemerisStore()
    private var tail: Task<Void, Never>?
    private var retryAfter = Date.distantPast
    private let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("PlanetariumMoons-v1")

    func load(_ moon: PlanetariumMoon, date: Double) async throws -> MoonEphemeris {
        let url = directory.appendingPathComponent("\(moon.id).json")
        if let data = try? Data(contentsOf: url), let cached = try? JSONDecoder().decode(MoonEphemeris.self, from: data), cached.contains(date) { return cached }
        guard Date() >= retryAfter else { throw URLError(.resourceUnavailable) }
        let previous = tail
        let job = Task {
            await previous?.value
            try Task.checkCancellation()
            // 1.2 orbital revolutions, with 192 intervals; enough for an orbit
            // overlay and accurate interpolation even for eccentric Hyperion.
            let start = date - moon.period * 0.6, end = date + moon.period * 0.6
            let body = try await Self.fetch(id: moon.id, start: start, end: end)
            let parent = try await Self.fetch(id: moon.parentID, start: start, end: end)
            guard body.count == 193, parent.count == body.count,
                  zip(body, parent).allSatisfy({ abs($0.date - $1.date) < 1e-8 }) else { throw URLError(.cannotParseResponse) }
            return MoonEphemeris(moonID: moon.id, moon: body, parent: parent)
        }
        tail = Task { _ = try? await job.value }
        do {
            let result = try await job.value
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(result).write(to: url, options: .atomic)
            return result
        } catch {
            retryAfter = Date().addingTimeInterval(120)
            throw error
        }
    }
    private static func fetch(id: Int, start: Double, end: Double) async throws -> [MoonVectorSample] {
        var components = URLComponents(string: "https://ssd.jpl.nasa.gov/api/horizons.api")!
        let parameters = ["COMMAND": "\(id)", "EPHEM_TYPE": "VECTORS", "CENTER": "500@399",
            "START_TIME": "JD\(start)", "STOP_TIME": "JD\(end)", "STEP_SIZE": "192",
            "REF_PLANE": "FRAME", "REF_SYSTEM": "ICRF", "OUT_UNITS": "KM-S", "TIME_TYPE": "UT",
            "VEC_TABLE": "2", "VEC_CORR": "LT", "CSV_FORMAT": "YES", "OBJ_DATA": "NO"]
        components.queryItems = [URLQueryItem(name: "format", value: "json")] + parameters.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: "'\($0.value)'") }
        var request = URLRequest(url: components.url!, timeoutInterval: 30)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        request.setValue("SpaceStationPasses/\(version) (+https://github.com/DJBen/SatelliteForecast)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let signature = object["signature"] as? [String: String], ["1.2", "1.3"].contains(signature["version"] ?? ""),
              object["error"] == nil, let result = object["result"] as? String else { throw URLError(.badServerResponse) }
        return try MoonEphemeris.parse(result)
    }
}

/// Small, original procedural material studies, not scientific surface maps.
/// Io is sulfur-toned, Europa fractured ice, Titan hazy amber; the other moons
/// use varied cratered ice/rock. Shared 128px disks keep GPU memory modest.
@MainActor enum MoonSurface {
    private static var images: [Int: UIImage] = [:]
    private static func noise(_ point: SIMD3<Double>) -> Double {
        let cell = SIMD3(floor(point.x), floor(point.y), floor(point.z))
        let f = point - cell
        let u = f*f*(SIMD3<Double>(repeating: 3)-2*f)
        var value = 0.0
        for z in 0...1 { for y in 0...1 { for x in 0...1 {
            let p = cell + SIMD3(Double(x), Double(y), Double(z))
            let h = sin(simd_dot(p, SIMD3(127.1, 311.7, 74.7))) * 43758.5453
            value += (h-floor(h)) * (x == 0 ? 1-u.x : u.x) * (y == 0 ? 1-u.y : u.y) * (z == 0 ? 1-u.z : u.z)
        }}}
        return value
    }
    static func image(for moon: PlanetariumMoon) -> UIImage {
        if let image = images[moon.id] { return image }
        let size = 128
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        let base: SIMD3<Double>
        switch moon.id {
        case 501: base = SIMD3(0.95, 0.75, 0.32)
        case 502: base = SIMD3(0.86, 0.80, 0.68)
        case 606: base = SIMD3(0.91, 0.62, 0.25)
        case 401, 402, 504, 607, 702, 808: base = SIMD3(0.48, 0.45, 0.41)
        case 801: base = SIMD3(0.83, 0.76, 0.75)
        default: base = SIMD3(0.78, 0.80, 0.81)
        }
        let craters: [(SIMD3<Double>, Double)] = (0..<32).map { i in
            let a = Double(i) * 2.39996 + Double(moon.id)
            let z = 1 - 2 * (Double(i) + 0.5) / 32
            return (SIMD3(sqrt(1-z*z)*cos(a), z, sqrt(1-z*z)*sin(a)), 0.035 + 0.08*abs(sin(a*3.1)))
        }
        for y in 0..<size { for x in 0..<size {
            let u = (Double(x) + 0.5) / Double(size) * 2 - 1
            let v = (Double(y) + 0.5) / Double(size) * 2 - 1
            let r2 = u*u + v*v
            guard r2 < 1 else { continue }
            let z = sqrt(1-r2), lon = atan2(u, z), lat = asin(v)
            let seed = Double(moon.id)
            let normal = SIMD3(u, v, z)
            let broad = noise(normal*7 + SIMD3(seed, 0, 0))
            var terrain = 0.66 + 0.3*broad + 0.16*noise(normal*29 + SIMD3(0, seed, 0))
            if moon.id == 501 {
                terrain -= 0.4 * max(0, (noise(normal*15 + SIMD3(seed, 0, 0))-0.64)*3)
            }
            if moon.id == 502 { terrain -= 0.18*pow(abs(sin(lon*17 + 2*sin(lat*9))), 28) }
            if moon.id != 501 && moon.id != 502 && moon.id != 606 {
                for (center, radius) in craters {
                    let distance = simd_length(SIMD3(u, v, z)-center) / radius
                    if distance < 1.4 {
                        terrain -= 0.19*exp(-distance*distance*3)
                        terrain += 0.17*exp(-pow((distance-0.95)*8, 2))
                    }
                }
            }
            if moon.id == 606 { terrain = 0.94 + 0.03*sin(lat*6) }
            if moon.id == 608 { terrain *= 0.4 + 0.6 / (1 + exp(-lon*9)) }
            let light = 0.18 + 0.82*max(0, -u*0.3 - v*0.25 + z*0.92)
            let color = base * terrain * light
            let i = (y*size+x)*4
            for c in 0..<3 { pixels[i+c] = UInt8(max(0, min(255, color[c]*255))) }
            pixels[i+3] = 255
        }}
        let data = Data(pixels) as CFData
        let cg = CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: size*4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: CGDataProvider(data: data)!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
        let image = UIImage(cgImage: cg)
        images[moon.id] = image
        return image
    }
}
