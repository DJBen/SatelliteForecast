//
//  RootView.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/5/22.
//

import SwiftUI
import SatelliteForecast
import StarryNight

public struct RootViewContext {
    public let starManager: AppStarCatalog
    public let julianDateProvider: () -> Double

    public init(
        starManager: AppStarCatalog,
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
    @Binding private var selectedTab: SatelliteForecast.Tab
    private let settings: AppSettings
    public let context: RootViewContext
    public let realtimeSkyViewFactory: (RealtimeSkyViewContext) -> RealtimeSkyViewType
    public let satelliteOverviewViewFactory: (SatelliteOverviewViewContext) -> SatelliteOverviewViewType
    public let satelliteCategoryViewFactory: (SatelliteCategoryViewContext) -> SatelliteCategoryViewType
    public let settingsOverviewFactory: () -> SettingsOverViewViewType

    public init(
        selectedTab: Binding<SatelliteForecast.Tab>,
        settings: AppSettings,
        context: RootViewContext,
        realtimeSkyViewFactory: @escaping (RealtimeSkyViewContext) -> RealtimeSkyViewType,
        satelliteOverviewViewFactory: @escaping (SatelliteOverviewViewContext) -> SatelliteOverviewViewType,
        satelliteCategoryViewFactory: @escaping (SatelliteCategoryViewContext) -> SatelliteCategoryViewType,
        settingsOverviewFactory: @escaping () -> SettingsOverViewViewType
    ) {
        self._selectedTab = selectedTab
        self.settings = settings
        self.context = context
        self.realtimeSkyViewFactory = realtimeSkyViewFactory
        self.satelliteOverviewViewFactory = satelliteOverviewViewFactory
        self.satelliteCategoryViewFactory = satelliteCategoryViewFactory
        self.settingsOverviewFactory = settingsOverviewFactory

        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = AppTheme.backgroundColor
        navBarAppearance.shadowImage = UIImage()
        navBarAppearance.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance

        // Keep navigation on the canvas color; raised surfaces belong to content cards.
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = AppTheme.backgroundColor
        tabBarAppearance.shadowColor = AppTheme.borderColor.withAlphaComponent(0.35)
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().backgroundColor = AppTheme.backgroundColor
        UITabBar.appearance().unselectedItemTintColor = AppTheme.mutedColor
    }
    
    private func isSelectedBinding(for tab: SatelliteForecast.Tab) -> Binding<Bool> {
        Binding<Bool>(
            get: {
                selectedTab == tab
            },
            set: { _ in

            }
        )
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            SwiftUI.Tab(value: .forecast, role: nil) {
                satelliteOverviewViewFactory(
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
                satelliteCategoryViewFactory(
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
            
            if settings.showExperimentalSkyNow {
                SwiftUI.Tab(value: .realtimeSky, role: nil) {
                    realtimeSkyViewFactory(
                        RealtimeSkyViewContext(
                            basicChartConfigs: .init(),
                            backgroundSkyConfigs: .preset,
                            satelliteMagToRadiusFunction: .default,
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
                settingsOverviewFactory()
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
        .tint(AppTheme.accent)
        .background(AppTheme.background.ignoresSafeArea())
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
            selectedTab: .constant(.forecast),
            settings: AppSettings(),
            context: RootViewContext(
                starManager: StarManagerMock(),
                julianDateProvider: { Date().julianDate }
            ),
            realtimeSkyViewFactory: { _ in MockRealtimeSkyView() },
            satelliteOverviewViewFactory: { _ in MockSatelliteOverviewView() },
            satelliteCategoryViewFactory: { _ in MockSatelliteCategoryView() },
            settingsOverviewFactory: { MockSettingsView() }
        )
    }
}

#endif
