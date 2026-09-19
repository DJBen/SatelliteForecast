import SatelliteForecast
import SatelliteKit
import SwiftUI

public struct NativeRootView: View {
  let session: AppSession
  public init(session: AppSession) { self.session = session }
  public var body: some View {
    let factory = ScreenFactory(session: session)
    RootView(
      selectedTab: Binding(get: { session.navigation.tab }, set: { session.navigation.tab = $0 }),
      settings: session.settings,
      context: RootViewContext(
        starManager: session.catalog, julianDateProvider: { Date().julianDate }),
      realtimeSkyViewFactory: {
        RealtimeSkyViewImpl(
          viewModel: RealtimeSkyModel(session: session, service: session.orbits), context: $0,
          backgroundSkyViewFactory: ViewFactory { factory.background($0) })
      },
      satelliteOverviewViewFactory: { NativeForecastView(session: session, context: $0) },
      satelliteCategoryViewFactory: {
        SatelliteCategoryViewImpl(
          viewModel: SatelliteCategoryModel(session: session), context: $0,
          listViewFactory: ViewFactory { factory.list($0) })
      },
      settingsOverviewFactory: { NativeSettingsView(session: session) }
    )
    .sheet(
      item: Binding(get: { session.navigation.deepLink }, set: { session.navigation.deepLink = $0 })
    ) { link in
      DeepLinkView(session: session, link: link).id(link.id)
    }
    .alert(
      AppLocalization.text("Unable to schedule alarm"),
      isPresented: Binding(
        get: { session.notifications.errorMessage != nil },
        set: { if !$0 { session.notifications.errorMessage = nil } })
    ) {
      Button(AppLocalization.text("OK")) { session.notifications.errorMessage = nil }
    } message: {
      Text(session.notifications.errorMessage ?? "")
    }
  }
}

struct DeepLinkView: View {
  let session: AppSession
  let link: SatelliteDeepLink
  @State private var info: SatelliteInfo?
  @State private var selectedPass: PassSnapshots?
  @State private var showAllPasses = false
  @State private var error: String?
  @State private var attempt = 0
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      Group {
        if let info, let selectedPass, !showAllPasses {
          ScreenFactory(session: session).pass(.init(
            passIndex: 0, satelliteInfo: info,
            satelliteCommonName: info.elements.commonName, category: link.category,
            julianDateRange: selectedPass.pass.rise.julianDate...selectedPass.pass.set.julianDate,
            observer: link.observer, passSnapshots: selectedPass,
            starManager: session.catalog, julianDateProvider: { Date().julianDate }))
        } else if let info, link.passTime == nil || showAllPasses {
          ScreenFactory(session: session).passes(
            .init(
              satelliteInfo: info,
              julianDateRange: JulianDateUtil.createJulianDateRange(
                now: Date().julianDate + session.debug.config.effectiveOffset),
              observer: link.observer, starManager: session.catalog,
              julianDateProvider: { Date().julianDate }), category: link.category)
        } else if let error {
          ContentUnavailableView {
            Label(AppLocalization.text("Unable to open pass"), systemImage: "exclamationmark.triangle")
          } description: {
            Text(error)
          } actions: {
            Button(AppLocalization.text("Retry")) { attempt += 1 }
            if info != nil { Button(AppLocalization.text("View all passes")) { showAllPasses = true } }
          }
        } else {
          ProgressView()
        }
      }
      .toolbar { ToolbarItem(placement: .cancellationAction) { Button(AppLocalization.text("Done")) { dismiss() } } }
    }
    .task(id: attempt) {
      error = nil
      do {
        let satellites = try await session.orbits.satellites(link.category)
        try Task.checkCancellation()
        guard let found = satellites.first(where: { $0.noradIndex == link.noradIndex }) else {
          throw ForecastServiceError.missingSatellite(link.noradIndex)
        }
        info = found
        if let time = link.passTime {
          let target = time.julianDate
          let trails = try await session.orbits.trails(info: found, observer: link.observer,
            range: (target - 45.0 / 1440)...(target + 45.0 / 1440))
          try Task.checkCancellation()
          guard let match = DeepLinkPassResolver.select(trails.passSnapshots ?? [], at: target) else {
            error = AppLocalization.text("This pass could not be found at the requested time. You can retry or view all passes.")
            return
          }
          selectedPass = match
        }
      } catch is CancellationError {} catch { self.error = error.localizedDescription }
    }
  }
}

/// Match only the requested orbit, allowing a small prediction drift as orbital data updates.
enum DeepLinkPassResolver {
  static func select(_ passes: [PassSnapshots], at time: Double) -> PassSnapshots? {
    passes.filter { contains(rise: $0.pass.rise.julianDate, set: $0.pass.set.julianDate, time: time) }
      .min { abs($0.pass.culmination.julianDate - time) < abs($1.pass.culmination.julianDate - time) }
  }
  static func contains(rise: Double, set: Double, time: Double) -> Bool {
    let tolerance = 5.0 / 1440
    return time.isFinite && rise.isFinite && set.isFinite && rise <= set
      && time >= rise - tolerance && time <= set + tolerance
  }
}
