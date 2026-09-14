import Foundation
import Observation
import SatelliteForecast
import SatelliteKit
import UIKit

@MainActor @Observable
public final class SkyChartModel {
  public var state: SkyChartViewState
  private let renderer: ChartRenderer
  @ObservationIgnored private var task: Task<Void, Never>?
  public init(state: SkyChartViewState = .init(), renderer: ChartRenderer = ChartRenderer()) {
    self.state = state
    self.renderer = renderer
  }
  public func send(_ action: SkyChartAction) {
    switch action {
    case .requestRasterizedSatellitePath(let size, let quality, let snapshots, let traits):
      task?.cancel()
      task = Task { [weak self, renderer] in
        do {
          let image = try await renderer.path(
            size: size, quality: quality, passSnapshots: snapshots, traitCollection: traits)
          try Task.checkCancellation()
          let key = SkyPathKey(pass: snapshots.pass, isDark: traits.userInterfaceStyle == .dark)
          self?.state.resources = .init()
          switch quality {
          case .preview: self?.state.resources.previewSatellitePaths = [key: image]
          case .full: self?.state.resources.rasterizedSatellitePaths = [key: image]
          case .detailed: self?.state.resources.detailedSatellitePaths = [key: image]
          case .onboarding: self?.state.resources.onboardingSatellitePaths = [key: image]
          }
        } catch {}
      }
    }
  }
  public func cancel() { task?.cancel() }
  deinit { task?.cancel() }
}

@MainActor @Observable
public final class BackgroundSkyModel {
  public var state: BackgroundSkyViewState
  private let catalog: AppStarCatalog?
  private let renderer: ChartRenderer
  @ObservationIgnored private var task: Task<Void, Never>?
  public init(
    state: BackgroundSkyViewState = .init(), catalog: AppStarCatalog? = nil,
    renderer: ChartRenderer = ChartRenderer()
  ) {
    self.state = state
    self.catalog = catalog
    self.renderer = renderer
    if let catalog { self.state.resources.allConstellations = Array(catalog.allConstellations()) }
  }
  public func send(_ action: BackgroundSkyViewAction) {
    guard let catalog else { return }
    switch action {
    case .requestRasterizedBackgroundSky(let size, let quality, let date, let key, let traits):
      task?.cancel()
      task = Task { [weak self, renderer] in
        do {
          let image = try await renderer.background(
            size: size, quality: quality, julianDate: date, key: key, traitCollection: traits,
            catalog: catalog)
          try Task.checkCancellation()
          self?.state.resources = .init(allConstellations: Array(catalog.allConstellations()))
          switch quality {
          case .preview: self?.state.resources.previewBackgroundSkies = [key: [date: image]]
          case .full: self?.state.resources.rasterizedBackgroundSky = [key: [date: image]]
          case .detailed: self?.state.resources.detailedBackgroundSkies = [key: [date: image]]
          case .onboarding: self?.state.resources.onboardingBackgroundSkies = [key: [date: image]]
          }
        } catch {}
      }
    }
  }
  public func cancel() { task?.cancel() }
  deinit { task?.cancel() }
}

@MainActor @Observable
public final class ElevationGraphModel {
  public var state: SatelliteElevationGraphState
  private let context: SatelliteElevationGraphContext?
  private let service: OrbitalService
  private let renderer: ChartRenderer
  @ObservationIgnored private var task: Task<Void, Never>?
  public init(
    state: SatelliteElevationGraphState = .init(), context: SatelliteElevationGraphContext? = nil,
    service: OrbitalService = OrbitalService(), renderer: ChartRenderer = ChartRenderer()
  ) {
    self.state = state
    self.context = context
    self.service = service
    self.renderer = renderer
  }
  public func send(_ action: SatelliteElevationGraphAction) {
    switch action {
    case .requestRasterizeElevationGraph(let size, let id, let range, let traits):
      guard let context else { return }
      task?.cancel()
      task = Task { [weak self, service, renderer] in
        do {
          let snapshots = try await service.snapshots(
            info: context.satelliteInfo, observer: context.observer, range: range)
          let image = try await renderer.elevation(
            size: size, snapshots: snapshots, range: range, traits: traits)
          try Task.checkCancellation()
          self?.state.elementsPropagatorResources.satelliteTrails = [
            id: SatelliteTrails(observer: context.observer, snapshots: snapshots)
          ]
          self?.state.satelliteElevationGraphResources.rasterizedElevationGraphs = [
            id: [.init(julianDateRange: range, image: image)]
          ]
        } catch {}
      }
    case .rasterizedElevationGraph: break
    }
  }
  public func cancel() { task?.cancel() }
  deinit { task?.cancel() }
}
