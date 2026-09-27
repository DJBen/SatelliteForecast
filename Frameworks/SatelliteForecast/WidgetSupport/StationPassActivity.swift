import ActivityKit
import Foundation

/// Small, local-only prediction payload shared with the WidgetKit extension.
public struct StationPassActivity: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public enum Phase: String, Codable, Sendable { case upcoming, visible, shadow, ended }
        public var phase: Phase
        public var target: Date
        public var targetsShadow: Bool
        public init(phase: Phase, target: Date, targetsShadow: Bool = false) {
            self.phase = phase; self.target = target; self.targetsShadow = targetsShadow
        }
    }
    public struct Point: Codable, Hashable, Sendable {
        /// Seconds after rise and tenths of a degree; integer encoding keeps payloads compact.
        public var seconds: Int
        public var elevation: Int
        public init(seconds: Int, elevation: Int) { self.seconds = seconds; self.elevation = elevation }
    }
    public struct Interval: Codable, Hashable, Sendable {
        public var start: Date
        public var end: Date
        public init(start: Date, end: Date) { self.start = start; self.end = end }
    }
    public var passID: String
    public var station: Int
    public var rise: Date
    public var set: Date
    public var peak: Int
    public var startDirection: String
    public var endDirection: String
    public var points: [Point]
    public var illuminated: [Interval]
    public var url: URL
    public init(passID: String, station: Int, rise: Date, set: Date, peak: Int,
                startDirection: String, endDirection: String, points: [Point], illuminated: [Interval], url: URL) {
        self.passID = passID; self.station = station; self.rise = rise; self.set = set; self.peak = peak
        self.startDirection = startDirection; self.endDirection = endDirection
        self.points = points; self.illuminated = illuminated; self.url = url
    }
    public var hasShadow: Bool {
        illuminated.count != 1 || illuminated.first?.start != rise || illuminated.first?.end != set
    }
    public func state(at date: Date) -> ContentState {
        guard date < set else { return .init(phase: .ended, target: set) }
        for interval in illuminated {
            if date < interval.start { return .init(phase: date < rise ? .upcoming : .shadow, target: interval.start) }
            if date < interval.end { return .init(phase: .visible, target: interval.end, targetsShadow: interval.end < set) }
        }
        return .init(phase: .shadow, target: set)
    }
    public func isIlluminated(at date: Date) -> Bool {
        illuminated.contains { date >= $0.start && date < $0.end }
    }
    public static func example(station: Int = 25544, scenario: Int = 0, rise: Date = Date().addingTimeInterval(-120)) -> Self {
        let set = rise.addingTimeInterval(480)
        let peak = station == 25544 ? 64 : 42
        let lit: [Interval] = scenario == 1 ? [.init(start: rise.addingTimeInterval(150), end: set)] :
            scenario == 2 ? [.init(start: rise, end: rise.addingTimeInterval(360))] : [.init(start: rise, end: set)]
        return .init(passID: "preview", station: station, rise: rise, set: set, peak: peak,
            startDirection: "SW", endDirection: "NE",
            points: (0...40).map { .init(seconds: $0 * 12, elevation: Int(sin(Double($0) / 40 * .pi) * Double(peak) * 10)) },
            illuminated: lit, url: URL(string: "satelliteforecast://satellite/\(station)?lat=0&lon=0&alt=0")!)
    }
}
