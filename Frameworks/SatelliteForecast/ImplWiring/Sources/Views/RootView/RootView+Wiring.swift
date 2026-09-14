//
//  RootView+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/5/22.
//

import SwiftUI
@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import SatelliteForecast
import SatelliteForecastImpl

extension RootViewState: AppStateMappable {
    public static func project(appState: AppState) -> RootViewState {
        RootViewState(
            selectedTab: appState.navigationState.tab
        )
    }

    public static func apply(appState: inout AppState, state: RootViewState) {
        appState.navigationState.tab = state.selectedTab
    }
}

/// Temporary adapter: only this boundary knows about the legacy tab action.
/// The native root view receives a Binding and ordinary view-building closures.
public struct LegacyRootView: View {
    @ObservedObject var tabs: ObservableViewModel<RootViewAction, RootViewState>
    let settings: AppSettings
    let context: RootViewContext
    let sky: ViewProducer<RealtimeSkyViewContext, RealtimeSkyViewImpl>
    let forecast: ViewProducer<SatelliteOverviewViewContext, LegacyForecastView>
    let satellites: ViewProducer<SatelliteCategoryViewContext, SatelliteCategoryViewImpl>
    let settingsView: ViewProducer<Void, LegacySettingsView>

    public var body: some View {
        RootView(
            selectedTab: Binding(get: { tabs.state.selectedTab }, set: { tabs.dispatch(.selectTab($0)) }),
            settings: settings,
            context: context,
            realtimeSkyViewProducer: { sky.view($0) },
            satelliteOverviewViewProducer: { forecast.view($0) },
            satelliteCategoryViewProducer: { satellites.view($0) },
            settingsOverviewProducer: { settingsView.view() }
        )
    }
}

extension ViewProducer where Context == RootViewContext, ProducedView == LegacyRootView {
    public static func root<S: StoreType>(viewModel: S, settings: AppSettings) -> ViewProducer
    where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer { context in
            LegacyRootView(
                tabs: viewModel.projection(action: AppAction.rootView, state: RootViewState.project(appState:))
                    .asObservableViewModel(initialState: .init(), emitsValue: .whenDifferent),
                settings: settings,
                context: context,
                sky: .realtimeSky(viewModel: viewModel),
                forecast: .satelliteOverview(viewModel: viewModel),
                satellites: .satelliteCategory(viewModel: viewModel),
                settingsView: .settingsOverview(viewModel: viewModel, settings: settings)
            )
        }
    }
}
