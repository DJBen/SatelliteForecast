import Foundation
import SatelliteKit

/// Shared contract for notification taps and satelliteforecast:// links.
public struct SatelliteDeepLink: Identifiable {
    public let id = UUID()
    public let category: SatelliteCategory
    public let noradIndex: UInt
    public let observer: LatLonAlt
    public let passTime: Date?

    public init(category: SatelliteCategory, noradIndex: UInt, observer: LatLonAlt, passTime: Date? = nil) {
        self.category = category
        self.noradIndex = noradIndex
        self.observer = observer
        self.passTime = passTime
    }

    public init?(userInfo: [AnyHashable: Any]) {
        guard let id = (userInfo["noradIndex"] as? String).flatMap(UInt.init), id > 0,
              let category = (userInfo["satelliteCategory"] as? String).flatMap(SatelliteCategory.init(rawValue:)),
              category.noradIndex == nil || category.noradIndex == id else { return nil }
        let observer: LatLonAlt
        if let data = userInfo["observer"] as? Data,
           let decoded = try? JSONDecoder().decode(LatLonAlt.self, from: data) {
            observer = decoded
        } else {
            guard let lat = (userInfo["lat"] as? String).flatMap(Double.init),
                  let lon = (userInfo["lon"] as? String).flatMap(Double.init),
                  let alt = (userInfo["alt"] as? String).flatMap(Double.init) else { return nil }
            observer = LatLonAlt(lat, lon, alt)
        }
        guard observer.lat.isFinite, (-90...90).contains(observer.lat),
              observer.lon.isFinite, (-180...180).contains(observer.lon),
              observer.alt.isFinite else { return nil }
        var time: Date?
        if let raw = userInfo["passTime"] {
            guard let value = raw as? String, let seconds = Double(value), seconds.isFinite,
                  (946684800...4102444800).contains(seconds) else { return nil }
            time = Date(timeIntervalSince1970: seconds)
        }
        self.init(category: category, noradIndex: id, observer: observer, passTime: time)
    }

    public init?(url: URL) {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme?.lowercased() == "satelliteforecast", parts.host == "satellite",
              parts.user == nil, parts.password == nil, parts.port == nil else { return nil }
        let station = parts.path.lowercased()
        let id: String
        switch station {
        case "/iss", "/25544": id = "25544"
        case "/tiangong", "/tianhe", "/48274": id = "48274"
        default: return nil
        }
        var values: [String: String] = [:]
        for item in parts.queryItems ?? [] {
            guard values[item.name] == nil, let value = item.value else { return nil }
            values[item.name] = value
        }
        var payload = values
        payload["noradIndex"] = id
        payload["satelliteCategory"] = id == "25544" ? "iss" : "tianhe"
        payload["alt"] = values["alt"] ?? "0"
        if let iso = values["time"] {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var date = formatter.date(from: iso)
            if date == nil {
                formatter.formatOptions = [.withInternetDateTime]
                date = formatter.date(from: iso)
            }
            guard let date else { return nil }
            payload["passTime"] = String(date.timeIntervalSince1970)
        }
        self.init(userInfo: payload)
    }
}
