//
//  SatelliteOverviewView+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/6/22.
//

import CombineRex
import CombineRextensions
import SatelliteKit
import SatelliteForecastImpl

extension SatelliteOverviewViewState: AppStateMappable {
    static func project(appState: AppState) -> SatelliteOverviewViewState {
        SatelliteOverviewViewState(
            selectedSatelliteOverviewItem: appState.navigationState.selectedSatelliteOverviewItem,
            observer: appState.locationResources.location.map(LatLonAlt.init),
            julianDateOffset: appState.debugMenu.effectiveOffset
        )
    }

    static func apply(appState: inout AppState, state: SatelliteOverviewViewState) {
        appState.navigationState.selectedSatelliteOverviewItem = state.selectedSatelliteOverviewItem
    }
}

extension ViewProducer where Context == SatelliteOverviewViewContext, ProducedView == SatelliteOverviewViewImpl {
    static func satelliteOverview<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            SatelliteOverviewViewImpl(
                viewModel: viewModel.projection(
                    action: AppAction.satelliteOverview,
                    state: SatelliteOverviewViewState.project(appState:)
                )
                .asObservableViewModel(initialState: .init(), emitsValue: .whenDifferent),
                context: context,
                listViewProducer: ViewProducer<SatelliteListViewContext, SatelliteListView>
                    .satelliteListView(viewModel: viewModel),
                singleSatelliteWrappingViewProducer: ViewProducer<SingleSatelliteWrappingViewContext, SingleSatelliteWrappingView>.singleSatelliteWrappingView(viewModel: viewModel)
            )
        }
    }
}

extension NavigationState {
    fileprivate var selectedSatelliteOverviewItem: SatelliteOverviewItem? {
        get {
            if let specialNoradIndex = specialSatelliteNavigation.noradIndex {
                return .specialSatellites(SatelliteOverviewItem.SatellitesOfSpecialInterest(rawValue: specialNoradIndex)!)
            } else if let category = listNavigation.category {
                return .category(category)
            } else {
                return nil
            }
        }

        set {
            switch newValue {
            case .specialSatellites(let specialSatellite):
                self.listNavigation = .init()
                self.specialSatelliteNavigation.noradIndex = specialSatellite.rawValue
            case .category(let category):
                self.listNavigation = .init(category: category, noradIndex: nil, selectedPassIndex: nil)
                self.specialSatelliteNavigation = .init()
            case .none:
                self.listNavigation = .init()
                self.specialSatelliteNavigation = .init()
            }
        }
    }
}
