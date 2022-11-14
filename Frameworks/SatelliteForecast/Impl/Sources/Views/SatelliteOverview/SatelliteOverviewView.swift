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
    case selectSatelliteOfSpecialInterest(
        SatellitesOfSpecialInterest?,
        julianDateRange: ClosedRange<Double>,
        observer: LatLonAlt?
    )

    case selectCategory(
        SatelliteCategory?,
        julianDateRange: ClosedRange<Double>,
        observer: LatLonAlt?
    )
}

public struct SatelliteOverviewViewState: Equatable {
    public var satellite: SatellitesOfSpecialInterest?
    public var category: SatelliteCategory?
    public var observer: LatLonAlt?
    public var julianDateOffset: Double = 0

    public init(
        satellite: SatellitesOfSpecialInterest? = nil,
        category: SatelliteCategory? = nil,
        observer: LatLonAlt? = nil,
        julianDateOffset: Double = 0
    ) {
        self.satellite = satellite
        self.category = category
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

    @ViewBuilder private func navigationLink(
        satelliteOfSpecialInterest satellite: SatellitesOfSpecialInterest
    ) -> some View {
        NavigationLink(
            destination: LazyView {
                singleSatelliteWrappingViewProducer.view(
                    SingleSatelliteWrappingViewContext(
                        selectedNoradIndex: satellite.noradIndex,
                        julianDateRange: JulianDateUtil.createJulianDateRange(now: context.julianDateProvider() + viewModel.state.julianDateOffset),
                        observer: viewModel.state.observer,
                        julianDateProvider: context.julianDateProvider
                    )
                )
            },
            tag: satellite,
            selection: Binding<SatellitesOfSpecialInterest?>(
                get: {
                    viewModel.state.satellite
                },
                set: {
                    viewModel.dispatch(
                        .selectSatelliteOfSpecialInterest(
                            $0,
                            julianDateRange: JulianDateUtil.createJulianDateRange(now: context.julianDateProvider() + viewModel.state.julianDateOffset),
                            observer: viewModel.state.observer
                        )
                    )
                }
            ),
            label: {
                SatelliteOverviewSpecialSatelliteCell(satellite: satellite)
            }
        )
    }

    @ViewBuilder private func navigationLink(
        category: SatelliteCategory
    ) -> some View {
        NavigationLink(
            destination: LazyView {
                listViewProducer.view(
                    SatelliteListViewContext(
                        category: category,
                        julianDateRange: JulianDateUtil.createJulianDateRange(now: context.julianDateProvider() + viewModel.state.julianDateOffset),
                        observer: viewModel.state.observer,
                        julianDateProvider: context.julianDateProvider
                    )
                )
            },
            tag: category,
            selection: Binding<SatelliteCategory?>(
                get: {
                    viewModel.state.category
                },
                set: {
                    viewModel.dispatch(
                        .selectCategory(
                            $0,
                            julianDateRange: JulianDateUtil.createJulianDateRange(now: context.julianDateProvider() + viewModel.state.julianDateOffset),
                            observer: viewModel.state.observer
                        )
                    )
                }
            ),
            label: {
                SatelliteOverviewCategoryCell(category: category)
            }
        )
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(
                    alignment: .leading,
                    spacing: 10,
                    pinnedViews: []
                ) {
                    Section(
                        header: Text(SatelliteOverviewViewImpl.satelliteOfSpecialInterestSectionTitle)
                            .font(.headline.lowercaseSmallCaps().weight(.semibold))
                            .foregroundColor(Color(UIColor.secondaryLabel))
                    ) {
                        ForEach(
                            [
                                SatellitesOfSpecialInterest.iss,
                                SatellitesOfSpecialInterest.tianhe
                            ],
                            id: \.self
                        ) { satellite in
                            navigationLink(satelliteOfSpecialInterest: satellite)
                        }
                    }

                    Section(
                        header: Text(SatelliteOverviewViewImpl.categoriesSectionTitle)
                            .font(.headline.lowercaseSmallCaps().weight(.semibold))
                            .foregroundColor(Color(UIColor.secondaryLabel))
                    ) {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ],
                            alignment: .leading,
                            spacing: 10
                        ) {
                            ForEach(
                                [
                                    SatelliteCategory.brightest100,
                                    SatelliteCategory.active,
                                    SatelliteCategory.last30DayLaunches
                                ],
                                id: \.self
                            ) { category in
                                navigationLink(category: category).id(category)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitle("Overview", displayMode: .inline)
            .navigationBarHidden(true)
        }
    }
}

extension SatelliteOverviewViewImpl {
    static let satelliteOfSpecialInterestSectionTitle = NSLocalizedString(
        "SatelliteListView.sectionOverviewView.section.satellitesOfSpecialInterest",
        tableName: nil,
        bundle: .main,
        value: "Satellites of special interest",
        comment: "The section title for satellites of special interest"
    )

    static let categoriesSectionTitle = NSLocalizedString(
        "SatelliteListView.sectionOverviewView.section.satellitesByCategories",
        tableName: nil,
        bundle: .main,
        value: "Satellites by categories",
        comment: "The section title for satellites grouped by categories"
    )
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
