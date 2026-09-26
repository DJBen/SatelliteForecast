import SwiftUI
import SatelliteForecast
import SatelliteKit

/// The ISS and Tiangong video cards from the original overview, now heading the
/// Satellites tab. They share the home forecast model so passes load once.
struct NativeStationCards: View {
  let session: AppSession
  let model: ForecastModel
  let context: SatelliteCategoryViewContext
  @Environment(\.locale) private var locale

  private var input: ForecastInput {
    .init(observer: session.location.resources.location.map(LatLonAlt.init),
      julianDateOffset: session.debug.config.effectiveOffset,
      authorizationStatus: session.location.resources.authorizationStatus)
  }

  var body: some View {
    LazyVStack(alignment: .leading, spacing: 20) {
      ForEach(SatelliteOverviewViewImpl.stationOrder(for: locale), id: \.self) { satellite in
        NavigationLink(value: SpecialSatellite(satellite)) {
          SatelliteOverviewCell(
            satellite: satellite,
            nextPassLoadingState: satellite == .iss ? model.issNextPass : model.tianheNextPass,
            currentDate: model.currentDate,
            julianDateOffset: input.julianDateOffset,
            isMissingLocation: input.isMissingLocation,
            locationLabel: SatelliteLocationLabel(
              julianDateProvider: context.julianDateProvider,
              julianDateOffset: input.julianDateOffset,
              loadSatellite: { try await model.satelliteInfo(for: satellite == .iss ? .iss : .tianhe) }))
        }
        .buttonStyle(.plain)
        .id(satellite.rawValue)
        .animation(.easeInOut(duration: 0.3), value: model.currentDate)
      }
    }
    // The Passes tab normally loads first; cover the case where this tab is opened before it.
    .task(id: input) { if !model.hasRefreshed { await model.refresh(input) } }
  }

  /// The station detail pushed from a card; registered by the category view on its stack.
  func destination(_ station: SpecialSatellite) -> some View {
    ScreenFactory(session: session).detail(.init(selectedNoradIndex: station.rawValue,
      julianDateRange: JulianDateUtil.createJulianDateRange(
        now: context.julianDateProvider() + input.julianDateOffset),
      observer: input.observer, starManager: context.starManager,
      julianDateProvider: context.julianDateProvider))
  }
}
