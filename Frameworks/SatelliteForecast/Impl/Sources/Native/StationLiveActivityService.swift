import ActivityKit
import CoreLocation
import Foundation
import Observation
import SatelliteForecast
import SatelliteKit
import SatelliteWidgetSupport

@MainActor @Observable
public final class StationLiveActivityService {
    public private(set) var followedID: String?
    public private(set) var busy = false
    public var errorKey: String?
    private let push = StationLiveActivityPush()
    private var tokenObservers: [String: Task<Void, Never>] = [:]
    #if DEBUG
    private var reviewStarted = false
    private var reviewObserver: Task<Void, Never>?
    private var isPushReview: Bool { ProcessInfo.processInfo.arguments.contains("-liveActivityPushReview") }
    #endif
    private var stateObservers: [String: Task<Void, Never>] = [:]
    public init() { followedID = activities.first?.attributes.passID }
    private var activities: [Activity<StationPassActivity>] {
        Activity.activities.filter { $0.activityState != .ended && $0.activityState != .dismissed }
    }

    public func follow(_ context: PassViewContext) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        errorKey = nil
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { errorKey = "live.disabled"; return }
        do {
            let pass = try Self.attributes(context)
            let now = Date()
            guard pass.set > now, let visible = pass.illuminated.last, visible.end > now else {
                errorKey = "live.expired"; return
            }
            guard pass.rise.timeIntervalSince(now) < 86400 else { errorKey = "live.tooEarly"; return }
            if activities.contains(where: { $0.attributes.passID == pass.passID }) { followedID = pass.passID; return }
            // This version follows one selected pass at a time. Never silently replace another.
            guard activities.isEmpty else { errorKey = "live.alreadyFollowing"; return }
            let start = max(now, (pass.illuminated.first?.start ?? pass.rise).addingTimeInterval(-120))
            let state = pass.state(at: start)
            let content = ActivityContent(state: state, staleDate: state.target)
            if start > now {
                let name = WidgetStrings.text(pass.station == 25544 ? "iss.compact" : "tiangong", locale: .current)
                let body = WidgetStrings.text("live.startAlert", locale: .current)
                _ = try Activity.request(attributes: pass, content: content, pushType: .token, style: .standard,
                    alertConfiguration: .init(title: LocalizedStringResource(stringLiteral: name),
                        body: LocalizedStringResource(stringLiteral: body), sound: .default), start: start)
            } else {
                _ = try Activity.request(attributes: pass, content: content, pushType: .token)
            }
            followedID = pass.passID
            await synchronizePush()
        } catch { errorKey = "live.failed" }
    }
    public func stop() async {
        errorKey = nil
        for activity in activities { await activity.end(nil, dismissalPolicy: .immediate) }
        followedID = nil
        await push.synchronize([])
    }
    public func invalidateIfMoved(to location: CLLocation?) async {
        #if DEBUG
        if isPushReview { return }
        #endif
        guard let location else { return }
        for activity in activities {
            let items = URLComponents(url: activity.attributes.url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            guard let lat = items.first(where: { $0.name == "lat" })?.value.flatMap(Double.init),
                  let lon = items.first(where: { $0.name == "lon" })?.value.flatMap(Double.init) else { continue }
            if CLLocation(latitude: lat, longitude: lon).distance(from: location) > 2000 {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        followedID = activities.first?.attributes.passID
        await synchronizePush()
    }
    public func refresh() async {
        #if DEBUG
        if isPushReview { await synchronizePush(); return }
        #endif
        let now = Date()
        for activity in activities where activity.activityState != .pending {
            let state = activity.attributes.state(at: now)
            if state.phase == .ended {
                await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: .after(now.addingTimeInterval(60)))
            } else if activity.content.state != state {
                await activity.update(.init(state: state, staleDate: state.target))
            }
        }
        followedID = activities.first(where: { $0.activityState != .ended && $0.activityState != .dismissed })?.attributes.passID
        await synchronizePush()
    }
    private func synchronizePush() async {
        let current = activities
        let ids = Set(current.map(\.id))
        for id in Array(tokenObservers.keys) where !ids.contains(id) {
            tokenObservers.removeValue(forKey: id)?.cancel()
            stateObservers.removeValue(forKey: id)?.cancel()
        }
        for activity in current where tokenObservers[activity.id] == nil {
            tokenObservers[activity.id] = Task { [weak self] in
                for await _ in activity.pushTokenUpdates {
                    guard !Task.isCancelled else { return }
                    await self?.synchronizePush()
                }
            }
            stateObservers[activity.id] = Task { [weak self] in
                for await _ in activity.activityStateUpdates {
                    guard !Task.isCancelled else { return }
                    await self?.refresh()
                }
            }
        }
        await push.synchronize(current)
    }
    public func runWhileActive() async {
        #if DEBUG
        if isPushReview, !reviewStarted { await startPushReview() }
        #endif
        while !Task.isCancelled {
            await refresh()
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
        }
    }
    #if DEBUG
    /// Opt-in physical-device smoke test. No local phase updates; all changes must arrive by APNs.
    private func startPushReview() async {
        reviewStarted = true
        guard activities.isEmpty else { return }
        let rise = Date().addingTimeInterval(45)
        var pass = StationPassActivity.example(rise: rise)
        pass.passID = "push-review-" + UUID().uuidString
        pass.set = rise.addingTimeInterval(120)
        pass.points = pass.points.map { .init(seconds: $0.seconds / 4, elevation: $0.elevation) }
        pass.illuminated = [.init(start: rise.addingTimeInterval(30), end: rise.addingTimeInterval(90))]
        do {
            let activity = try Activity.request(attributes: pass,
                content: .init(state: pass.state(at: Date()), staleDate: rise), pushType: .token)
            followedID = pass.passID
            let file = URL.documentsDirectory.appendingPathComponent("live-activity-push-review.json")
            try Data("[]".utf8).write(to: file, options: .atomic)
            reviewObserver = Task {
                var receipts: [[String: String]] = []
                for await content in activity.contentUpdates {
                    receipts.append(["phase": content.state.phase.rawValue,
                                     "receivedAt": Date().ISO8601Format()])
                    if let data = try? JSONSerialization.data(withJSONObject: receipts, options: .prettyPrinted) {
                        try? data.write(to: file, options: .atomic)
                    }
                }
            }
            await synchronizePush()
        } catch { errorKey = "live.failed" }
    }
    #endif

    static func attributes(_ context: PassViewContext) throws -> StationPassActivity {
        let pass = context.passSnapshots.pass
        let intervals = ObservationOpportunity.visibleIntervals(pass)
        guard [25544, 48274].contains(pass.noradIndex), !intervals.isEmpty else { throw BuildError.ineligible }
        let rise = Date(julianDate: pass.rise.julianDate)
        let set = Date(julianDate: pass.set.julianDate)
        func direction(_ azimuth: Double) -> String {
            let normalized = (azimuth.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
            return ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][Int((normalized / 45).rounded()) % 8]
        }
        let points = try (0...40).map { i -> StationPassActivity.Point in
            let jd = pass.rise.julianDate + (pass.set.julianDate - pass.rise.julianDate) * Double(i) / 40
            let snapshot = try SatelliteSnapshot(satelliteInfo: context.satelliteInfo, julianDate: jd, observer: context.observer)
            return .init(seconds: Int(((jd - pass.rise.julianDate) * 86400).rounded()), elevation: Int((max(0, snapshot.position.elev) * 10).rounded()))
        }
        var url = URLComponents()
        url.scheme = "satelliteforecast"; url.host = "satellite"; url.path = "/\(pass.noradIndex)"
        url.queryItems = [URLQueryItem(name: "lat", value: String(context.observer.lat)),
            .init(name: "lon", value: String(context.observer.lon)), .init(name: "alt", value: String(context.observer.alt)),
            .init(name: "passTime", value: String(rise.timeIntervalSince1970))]
        guard let link = url.url else { throw BuildError.ineligible }
        let result = StationPassActivity(passID: pass.notificationIdentifier, station: Int(pass.noradIndex), rise: rise, set: set,
            peak: Int(pass.culmination.elev.rounded()), startDirection: direction(pass.rise.azim), endDirection: direction(pass.set.azim),
            points: points, illuminated: intervals.map { .init(start: Date(julianDate: $0.lowerBound), end: Date(julianDate: $0.upperBound)) }, url: link)
        guard try JSONEncoder().encode(result).count < 3500 else { throw BuildError.ineligible }
        return result
    }
    private enum BuildError: Error { case ineligible }
}
