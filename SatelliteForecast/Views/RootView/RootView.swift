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

enum RootViewAction {
    case selectTab(Tab)
}

extension RootViewAction: Equatable {}

struct RootViewState {
    var selectedTab: Tab = .realtimeSky
}

extension RootViewState: Equatable {}

struct RootView<RealtimeSkyViewType: RealtimeSkyView, SatelliteOverviewViewType: SatelliteOverviewView>: View {
    @ObservedObject var viewModel: ObservableViewModel<RootViewAction, RootViewState>
    let realtimeSkyViewProducer: ViewProducer<RealtimeSkyViewContext, RealtimeSkyViewType>
    let satelliteOverviewViewProducer: ViewProducer<Void, SatelliteOverviewViewType>

    init(
        viewModel: ObservableViewModel<RootViewAction, RootViewState>,
        realtimeSkyViewProducer: ViewProducer<RealtimeSkyViewContext, RealtimeSkyViewType>,
        satelliteOverviewViewProducer: ViewProducer<Void, SatelliteOverviewViewType>
    ) {
        self.viewModel = viewModel
        self.realtimeSkyViewProducer = realtimeSkyViewProducer
        self.satelliteOverviewViewProducer = satelliteOverviewViewProducer

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
            realtimeSkyViewProducer.view(
                RealtimeSkyViewContext(
                    basicChartConfigs: .init(),
                    backgroundSkyConfigs: .preset
                )
            )
            .modifier(
                TabBarItemModifier(
                    tab: .realtimeSky,
                    selectedTab: viewModel.state.selectedTab
                )
            )

            satelliteOverviewViewProducer.view(
            )
            .modifier(
                TabBarItemModifier(
                    tab: .forecast,
                    selectedTab: viewModel.state.selectedTab
                )
            )
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

    static var previews: some View {
        RootView(
            viewModel: .mock(
                state: .init(),
                action: { action, _, state in
                    switch action {
                    case .selectTab(let tab):
                        state.selectedTab = tab
                    }
                }
            ),
            realtimeSkyViewProducer: .pure(MockRealtimeSkyView()),
            satelliteOverviewViewProducer: .pure(MockSatelliteOverviewView())
        )
    }
}

#endif
