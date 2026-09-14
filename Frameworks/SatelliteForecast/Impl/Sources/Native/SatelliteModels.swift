import BTree
import Foundation
import Observation
import SatelliteForecast
import SatelliteKit
import SwiftUI

@MainActor @Observable
public final class SatelliteCategoryModel {
  private var local: SatelliteCategoryViewState
  private let session: AppSession?
  public var state: SatelliteCategoryViewState {
    get {
      guard let session else { return local }
      return .init(
        navigationPath: session.navigation.satelliteCategoryNavigationPath,
        observer: session.location.resources.location.map(LatLonAlt.init),
        julianDateOffset: session.debug.config.effectiveOffset)
    }
    set {
      local = newValue
      session?.navigation.satelliteCategoryNavigationPath = newValue.navigationPath
    }
  }
  public init(state: SatelliteCategoryViewState = .init(), session: AppSession? = nil) {
    local = state
    self.session = session
  }
  public func send(_ action: SatelliteCategoryViewAction) {
    if case .navigate(let path) = action { state.navigationPath = path }
  }
}

@MainActor @Observable
public final class SatelliteListModel {
  public var state: SatelliteListViewState
  private let service: OrbitalService
  @ObservationIgnored private var task: Task<Void, Never>?
  @ObservationIgnored private var searchTask: Task<Void, Never>?
  private var query = ""
  public init(state: SatelliteListViewState = .init(), service: OrbitalService = OrbitalService()) {
    self.state = state
    self.service = service
  }
  public func load(_ category: SatelliteCategory, force: Bool = false) {
    task?.cancel()
    state.satelliteInfo[category] = .loading
    task = Task { [weak self, service] in
      do {
        let info = try await service.satellites(category, force: force)
        try Task.checkCancellation()
        self?.state.satelliteInfo[category] = .loaded(
          info.reduce(into: Map<UInt, SatelliteInfo>()) { $0[$1.noradIndex] = $1 })
        self?.filter(category)
      } catch {
        if !Task.isCancelled { self?.state.satelliteInfo[category] = .failed(.wrapError(error)) }
      }
    }
  }
  public func send(_ action: SatelliteListViewAction) {
    switch action {
    case .retryLoadingSatelliteList(let category): load(category, force: true)
    case .searchSatellites(let text, let category):
      query = text
      filter(category)
    case .loadSatellite, .selectSatellite: break  // Destination owns its prediction task.
    }
  }
  private func filter(_ category: SatelliteCategory) {
    searchTask?.cancel()
    let text = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !text.isEmpty else {
      state.filteredSatellites = nil
      return
    }
    let values = state.satelliteInfo[category]?.content.map { Array($0.values) } ?? []
    searchTask = Task { [weak self, service] in
      do {
        let filtered = try await service.search(values, text: text)
        try Task.checkCancellation()
        self?.state.filteredSatellites = filtered.reduce(into: Map<UInt, SatelliteInfo>()) {
          $0[$1.noradIndex] = $1
        }
      } catch {}
    }
  }
  public func cancel() {
    task?.cancel()
    searchTask?.cancel()
  }
  deinit {
    task?.cancel()
    searchTask?.cancel()
  }

}

@MainActor @Observable
public final class RealtimeSkyModel {
  private var local: RealtimeSkyViewState
  private let session: AppSession?
  private let service: OrbitalService
  @ObservationIgnored private var loadTask: Task<Void, Never>?
  @ObservationIgnored private var predictionTask: Task<Void, Never>?
  private var lastObserver: LatLonAlt?
  private var lastDate: Double?
  private var predictionGeneration = 0
  @ObservationIgnored private let predict:
    @MainActor ([SatelliteInfo], LatLonAlt, Double) async throws -> [RealtimePropagationResult]
  public var state: RealtimeSkyViewState {
    get {
      var value = local
      if let session {
        value.observer = session.location.resources.location.map(LatLonAlt.init)
        value.julianDateOffset = session.debug.config.effectiveOffset
      }
      return value
    }
    set { local = newValue }
  }
  public init(
    state: RealtimeSkyViewState = .init(), session: AppSession? = nil,
    service: OrbitalService = OrbitalService(),
    predict: (
      @MainActor ([SatelliteInfo], LatLonAlt, Double) async throws -> [RealtimePropagationResult]
    )? = nil
  ) {
    local = state
    self.session = session
    self.service = service
    self.predict = predict ?? { try await service.realtime(satellites: $0, observer: $1, date: $2) }
  }
  public func send(_ action: RealtimeSkyViewAction) {
    switch action {
    case .loadElements:
      loadTask?.cancel()
      local.satellites = .loading
      loadTask = Task { [weak self, service] in
        do {
          let found = try await service.satellites(.active)
          try Task.checkCancellation()
          self?.local.satellites = .loaded(found.filter { $0.elements.orbitTypeByAltitude == .leo })
        } catch { if !Task.isCancelled { self?.local.satellites = .failed(.wrapError(error)) } }
      }
    case .setRealtimeSkyViewActive(let active):
      local.resources.isRealtimeSkyViewActive = active
      if active { send(.loadElements) } else { cancel() }
    case .purgeElements:
      predictionGeneration += 1
      predictionTask?.cancel()
      local.resources.isPropagatingEphemerides = false
      local.resources.results = .init()
      local.resources.displayResults = []
    case .propagateCurrentEphemerides(let satellites, let observer, let date):
      if lastObserver != observer
        || lastDate.map({ date < $0 || date - $0 > 60 * TimeConstants.sec2day }) == true
      {
        send(.purgeElements)
        lastObserver = observer
      }
      guard !local.resources.isPropagatingEphemerides else { return }
      lastDate = date
      let generation = predictionGeneration
      let candidates =
        local.resources.results.isEmpty
        ? satellites : local.resources.results.prefix(upTo: date).map(\.1.satelliteInfo)
      local.resources.isPropagatingEphemerides = true
      predictionTask = Task { [weak self, predict] in
        defer {
          if self?.predictionGeneration == generation {
            self?.local.resources.isPropagatingEphemerides = false
          }
        }
        do {
          let results = try await predict(candidates, observer, date)
          try Task.checkCancellation()
          guard let self, predictionGeneration == generation,
            state.observer == nil || state.observer == observer
          else { return }
          local.resources.results = local.resources.results.suffix(from: date)
          for result in results {
            local.resources.results.insert((result.nextCheckJulianDate, result))
          }
          local.resources.displayResults = local.resources.results.map(\.1).filter {
            $0.snapshot.position.elev > 5
          }
        } catch {}
      }
    }
  }
  public func cancel() {
    loadTask?.cancel()
    predictionTask?.cancel()
    predictionGeneration += 1
    local.resources.isPropagatingEphemerides = false
  }
  deinit {
    loadTask?.cancel()
    predictionTask?.cancel()
  }
}
