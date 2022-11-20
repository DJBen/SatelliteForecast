//
//  TabBarItemModifier.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/5/22.
//

import CombineRex
import SwiftUI
import SwiftRex

struct TabBarItemModifier: ViewModifier {
    let tab: Tab
    let selectedTab: Tab

    private func isSelectedBinding(for tab: Tab) -> Binding<Bool> {
        Binding<Bool>(
            get: {
                selectedTab == tab
            },
            set: { _ in

            }
        )
    }

    func body(content: Content) -> some View {
        content.tabItem {
            DynamicTabBarItemView(
                isSelected: isSelectedBinding(for: tab),
                content: {
                    glyphImage
                    Text(
                        text
                    )
                },
                selectedContent: {
                    selectedGlyphImage
                    Text(
                        text
                    )
                }
            )
        }
        .tag(tab)
    }

    private var text: String {
        switch tab {
        case .realtimeSky:
            return Self.Tabs.RealtimeSky.text
        case .forecast:
            return Self.Tabs.Forecast.text
        case .settings:
            return Self.Tabs.Settings.text
        }
    }

    @ViewBuilder private var glyphImage: some View {
        switch tab {
        case .realtimeSky:
            Image("glyph_satellite")
        case .forecast:
            Image("glyph_pass")
        case .settings:
            Image(systemName: "gear")
        }
    }

    @ViewBuilder private var selectedGlyphImage: some View {
        switch tab {
        case .realtimeSky:
            Image("glyph_satellite.fill")
        case .forecast:
            Image("glyph_pass")
        case .settings:
            Image(systemName: "gear")
        }
    }
}

// MARK: - Localizations

extension TabBarItemModifier {
    enum Tabs {
        enum RealtimeSky {
            static let text: String = NSLocalizedString(
                "tabs.realtimeSky.text",
                value: "Sky now",
                comment: "The title of the 'Realtime sky' tab of the root view."
            )
        }

        enum Forecast {
            static let text: String = NSLocalizedString(
                "tabs.forecast.text",
                value: "Pass forecast",
                comment: "The title of the 'Forecast' tab of the root view."
            )
        }

        enum Settings {
            static let text: String = NSLocalizedString(
                "tabs.settings.text",
                value: "Settings",
                comment: "The title of the 'Settings' tab of the root view."
            )
        }
    }
}
