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
import StarryNight

public struct RootViewContext {
    public let starManager: any StarManaging
    public let julianDateProvider: () -> Double

    public init(
        starManager: any StarManaging,
        julianDateProvider: @escaping () -> Double
    ) {
        self.starManager = starManager
        self.julianDateProvider = julianDateProvider
    }
}

private let satelliteCategoryText = NSLocalizedString(
    "tabs.satelliteCategory.text",
    bundle: .module,
    value: "Satellites",
    comment: "The title of the 'Satellites' tab of the root view.",
)

private let realtimeSkyTabText = NSLocalizedString(
    "tabs.realtimeSky.text",
    bundle: .module,
    value: "Sky now",
    comment: "The title of the 'Realtime sky' tab of the root view."
)

private let forecastTabText = NSLocalizedString(
    "tabs.forecast.text",
    bundle: .module,
    value: "Pass forecast",
    comment: "The title of the 'Forecast' tab of the root view."
)

private let settingsTabText = NSLocalizedString(
    "tabs.settings.text",
    bundle: .module,
    value: "Settings",
    comment: "The title of the 'Settings' tab of the root view."
)

public struct RootView<RealtimeSkyViewType: RealtimeSkyView, SatelliteOverviewViewType: SatelliteOverviewView, SettingsOverViewViewType: SettingsOverviewView, SatelliteCategoryViewType: SatelliteCategoryView>: View {
    @ObservedObject var viewModel: ObservableViewModel<RootViewAction, RootViewState>
    public let context: RootViewContext
    public let realtimeSkyViewProducer: ViewProducer<RealtimeSkyViewContext, RealtimeSkyViewType>
    public let satelliteOverviewViewProducer: ViewProducer<SatelliteOverviewViewContext, SatelliteOverviewViewType>
    public let satelliteCategoryViewProducer: ViewProducer<SatelliteCategoryViewContext, SatelliteCategoryViewType>
    public let settingsOverviewProducer: ViewProducer<Void, SettingsOverViewViewType>

    public init(
        viewModel: ObservableViewModel<RootViewAction, RootViewState>,
        context: RootViewContext,
        realtimeSkyViewProducer: ViewProducer<RealtimeSkyViewContext, RealtimeSkyViewType>,
        satelliteOverviewViewProducer: ViewProducer<SatelliteOverviewViewContext, SatelliteOverviewViewType>,
        satelliteCategoryViewProducer: ViewProducer<SatelliteCategoryViewContext, SatelliteCategoryViewType>,
        settingsOverviewProducer: ViewProducer<Void, SettingsOverViewViewType>
    ) {
        self.viewModel = viewModel
        self.context = context
        self.realtimeSkyViewProducer = realtimeSkyViewProducer
        self.satelliteOverviewViewProducer = satelliteOverviewViewProducer
        self.satelliteCategoryViewProducer = satelliteCategoryViewProducer
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
    
    private func isSelectedBinding(for tab: SatelliteForecast.Tab) -> Binding<Bool> {
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
            selection: Binding<SatelliteForecast.Tab>.store(
                viewModel,
                state: \.selectedTab,
                onChange: RootViewAction.selectTab
            )
        ) {
            SwiftUI.Tab(value: .forecast, role: nil) {
                satelliteOverviewViewProducer.view(
                    SatelliteOverviewViewContext(
                        starManager: context.starManager,
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
            
            SwiftUI.Tab(value: .satellites, role: nil) {
                satelliteCategoryViewProducer.view(
                    SatelliteCategoryViewContext(
                        starManager: context.starManager,
                        julianDateProvider: context.julianDateProvider
                    )
                )
            } label: {
                DynamicTabBarItemView(
                    isSelected: isSelectedBinding(for: .satellites),
                    content: {
                        Image("glyph_satellite")
                        Text(satelliteCategoryText)
                    },
                    selectedContent: {
                        Image("glyph_satellite.fill")
                        Text(satelliteCategoryText)
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
                            starManager: context.starManager,
                            julianDateProvider: context.julianDateProvider
                        )
                    )
                } label: {
                    DynamicTabBarItemView(
                        isSelected: isSelectedBinding(for: .realtimeSky),
                        content: {
                            Image(systemName: "moon.stars")
                            Text(realtimeSkyTabText)
                        },
                        selectedContent: {
                            Image(systemName: "moon.stars.fill")
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
    
    struct MockSatelliteCategoryView: SatelliteCategoryView {
        var body: some View {
            Color.yellow
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
            context: RootViewContext(
                starManager: StarManagerMock(),
                julianDateProvider: { Date().julianDate }
            ),
            realtimeSkyViewProducer: .pure(MockRealtimeSkyView()),
            satelliteOverviewViewProducer: .pure(MockSatelliteOverviewView()),
            satelliteCategoryViewProducer: .pure(MockSatelliteCategoryView()),
            settingsOverviewProducer: .pure(MockSettingsView())
        )
    }
}

#endif
