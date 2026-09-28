import CoreLocation
import Foundation
import WidgetKit

public struct WidgetSkyPoint: Codable, Equatable, Sendable {
    public let azimuth: Double
    public let elevation: Double
    public let illuminated: Bool
    public init(azimuth: Double, elevation: Double, illuminated: Bool = true) {
        self.azimuth = azimuth
        self.elevation = elevation
        self.illuminated = illuminated
    }
    /// Matches the app's north-up sky projection: east is on the left.
    public var unitPoint: CGPoint {
        let radius = (90 - min(90, max(0, elevation))) / 90
        let angle = azimuth * .pi / 180
        return CGPoint(x: -sin(angle) * radius, y: -cos(angle) * radius)
    }
    /// Frozen propagated ISS pass from the app's June 2021 San Francisco fixture.
    /// A real projected orbit also keeps the widget gallery representative.
    public static var previewTrack: [Self] {
        [
            .init(azimuth: 207.365338, elevation: 0.000000, illuminated: false),
            .init(azimuth: 206.579135, elevation: 0.896276, illuminated: false),
            .init(azimuth: 205.713822, elevation: 1.939866, illuminated: false),
            .init(azimuth: 204.756978, elevation: 3.034667, illuminated: false),
            .init(azimuth: 203.693565, elevation: 4.187722, illuminated: false),
            .init(azimuth: 202.505274, elevation: 5.407195, illuminated: false),
            .init(azimuth: 201.169615, elevation: 6.702551, illuminated: false),
            .init(azimuth: 199.658781, elevation: 8.084650, illuminated: false),
            .init(azimuth: 197.938105, elevation: 9.565816, illuminated: false),
            .init(azimuth: 195.964114, elevation: 11.159673, illuminated: false),
            .init(azimuth: 193.681957, elevation: 12.880655, illuminated: true),
            .init(azimuth: 191.022244, elevation: 14.742786, illuminated: true),
            .init(azimuth: 187.897357, elevation: 16.757163, illuminated: true),
            .init(azimuth: 184.197654, elevation: 18.927292, illuminated: true),
            .init(azimuth: 179.789275, elevation: 21.240816, illuminated: true),
            .init(azimuth: 174.516887, elevation: 23.656400, illuminated: true),
            .init(azimuth: 168.218915, elevation: 26.085405, illuminated: true),
            .init(azimuth: 160.766328, elevation: 28.372948, illuminated: true),
            .init(azimuth: 152.135351, elevation: 30.292152, illuminated: true),
            .init(azimuth: 142.501583, elevation: 31.575556, illuminated: true),
            .init(azimuth: 132.295107, elevation: 31.997628, illuminated: true),
            .init(azimuth: 122.129378, elevation: 31.475967, illuminated: true),
            .init(azimuth: 112.604024, elevation: 30.114578, illuminated: true),
            .init(azimuth: 104.118040, elevation: 28.149514, illuminated: true),
            .init(azimuth: 96.817425, elevation: 25.846277, illuminated: true),
            .init(azimuth: 90.660212, elevation: 23.423260, illuminated: true),
            .init(azimuth: 85.510061, elevation: 21.026277, illuminated: true),
            .init(azimuth: 81.204668, elevation: 18.737087, illuminated: true),
            .init(azimuth: 77.590899, elevation: 16.592700, illuminated: true),
            .init(azimuth: 74.537925, elevation: 14.603108, illuminated: true),
            .init(azimuth: 71.939031, elevation: 12.763697, illuminated: true),
            .init(azimuth: 69.709092, elevation: 11.062982, illuminated: true),
            .init(azimuth: 67.780728, elevation: 9.486934, illuminated: true),
            .init(azimuth: 66.100673, elevation: 8.021290, illuminated: true),
            .init(azimuth: 64.626683, elevation: 6.652669, illuminated: true),
            .init(azimuth: 63.325047, elevation: 5.369000, illuminated: true),
            .init(azimuth: 62.168703, elevation: 4.159665, illuminated: true),
            .init(azimuth: 61.135742, elevation: 3.015417, illuminated: true),
            .init(azimuth: 60.208311, elevation: 1.928278, illuminated: true),
            .init(azimuth: 59.371736, elevation: 0.891368, illuminated: true),
            .init(azimuth: 58.613886, elevation: 0.000000, illuminated: true)
        ]
    }
}

