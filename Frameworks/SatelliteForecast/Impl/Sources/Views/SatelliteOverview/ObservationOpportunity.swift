import Foundation
import SatelliteForecast
import SatelliteKit

/// Shared ordering and timing for home, independent of presentation and locale.
enum ObservationOpportunity {
    static func visibleIntervals(_ pass: Pass) -> [ClosedRange<Double>] {
        guard pass.visibility == .visible else { return [] }
        var start = pass.rise.julianDate
        var lit = pass.illumination.initiallyIlluminated
        var intervals: [ClosedRange<Double>] = []
        for change in pass.illumination.changes {
            let end = min(pass.set.julianDate, max(start, change.datePosition.julianDate))
            if lit && end > start { intervals.append(start...end) }
            start = end
            switch change { case .entersShadow: lit = false; case .exitsShadow: lit = true }
        }
        if lit && pass.set.julianDate > start { intervals.append(start...pass.set.julianDate) }
        return intervals
    }

    static func start(_ pass: Pass) -> Double { visibleIntervals(pass).first?.lowerBound ?? pass.rise.julianDate }
    static func end(_ pass: Pass) -> Double { visibleIntervals(pass).last?.upperBound ?? pass.set.julianDate }
    static func upcoming(_ passes: [Pass], now: Double) -> [Pass] {
        var ids = Set<String>()
        return passes.filter {
            ($0.highestIlluminated?.elev ?? 0) > 10 && $0.sunElevationAtTransit < -6 && end($0) > now
        }.sorted {
            let a = start($0), b = start($1)
            return a == b ? $0.noradIndex < $1.noradIndex : a < b
        }.filter { ids.insert($0.notificationIdentifier).inserted }
    }

    static func category(_ pass: Pass) -> SatelliteCategory { pass.noradIndex == 25544 ? .iss : .tianhe }
    static func name(_ pass: Pass) -> String {
        SatelliteOverviewCell.satelliteOfSpecialInterestLocalizedTitle(category(pass))
    }
    /// Compact station name for list rows where the full title would wrap.
    static func shortName(_ pass: Pass) -> String {
        AppLocalization.text(category(pass) == .iss ? "ISS" : "Tiangong")
    }
    static func direction(_ azimuth: Double) -> String {
        let angle = (azimuth.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return AppLocalization.text(["N", "NE", "E", "SE", "S", "SW", "W", "NW"][Int((angle / 45).rounded()) % 8])
    }
    static func reminder(_ pass: Pass, observer: LatLonAlt) -> PassNotification {
        PassNotification(pass: pass, satelliteName: name(pass), category: category(pass), observer: observer,
            timing: .rise, timeOffset: (start(pass) - pass.rise.julianDate) * 86400 - 300)
    }
}

struct ObservationPreview: Sendable {
    let info: SatelliteInfo
    let snapshots: PassSnapshots
}
