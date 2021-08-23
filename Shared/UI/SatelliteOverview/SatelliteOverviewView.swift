//
//  SatelliteOverviewView.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/24/21.
//

import SwiftUI
import SwiftRex
import CombineRex
import CombineRextensions

enum SatelliteOverviewViewAction {
    case selectSpecialSatellite(noradIndex: Int)
    case selectCategory(SatelliteCategory)
    case selectObserver
    case selectAlert
    case returnToSatelliteOverview
}

struct SatelliteOverviewViewState: Equatable {
    var navigationState: NavigationState

    static func project(state: AppState) -> SatelliteOverviewViewState {
        SatelliteOverviewViewState(
            navigationState: state.navigationState
        )
    }

    static var initial: SatelliteOverviewViewState {
        SatelliteOverviewViewState(navigationState: .overview)
    }
}

struct SatelliteOverviewView: View {
    @ObservedObject var viewModel: ObservableViewModel<SatelliteOverviewViewAction, SatelliteOverviewViewState>
    let listViewProducer: ViewProducer<Void, SatelliteListView>
    let singleSatelliteWrappingViewProducer: ViewProducer<Void, SingleSatelliteWrappingView>
    let observerCellViewProducer: ViewProducer<Void, ObserverCell>
    let locationSettingsViewProducer: ViewProducer<Void, LocationSettingsView>
    let alarmSettingsCellProducer: ViewProducer<Void, AlarmSettingsCell>
    let alarmSettingsViewProducer: ViewProducer<Void, AlarmSettingsView>

    let sections: [SatelliteOverviewSection] = [
        .satellitesOfSpecialInterest([
            .specialSatellites(.iss),
            .specialSatellites(.tianhe)
        ]),
        .categories([
            .category(.brightest100),
            .category(.active),
            .category(.last30DayLaunches)
        ]),
        .settings([
            .settings(.alert),
            .settings(.observer)
        ])
    ]

    @ViewBuilder private func destination(for item: SatelliteOverviewItem) -> some View {
        switch item {
        case .specialSatellites(_):
            singleSatelliteWrappingViewProducer.view()
        case .category(_):
            listViewProducer.view()
        case let .settings(settings):
            switch settings {
            case .observer:
                locationSettingsViewProducer.view()
            case .alert:
                alarmSettingsViewProducer.view()
            }
        }
    }

    private func setNavigationItem(_ item: SatelliteOverviewItem?) {
        switch item {
        case let .specialSatellites(satellite):
            viewModel.dispatch(.selectSpecialSatellite(noradIndex: satellite.rawValue))
        case let .category(category):
            viewModel.dispatch(.selectCategory(category))
        case let .settings(settings):
            switch settings {
            case .observer:
                viewModel.dispatch(.selectObserver)
            case .alert:
                viewModel.dispatch(.selectAlert)
            }
        case .none:
            viewModel.dispatch(.returnToSatelliteOverview)
        }
    }

    @ViewBuilder private func navigationLink(
        for item: SatelliteOverviewItem
    ) -> some View {
        NavigationLink(
            destination: LazyView(destination(for: item)),
            tag: item,
            selection: Binding<SatelliteOverviewItem?>(
                get: {
                    viewModel.state.navigationState.selectedSatelliteOverviewItem
                },
                set: self.setNavigationItem
            ),
            label: {
                SatelliteOverviewCell(
                    model: SatelliteOverviewCellModel(
                        item: item
                    ),
                    observerCellViewProducer: observerCellViewProducer,
                    alarmSettingsCellProducer: alarmSettingsCellProducer
                )
                .fixedSize(horizontal: false, vertical: true)
            }
        )
    }

    private func sectionView(_ section: SatelliteOverviewSection) -> some View {
        ForEach(section.items, id: \.self) { item in
            navigationLink(for: item)
                .id(item)
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(
                    alignment: .leading,
                    spacing: 10,
                    pinnedViews: []
                ) {
                    ForEach(sections, id: \.self) { section in
                        Section(
                            header: Text(LocalizedStrings.SatelliteOverviewView.sectionTitle(section))
                                .font(.headline.lowercaseSmallCaps().weight(.semibold))
                                .foregroundColor(Color(UIColor.secondaryLabel))
                        ) {
                            sectionView(section)
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitle("Overview", displayMode: .inline)
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

extension ViewProducer where Context == Void, ProducedView == SatelliteOverviewView {
    static func satelliteOverview<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            SatelliteOverviewView(
                viewModel: viewModel.projection(
                    action: AppAction.satelliteOverview,
                    state: SatelliteOverviewViewState.project(state:)
                )
                .asObservableViewModel(initialState: .initial, emitsValue: .whenDifferent),
                listViewProducer: ViewProducer<Void, SatelliteListView>
                    .satelliteListView(viewModel: viewModel),
                singleSatelliteWrappingViewProducer: ViewProducer<Void, SingleSatelliteWrappingView>.singleSatelliteWrappingView(viewModel: viewModel),
                observerCellViewProducer: ViewProducer<Void, ObserverCell>.observerCell(viewModel: viewModel),
                locationSettingsViewProducer: ViewProducer<Void, LocationSettingsView>.locationSettings(viewModel: viewModel),
                alarmSettingsCellProducer: ViewProducer<Void, AlarmSettingsCell>.alarmSettingsCell(viewModel: viewModel),
                alarmSettingsViewProducer: ViewProducer<Void, AlarmSettingsView>.alarmSettingsView(viewModel: viewModel)
            )
        }
    }
}

#if DEBUG
struct SatelliteOverviewView_Previews: PreviewProvider {
    static var previews: some View {
        SatelliteOverviewView(
            viewModel: .mock(
                state: SatelliteOverviewViewState(navigationState: .overview)
            ),
            listViewProducer: .crash,
            singleSatelliteWrappingViewProducer: .crash,
            observerCellViewProducer: .crash,
            locationSettingsViewProducer: .crash,
            alarmSettingsCellProducer: .crash,
            alarmSettingsViewProducer: .crash
        )
    }
}
#endif
