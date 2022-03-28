//
//  MenuView.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/27/22.
//

import CombineRex
import CombineRextensions
import SatelliteForecastCore
import SatelliteKit
import SwiftUI

struct MenuViewContext {
    let sections: [SatelliteOverviewSection]
    let julianDateRange: ClosedRange<Double>
    let observer: LatLonAlt
    @Binding var sectionItem: SatelliteOverviewItem?
}

struct MenuView: View {
    let context: MenuViewContext
    let listViewProducer: ViewProducer<SatelliteListViewContext, SatelliteListView>
    let singleSatelliteWrappingViewProducer: ViewProducer<SingleSatelliteWrappingViewContext, SingleSatelliteWrappingView>
    let observerCellViewProducer: ViewProducer<Void, ObserverCell>
    let locationSettingsViewProducer: ViewProducer<Void, LocationSettingsView>
    let alarmSettingsCellProducer: ViewProducer<Void, AlarmSettingsCell>
    let alarmSettingsViewProducer: ViewProducer<Void, AlarmSettingsView>

    @ViewBuilder private func destination(for item: SatelliteOverviewItem) -> some View {
        switch item {
        case let .specialSatellites(satellite):
            singleSatelliteWrappingViewProducer.view(
                SingleSatelliteWrappingViewContext(
                    selectedNoradIndex: satellite.rawValue,
                    julianDateRange: context.julianDateRange,
                    observer: context.observer
                )
            )
        case let .category(category):
            listViewProducer.view(
                SatelliteListViewContext(
                    category: category,
                    julianDateRange: context.julianDateRange,
                    observer: context.observer
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

    @ViewBuilder private func navigationLink(
        for item: SatelliteOverviewItem
    ) -> some View {
        NavigationLink(
            destination: LazyView(destination(for: item)),
            tag: item,
            selection: context.$sectionItem,
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
                    ForEach(context.sections, id: \.self) { section in
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

struct MenuView_Previews: PreviewProvider {
    static var previews: some View {
        MenuView(
            context: MenuViewContext(
                sections:  [
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
                ],
                julianDateRange: JulianDateUtil.createJulianDateRange(now: 0),
                observer: LatLonAlt(lat: 0, lon: 0, alt: 0),
                sectionItem: .constant(nil)
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
