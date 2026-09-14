import Foundation
import Observation
import SatelliteForecast
import SatelliteKit

@MainActor @Observable
public final class DebugModel {
  public var config = DebugMenuConfig()
  public var fcmToken: String?
  public weak var session: AppSession?
  public var state: DebugMenuState? {
    .init(
      trueJulianDate: Date().julianDate, config: config,
      pendingNotifications: session?.notifications.pending ?? [],
      deliveredNotifications: session?.notifications.delivered ?? [], fcmToken: fcmToken)
  }
  public init(state: DebugMenuState? = nil) {
    if let state {
      config = state.config
      fcmToken = state.fcmToken
    }
  }
  public func send(_ action: DebugMenuAction) {
    let now = Date().julianDate
    switch action {
    case .toggleDebugMenu(let value): config.isDebugMenuVisible = value
    case .toggleFreezeTime(let value): config.frozenAt = value ? now + config.effectiveOffset : nil
    case .toggleMockedOffset(let value): config.mockedOffsetOn = value
    case .setMockedDateOffset(let value): config.mockedOffset = value
    case .toggleRapidNotificationDelivery(let value): config.rapidNotificationDelivery = value
    case .fetchNotifications: Task { await session?.notifications.refresh() }
    case .triggerPassDeepLink(let category, let id):
      config.isDebugMenuVisible = false
      if let observer = session?.location.resources.location.map(LatLonAlt.init) {
        session?.open(category, id: id, observer: observer)
      }
    case .resetOnboarding, .resetMainOnboarding:
      UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
      session?.hasCompletedOnboarding = false
      if case .resetOnboarding = action {
        UserDefaults.standard.set(false, forKey: "hasCompletedAllPassesOnboarding")
      }
    case .resetAllPassesOnboarding:
      UserDefaults.standard.set(false, forKey: "hasCompletedAllPassesOnboarding")
    }
  }
}
