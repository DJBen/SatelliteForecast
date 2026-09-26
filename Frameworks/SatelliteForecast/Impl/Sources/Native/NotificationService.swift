import Foundation
import Observation
import SatelliteForecast
import SatelliteKit
import UIKit
import UserNotifications

@MainActor @Observable
public final class NotificationService {
  public var scheduled: Set<ScheduledPassNotification> = []
  public var pending: [UNNotificationRequest] = []
  public var delivered: [UNNotification] = []
  public var errorMessage: String?
  /// True when the OS currently allows this app to present notifications. Station push
  /// reminders are delivered only to authorized devices; see `enableStationReminders()`.
  public var isAuthorized = false
  /// Raw OS state, so views can tell "never asked" from "explicitly denied".
  public var authorizationStatus: UNAuthorizationStatus = .notDetermined
  public var isDenied: Bool { authorizationStatus == .denied }
  public var isRequestingAuthorization = false
  private var revision = 0
  @ObservationIgnored private let center: UNUserNotificationCenter
  @ObservationIgnored private let defaults: UserDefaults
  public init(center: UNUserNotificationCenter = .current(), defaults: UserDefaults = .standard) {
    self.center = center
    self.defaults = defaults
    if let data = defaults.data(forKey: "scheduledLocalNotifications"),
      let saved = try? JSONDecoder().decode([ScheduledPassNotification].self, from: data)
    {
      scheduled = Set(saved)
    }
  }
  public func register() {
    center.setNotificationCategories([
      UNNotificationCategory(identifier: "PASS", actions: [], intentIdentifiers: [], options: [])
    ])
  }
  public func refresh() async {
    let expectedRevision = revision
    isAuthorized = await checkAuthorization()
    let requests = await center.pendingNotificationRequests()
    pending = requests
    delivered = await center.deliveredNotifications()
    guard expectedRevision == revision else { return }
    let ids = Set(requests.map(\.identifier))
    scheduled = scheduled.filter { ids.contains($0.id) }
    persist()
  }
  public func persist() {
    if let data = try? JSONEncoder().encode(Array(scheduled)) {
      defaults.set(data, forKey: "scheduledLocalNotifications")
    }
  }
  /// Reads the live OS authorization state without prompting.
  public func checkAuthorization() async -> Bool {
    let status = await center.notificationSettings().authorizationStatus
    authorizationStatus = status
    return [.authorized, .provisional, .ephemeral].contains(status)
  }
  /// Requests notification permission for ISS and Tiangong push reminders. The prompt appears
  /// only from an explicit user action; nothing is scheduled locally. Returns the OS decision.
  public func enableStationReminders() async -> Bool {
    guard !isRequestingAuthorization else { return isAuthorized }
    isRequestingAuthorization = true
    defer { isRequestingAuthorization = false }
    let metric = AppAnalytics.Operation("enable_station_reminders", screen: .forecast)
    do {
      let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
      isAuthorized = granted
      authorizationStatus = await center.notificationSettings().authorizationStatus
      guard granted else {
        metric.finish("blocked", reason: "notification_permission_denied")
        errorMessage = AppLocalization.text("Notifications are disabled. Enable them in Settings to get station reminders.")
        return false
      }
      metric.finish("success")
      AppAnalytics.event("station_reminders_enabled", screen: .forecast)
      return true
    } catch {
      metric.finish("failure", reason: "authorization_failed")
      errorMessage = error.localizedDescription
      return false
    }
  }
  public func cancel(_ ids: [String]) {
    if scheduled.contains(where: { ids.contains($0.id) }) {
      AppAnalytics.event("alarm_cancelled", screen: .alarms)
    }
    revision += 1
    center.removePendingNotificationRequests(withIdentifiers: ids)
    for item in scheduled where ids.contains(item.id) {
      try? FileManager.default.removeItem(
        at: item.notification.pass.attachmentImageURL(extension: "png"))
    }
    scheduled = scheduled.filter { !ids.contains($0.id) }
    persist()
  }
  public func schedule(
    _ notification: PassNotification, snapshots: PassSnapshots, catalog: AppStarCatalog,
    offset: Double = 0, rapid: Bool = false, fromAlarmSetup: Bool = false, fromForecast: Bool = false
  ) async {
    let source: AppAnalytics.Screen = fromForecast ? .forecast : (fromAlarmSetup ? .alarmSetup : .passes)
    let metric = AppAnalytics.Operation("schedule_alarm", screen: source)
    defer { metric.finish("cancelled") }
    do {
      guard try await center.requestAuthorization(options: [.alert, .sound, .badge]) else {
        metric.finish("blocked", reason: "notification_permission_denied")
        errorMessage = AppLocalization.text("Notifications are disabled. Enable them in Settings to schedule an alarm.")
        return
      }
      let seconds =
        rapid
        ? 10 : (notification.alertJulianDate - Date().julianDate - offset) * TimeConstants.day2sec
      guard seconds > 0 else {
        metric.finish("blocked", reason: "alert_time_passed")
        errorMessage = AppLocalization.text("This alert time has already passed.")
        return
      }
      let content = UNMutableNotificationContent()
      content.categoryIdentifier = "PASS"
      content.title = LocalizedStrings.Notification.title(passNotification: notification)
      content.body = LocalizedStrings.Notification.description(passNotification: notification)
      content.userInfo = [
        "satelliteCategory": notification.category.rawValue,
        "noradIndex": String(notification.pass.noradIndex),
        "passTime": String(Date(julianDate: notification.pass.culmination.julianDate).timeIntervalSince1970),
        "observer": try JSONEncoder().encode(notification.observer),
      ]
      // Attachment failure must not prevent an otherwise valid alarm.
      if let image = try? await NotificationPreview.render(
        notification, snapshots: snapshots, catalog: catalog), let data = image.pngData()
      {
        let url = notification.pass.attachmentImageURL(extension: "png")
        try? data.write(to: url, options: .atomic)
        if let attachment = try? UNNotificationAttachment(
          identifier: notification.pass.notificationIdentifier + "_attachment", url: url)
        {
          content.attachments = [attachment]
        }
      }
      try Task.checkCancellation()
      try await center.add(
        UNNotificationRequest(
          identifier: notification.pass.notificationIdentifier, content: content,
          trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)))
      revision += 1
      scheduled.update(
        with: ScheduledPassNotification(
          id: notification.pass.notificationIdentifier, notification: notification))
      persist()
      metric.finish("success")
      AppAnalytics.event("alarm_scheduled", screen: source)
    } catch is CancellationError {} catch {
      metric.finish("failure", reason: "scheduling_failed")
      errorMessage = error.localizedDescription
    }
  }
}
