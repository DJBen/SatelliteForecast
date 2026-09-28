import ActivityKit
import FirebaseAppCheck
import FirebaseCore
import FirebaseMessaging
import Foundation
import SatelliteWidgetSupport
import UIKit

/// Small, durable outbox. Tokens and cancellation secrets are never analytics data.
@MainActor
final class StationLiveActivityPush {
    private struct Interval: Codable { let start: Double; let end: Double }
    private struct Schedule: Codable { let rise: Double; let set: Double; let illuminated: [Interval] }
    private struct Registration: Codable {
        let id: String
        let secret: String
        let schedule: Schedule
        var activityToken: String
        var fcmToken: String
        var revision: Int64
        var cancel = false
        var delivered = false
    }
    private let key = "stationLiveActivityPushOutbox.v1"
    private var records: [String: Registration] = [:]
    private var sending = false
    private var retryAfter = Date.distantPast

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([String: Registration].self, from: data) { records = saved }
    }
    private func save() {
        if let data = try? JSONEncoder().encode(records) { UserDefaults.standard.set(data, forKey: key) }
    }
    func synchronize(_ activities: [Activity<StationPassActivity>]) async {
        // Simulator and test requests never register with production services.
        #if targetEnvironment(simulator)
        return
        #else
        guard NSClassFromString("XCTestCase") == nil,
              ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1",
              let project = FirebaseApp.app()?.options.projectID else { return }
        let now = Date()
        let ids = Set(activities.map(\.id))
        for id in Array(records.keys) {
            guard var record = records[id] else { continue }
            if record.schedule.set + 86400 < now.timeIntervalSince1970 { records.removeValue(forKey: id); continue }
            if !ids.contains(id), !record.cancel {
                record.cancel = true; record.delivered = false
                records[id] = record
            }
        }
        let fcm = Messaging.messaging().fcmToken ?? ""
        for activity in activities {
            guard let token = activity.pushToken else { continue }
            let hex = token.map { String(format: "%02x", $0) }.joined()
            let pass = activity.attributes
            var record = records[activity.id] ?? Registration(id: activity.id, secret: UUID().uuidString,
                schedule: Schedule(rise: pass.rise.timeIntervalSince1970, set: pass.set.timeIntervalSince1970,
                    illuminated: pass.illuminated.map { Interval(start: $0.start.timeIntervalSince1970, end: $0.end.timeIntervalSince1970) }),
                activityToken: "", fcmToken: "", revision: 0)
            guard !record.cancel else { continue }
            if record.activityToken != hex || record.fcmToken != fcm {
                record.activityToken = hex; record.fcmToken = fcm
                record.revision = max(record.revision + 1, Int64(now.timeIntervalSince1970 * 1000))
                record.delivered = false
            }
            records[activity.id] = record
        }
        save()
        guard !sending, now >= retryAfter else { return }
        let pending = records.values.filter { !$0.delivered && ($0.cancel || !$0.fcmToken.isEmpty) }
        guard !pending.isEmpty else { return }
        sending = true
        let background = UIApplication.shared.beginBackgroundTask(withName: "Live Activity registration")
        defer {
            sending = false
            if background != .invalid { UIApplication.shared.endBackgroundTask(background) }
        }
        do {
            let attestation = try await AppCheck.appCheck().token(forcingRefresh: false)
            for record in pending {
                guard let url = URL(string: "https://us-central1-\(project).cloudfunctions.net/register_live_activity") else { continue }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.timeoutInterval = 15
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(attestation.token, forHTTPHeaderField: "X-Firebase-AppCheck")
                request.httpBody = try JSONEncoder().encode(record)
                let (_, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 204 else { throw URLError(.badServerResponse) }
                // An await may race cancellation or token rotation; acknowledge only this version.
                if records[record.id]?.revision == record.revision, records[record.id]?.cancel == record.cancel {
                    if record.cancel { records.removeValue(forKey: record.id) }
                    else { records[record.id]?.delivered = true }
                    save()
                }
            }
            retryAfter = .distantPast
        } catch {
            // Leave the durable outbox for the next foreground/relaunch retry.
            retryAfter = Date().addingTimeInterval(30)
        }
        #endif
    }
}
