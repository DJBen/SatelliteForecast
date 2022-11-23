//
//  SettingsOverviewView.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 3/19/22.
//

import CombineRex
import CombineRextensions
import SatelliteForecast
import SatelliteForecastImpl
import SwiftRex
import SwiftUI

public enum SettingsOverviewViewAction {
    case navigate(NavigationPath)
}

extension SettingsOverviewViewAction: Equatable {}

public struct SettingsOverviewViewState {
    public var navigationPath: NavigationPath = .init()

    public init(
        navigationPath: NavigationPath = .init()
    ) {
        self.navigationPath = navigationPath
    }
}

extension SettingsOverviewViewState: Equatable {}

struct SettingsOverviewAlarmNavigation: Equatable, Hashable, Codable {}

struct SettingsOverviewObserverNavigation: Equatable, Hashable, Codable {}

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
        .alarms
    ]

    @ViewBuilder private func destination(for item: SettingsOverviewItem) -> some View {
        switch item {
        case .observer:
            locationSettingsViewProducer.view()
        case .alarms:
            alarmSettingsViewProducer.view()
        }
    }

    @ViewBuilder private func sectionHeader(for item: SettingsOverviewItem) -> some View {
        switch item {
        case .alarms:
            Text(
                NSLocalizedString(
                    "SettingsOverviewView.alarms.header",
                    tableName: nil,
                    bundle: .satelliteForecastImplResourcesBundle,
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
                    bundle: .satelliteForecastImplResourcesBundle,
                    value: "Location settings",
                    comment: "The section header of the observer section in settings"
                )
            )
            .font(.headline.lowercaseSmallCaps().weight(.semibold))
            .foregroundColor(Color(UIColor.secondaryLabel))
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
                        }
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
            }
            .navigationBarTitle("Settings", displayMode: .inline)
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
