//
//  SettingsOverviewView.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 3/19/22.
//

@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import SatelliteForecast
import SwiftRex
import SwiftUI

public struct SettingsOverviewViewState {
    public var navigationPath: NavigationPath = .init()
    public var isNightModeOn: Bool = false
    public var showExperimentalSkyNow: Bool = false

    public init(
        navigationPath: NavigationPath = .init(),
        isNightModeOn: Bool = false,
        showExperimentalSkyNow: Bool = false
    ) {
        self.navigationPath = navigationPath
        self.isNightModeOn = isNightModeOn
        self.showExperimentalSkyNow = showExperimentalSkyNow
    }
}

extension SettingsOverviewViewState: Equatable {}

struct SettingsOverviewAlarmNavigation: Equatable, Hashable, Codable {}

struct SettingsOverviewObserverNavigation: Equatable, Hashable, Codable {}

struct EphemeridesManagerNavigation: Equatable, Hashable, Codable {}

public protocol SettingsOverviewView: View {}

public struct SettingsOverviewViewImpl: SettingsOverviewView {
    @ObservedObject var viewModel: ObservableViewModel<SettingsOverviewViewAction, SettingsOverviewViewState>
    let observerCellViewProducer: ViewProducer<Void, ObserverCell>
    let locationSettingsViewProducer: ViewProducer<Void, LocationSettingsView>
    let alarmSettingsCellProducer: ViewProducer<Void, AlarmSettingsCell>
    let alarmSettingsViewProducer: ViewProducer<Void, AlarmSettingsView>

    public init(
        viewModel: ObservableViewModel<SettingsOverviewViewAction, SettingsOverviewViewState>,
        observerCellViewProducer: ViewProducer<Void, ObserverCell>,
        locationSettingsViewProducer: ViewProducer<Void, LocationSettingsView>,
        alarmSettingsCellProducer: ViewProducer<Void, AlarmSettingsCell>,
        alarmSettingsViewProducer: ViewProducer<Void, AlarmSettingsView>
    ) {
        self.viewModel = viewModel
        self.observerCellViewProducer = observerCellViewProducer
        self.locationSettingsViewProducer = locationSettingsViewProducer
        self.alarmSettingsCellProducer = alarmSettingsCellProducer
        self.alarmSettingsViewProducer = alarmSettingsViewProducer
    }

    let items: [SettingsOverviewItem] = [
        .observer,
        .alarms,
        .ephemeridesManager
    ]

    @ViewBuilder private func destination(for item: SettingsOverviewItem) -> some View {
        switch item {
        case .observer:
            locationSettingsViewProducer.view()
        case .alarms:
            alarmSettingsViewProducer.view()
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
            .font(.headline.lowercaseSmallCaps().weight(.semibold))
            .foregroundColor(Color(UIColor.secondaryLabel))
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
            .font(.headline.lowercaseSmallCaps().weight(.semibold))
            .foregroundColor(Color(UIColor.secondaryLabel))
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
            .font(.headline.lowercaseSmallCaps().weight(.semibold))
            .foregroundColor(Color(UIColor.secondaryLabel))
        }
    }

    @ViewBuilder private var nightModeCell: some View {
        Button(
            store: viewModel,
            action: .setNightMode(!viewModel.state.isNightModeOn)
        ) { viewModel in
            HStack {
                Image(systemName: viewModel.state.isNightModeOn ? "moon.stars.fill" : "moon.stars")
                    .font(.headline)
                    .foregroundColor(Color(UIColor.label))

                let text: String = {
                    if viewModel.state.isNightModeOn {
                        return NSLocalizedString(
                            "SettingsOverviewView.nightModeCell.off.title",
                            tableName: nil,
                            bundle: .module,
                            value: "Turn off night mode",
                            comment: "The title of the toggle that toggles night mode off in the settings view."
                        )
                    } else {
                        return NSLocalizedString(
                            "SettingsOverviewView.nightModeCell.on.title",
                            tableName: nil,
                            bundle: .module,
                            value: "Turn on night mode",
                            comment: "The title of the toggle that toggles night mode on in the settings view."
                        )
                    }
                }()

                Text(
                    text
                )
                .font(.headline)
                .foregroundColor(Color(UIColor.label))

                Spacer()
            }
            .padding()
            .background {
                let colors = [UIColor.systemGray4, UIColor.systemGray5]

                LinearGradient(
                    gradient: Gradient(colors: colors.map(Color.init)),
                    startPoint: UnitPoint(x: 0, y: 0),
                    endPoint: UnitPoint(x: 1, y: 1)
                )
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                )
            )
        }
    }

    @ViewBuilder private var experimentalSkyNowCell: some View {
        Button(
            store: viewModel,
            action: .setExperimentalSkyNow(!viewModel.state.showExperimentalSkyNow)
        ) { viewModel in
            HStack {
                Image(systemName: viewModel.state.showExperimentalSkyNow ? "star.fill" : "star")
                    .font(.headline)
                    .foregroundColor(Color(UIColor.label))

                let text: String = {
                    if viewModel.state.showExperimentalSkyNow {
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

                Spacer()
            }
            .padding()
            .background {
                let colors = [UIColor.systemPurple, UIColor.systemBlue]

                LinearGradient(
                    gradient: Gradient(colors: colors.map(Color.init)),
                    startPoint: UnitPoint(x: 0, y: 0),
                    endPoint: UnitPoint(x: 1, y: 1)
                )
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                )
            )
        }
    }

    public var body: some View {
        NavigationStack(
            path: Binding<NavigationPath>(
                get: {
                    viewModel.state.navigationPath
                }, set: { navigationPath in
                    viewModel.dispatch(.navigate(navigationPath))
                }
            )
        ) {
            ScrollView {
                LazyVStack(
                    alignment: .leading,
                    spacing: 10,
                    pinnedViews: []
                ) {
                    ForEach(items, id: \.self) { item in
                        switch item {
                        case .observer:
                            Section {
                                NavigationLink(value: SettingsOverviewObserverNavigation()) {
                                    observerCellViewProducer.view()
                                }
                            } header: {
                                sectionHeader(for: item)
                            }
                        case .alarms:
                            Section {
                                NavigationLink(value: SettingsOverviewAlarmNavigation()) {
                                    alarmSettingsCellProducer.view()
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
                        nightModeCell
                    } header: {
                        EmptyView()
                    }
                }
                .padding()
                .navigationDestination(for: SettingsOverviewObserverNavigation.self) { _ in
                    LazyView {
                        locationSettingsViewProducer.view()
                    }
                }
                .navigationDestination(for: SettingsOverviewAlarmNavigation.self) { _ in
                    LazyView {
                        alarmSettingsViewProducer.view()
                    }
                }
                .navigationDestination(for: EphemeridesManagerNavigation.self) { _ in
                    LazyView {
                        EphemeridesManagementView()
                    }
                }
            }
            .navigationBarTitle(Text("Settings", bundle: .module), displayMode: .inline)
            .navigationBarHidden(true)
        }
    }
}

#if DEBUG

struct SettingsOverviewView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsOverviewViewImpl(
            viewModel: .mock(state: .init()),
            observerCellViewProducer: .crash,
            locationSettingsViewProducer: .crash,
            alarmSettingsCellProducer: .crash,
            alarmSettingsViewProducer: .crash
        )
    }
}

#endif
