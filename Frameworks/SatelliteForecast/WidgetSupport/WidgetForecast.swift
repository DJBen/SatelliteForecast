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

    public init(station: Int, rise: Date, peak: Date, set: Date, elevation: Double,
                startDirection: String, endDirection: String, skyTrack: [WidgetSkyPoint]? = nil, skyBackground: WidgetSkyBackground? = nil) {
        self.station = station
        self.rise = rise
        self.peak = peak
        self.set = set
        self.elevation = elevation
        self.startDirection = startDirection
        self.endDirection = endDirection
        self.skyTrack = skyTrack
        self.skyBackground = skyBackground
    }
    public var name: String { station == 25544 ? "ISS" : "Tiangong" }
}

public struct WidgetForecast: Codable, Sendable {
    public let generated: Date
    public let expires: Date
    public let passes: [WidgetPass]
    public init(generated: Date, expires: Date, passes: [WidgetPass]) {
        self.generated = generated
        self.expires = expires
        self.passes = passes.sorted { $0.rise < $1.rise }
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

public enum WidgetForecastStore {
    public static let group = "group.io.djben.SatelliteForecast"
    public static let kind = "SatelliteForecastWidget"
    private static var file: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?
            .appendingPathComponent("widget-forecast-v1.json")
    }
    public static func read() -> WidgetForecast? {
        guard let file, let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode(WidgetForecast.self, from: data)
    }
    public static func write(_ forecast: WidgetForecast) {
        guard let file, let data = try? JSONEncoder().encode(forecast) else { return }
        do {
            try data.write(to: file, options: .atomic)
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        } catch { /* The app remains usable if the shared container is unavailable. */ }
    }
    public static func clear() {
        if let file { try? FileManager.default.removeItem(at: file) }
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }
}
