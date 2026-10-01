import CoreLocation
import FirebaseAuth
import FirebaseCore
import Foundation
import Observation

/// Rounded to roughly a kilometre so small GPS changes do not start another request.
struct HomeWeatherLocation: Equatable, Hashable {
    let latitude: Double
    let longitude: Double

    init?(_ coordinate: CLLocationCoordinate2D) {
        guard coordinate.latitude.isFinite, coordinate.longitude.isFinite,
              (-89...89).contains(coordinate.latitude), (-179...179).contains(coordinate.longitude) else { return nil }
        latitude = (coordinate.latitude * 100).rounded() / 100
        longitude = (coordinate.longitude * 100).rounded() / 100
    }
}

struct HomeWeatherForecast: Decodable {
    struct Provider: Decodable {
        let status: String
        let fetchedAt: Date
        let stale: Bool?
    }
    struct Providers: Decodable { let weatherkit: Provider }
    struct Attribution: Decodable { let weatherkit: [String: String]? }
    struct Hour: Decodable {
        struct Weather: Decodable {
            let temperatureC: Double?
            let conditionCode: String?
            let daylight: Bool?
        }
        let time: Date
        let weather: Weather?
    }
    let schemaVersion: Int
    let providers: Providers
    let hours: [Hour]
    let attribution: Attribution

    static func decode(_ data: Data) throws -> Self {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: value) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid forecast timestamp"))
            }
            return date
        }
        return try decoder.decode(Self.self, from: data)
    }

    func current(at now: Date) -> HomeWeatherReading? {
        let provider = providers.weatherkit
        let age = now.timeIntervalSince(provider.fetchedAt)
        guard schemaVersion == 1, ["ok", "partial"].contains(provider.status), provider.stale != true,
              age >= -120, age < 900,
              let hour = hours.first(where: { $0.time <= now && now.timeIntervalSince($0.time) < 3600 }),
              let weather = hour.weather, let temperature = weather.temperatureC, temperature.isFinite,
              let branding = attribution.weatherkit else { return nil }
        return HomeWeatherReading(temperatureC: temperature, conditionCode: weather.conditionCode,
            daylight: weather.daylight ?? false, forecastTime: hour.time, fetchedAt: provider.fetchedAt,
            attribution: branding)
    }
}

struct HomeWeatherReading {
    let temperatureC: Double
    let conditionCode: String?
    let daylight: Bool
    let forecastTime: Date
    let fetchedAt: Date
    let attribution: [String: String]

    func temperature(locale: Locale) -> String {
        let formatter = MeasurementFormatter()
        formatter.locale = locale
        formatter.unitStyle = .short
        formatter.numberFormatter.maximumFractionDigits = 0
        return formatter.string(from: Measurement(value: temperatureC, unit: UnitTemperature.celsius))
    }

    var condition: (title: String, symbol: String) {
        switch conditionCode {
        case "Clear": return ("Clear", daylight ? "sun.max.fill" : "moon.stars.fill")
        case "MostlyClear": return ("Mostly clear", daylight ? "sun.max.fill" : "moon.stars.fill")
        case "PartlyCloudy": return ("Partly cloudy", daylight ? "cloud.sun.fill" : "cloud.moon.fill")
        case "MostlyCloudy": return ("Mostly cloudy", daylight ? "cloud.sun.fill" : "cloud.moon.fill")
        case "Cloudy": return ("Cloudy", "cloud.fill")
        case "Drizzle": return ("Drizzle", "cloud.drizzle.fill")
        case "Rain", "SunShowers": return ("Rain", "cloud.rain.fill")
        case "HeavyRain": return ("Heavy rain", "cloud.heavyrain.fill")
        case "Thunderstorms", "IsolatedThunderstorms", "ScatteredThunderstorms", "StrongStorms": return ("Thunderstorms", "cloud.bolt.rain.fill")
        case "Snow", "SunFlurries", "Flurries": return ("Snow", "cloud.snow.fill")
        case "HeavySnow", "BlowingSnow", "Blizzard": return ("Heavy snow", "cloud.snow.fill")
        case "Sleet", "WintryMix": return ("Wintry mix", "cloud.sleet.fill")
        case "FreezingDrizzle", "FreezingRain": return ("Freezing rain", "cloud.sleet.fill")
        case "Hail": return ("Hail", "cloud.hail.fill")
        case "Foggy": return ("Fog", "cloud.fog.fill")
        case "Haze": return ("Haze", daylight ? "sun.haze.fill" : "cloud.fog.fill")
        case "Smoky": return ("Smoke", "smoke.fill")
        case "Breezy", "Windy": return ("Windy", "wind")
        case "BlowingDust": return ("Blowing dust", "sun.dust.fill")
        case "Hot": return ("Hot", "thermometer.sun.fill")
        case "Frigid": return ("Frigid", "thermometer.snowflake")
        case "Hurricane": return ("Hurricane", "hurricane")
        case "TropicalStorm": return ("Tropical storm", "tropicalstorm")
        default: return ("Weather", "thermometer.medium")
        }
    }

