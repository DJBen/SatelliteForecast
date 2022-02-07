//
//  SatelliteOverviewView.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/24/21.
//

import SatelliteForecastCore
import SatelliteKit
import SwiftUI
import SwiftRex
import CombineRex
import CombineRextensions
import CoreLocation

enum SatelliteOverviewViewAction {
    struct SelectSpecialSatelliteParams {
        let noradIndex: Int
        let julianDateRange: Range<Double>
        let observer: LatLonAlt?
    }
    case selectSpecialSatellite(SelectSpecialSatelliteParams)
    case selectCategory(SatelliteCategory)
    case selectObserver
    case selectAlert
    case returnToSatelliteOverview
}

struct SatelliteOverviewViewState: Equatable {
    var navigationState: NavigationState
    var julianDate: Double
    var location: CLLocation?

    static func project(state: AppState) -> SatelliteOverviewViewState {
        SatelliteOverviewViewState(
            navigationState: state.navigationState,
            julianDate: state.julianDate,
            location: state.locationState.location
        )
    }

    static var initial: SatelliteOverviewViewState {
        SatelliteOverviewViewState(
            navigationState: .overview,
            julianDate: 0,
            location: nil
        )
    }
}

struct SatelliteOverviewView: View {
    @ObservedObject var viewModel: ObservableViewModel<SatelliteOverviewViewAction, SatelliteOverviewViewState>
    let listViewProducer: ViewProducer<SatelliteListViewContext, SatelliteListView>
    let singleSatelliteWrappingViewProducer: ViewProducer<SingleSatelliteWrappingViewContext, SingleSatelliteWrappingView>
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
        case let .specialSatellites(satellite):
            singleSatelliteWrappingViewProducer.view(
                SingleSatelliteWrappingViewContext(
                    selectedNoradIndex: satellite.rawValue,
                    julianDateRange: JulianDateUtil.createJulianDateRange(now: viewModel.state.julianDate),
                    observer: viewModel.state.location.map(LatLonAlt.init)
                )
            )
        case let .category(category):
            listViewProducer.view(
                SatelliteListViewContext(
                    category: category,
                    julianDateRange: JulianDateUtil.createJulianDateRange(now: viewModel.state.julianDate),
                    observer: viewModel.state.location.map(LatLonAlt.init)
                )
            )
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
            viewModel.dispatch(
                .selectSpecialSatellite(
                    .init(
                        noradIndex: satellite.rawValue,
                        julianDateRange: JulianDateUtil.createJulianDateRange(now: viewModel.state.julianDate),
                        observer: viewModel.state.location.map(LatLonAlt.init)
                    )
                )
            )
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
            }
        )
    }

    @ViewBuilder private func sectionView(_ section: SatelliteOverviewSection) -> some View {
        switch section {
        case .categories(_):
            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(section.items, id: \.self) { item in
                    navigationLink(for: item)
                        .id(item)
                }
            }
        case .satellitesOfSpecialInterest(_), .settings(_):
            ForEach(section.items, id: \.self) { item in
                navigationLink(for: item)
                    .id(item)
            }
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
        .navigationViewStyle(.stack)
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
                listViewProducer: ViewProducer<SatelliteListViewContext, SatelliteListView>
                    .satelliteListView(viewModel: viewModel),
                singleSatelliteWrappingViewProducer: ViewProducer<SingleSatelliteWrappingViewContext, SingleSatelliteWrappingView>.singleSatelliteWrappingView(viewModel: viewModel),
                observerCellViewProducer: ViewProducer<Void, ObserverCell>.observerCell(viewModel: viewModel),
                locationSettingsViewProducer: ViewProducer<Void, LocationSettingsView>.locationSettings(viewModel: viewModel),
                alarmSettingsCellProducer: ViewProducer<Void, AlarmSettingsCell>.alarmSettingsCell(viewModel: viewModel),
                alarmSettingsViewProducer: ViewProducer<Void, AlarmSettingsView>.alarmSettingsView(viewModel: viewModel)
            )
        }
    }
}

//#if DEBUG
//struct SatelliteOverviewView_Previews: PreviewProvider {
//    static var previews: some View {
//        SatelliteOverviewView(
//            viewModel: .mock(
//                state: SatelliteOverviewViewState(
//                    navigationState: .overview,
//                    julianDate: 0
//                )
//            ),
//            listViewProducer: .crash,
//            singleSatelliteWrappingViewProducer: .crash,
//            observerCellViewProducer: .crash,
//            locationSettingsViewProducer: .crash,
//            alarmSettingsCellProducer: .crash,
//            alarmSettingsViewProducer: .crash
//        )
//    }
//}
//#endif
