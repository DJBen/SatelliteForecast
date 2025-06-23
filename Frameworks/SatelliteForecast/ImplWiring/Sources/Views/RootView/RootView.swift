//
//  RootView.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/5/22.
//

@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import SwiftRex
import SwiftUI
import SatelliteForecast
import SatelliteForecastImpl

public enum RootViewAction {
    case selectTab(Tab)
}

extension RootViewAction: Equatable {}

public struct RootViewState {
    public var selectedTab: Tab = .forecast
    public var showExperimentalSkyNow: Bool = false
}

extension RootViewState: Equatable {}

public struct RootViewContext {
    public let julianDateProvider: () -> Double

    public init(
        julianDateProvider: @escaping () -> Double
    ) {
        self.julianDateProvider = julianDateProvider
    }
}

private let realtimeSkyTabText = NSLocalizedString(
    "tabs.realtimeSky.text",
    value: "Sky now",
    comment: "The title of the 'Realtime sky' tab of the root view."
)

private let forecastTabText = NSLocalizedString(
    "tabs.forecast.text",
    value: "Pass forecast",
    comment: "The title of the 'Forecast' tab of the root view."
)

private let settingsTabText = NSLocalizedString(
    "tabs.settings.text",
    value: "Settings",
    comment: "The title of the 'Settings' tab of the root view."
)

public struct RootView<RealtimeSkyViewType: RealtimeSkyView, SatelliteOverviewViewType: SatelliteOverviewView, SettingsOverViewViewType: SettingsOverviewView>: View {
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
    
    private func isSelectedBinding(for tab: SatelliteForecastImplWiring.Tab) -> Binding<Bool> {
        Binding<Bool>(
            get: {
                viewModel.state.selectedTab == tab
            },
            set: { _ in

            }
        )
    }

    public var body: some View {
        TabView(
            selection: Binding<Tab>.store(
                viewModel,
                state: \.selectedTab,
                onChange: RootViewAction.selectTab
            )
        ) {
            SwiftUI.Tab(value: .forecast, role: nil) {
                satelliteOverviewViewProducer.view(
                    SatelliteOverviewViewContext(
                        julianDateProvider: context.julianDateProvider
                    )
                )
            } label: {
                DynamicTabBarItemView(
                    isSelected: isSelectedBinding(for: .forecast),
                    content: {
                        Image("glyph_pass")
                        Text(forecastTabText)
                    },
                    selectedContent: {
                        Image("glyph_pass")
                        Text(forecastTabText)
                    }
                )
            }
            
            if viewModel.state.showExperimentalSkyNow {
                SwiftUI.Tab(value: .realtimeSky, role: nil) {
                    realtimeSkyViewProducer.view(
                        RealtimeSkyViewContext(
                            basicChartConfigs: .init(),
                            backgroundSkyConfigs: .preset,
                            satelliteMagToRadiusFunction: .init(multipler: 3.2, exponent: -0.32, minimum: 1),
                            julianDateProvider: context.julianDateProvider
                        )
                    )
                } label: {
                    DynamicTabBarItemView(
                        isSelected: isSelectedBinding(for: .realtimeSky),
                        content: {
                            Image("glyph_satellite")
                            Text(realtimeSkyTabText)
                        },
                        selectedContent: {
                            Image("glyph_satellite.fill")
                            Text(realtimeSkyTabText)
                        }
                    )
                }
            }

            SwiftUI.Tab(value: .settings, role: nil) {
                settingsOverviewProducer.view()
            } label: {
                DynamicTabBarItemView(
                    isSelected: isSelectedBinding(for: .settings),
                    content: {
                        Image(systemName: "gear")
                        Text(settingsTabText)
                    },
                    selectedContent: {
                        Image(systemName: "gear")
                        Text(settingsTabText)
                    }
                )
            }
        }
        .tint(Color(uiColor: .label))
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
