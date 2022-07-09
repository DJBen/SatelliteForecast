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
    case selectSettingItem(SettingsOverviewItem?)
}

extension SettingsOverviewViewAction: Equatable {}

public struct SettingsOverviewViewState {
    public var observerNavigation: ObserverNavigationState = .init()
    public var alarmNavigation: AlarmNavigationState = .init()

    public init(
        observerNavigation: ObserverNavigationState = .init(),
        alarmNavigation: AlarmNavigationState = .init()
    ) {
        self.observerNavigation = observerNavigation
        self.alarmNavigation = alarmNavigation
    }
}

extension SettingsOverviewViewState: Equatable {}

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
                    bundle: .main,
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
                    bundle: .main,
                    value: "Location settings",
                    comment: "The section header of the observer section in settings"
                )
            )
            .font(.headline.lowercaseSmallCaps().weight(.semibold))
            .foregroundColor(Color(UIColor.secondaryLabel))
        }
    }

    @ViewBuilder private func navigationLink(for item: SettingsOverviewItem) -> some View {
        Section {
            NavigationLink(
                destination: LazyView {
                    destination(for: item)
                },
                tag: item,
                selection: Binding<SettingsOverviewItem?>(
                    get: {
                        if viewModel.state.alarmNavigation.enabled {
                            return .alarms
                        } else if viewModel.state.observerNavigation.enabled {
                            return .observer
                        } else {
                            return nil
                        }
                    },
                    set: { item, _ in
                        viewModel.dispatch(.selectSettingItem(item))
                    }
                ),
                label: {
                    switch item {
                    case .observer:
                        observerCellViewProducer.view()
                    case .alarms:
                        alarmSettingsCellProducer.view()
                    }
                }
            )
        } header: {
            sectionHeader(for: item)
        }
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(
                    alignment: .leading,
                    spacing: 10,
                    pinnedViews: []
                ) {
                    ForEach(items, id: \.self) { item in
                        navigationLink(for: item)
                    }
                }
                .padding()
            }
            .navigationBarTitle("Settings", displayMode: .inline)
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
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
