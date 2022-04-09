//
//  SatelliteOverviewView.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/24/21.
//

import SatelliteForecast
import SatelliteForecastImpl
import SatelliteKit
import SwiftUI
import SwiftRex
import CombineRex
import CombineRextensions
import CoreLocation

public enum SatelliteOverviewViewAction {
    case selectNavigationItem(
        SatelliteOverviewItem?,
        julianDateRange: ClosedRange<Double>,
        observer: LatLonAlt?
    )
}

public struct SatelliteOverviewViewState: Equatable {
    public var selectedSatelliteOverviewItem: SatelliteOverviewItem?
    public var observer: LatLonAlt?
    public var julianDateOffset: Double = 0

    public init(
        selectedSatelliteOverviewItem: SatelliteOverviewItem? = nil,
        observer: LatLonAlt? = nil,
        julianDateOffset: Double = 0
    ) {
        self.selectedSatelliteOverviewItem = selectedSatelliteOverviewItem
        self.observer = observer
        self.julianDateOffset = julianDateOffset
    }
}

public protocol SatelliteOverviewView: View {}

public struct SatelliteOverviewViewContext {
    public let julianDateProvider: () -> Double

    public init(julianDateProvider: @escaping () -> Double) {
        self.julianDateProvider = julianDateProvider
    }
}

public struct SatelliteOverviewViewImpl: SatelliteOverviewView {
    @ObservedObject var viewModel: ObservableViewModel<SatelliteOverviewViewAction, SatelliteOverviewViewState>
    let context: SatelliteOverviewViewContext
    let listViewProducer: ViewProducer<SatelliteListViewContext, SatelliteListView>
    let singleSatelliteWrappingViewProducer: ViewProducer<SingleSatelliteWrappingViewContext, SingleSatelliteWrappingView>

    public init(
        viewModel: ObservableViewModel<SatelliteOverviewViewAction, SatelliteOverviewViewState>,
        context: SatelliteOverviewViewContext,
        listViewProducer: ViewProducer<SatelliteListViewContext, SatelliteListView>,
        singleSatelliteWrappingViewProducer: ViewProducer<SingleSatelliteWrappingViewContext, SingleSatelliteWrappingView>
    ) {
        self.viewModel = viewModel
        self.context = context
        self.listViewProducer = listViewProducer
        self.singleSatelliteWrappingViewProducer = singleSatelliteWrappingViewProducer
    }

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

    @ViewBuilder private func destination(for item: SatelliteOverviewItem) -> some View {
        switch item {
        case let .specialSatellites(satellite):
            singleSatelliteWrappingViewProducer.view(
                SingleSatelliteWrappingViewContext(
                    selectedNoradIndex: satellite.rawValue,
                    julianDateRange: JulianDateUtil.createJulianDateRange(now: context.julianDateProvider() + viewModel.state.julianDateOffset),
                    observer: viewModel.state.observer,
                    julianDateProvider: context.julianDateProvider
                )
            )
        case let .category(category):
            listViewProducer.view(
                SatelliteListViewContext(
                    category: category,
                    julianDateRange: JulianDateUtil.createJulianDateRange(now: context.julianDateProvider() + viewModel.state.julianDateOffset),
                    observer: viewModel.state.observer,
                    julianDateProvider: context.julianDateProvider
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
                    viewModel.state.selectedSatelliteOverviewItem
                },
                set: {
                    viewModel.dispatch(
                        .selectNavigationItem(
                            $0,
                            julianDateRange: JulianDateUtil.createJulianDateRange(now: context.julianDateProvider() + viewModel.state.julianDateOffset),
                            observer: viewModel.state.observer
                        )
                    )
                }
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

    public var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(
                    alignment: .leading,
                    spacing: 10,
                    pinnedViews: []
                ) {
                    ForEach(sections, id: \.self) { section in
                        Section(
                            header: Text(SatelliteOverviewViewImpl.sectionTitle(section))
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

extension SatelliteOverviewViewImpl {
    static func sectionTitle(_ section: SatelliteOverviewSection) -> String {
        switch section {
        case .satellitesOfSpecialInterest(_):
            return NSLocalizedString(
                "SatelliteListView.sectionOverviewView.section.satellitesOfSpecialInterest",
                tableName: nil,
                bundle: .main,
                value: "Satellites of special interest",
                comment: "The section title for satellites of special interest"
            )
        case .categories(_):
            return NSLocalizedString(
                "SatelliteListView.sectionOverviewView.section.satellitesByCategories",
                tableName: nil,
                bundle: .main,
                value: "Satellites by categories",
                comment: "The section title for satellites grouped by categories"
            )
        }
    }

}

#if DEBUG
struct SatelliteOverviewView_Previews: PreviewProvider {
    static var previews: some View {
        SatelliteOverviewViewImpl(
            viewModel: .mock(
                state: SatelliteOverviewViewState()
            ),
            context: SatelliteOverviewViewContext(
                julianDateProvider: { Date().julianDate }
            ),
            listViewProducer: .crash,
            singleSatelliteWrappingViewProducer: .crash
        )
    }
}
#endif
