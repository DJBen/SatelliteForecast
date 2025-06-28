//
//  SatelliteOverviewView.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/24/21.
//

import SatelliteForecast
@preconcurrency import SatelliteKit
import SwiftUI
@preconcurrency import SwiftRex
@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import CoreLocation

public enum SatelliteOverviewViewAction {
    case navigate(
        NavigationPath
    )
    
    case onAppear(
        julianDateRange: ClosedRange<Double>,
        observer: LatLonAlt?
    )

    case selectSatellite(
        specialSatellite: SpecialSatellite,
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
    let singleSatelliteWrappingViewProducer: ViewProducer<SingleSatelliteWrappingViewContext, SingleSatelliteWrappingView>

    public init(
        viewModel: ObservableViewModel<SatelliteOverviewViewAction, SatelliteOverviewViewState>,
        context: SatelliteOverviewViewContext,
        singleSatelliteWrappingViewProducer: ViewProducer<SingleSatelliteWrappingViewContext, SingleSatelliteWrappingView>
    ) {
        self.viewModel = viewModel
        self.context = context
        self.singleSatelliteWrappingViewProducer = singleSatelliteWrappingViewProducer
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
                    spacing: 24,
                    pinnedViews: []
                ) {
                    Section {
                        ForEach(
                            [
                                SatelliteCategory.iss,
                                SatelliteCategory.tianhe
                            ],
                            id: \.self
                        ) { satellite in
                            NavigationLink(value: SpecialSatellite(satellite)) {
                                SatelliteOverviewSpecialSatelliteCell(satellite: satellite)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitle("Overview", displayMode: .inline)
            .navigationBarHidden(true)
            .navigationDestination(for: SpecialSatellite.self) { specialSatellite in
                LazyView {
                    singleSatelliteWrappingViewProducer.view(
                        SingleSatelliteWrappingViewContext(
                            selectedNoradIndex: specialSatellite.rawValue,
                            julianDateRange: JulianDateUtil.createJulianDateRange(now: context.julianDateProvider() + viewModel.state.julianDateOffset),
                            observer: viewModel.state.observer,
                            julianDateProvider: context.julianDateProvider
                        )
                    )
                }
            }
        }
        .tint(Color(uiColor: .label))
        .onAppear {
            viewModel.dispatch(
                .onAppear(
                    julianDateRange: JulianDateUtil.createJulianDateRange(now: context.julianDateProvider() + viewModel.state.julianDateOffset),
                    observer: viewModel.state.observer
                )
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
            singleSatelliteWrappingViewProducer: .crash
        )
    }
}
#endif
