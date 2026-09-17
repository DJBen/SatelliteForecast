import Foundation

/// Coarse, offline geographic context, not a navigational or political boundary service.
actor GeographicRegionLookup {
    static let shared = GeographicRegionLookup()

    struct Place: Codable, Equatable, Sendable {
        let names: [String: String]
        let countryCode: String?

        func countryName(locale: Locale) -> String {
            if let countryCode, ["US", "AE", "GB"].contains(countryCode) {
                return GeographicLocalization.text("country." + countryCode, locale: locale)
            }
            return name(locale: locale)
        }

        func name(locale: Locale) -> String {
            names[GeographicLocalization.nameLanguage(for: locale)] ?? names["en"] ?? ""
        }
    }

    struct Summary: Equatable, Sendable {
        let place: Place?
        let isWater: Bool
        let nearestLand: Place?
        let distanceKilometers: Double?
        let bearingDegrees: Double?
        var subdivision: Place? = nil

        var name: String { place?.names["en"] ?? nearestLand?.names["en"] ?? "" }

        var flag: String? {
            guard let code = place?.countryCode, code.count == 2,
                  code.utf8.allSatisfy({ (65...90).contains($0) }) else { return nil }
            return String(String.UnicodeScalarView(code.unicodeScalars.compactMap {
                UnicodeScalar(127397 + $0.value)
            }))
        }

        func compactDescription(locale: Locale) -> String {
            if let place {
                if isWater, let nearestLand, let distanceKilometers, distanceKilometers <= 500 {
                    return GeographicLocalization.text("waterNear", locale: locale,
                        place.name(locale: locale), nearestLand.countryName(locale: locale))
                }
                let location: String
                if let subdivision {
                    location = GeographicLocalization.text("subdivision", locale: locale,
                        subdivision.name(locale: locale), place.countryName(locale: locale))
                } else {
                    location = isWater ? place.name(locale: locale) : place.countryName(locale: locale)
                }
                return GeographicLocalization.text("over", locale: locale, location)
            }
            if let nearestLand {
                return GeographicLocalization.text("near", locale: locale, nearestLand.countryName(locale: locale))
            }
            return GeographicLocalization.text("unavailable", locale: locale)
        }

        /// Retains the detailed presentation for future surfaces, without exposing it on home.
        func detail(locale: Locale) -> String {
            guard let nearestLand, let distanceKilometers, let bearingDegrees else {
                return GeographicLocalization.text("landDetail", locale: locale)
            }
            let country = nearestLand.countryName(locale: locale)
            if distanceKilometers < 20 {
                return GeographicLocalization.text("coast", locale: locale, country)
            }
            let keys = ["north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest"]
            let index = Int((bearingDegrees + 360 + 22.5).truncatingRemainder(dividingBy: 360) / 45)
            let direction = GeographicLocalization.text(keys[index], locale: locale)
            let distance = max(10, Int((distanceKilometers / 10).rounded()) * 10)
                .formatted(.number.locale(locale))
            return GeographicLocalization.text("distance", locale: locale, distance, direction, country)
        }
    }

    private struct Dataset: Decodable {
        let places: [String: Place]
        let regions: [Region]
        let subdivisionCountries: [String]?
    }

    private struct Region: Decodable {
        let placeID: String
        let kind: String
        let bounds: [Double]
        let rings: [[[Double]]]

        var area: Double { (bounds[2] - bounds[0]) * (bounds[3] - bounds[1]) }

        func contains(latitude: Double, longitude: Double) -> Bool {
            guard longitude >= bounds[0], longitude <= bounds[2],
                  latitude >= bounds[1], latitude <= bounds[3] else { return false }
            func inside(_ ring: [[Double]]) -> Bool {
                var result = false
                guard var previous = ring.last else { return false }
                for point in ring {
                    if (point[1] > latitude) != (previous[1] > latitude),
                       longitude < (previous[0] - point[0]) * (latitude - point[1]) / (previous[1] - point[1]) + point[0] {
                        result.toggle()
                    }
                    previous = point
                }
                return result
            }
            return rings.first.map(inside) == true && !rings.dropFirst().contains(where: inside)
        }
    }

    private var regions: [Region]?
    private var places: [String: Place] = [:]
    private var subdivisionCountries: Set<String> = []
    private var subdivisions: Dataset?
    private var attemptedSubdivisionLoad = false

    private func subdivision(in country: Place?, latitude: Double, longitude: Double) -> Place? {
        guard let code = country?.countryCode, subdivisionCountries.contains(code) else { return nil }
        if !attemptedSubdivisionLoad {
            attemptedSubdivisionLoad = true
            if let url = Bundle.module.url(forResource: "subdivisions", withExtension: "json"),
               let data = try? Data(contentsOf: url) {
                subdivisions = try? JSONDecoder().decode(Dataset.self, from: data)
            }
        }
        guard let subdivisions,
              let region = subdivisions.regions.first(where: {
                  subdivisions.places[$0.placeID]?.countryCode == code &&
                  $0.contains(latitude: latitude, longitude: longitude)
              }) else { return nil }
        return subdivisions.places[region.placeID]
    }

    func summary(latitude: Double, longitude: Double) -> Summary? {
        guard latitude.isFinite, longitude.isFinite, abs(latitude) <= 90 else { return nil }
        let longitude = (longitude.truncatingRemainder(dividingBy: 360) + 540).truncatingRemainder(dividingBy: 360) - 180
        if regions == nil {
            guard let url = Bundle.module.url(forResource: "regions", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode(Dataset.self, from: data) else { return nil }
            regions = decoded.regions.sorted { $0.area < $1.area }
            places = decoded.places
            subdivisionCountries = Set(decoded.subdivisionCountries ?? [])
        }
        guard let regions else { return nil }
        if let land = regions.first(where: { $0.kind == "land" && $0.contains(latitude: latitude, longitude: longitude) }) {
            return Summary(place: places[land.placeID], isWater: false, nearestLand: nil,
                           distanceKilometers: nil, bearingDegrees: nil,
                           subdivision: subdivision(in: places[land.placeID], latitude: latitude, longitude: longitude))
        }
        let water = regions.first { $0.kind == "water" && $0.contains(latitude: latitude, longitude: longitude) }
        // Nearest sampled boundary point, using spherical distance so the date line and poles work.
        // Natural Earth's generalized coastlines make both the distance and proximity approximate.
        let lat = latitude * .pi / 180
        var nearest: (placeID: String, distance: Double, latitude: Double, longitude: Double)?
        for region in regions where region.kind == "land" {
            for point in region.rings[0] {
                let otherLat = point[1] * .pi / 180
                let deltaLon = (longitude - point[0]) * .pi / 180
                let a = pow(sin((lat - otherLat) / 2), 2) + cos(lat) * cos(otherLat) * pow(sin(deltaLon / 2), 2)
                let distance = 6371 * 2 * asin(sqrt(min(1, max(0, a))))
                if distance < (nearest?.distance ?? .infinity) {
                    nearest = (region.placeID, distance, otherLat, point[0] * .pi / 180)
                }
            }
        }
        guard let nearest else { return nil }
        let deltaLon = longitude * .pi / 180 - nearest.longitude
        let bearing = atan2(sin(deltaLon) * cos(lat), cos(nearest.latitude) * sin(lat) - sin(nearest.latitude) * cos(lat) * cos(deltaLon)) * 180 / .pi
        return Summary(place: water.flatMap { places[$0.placeID] }, isWater: water != nil,
                       nearestLand: places[nearest.placeID], distanceKilometers: nearest.distance,
                       bearingDegrees: bearing)
    }
}
