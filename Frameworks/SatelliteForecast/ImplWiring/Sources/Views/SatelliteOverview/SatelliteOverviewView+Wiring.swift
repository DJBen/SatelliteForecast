//
//  SatelliteOverviewView+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/6/22.
//

@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
@preconcurrency import SatelliteKit
import Foundation
import SatelliteForecast
import SatelliteForecastImpl

private func nextPass(_ satellite: SpecialSatellite, appState: AppState) -> Loadable<NextPass, Error> {
    let currentJulianDate = Date().julianDate + appState.debugMenu.effectiveOffset
    if let loadable = appState.elementsLoader.info[satellite.category] {
        if case .failed(let error) = loadable {
            return .failed(error)
        } else if case .loading = loadable {
            return .loading
        } else if case .loaded(_) = loadable {
            if let passSnapshots = appState.elementsPropagatorResources.satelliteTrails[satellite.rawValue] {
                return .loaded(
                    NextPass(
                        nextVisiblePass: passSnapshots.nextVisiblePass(currentJulianDate: currentJulianDate),
                        nextProminentPass: passSnapshots.nextProminentPass(currentJulianDate: currentJulianDate)
                    )
                )
            } else {
                return .loading
            }
        } else {
            return .notLoaded
        }
    } else {
        return .notLoaded
    }
}

extension SatelliteOverviewViewState: AppStateMappable {
    public static func project(appState: AppState) -> SatelliteOverviewViewState {
        SatelliteOverviewViewState(
            navigationState: appState.navigationState,
            observer: appState.locationResources.location.map(LatLonAlt.init),
            julianDateOffset: appState.debugMenu.effectiveOffset,
            issNextPass: nextPass(.iss, appState: appState),
            tianheNextPass: nextPass(.tianhe, appState: appState),
            authorizationStatus: appState.locationResources.authorizationStatus,
        )
    }

    public static func apply(appState: inout AppState, state: SatelliteOverviewViewState) {
        appState.navigationState = state.navigationState
    }
}

extension ViewProducer where Context == SatelliteOverviewViewContext, ProducedView == SatelliteOverviewViewImpl {
    public static func satelliteOverview<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            SatelliteOverviewViewImpl(
                viewModel: viewModel.projection(
                    action: AppAction.satelliteOverview,
                    state: SatelliteOverviewViewState.project(appState:)
                )
                .asObservableViewModel(initialState: .init(), emitsValue: .whenDifferent),
                context: context,
                singleSatelliteWrappingViewProducer: ViewProducer<SingleSatelliteWrappingViewContext, SingleSatelliteWrappingView>.singleSatelliteWrappingView(viewModel: viewModel)
            )
        }
    }
}
