//
//  SatelliteOverviewView.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/24/21.
//

import SatelliteForecast
import SatelliteKit
import SwiftUI
import SwiftRex
import CombineRex
import CombineRextensions
import CoreLocation

enum SatelliteOverviewViewAction {
    struct SelectSpecialSatelliteParams: Equatable {
        let noradIndex: UInt
        let julianDateRange: ClosedRange<Double>
        let observer: LatLonAlt?
    }
    case selectSpecialSatellite(SelectSpecialSatelliteParams)
    case selectCategory(SatelliteCategory)
    case selectObserver
    case selectAlert
    case returnToSatelliteOverview
}

struct SatelliteOverviewViewState: Equatable {
    var navigationState: NavigationState = .init()
    var julianDate: Double = 0
    var location: CLLocation?
}

protocol SatelliteOverviewView: View {}

struct SatelliteOverviewViewImpl: SatelliteOverviewView {
    @ObservedObject var viewModel: ObservableViewModel<SatelliteOverviewViewAction, SatelliteOverviewViewState>
    let listViewProducer: ViewProducer<SatelliteListViewContext, SatelliteListView>
    let singleSatelliteWrappingViewProducer: ViewProducer<SingleSatelliteWrappingViewContext, SingleSatelliteWrappingView>

    let sections: [SatelliteOverviewSection] = [
        .satellitesOfSpecialInterest([
            .specialSatellites(.iss),
            .specialSatellites(.tianhe)
        ]),
        .categories([
            .category(.brightest100),
            .category(.active),
            .category(.last30DayLaunches)
        ])
    ]

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
        case .none:
            viewModel.dispatch(.returnToSatelliteOverview)
        }
    }

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
                    )
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
        case .satellitesOfSpecialInterest(_):
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

#if DEBUG
struct SatelliteOverviewView_Previews: PreviewProvider {
    static var previews: some View {
        SatelliteOverviewViewImpl(
            viewModel: .mock(
                state: SatelliteOverviewViewState(
                    navigationState: .init(),
                    julianDate: 0
                )
            ),
            listViewProducer: .crash,
            singleSatelliteWrappingViewProducer: .crash
        )
    }
}
#endif
