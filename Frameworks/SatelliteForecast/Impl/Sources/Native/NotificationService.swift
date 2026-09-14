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
  public func cancel(_ ids: [String]) {
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
    offset: Double = 0, rapid: Bool = false
  ) async {
    do {
      guard try await center.requestAuthorization(options: [.alert, .sound, .badge]) else {
        errorMessage = "Notifications are disabled. Enable them in Settings to schedule an alarm."
        return
      }
      let seconds =
        rapid
        ? 10 : (notification.alertJulianDate - Date().julianDate - offset) * TimeConstants.day2sec
      guard seconds > 0 else {
        errorMessage = "This alert time has already passed."
        return
      }
      let content = UNMutableNotificationContent()
      content.categoryIdentifier = "PASS"
      content.title = LocalizedStrings.Notification.title(passNotification: notification)
      content.body = LocalizedStrings.Notification.description(passNotification: notification)
      content.userInfo = [
        "satelliteCategory": notification.category.rawValue,
        "noradIndex": String(notification.pass.noradIndex),
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
    } catch is CancellationError {} catch { errorMessage = error.localizedDescription }
  }
}
