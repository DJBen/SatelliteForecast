import SwiftUI
@preconcurrency import CombineRex
import CombineRextensions
import SatelliteKit
import SatelliteForecast
import SatelliteForecastImpl

extension SatelliteOverviewViewState: AppStateMappable {
    public static func project(appState: AppState) -> SatelliteOverviewViewState {
        .init(navigationState: appState.navigationState,
              observer: appState.locationResources.location.map(LatLonAlt.init),
              julianDateOffset: appState.debugMenu.effectiveOffset,
              authorizationStatus: appState.locationResources.authorizationStatus)
    }
    public static func apply(appState: inout AppState, state: SatelliteOverviewViewState) {
        appState.navigationState = state.navigationState
    }
}

/// Navigation and shared location are the only legacy inputs. Forecast loading,
/// errors, countdowns and cancellation belong to the native feature model.
public struct LegacyForecastView: SatelliteOverviewView {
    @ObservedObject var routing: ObservableViewModel<SatelliteOverviewViewAction, SatelliteOverviewViewState>
    @State private var model: ForecastModel
    let context: SatelliteOverviewViewContext
    let destination: ViewProducer<SingleSatelliteWrappingViewContext, SingleSatelliteWrappingView>

    init(routing: ObservableViewModel<SatelliteOverviewViewAction, SatelliteOverviewViewState>,
         context: SatelliteOverviewViewContext,
         destination: ViewProducer<SingleSatelliteWrappingViewContext, SingleSatelliteWrappingView>) {
        self.routing = routing
        self.context = context
        self.destination = destination
        let service = ForecastService()
        _model = State(initialValue: ForecastModel(client: .init(
            load: { try await service.passes(for: $0, request: $1) },
            now: { Date(julianDate: context.julianDateProvider()) })))
    }

    public var body: some View {
        SatelliteOverviewViewImpl(model: model,
            input: .init(observer: routing.state.observer, julianDateOffset: routing.state.julianDateOffset,
                         authorizationStatus: routing.state.authorizationStatus),
            navigationPath: Binding(get: { routing.state.navigationState.passPredictionNavigationPath },
                                    set: { routing.dispatch(.navigate($0)) }),
            context: context, singleSatelliteWrappingViewProducer: { destination.view($0) })
    }
}

extension ViewProducer where Context == SatelliteOverviewViewContext, ProducedView == LegacyForecastView {
    public static func satelliteOverview<S: StoreType>(viewModel: S) -> ViewProducer
    where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer { context in
            LegacyForecastView(routing: viewModel.projection(action: AppAction.satelliteOverview,
                state: SatelliteOverviewViewState.project(appState:))
                .asObservableViewModel(initialState: .init(), emitsValue: .whenDifferent),
                context: context, destination: .singleSatelliteWrappingView(viewModel: viewModel))
        }
    }
}