    var legalURL: URL {
        secureURL(attribution["legalPageURL"]) ?? URL(string: "https://weatherkit.apple.com/legal-attribution.html")!
    }

    func logoURL(dark: Bool) -> URL? {
        secureURL(attribution[dark ? "logoDark@2x" : "logoLight@2x"])
    }

    private func secureURL(_ value: String?) -> URL? {
        guard let value, let url = URL(string: value), url.scheme == "https", url.host != nil else { return nil }
        return url
    }
}

/// Auth is scoped to a named Firebase app. Its SDK persists and refreshes the guest session.
@MainActor
private enum ClearSkyWeatherAPI {
    private static var signingIn: Task<User, Error>?

    private static func guest(_ auth: Auth) async throws -> User {
        if let current = auth.currentUser { return current }
        if let signingIn { return try await signingIn.value }
        let task = Task { try await auth.signInAnonymously().user }
        signingIn = task
        defer { signingIn = nil }
        return try await task.value
    }

    static func auth() -> Auth {
        let name = "ClearSkyWeather"
        if FirebaseApp.app(name: name) == nil {
            // Public Firebase client configuration for SatelliteForecast Weather.
            let options = FirebaseOptions(googleAppID: "1:4137038259:ios:b34400916d7627caba5bc6", gcmSenderID: "4137038259")
            options.apiKey = "AIzaSyBdG_wkT4tvUGywFnH7K9tioUqNFYYX1gQ"
            options.projectID = "clear-sky-chart"
            options.bundleID = "io.djben.SatelliteForecast"
            FirebaseApp.configure(name: name, options: options)
        }
        return Auth.auth(app: FirebaseApp.app(name: name)!)
    }

    static func load(_ location: HomeWeatherLocation) async throws -> HomeWeatherForecast {
        let environment = ProcessInfo.processInfo.environment
        guard !SnapshotEnvironment.isEnabled, NSClassFromString("XCTestCase") == nil,
              environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { throw URLError(.cancelled) }
        try Task.checkCancellation()
        let user = try await guest(auth())
        var url = URLComponents(string: "https://us-west1-clear-sky-chart.cloudfunctions.net/api/v1/forecast")!
        url.queryItems = [URLQueryItem(name: "latitude", value: String(location.latitude)),
                         URLQueryItem(name: "longitude", value: String(location.longitude)),
                         URLQueryItem(name: "hours", value: "2")]
        for retry in 0...1 {
            try Task.checkCancellation()
            var request = URLRequest(url: url.url!)
            request.timeoutInterval = 120
            request.setValue("Bearer \(try await user.getIDToken(forcingRefresh: retry == 1))", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            if response.statusCode == 401 && retry == 0 { continue }
            guard response.statusCode == 200 else { throw URLError(.badServerResponse) }
            return try HomeWeatherForecast.decode(data)
        }
        throw URLError(.userAuthenticationRequired)
    }
}

@MainActor @Observable
final class HomeWeatherModel {
    private(set) var isLoading = false
    private(set) var failed = false
    private(set) var location: HomeWeatherLocation?
    private var forecast: HomeWeatherForecast?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var lastAttempt: Date?
    @ObservationIgnored private let load: (HomeWeatherLocation) async throws -> HomeWeatherForecast
    @ObservationIgnored private let now: () -> Date

    init(load: @escaping (HomeWeatherLocation) async throws -> HomeWeatherForecast = { try await ClearSkyWeatherAPI.load($0) },
         now: @escaping () -> Date = { Date() }) {
        self.load = load
        self.now = now
    }

    func current(for location: HomeWeatherLocation?) -> HomeWeatherReading? {
        guard location != nil, self.location == location else { return nil }
        return forecast?.current(at: now())
    }

    func refresh(_ next: HomeWeatherLocation?, force: Bool = false) async {
        if location != next {
            generation += 1
            location = next
            forecast = nil
            lastAttempt = nil
            isLoading = false
            failed = false
        }
        guard let next else { return }
        // Reuse valid readings and back off after outages or rate-limit failures.
        if !force, let lastAttempt, now().timeIntervalSince(lastAttempt) < 900,
           current(for: next) != nil || failed { return }
        if isLoading { return }
        generation += 1
        let request = generation
        isLoading = true
        failed = false
        lastAttempt = now()
        defer { if request == generation { isLoading = false } }
        do {
            let result = try await load(next)
            try Task.checkCancellation()
            guard request == generation, location == next else { return }
            forecast = result
            failed = result.current(at: now()) == nil
        } catch {
            guard request == generation else { return }
            if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                lastAttempt = nil
            } else {
                failed = true
            }
        }
    }
}