public struct WidgetStar: Codable, Equatable, Sendable {
    public let position: WidgetSkyPoint
    public let magnitude: Double
    public let spectralClass: String?
    public init(position: WidgetSkyPoint, magnitude: Double, spectralClass: String?) {
        self.position = position
        self.magnitude = magnitude
        self.spectralClass = spectralClass
    }
}

public struct WidgetSkyBackground: Codable, Equatable, Sendable {
    public let stars: [WidgetStar]
    public let sun: WidgetSkyPoint
    public let imagePNG: Data?
    public init(stars: [WidgetStar], sun: WidgetSkyPoint, imagePNG: Data? = nil) {
        self.imagePNG = imagePNG
        self.stars = stars
        self.sun = sun
    }
}

/// A labelled moment on the large widget's sky chart.
public struct WidgetSkyEvent: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case rise, peak, set, entersShadow, exitsShadow }
    public let kind: Kind
    public let date: Date
    public let position: WidgetSkyPoint
    public init(kind: Kind, date: Date, position: WidgetSkyPoint) {
        self.kind = kind
        self.date = date
        self.position = position
    }
}

/// A point in the side-on dome image, normalised to 0…1 of its width and height.
public struct WidgetDomePoint: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let illuminated: Bool
    public init(x: Double, y: Double, illuminated: Bool = true) {
        self.x = x
        self.y = y
        self.illuminated = illuminated
    }
}

/// The home screen's rise-to-set dome, pre-rendered by the app for the small chart widget:
/// the photographic sky as PNG plus the projected track and horizon in image coordinates.
public struct WidgetDome: Codable, Equatable, Sendable {
    public let imagePNG: Data?
    public let width: Double
    public let height: Double
    public let track: [WidgetDomePoint]
    public let horizon: [WidgetDomePoint]
    public init(imagePNG: Data?, width: Double, height: Double, track: [WidgetDomePoint], horizon: [WidgetDomePoint]) {
        self.imagePNG = imagePNG
        self.width = width
        self.height = height
        self.track = track
        self.horizon = horizon
    }
}

public struct WidgetPass: Codable, Equatable, Sendable {
    public let station: Int
    public let rise: Date
    public let peak: Date
    public let set: Date
    public let elevation: Double
    public let startDirection: String
    public let endDirection: String
    public let skyTrack: [WidgetSkyPoint]?
    public let skyBackground: WidgetSkyBackground?
    /// Rise, culmination, set and shadow crossings with their sky positions. Optional so
    /// forecasts written by earlier app versions still decode.
    public let events: [WidgetSkyEvent]?
    public let dome: WidgetDome?

    public init(station: Int, rise: Date, peak: Date, set: Date, elevation: Double,
                startDirection: String, endDirection: String, skyTrack: [WidgetSkyPoint]? = nil,
                skyBackground: WidgetSkyBackground? = nil, events: [WidgetSkyEvent]? = nil, dome: WidgetDome? = nil) {
        self.station = station
        self.rise = rise
        self.peak = peak
        self.set = set
        self.elevation = elevation
        self.startDirection = startDirection
        self.endDirection = endDirection
        self.skyTrack = skyTrack
        self.skyBackground = skyBackground
        self.events = events
        self.dome = dome
    }
    public var name: String { station == 25544 ? "ISS" : "Tiangong" }
}

public struct WidgetForecast: Codable, Sendable {
    public let generated: Date
    public let expires: Date
    public let passes: [WidgetPass]
    /// Where the forecast was computed. Optional so forecasts written by earlier app versions still decode.
    public let latitude: Double?
    public let longitude: Double?
    public init(generated: Date, expires: Date, passes: [WidgetPass], latitude: Double? = nil, longitude: Double? = nil) {
        self.generated = generated
        self.expires = expires
        self.passes = passes.sorted { $0.rise < $1.rise }
        self.latitude = latitude
        self.longitude = longitude
    }
    public func next(station: Int, at date: Date) -> WidgetPass? {
        guard date >= generated, date < expires else { return nil }
        return passes.first { $0.station == station && $0.set > date }
    }
    public func next(at date: Date) -> WidgetPass? {
        guard date >= generated, date < expires else { return nil }
        return passes.first { $0.set > date }
    }
    public func entryDates(after date: Date) -> [Date] {
        guard expires > date else { return [date] }
        let transitions = passes.flatMap { [$0.rise, $0.set] }.filter { $0 > date && $0 < expires }
        return Array(Set([date, expires] + transitions)).sorted()
    }
    public static func preview(at date: Date) -> Self {
        .init(generated: date, expires: date.addingTimeInterval(86_400), passes: [
            .init(station: 25544, rise: date.addingTimeInterval(2100), peak: date.addingTimeInterval(2300),
                  set: date.addingTimeInterval(2500), elevation: 32, startDirection: "SW", endDirection: "NE", skyTrack: WidgetSkyPoint.previewTrack),
            .init(station: 48274, rise: date.addingTimeInterval(5400), peak: date.addingTimeInterval(5590),
                  set: date.addingTimeInterval(5780), elevation: 32, startDirection: "SW", endDirection: "NE", skyTrack: WidgetSkyPoint.previewTrack)
        ])
    }
}

