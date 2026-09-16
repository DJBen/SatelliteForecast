//
//  SettingsOverviewView.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 3/19/22.
//

import SatelliteForecast
import SwiftUI

struct SettingsOverviewAlarmNavigation: Equatable, Hashable, Codable {}

struct SettingsOverviewObserverNavigation: Equatable, Hashable, Codable {}

struct EphemeridesManagerNavigation: Equatable, Hashable, Codable {}

public protocol SettingsOverviewView: View {}

public struct SettingsOverviewViewImpl: SettingsOverviewView {
    @Bindable private var settings: AppSettings
    @State private var navigationPath = NavigationPath()
    let watchOnboardingAgain: () -> Void
    let observerCellViewFactory: () -> ObserverCell
    let locationSettingsViewFactory: () -> LocationSettingsView
    let alarmSettingsCellFactory: () -> AlarmSettingsCell
    let alarmSettingsViewFactory: () -> AlarmSettingsView

    public init(
        settings: AppSettings,
        watchOnboardingAgain: @escaping () -> Void,
        observerCellViewFactory: @escaping () -> ObserverCell,
        locationSettingsViewFactory: @escaping () -> LocationSettingsView,
        alarmSettingsCellFactory: @escaping () -> AlarmSettingsCell,
        alarmSettingsViewFactory: @escaping () -> AlarmSettingsView
    ) {
        self.settings = settings
        self.watchOnboardingAgain = watchOnboardingAgain
        self.observerCellViewFactory = observerCellViewFactory
        self.locationSettingsViewFactory = locationSettingsViewFactory
        self.alarmSettingsCellFactory = alarmSettingsCellFactory
        self.alarmSettingsViewFactory = alarmSettingsViewFactory
    }

    let items: [SettingsOverviewItem] = [
        .observer,
        .alarms,
        .ephemeridesManager
    ]

    @ViewBuilder private func destination(for item: SettingsOverviewItem) -> some View {
        switch item {
        case .observer:
            locationSettingsViewFactory()
        case .alarms:
            alarmSettingsViewFactory()
        case .ephemeridesManager:
            EphemeridesManagementView()
        }
    }

    @ViewBuilder private func sectionHeader(for item: SettingsOverviewItem) -> some View {
        switch item {
        case .alarms:
            Text(
                NSLocalizedString(
                    "SettingsOverviewView.alarms.header",
                    tableName: nil,
                    bundle: .module,
                    value: "Alarms",
                    comment: "The section header of the alarms section in settings"
                )
            )
            .font(.subheadline.weight(.semibold))
            .foregroundColor(AppTheme.muted)
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

    @ViewBuilder private var experimentalSkyNowCell: some View {
        Button {
            settings.showExperimentalSkyNow.toggle()
        } label: {
            HStack {
                Image(systemName: settings.showExperimentalSkyNow ? "star.fill" : "star")
                    .font(.headline)
                    .foregroundColor(Color(UIColor.label))

                let text: String = {
                    if settings.showExperimentalSkyNow {
                        return NSLocalizedString(
                            "SettingsOverviewView.experimentalSkyNowCell.off.title",
                            tableName: nil,
                            bundle: .module,
                            value: "Hide experimental Sky Now tab",
                            comment: "The title of the toggle that hides the experimental Sky Now tab in the settings view."
                        )
                    } else {
                        return NSLocalizedString(
                            "SettingsOverviewView.experimentalSkyNowCell.on.title",
                            tableName: nil,
                            bundle: .module,
                            value: "Show experimental Sky Now tab",
                            comment: "The title of the toggle that shows the experimental Sky Now tab in the settings view."
                        )
                    }
                }()

                Text(
                    text
                )
                .font(.headline)
                .foregroundColor(Color(UIColor.label))
                .multilineTextAlignment(.leading)

                Spacer()
            }
            .padding()
            .background {
                let colors = [AppTheme.surfaceColor, AppTheme.surfaceColor]

                LinearGradient(
                    gradient: Gradient(colors: colors.map(Color.init)),
                    startPoint: UnitPoint(x: 0, y: 0),
                    endPoint: UnitPoint(x: 1, y: 1)
                )
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: AppTheme.cardRadius,
                    style: .continuous
                )
            )
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
                        case .alarms:
                            Section {
                                NavigationLink(value: SettingsOverviewAlarmNavigation()) {
                                    alarmSettingsCellFactory()
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
                        experimentalSkyNowCell
                        Button(action: watchOnboardingAgain) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Watch onboarding again", bundle: .module)
                                Spacer()
                            }
                            .font(.headline)
                            .foregroundStyle(.primary)
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
                .padding()
                .navigationDestination(for: SettingsOverviewObserverNavigation.self) { _ in
                    LazyView {
                        locationSettingsViewFactory()
                    }
                }
                .navigationDestination(for: SettingsOverviewAlarmNavigation.self) { _ in
                    LazyView {
                        alarmSettingsViewFactory()
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
        }
    }
}
