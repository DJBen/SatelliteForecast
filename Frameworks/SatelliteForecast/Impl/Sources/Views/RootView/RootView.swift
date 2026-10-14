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
    value: "Passes",
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

    public let alarmsFactory: () -> AnyView

    public init(
        selectedTab: Binding<SatelliteForecast.Tab>,
        settings: AppSettings,
        context: RootViewContext,
        realtimeSkyViewFactory: @escaping (RealtimeSkyViewContext) -> RealtimeSkyViewType,
        satelliteOverviewViewFactory: @escaping (SatelliteOverviewViewContext) -> SatelliteOverviewViewType,
        satelliteCategoryViewFactory: @escaping (SatelliteCategoryViewContext) -> SatelliteCategoryViewType,
        settingsOverviewFactory: @escaping () -> SettingsOverViewViewType,
        alarmsFactory: @escaping () -> AnyView = { AnyView(EmptyView()) }
    ) {
        self._selectedTab = selectedTab
        self.settings = settings
        self.context = context
        self.realtimeSkyViewFactory = realtimeSkyViewFactory
        self.satelliteOverviewViewFactory = satelliteOverviewViewFactory
        self.satelliteCategoryViewFactory = satelliteCategoryViewFactory
        self.settingsOverviewFactory = settingsOverviewFactory
        self.alarmsFactory = alarmsFactory

        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = AppTheme.backgroundColor
        navBarAppearance.titleTextAttributes = [.foregroundColor: AppTheme.textColor]
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: AppTheme.textColor]
        navBarAppearance.shadowImage = UIImage()
        navBarAppearance.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance

        // Let the system tab bar and scroll-edge effect composite over content.

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
            
            SwiftUI.Tab(value: .realtimeSky, role: nil) {
                realtimeSkyViewFactory(
                    RealtimeSkyViewContext(
                        basicChartConfigs: .init(),
                        backgroundSkyConfigs: .preset,
                        satelliteMagToRadiusFunction: .satellite,
                        starManager: context.starManager,
                        julianDateProvider: context.julianDateProvider
                    )
                )
            } label: {
                DynamicTabBarItemView(
                    isSelected: isSelectedBinding(for: .realtimeSky),
                    content: {
                        Image("glyph_sky")
                        Text(realtimeSkyTabText)
                    },
                    selectedContent: {
                        Image(systemName: "moon.stars.fill")
                        Text(realtimeSkyTabText)
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
            

            SwiftUI.Tab(value: .alarms, role: nil) {
                alarmsFactory()
            } label: {
                Label {
                    Text("Alarms", bundle: .module)
                } icon: {
                    Image(uiImage: selectedTab == .alarms ? AlarmTabIcon.filledAlarmBell : AlarmTabIcon.alarmBell)
                        .renderingMode(.template)
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
        .foregroundStyle(AppTheme.text)
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .background {
            // Native keyboard commands work without adding visible product chrome.
            HStack {
                Button(forecastTabText) { selectedTab = .forecast }.keyboardShortcut("1")
                Button(realtimeSkyTabText) { selectedTab = .realtimeSky }.keyboardShortcut("2")
                Button(satelliteCategoryText) { selectedTab = .satellites }.keyboardShortcut("3")
                Button(AppLocalization.text("Alarms")) { selectedTab = .alarms }.keyboardShortcut("4")
                Button(settingsTabText) { selectedTab = .settings }.keyboardShortcut("5")
            }
            .frame(width: 0, height: 0).clipped().accessibilityHidden(true)
        }
    }
}

@MainActor
private enum AlarmTabIcon {
    // Rasterize the resolved SF Symbol so TabView cannot substitute its fill
    // variant when an unselected tab hosts a pushed navigation destination.
    static let alarmBell = tabBell("bell")
    static let filledAlarmBell = tabBell("bell.fill")

    private static func tabBell(_ name: String) -> UIImage {
        let symbol = UIImage(systemName: name,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 25, weight: .regular))!
        return UIGraphicsImageRenderer(size: symbol.size).image { _ in
            symbol.withTintColor(.black, renderingMode: .alwaysOriginal)
                .draw(at: .zero)
        }
    }

}
