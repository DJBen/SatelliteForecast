import AppDelegate
import BackgroundTasks
import FirebaseFirestore
import Foundation
import Geohash
import Observation
import SatelliteForecast
import SatelliteKit
import SwiftUI

@MainActor @Observable
public final class AppNavigation {
  public var tab: SatelliteForecast.Tab = .forecast
  public var forecastPath = NavigationPath()
  public var satelliteCategoryNavigationPath = NavigationPath()
  public var deepLink: SatelliteDeepLink?
  public init() {}
}
@MainActor @Observable
public final class AppSession {
  public let location: LocationService
  public let notifications: NotificationService
  public let liveActivity = StationLiveActivityService()
  public let navigation = AppNavigation()
  public let settings = AppSettings()
  public let debug = DebugModel()
  public let catalog: AppStarCatalog
  public let orbits = OrbitalService()
  // Live-sky catalog/propagation must not queue in front of pass-detail requests.
  let skyOrbits = OrbitalService()
  public let renderer = ChartRenderer()
  public var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
  @ObservationIgnored private var alarmTasks: [UUID: Task<Void, Never>] = [:]
  public init(
    catalog: AppStarCatalog, location: LocationService? = nil,
    notifications: NotificationService? = nil
  ) {
    self.catalog = catalog
    self.location = location ?? LocationService()
    self.notifications = notifications ?? NotificationService()
    debug.session = self
    self.location.onLocationChanged = { [weak self] _ in
      guard let self else { return }
      Task { await self.liveActivity.invalidateIfMoved(to: self.location.resources.location) }
      if let token = debug.fcmToken { updateRegistration(token) }
    }
  }
  public func completeOnboarding() {
    AppAnalytics.event("onboarding_completed", screen: .onboarding)
    hasCompletedOnboarding = true
    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
  }
  public func schedule(_ notification: PassNotification, snapshots: PassSnapshots, fromAlarmSetup: Bool = false) {
    let id = UUID()
    alarmTasks[id] = Task { [weak self] in
      guard let self else { return }
      await notifications.schedule(
        notification, snapshots: snapshots, catalog: catalog, offset: debug.config.effectiveOffset,
        rapid: debug.config.rapidNotificationDelivery, fromAlarmSetup: fromAlarmSetup)
      alarmTasks[id] = nil
    }
  }
  /// Asks for notification permission and, once granted, registers this device for ISS and
  /// Tiangong push reminders. The backend delivers reminders to every registered device.
  public func enableStationReminders() async -> Bool {
    let granted = await notifications.enableStationReminders()
    if granted, let token = debug.fcmToken { updateRegistration(token) }
    return granted
  }
  public func handle(_ event: AppDelegateAction) {
    switch event {
    case .didFinishLaunchingWithOptions:
      notifications.register()
      BGTaskScheduler.shared.register(forTaskWithIdentifier: "calculateUpcomingPasses", using: nil)
      { $0.setTaskCompleted(success: true) }
      Task { await notifications.refresh() }
    case .didRegisterForRemoteNotificationsWithDeviceToken: break
    case .didReceiveFCMToken(let token):
      debug.fcmToken = token
      updateRegistration(token)
    case .scenePhaseDidChange(_, let phase):
      if phase == .active { Task { await notifications.refresh() } }
      if phase == .background {
        notifications.persist()
        let request = BGProcessingTaskRequest(identifier: "calculateUpcomingPasses")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60)
        request.requiresNetworkConnectivity = true
        try? BGTaskScheduler.shared.submit(request)
      }
    }
  }
  public func open(_ category: SatelliteCategory, id: UInt, observer: LatLonAlt, passTime: Date? = nil, fromNotification: Bool = true) {
    if fromNotification { AppAnalytics.event("notification_opened", screen: .passes) }
    navigation.tab = category == .iss || category == .tianhe ? .forecast : .satellites
    navigation.deepLink = SatelliteDeepLink(category: category, noradIndex: id, observer: observer, passTime: passTime)
  }
  /// Writes the push registration only after the user has allowed notifications, so a device
  /// is never subscribed to station reminders it cannot receive.
  private func updateRegistration(_ token: String) {
    Task { [weak self] in
      guard let self, await notifications.checkAuthorization() else { return }
      writeRegistration(token)
    }
  }
  private func writeRegistration(_ token: String) {
    // Real Debug devices receive reminders; automated tests and previews never register.
    let environment = ProcessInfo.processInfo.environment
    guard environment["SATELLITE_SNAPSHOT_TESTS"] != "1",
          environment["XCTestConfigurationFilePath"] == nil,
          environment["XCTestBundlePath"] == nil,
          environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1",
          NSClassFromString("XCTestCase") == nil else { return }
    #if targetEnvironment(simulator)
      return
    #else
      let device = UIDevice.current
      var data: [String: Any] = [
        "deviceModel": device.machineName, "osVersion": device.systemVersion,
        "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
          ?? "unknown", "lastAppLaunch": Timestamp(date: Date()),
        "tzOffset": TimeZone.current.secondsFromGMT(), "locale": Locale.current.identifier,
      ]
      #if DEBUG
        data["appVariant"] = "debug"
      #else
        data["appVariant"] = "release"
      #endif
      if let location = location.resources.currentLocation {
        data["lat"] = location.coordinate.latitude
        data["lon"] = location.coordinate.longitude
        data["alt"] = location.altitude
        data["geoHash5"] = Geohash.encode(
          latitude: location.coordinate.latitude, longitude: location.coordinate.longitude,
          length: 5)
      }
      Firestore.firestore().collection("users").document(token).setData(data, merge: true)
    #endif
  }
}
