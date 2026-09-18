import BTree
import Foundation
import Observation
import SatelliteForecast
import SatelliteKit
import SwiftUI

@MainActor @Observable
public final class SatelliteDetailModel {
  public var state: SingleSatelliteWrappingViewState
  private let service: OrbitalService
  @ObservationIgnored private var task: Task<Void, Never>?
  public init(
    state: SingleSatelliteWrappingViewState = .init(), service: OrbitalService = OrbitalService()
  ) {
    self.state = state
    self.service = service
  }
  public func send(_ action: SingleSatelliteWrappingViewAction) {
    switch action {
    case .loadSingleSatellite(let params):
      let category: SatelliteCategory = params.selectedNoradIndex == 25544 ? .iss : .tianhe
      task?.cancel()
      state.elementsLoader.info[category] = .loading
      task = Task { [weak self, service] in
        let metric = AppAnalytics.Operation("load_station", screen: .passes)
        defer { metric.finish("cancelled") }
        do {
          let info = try await service.satellites(category)
          try Task.checkCancellation()
          metric.finish(info.isEmpty ? "empty" : "success", count: info.count)
          self?.state.elementsLoader.info[category] = .loaded(
            info.reduce(into: Map<UInt, SatelliteInfo>()) { $0[$1.noradIndex] = $1 })
        } catch {
          if !Task.isCancelled && !(error is CancellationError) {
            metric.finish("failure", reason: "load_failed")
            self?.state.elementsLoader.info[category] = .failed(.wrapError(error))
          }
        }
      }
    }
  }
  public func cancel() { task?.cancel() }
  deinit { task?.cancel() }
}

@MainActor @Observable
public final class PassListModel {
  private var local: AllPassesViewState
  private let session: AppSession?
  private let service: OrbitalService
  @ObservationIgnored private var task: Task<Void, Never>?
  @ObservationIgnored private let load:
    @MainActor (CalculatePassesParams) async throws -> SatelliteTrails
  private var lastRequest: CalculatePassesParams?
  public var errorMessage: String?
  public var state: AllPassesViewState {
    get {
      var value = local
      if let session {
        value.scheduledPassNotifications = session.notifications.scheduled
        value.location = session.location.resources.location
        value.placemark = session.location.resources.placemark
        value.julianDateOffset = session.debug.config.effectiveOffset
      }
      return value
    }
    set { local = newValue }
  }
  public init(
    state: AllPassesViewState = .init(), session: AppSession? = nil,
    service: OrbitalService = OrbitalService(),
    load: (@MainActor (CalculatePassesParams) async throws -> SatelliteTrails)? = nil
  ) {
    self.local = state
    self.session = session
    self.service = service
    self.load =
      load ?? {
        try await service.trails(
          info: $0.satelliteInfo, observer: $0.observer, range: $0.julianDateRange)
      }
  }
  public func send(_ action: AllPassesViewAction) {
    switch action {
    case .calculatePasses(let params), .recalculatePasses(let params):
      if case .calculatePasses = action, lastRequest == params,
        local.satelliteTrails[params.selectedNoradIndex]?.passSnapshots != nil
      {
        return
      }
      lastRequest = params
      task?.cancel()
      errorMessage = nil
      local.satelliteTrails = [:]
      task = Task { [weak self, load] in
        let metric = AppAnalytics.Operation("calculate_passes", screen: .passes)
        defer { metric.finish("cancelled") }
        do {
          let trails = try await load(params)
          try Task.checkCancellation()
          let count = trails.passSnapshots?.count ?? 0
          metric.finish(count == 0 ? "empty" : "success", count: count)
          self?.local.satelliteTrails = [params.selectedNoradIndex: trails]
        } catch {
          if !Task.isCancelled && !(error is CancellationError) {
            metric.finish("failure", reason: "calculation_failed")
            self?.errorMessage = error.localizedDescription
          }
        }
      }
    case .scheduleNotification(let notification, let snapshots):
      session?.schedule(notification, snapshots: snapshots)
    case .unscheduleNotification(let pass):
      session?.notifications.cancel([pass.notificationIdentifier])
    case .deeplinkToLocationSelection: session?.navigation.tab = .settings
    case .showLocationSettings:
      UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
    case .showOnboarding(let value): local.showsOnboarding = value
    case .completeOnboarding:
      UserDefaults.standard.set(true, forKey: "hasCompletedAllPassesOnboarding")
      local.showsOnboarding = false
    }
  }
  public func cancel() { task?.cancel() }
  deinit { task?.cancel() }
}

@MainActor @Observable
public final class PassModel {
  private var local: PassViewState
  public let session: AppSession?
  public var state: PassViewState {
    get {
      var value = local
      if let session { value.scheduledPassNotifications = session.notifications.scheduled }
      return value
    }
    set { local = newValue }
  }
  public init(state: PassViewState = .init(), session: AppSession? = nil) {
    local = state
    self.session = session
  }
  public func send(_ action: PassViewAction) {
    switch action {
    case .showAlarmConfiguration(let value): local.showAlarmConfigurationModal = value
    case .showDetailPassView(let value): local.showsDetailPassView = value
    case .unscheduleAlarm(let pass): session?.notifications.cancel([pass.notificationIdentifier])
    }
  }
}

@MainActor @Observable
public final class PassAlarmModel {
  private var local: PassAlarmSettingsModalViewState
  private let session: AppSession?
  public var state: PassAlarmSettingsModalViewState {
    var value = local
    if let session { value.scheduledPassNotifications = session.notifications.scheduled }
    return value
  }
  public init(
    state: PassAlarmSettingsModalViewState = .init(), session: AppSession? = nil
  ) {
    local = state
    self.session = session
  }
  public func send(_ action: PassAlarmSettingsModalViewAction) {
    switch action {
    case .dismissModal: break
    case .scheduleAlarm(let notification, let snapshots):
      session?.schedule(notification, snapshots: snapshots, fromAlarmSetup: true)
    case .unscheduleAlarm(let pass): session?.notifications.cancel([pass.notificationIdentifier])
    }
  }
}
