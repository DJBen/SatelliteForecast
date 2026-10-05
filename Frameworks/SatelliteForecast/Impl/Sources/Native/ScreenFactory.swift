import SatelliteForecast
import SatelliteKit
import SwiftUI

/// Application composition uses ordinary initializers and typed view-building closures.
@MainActor
public struct ScreenFactory {
  public let session: AppSession
  public init(session: AppSession) { self.session = session }
  public func background<L: View, A: View>(_ context: BackgroundSkyViewContext<L, A>)
    -> BackgroundSkyView<L, A>
  {
    BackgroundSkyView(
      viewModel: BackgroundSkyModel(catalog: session.catalog, renderer: session.renderer),
      context: context)
  }
  public func sky<L: View, A: View>(_ context: SkyChartContext<L, A>) -> SkyChart<L, A> {
    SkyChart(
      viewModel: SkyChartModel(
        state: .init(julianDateOffset: session.debug.config.effectiveOffset),
        renderer: session.renderer), context: context,
      backgroundSkyViewFactory: ViewFactory { background($0) })
  }
  public func passes(_ context: AllPassesViewContext, category: SatelliteCategory = .iss)
    -> AllPassesView
  {
    AllPassesView(
      viewModel: PassListModel(
        state: .init(satelliteCategory: category), session: session, service: session.orbits),
      context: context, skyChartFactory: ViewFactory { sky($0) },
      passViewFactory: ViewFactory { pass($0) })
  }
  public func detail(_ context: SingleSatelliteWrappingViewContext) -> SingleSatelliteWrappingView {
    SingleSatelliteWrappingView(
      viewModel: SatelliteDetailModel(service: session.orbits), context: context,
      allPassesViewFactory: ViewFactory {
        passes($0, category: context.selectedNoradIndex == 25544 ? .iss : .tianhe)
      })
  }
  public func list(_ context: SatelliteListViewContext) -> SatelliteListView {
    SatelliteListView(
      viewModel: SatelliteListModel(service: session.orbits), context: context,
      allPassesViewFactory: ViewFactory { passes($0, category: context.category) })
  }
  public func pass(_ context: PassViewContext, isCompassEnabled: Bool? = nil) -> PassView {
    let model = PassModel(session: session)
    return PassView(
      viewModel: model, context: context,
      skyChartFactory: ViewFactory { sky($0) },
      passAlarmSettingsFactory: ViewFactory {
        PassAlarmSettingsModalView(
          viewModel: PassAlarmModel(
            session: session), context: $0)
      },
      detailedPassViewFactory: ViewFactory {
        DetailedPassView(
          context: $0, skyChartFactory: ViewFactory { sky($0) })
      }, isCompassEnabled: isCompassEnabled)
  }
}

public struct NativeForecastView: SatelliteOverviewView {
  let session: AppSession
  let context: SatelliteOverviewViewContext
  @State private var model: ForecastModel
  public init(session: AppSession, context: SatelliteOverviewViewContext, model: ForecastModel? = nil) {
    self.session = session
    self.context = context
    _model = State(initialValue: model ?? ForecastModel(client: .live(service: ForecastService(brightStars: session.catalog.stars(maximumMagnitude: 3)))))
  }
  public var body: some View {
    ObservationHomeView(session: session, model: model, context: context)
  }
}

public struct NativeSettingsView: SettingsOverviewView {
  let session: AppSession
  public init(session: AppSession) { self.session = session }
  public var body: some View {
    SettingsOverviewViewImpl(
      settings: session.settings,
      watchOnboardingAgain: { session.debug.send(.resetOnboarding) },
      observerCellViewFactory: { ObserverCell(resources: session.location.resources) },
      locationSettingsViewFactory: {
        LocationSettingsView(
          state: .init(
            locationSelection: session.location.resources.selection,
            currentLocation: session.location.resources.currentLocation,
            currentLocationPlacemark: session.location.resources.currentLocationPlacemark),
          selectLocation: { session.location.select($0) },
          requestCurrentLocation: { session.location.useCurrentLocation() })
      })
  }
}

/// A dedicated tab sharing the same notification service and pass editor as pass details.
public struct NativeAlarmsView: View {
  let session: AppSession
  @Environment(\.scenePhase) private var scenePhase
  public init(session: AppSession) { self.session = session }
  public var body: some View {
    NavigationStack {
      AlarmSettingsView(
        notifications: Array(session.notifications.scheduled),
        deleteNotifications: { session.notifications.cancel(Array($0)) },
        choosePass: {
          session.navigation.tab = .forecast
          session.navigation.forecastPath = NavigationPath()
          session.navigation.forecastPath.append(ForecastRoute.allPasses)
        },
        alarmEditor: { alarm in
          PassAlarmSettingsModalView(viewModel: PassAlarmModel(session: session),
            context: .init(notification: alarm.notification))
        },
        authorizationStatus: session.notifications.hasLoadedAuthorization ? session.notifications.authorizationStatus : nil,
        isRequestingAuthorization: session.notifications.isRequestingAuthorization,
        enableNotifications: { Task { _ = await session.enableStationReminders(fromAlarms: true) } },
        openNotificationSettings: {
          if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
        })
    }
    .task { await session.refreshNotifications() }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { Task { await session.refreshNotifications() } }
    }
  }
}
