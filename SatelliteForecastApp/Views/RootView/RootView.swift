//
//  RootView.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/5/22.
//

import CombineRex
import CombineRextensions
import SwiftRex
import SwiftUI
import SatelliteForecast
import SatelliteForecastImpl

enum RootViewAction {
    case selectTab(Tab)
    case loadElementsForRealtimeSky
}

extension RootViewAction: Equatable {}

struct RootViewState {
    var selectedTab: Tab = .forecast
}

extension RootViewState: Equatable {}

struct RootViewContext {
    let julianDateProvider: () -> Double
}

struct RootView<RealtimeSkyViewType: RealtimeSkyView, SatelliteOverviewViewType: SatelliteOverviewView, SettingsOverViewViewType: SettingsOverviewView>: View {
    @ObservedObject var viewModel: ObservableViewModel<RootViewAction, RootViewState>
    let context: RootViewContext
    let realtimeSkyViewProducer: ViewProducer<RealtimeSkyViewContext, RealtimeSkyViewType>
    let satelliteOverviewViewProducer: ViewProducer<SatelliteOverviewViewContext, SatelliteOverviewViewType>
    let settingsOverviewProducer: ViewProducer<Void, SettingsOverViewViewType>

    init(
        viewModel: ObservableViewModel<RootViewAction, RootViewState>,
        context: RootViewContext,
        realtimeSkyViewProducer: ViewProducer<RealtimeSkyViewContext, RealtimeSkyViewType>,
        satelliteOverviewViewProducer: ViewProducer<SatelliteOverviewViewContext, SatelliteOverviewViewType>,
        settingsOverviewProducer: ViewProducer<Void, SettingsOverViewViewType>
    ) {
        self.viewModel = viewModel
        self.context = context
        self.realtimeSkyViewProducer = realtimeSkyViewProducer
        self.satelliteOverviewViewProducer = satelliteOverviewViewProducer
        self.settingsOverviewProducer = settingsOverviewProducer

        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.shadowImage = UIImage()
        navBarAppearance.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance

        UITabBar.appearance().backgroundColor = UIColor.systemBackground
        UITabBar.appearance().unselectedItemTintColor = UIColor.systemGray2
    }

    var body: some View {
        TabView(
            selection: Binding<Tab>.store(
                viewModel,
                state: \.selectedTab,
                onChange: RootViewAction.selectTab
            )
        ) {
            satelliteOverviewViewProducer.view(
                SatelliteOverviewViewContext(
                    julianDateProvider: context.julianDateProvider
                )
            )
            .modifier(
                TabBarItemModifier(
                    tab: .forecast,
                    selectedTab: viewModel.state.selectedTab
                )
            )

            realtimeSkyViewProducer.view(
                RealtimeSkyViewContext(
                    basicChartConfigs: .init(),
                    backgroundSkyConfigs: .preset,
                    satelliteMagToRadiusFunction: .init(multipler: 3.2, exponent: -0.32, minimum: 1)
                )
            )
            .modifier(
                TabBarItemModifier(
                    tab: .realtimeSky,
                    selectedTab: viewModel.state.selectedTab
                )
            )

            settingsOverviewProducer.view(
            )
            .modifier(
                TabBarItemModifier(
                    tab: .settings,
                    selectedTab: viewModel.state.selectedTab
                )
            )
        }
        .onLoad {
            viewModel.dispatch(.loadElementsForRealtimeSky)
        }
    }
}

#if DEBUG

struct RootView_Previews: PreviewProvider {
    struct MockSatelliteOverviewView: SatelliteOverviewView {
        var body: some View {
            Color.green
        }
    }

    struct MockRealtimeSkyView: RealtimeSkyView {
        var body: some View {
            Color.blue
        }
    }

    struct MockSettingsView: SettingsOverviewView {
        var body: some View {
            Color.purple
        }
    }

    static var previews: some View {
        RootView(
            viewModel: .mock(
                state: .init(),
                action: { action, _, state in
                    switch action {
                    case .selectTab(let tab):
                        state.selectedTab = tab
                    case .loadElementsForRealtimeSky:
                        break
                    }
                }
            ),
            context: RootViewContext(julianDateProvider: { Date().julianDate }),
            realtimeSkyViewProducer: .pure(MockRealtimeSkyView()),
            satelliteOverviewViewProducer: .pure(MockSatelliteOverviewView()),
            settingsOverviewProducer: .pure(MockSettingsView())
        )
    }
}

#endif