/// Keeps one forecast per recent place, so returning to a place fills the widget immediately
/// instead of waiting for the app to recompute it. Each place is its own file, so the widget
/// only ever decodes the forecast it shows.
public enum WidgetForecastStore {
    public static let group = "group.io.djben.SatelliteForecast"
    public static let kind = "SatelliteForecastWidget"
    /// Returning to one of this many most recently used places needs no recomputation.
    public static let cachedPlaceLimit = 4
    /// Pass times and visibility barely change within this distance, so one forecast serves it.
    public static let placeRadius: CLLocationDistance = 25_000
    /// Tests point this at a temporary directory.
    nonisolated(unsafe) public static var directory: URL? =
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)

    private struct Place: Codable {
        let id: UUID
        let latitude: Double
        let longitude: Double
        let expires: Date
        func contains(latitude: Double, longitude: Double) -> Bool {
            CLLocation(latitude: self.latitude, longitude: self.longitude)
                .distance(from: CLLocation(latitude: latitude, longitude: longitude)) <= placeRadius
        }
    }
    /// Places are most recently used first; `active` is the one the widget shows.
    private struct Index: Codable {
        var active: UUID?
        var places: [Place]
    }
    /// The single forecast written before places were cached.
    private static let legacyName = "widget-forecast-v1.json"
    private static let indexName = "widget-forecast-places-v1.json"
    private static func placeName(_ id: UUID) -> String { "widget-forecast-\(id.uuidString).json" }

    private static func load<T: Decodable>(_ type: T.Type, _ name: String) -> T? {
        guard let url = directory?.appendingPathComponent(name), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    private static func save(_ value: some Encodable, _ name: String) -> Bool {
        guard let url = directory?.appendingPathComponent(name), let data = try? JSONEncoder().encode(value) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }
    private static func remove(_ name: String) {
        if let url = directory?.appendingPathComponent(name) { try? FileManager.default.removeItem(at: url) }
    }

    public static func read() -> WidgetForecast? {
        guard let index = load(Index.self, indexName) else { return load(WidgetForecast.self, legacyName) }
        return index.active.flatMap { load(WidgetForecast.self, placeName($0)) }
    }
    /// Shows this forecast and caches it for its place, replacing any older one for the same place.
    public static func write(_ forecast: WidgetForecast, now: Date = Date()) {
        guard let latitude = forecast.latitude, let longitude = forecast.longitude else { return }
        let place = Place(id: UUID(), latitude: latitude, longitude: longitude, expires: forecast.expires)
        guard save(forecast, placeName(place.id)) else { return /* The app remains usable without the shared container. */ }
        let old = load(Index.self, indexName)?.places ?? []
        let kept = old.filter { $0.expires > now && !$0.contains(latitude: latitude, longitude: longitude) }
        let index = Index(active: place.id, places: [place] + kept.prefix(cachedPlaceLimit - 1))
        guard save(index, indexName) else { return remove(placeName(place.id)) }
        for evicted in old where !index.places.contains(where: { $0.id == evicted.id }) { remove(placeName(evicted.id)) }
        remove(legacyName)
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }
    /// Switches the widget to the forecast cached for the observer's place. Without one it shows
    /// setup until the app computes a forecast there; an expired one for this place still says refresh.
    public static func activate(latitude: Double, longitude: Double, now: Date = Date()) {
        // A legacy forecast has no place; it stays until the app's next forecast replaces it.
        guard var index = load(Index.self, indexName) else { return }
        if let active = index.places.first(where: { $0.id == index.active }),
           active.contains(latitude: latitude, longitude: longitude) { return }
        let match = index.places.first { $0.expires > now && $0.contains(latitude: latitude, longitude: longitude) }
        guard match?.id != index.active else { return }
        index.active = match?.id
        if let match { index.places = [match] + index.places.filter { $0.id != match.id } }
        guard save(index, indexName) else { return }
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }
}
