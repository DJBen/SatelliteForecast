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
    case navigate(
        NavigationPath
    )

    case selectSatelliteOfSpecialInterest(
        SatellitesOfSpecialInterest,
        julianDateRange: ClosedRange<Double>,
        observer: LatLonAlt?
    )

    case loadSatelliteOfSpecialInterest(
        SatellitesOfSpecialInterest,
        julianDateRange: ClosedRange<Double>,
        observer: LatLonAlt?
    )

    case loadCategory(
        SatelliteCategory,
        julianDateRange: ClosedRange<Double>,
        observer: LatLonAlt?
    )
}

public struct SatelliteOverviewViewState: Equatable {
    public var navigationPath: NavigationPath
    public var observer: LatLonAlt?
    public var julianDateOffset: Double = 0

    public init(
        navigationPath: NavigationPath = .init(),
        observer: LatLonAlt? = nil,
        julianDateOffset: Double = 0
    ) {
        self.navigationPath = navigationPath
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

    public var body: some View {
        return NavigationStack(
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
                            NavigationLink(value: satellite) {
                                SatelliteOverviewSpecialSatelliteCell(satellite: satellite)
                            }
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
                                NavigationLink(value: category) {
                                    SatelliteOverviewCategoryCell(category: category)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitle("Overview", displayMode: .inline)
            .navigationBarHidden(true)
            .navigationDestination(for: SatellitesOfSpecialInterest.self) { satelliteOfSpecialInterest in
                LazyView {
                    singleSatelliteWrappingViewProducer.view(
                        SingleSatelliteWrappingViewContext(
                            selectedNoradIndex: satelliteOfSpecialInterest.noradIndex,
                            julianDateRange: JulianDateUtil.createJulianDateRange(now: context.julianDateProvider() + viewModel.state.julianDateOffset),
                            observer: viewModel.state.observer,
                            julianDateProvider: context.julianDateProvider
                        )
                    )
                    .onAppear {
                        viewModel.dispatch(
                            .loadSatelliteOfSpecialInterest(
                                satelliteOfSpecialInterest,
                                julianDateRange: JulianDateUtil.createJulianDateRange(now: context.julianDateProvider() + viewModel.state.julianDateOffset),
                                observer: viewModel.state.observer
                            )
                        )
                    }
                }
            }
            .navigationDestination(for: SatelliteCategory.self) { category in
                LazyView {
                    listViewProducer.view(
                        SatelliteListViewContext(
                            category: category,
                            julianDateRange: JulianDateUtil.createJulianDateRange(now: context.julianDateProvider() + viewModel.state.julianDateOffset),
                            observer: viewModel.state.observer,
                            julianDateProvider: context.julianDateProvider
                        )
                    )
                    .onAppear {
                        viewModel.dispatch(
                            .loadCategory(
                                category,
                                julianDateRange: JulianDateUtil.createJulianDateRange(now: context.julianDateProvider() + viewModel.state.julianDateOffset),
                                observer: viewModel.state.observer
                            )
                        )
                    }
                }
            }
        }
    }
}

extension SatelliteOverviewViewImpl {
    static let satelliteOfSpecialInterestSectionTitle = NSLocalizedString(
        "SatelliteListView.sectionOverviewView.section.satellitesOfSpecialInterest",
        tableName: nil,
        bundle: .satelliteForecastImplResourcesBundle,
        value: "Satellites of special interest",
        comment: "The section title for satellites of special interest"
    )

    static let categoriesSectionTitle = NSLocalizedString(
        "SatelliteListView.sectionOverviewView.section.satellitesByCategories",
        tableName: nil,
        bundle: .satelliteForecastImplResourcesBundle,
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
