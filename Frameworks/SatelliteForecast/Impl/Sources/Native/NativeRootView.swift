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
      DeepLinkView(session: session, link: link)
    }
    .alert(
      "Unable to schedule alarm",
      isPresented: Binding(
        get: { session.notifications.errorMessage != nil },
        set: { if !$0 { session.notifications.errorMessage = nil } })
    ) {
      Button("OK") { session.notifications.errorMessage = nil }
    } message: {
      Text(session.notifications.errorMessage ?? "")
    }
  }
}

private struct DeepLinkView: View {
  let session: AppSession
  let link: SatelliteDeepLink
  @State private var info: SatelliteInfo?
  @State private var error: String?
  @State private var attempt = 0
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      Group {
        if let info {
          ScreenFactory(session: session).passes(
            .init(
              satelliteInfo: info,
              julianDateRange: JulianDateUtil.createJulianDateRange(
                now: Date().julianDate + session.debug.config.effectiveOffset),
              observer: link.observer, starManager: session.catalog,
              julianDateProvider: { Date().julianDate }), category: link.category)
        } else if let error {
          ContentUnavailableView {
            Label("Unable to load satellite", systemImage: "exclamationmark.triangle")
          } description: {
            Text(error)
          } actions: {
            Button("Retry") { attempt += 1 }
          }
        } else {
          ProgressView()
        }
      }
      .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
    }
    .task(id: attempt) {
      do {
        let satellites = try await session.orbits.satellites(link.category)
        try Task.checkCancellation()
        guard let found = satellites.first(where: { $0.noradIndex == link.noradIndex }) else {
          throw ForecastServiceError.missingSatellite(link.noradIndex)
        }
        info = found
      } catch is CancellationError {} catch { self.error = error.localizedDescription }
    }
  }
}
