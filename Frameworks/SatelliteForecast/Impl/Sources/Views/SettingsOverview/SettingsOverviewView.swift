//
//  SettingsOverviewView.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 3/19/22.
//

import SatelliteForecast
import SwiftUI

struct SettingsOverviewObserverNavigation: Equatable, Hashable, Codable {}

struct EphemeridesManagerNavigation: Equatable, Hashable, Codable {}

public protocol SettingsOverviewView: View {}

public struct SettingsOverviewViewImpl: SettingsOverviewView {
    @Bindable private var settings: AppSettings
    @State private var navigationPath = NavigationPath()
    let watchOnboardingAgain: () -> Void
    let observerCellViewFactory: () -> ObserverCell
    let locationSettingsViewFactory: () -> LocationSettingsView

    public init(
        settings: AppSettings,
        watchOnboardingAgain: @escaping () -> Void,
        observerCellViewFactory: @escaping () -> ObserverCell,
        locationSettingsViewFactory: @escaping () -> LocationSettingsView
    ) {
        self.settings = settings
        self.watchOnboardingAgain = watchOnboardingAgain
        self.observerCellViewFactory = observerCellViewFactory
        self.locationSettingsViewFactory = locationSettingsViewFactory
    }

    let items: [SettingsOverviewItem] = [
        .observer,
        .ephemeridesManager
    ]

    @ViewBuilder private func destination(for item: SettingsOverviewItem) -> some View {
        switch item {
        case .observer:
            locationSettingsViewFactory()
        case .ephemeridesManager:
            EphemeridesManagementView()
        }
    }

    @ViewBuilder private func sectionHeader(for item: SettingsOverviewItem) -> some View {
        switch item {
        case .observer:
            Text(
                NSLocalizedString(
                    "SettingsOverviewView.observer.header",
                    tableName: nil,
                    bundle: .module,
                    value: "Observer location",
                    comment: "The section header of the observer section in settings"
                )
            )
            .font(.subheadline.weight(.semibold))
            .foregroundColor(AppTheme.muted)
        case .ephemeridesManager:
            Text(
                NSLocalizedString(
                    "SettingsOverviewView.ephemeridesManager.header",
                    tableName: nil,
                    bundle: .module,
                    value: "Downloaded ephemerides",
                    comment: "The section header of the ephemerides manager section in settings"
                )
            )
            .font(.subheadline.weight(.semibold))
            .foregroundColor(AppTheme.muted)
        }
    }

    public var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                LazyVStack(
                    alignment: .leading,
                    spacing: 20,
                    pinnedViews: []
                ) {
                    ForEach(items, id: \.self) { item in
                        switch item {
                        case .observer:
                            Section {
                                NavigationLink(value: SettingsOverviewObserverNavigation()) {
                                    observerCellViewFactory()
                                }
                            } header: {
                                sectionHeader(for: item)
                            }
                        case .ephemeridesManager:
                            Section {
                                NavigationLink(value: EphemeridesManagerNavigation()) {
                                    EphemeridesManagerCell()
                                }
                            } header: {
                                sectionHeader(for: item)
                            }
                        }
                    }

                    Section {
                        Button(action: watchOnboardingAgain) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Watch onboarding again", bundle: .module)
                                Spacer()
                            }
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                            .padding()
                            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
                        }
                    } header: {
                        EmptyView()
                    } footer: {
                        Link(destination: URL(string: "https://svs.gsfc.nasa.gov/4851/")!) {
                            Text(verbatim: "Milky Way: NASA/Goddard SVS · ESA/Gaia/DPAC")
                                .font(.caption2)
                        }
                    }
                }
                .frame(maxWidth: 680)
                .padding()
                .frame(maxWidth: .infinity, alignment: .top)
                .navigationDestination(for: SettingsOverviewObserverNavigation.self) { _ in
                    LazyView {
                        locationSettingsViewFactory()
                    }
                }
                .navigationDestination(for: EphemeridesManagerNavigation.self) { _ in
                    LazyView {
                        EphemeridesManagementView()
                    }
                }
            }
            .modifier(AppSurface())
            .navigationBarTitle(Text("Settings", bundle: .module), displayMode: .inline)
            .navigationBarHidden(true)
        .analyticsScreen(.settings)
        }
    }
}
