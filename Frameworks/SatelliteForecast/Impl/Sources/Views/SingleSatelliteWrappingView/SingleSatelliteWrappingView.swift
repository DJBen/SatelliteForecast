//
//  SingleSatelliteWrappingView.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 7/9/21.
//

import BTree
import SwiftUI
@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import SatelliteForecast
@preconcurrency import SatelliteKit

public struct SingleSatelliteWrappingViewState: Equatable {
    public var elementsLoader: ElementsLoaderResources = .init()

    public init(elementsLoader: ElementsLoaderResources = .init()) {
        self.elementsLoader = elementsLoader
    }
}

public struct SingleSatelliteWrappingViewContext {
    public let selectedNoradIndex: UInt
    public let julianDateRange: ClosedRange<Double>
    public let observer: LatLonAlt?
    public let julianDateProvider: () -> Double

    public init(selectedNoradIndex: UInt, julianDateRange: ClosedRange<Double>, observer: LatLonAlt?, julianDateProvider: @escaping () -> Double) {
        self.selectedNoradIndex = selectedNoradIndex
        self.julianDateRange = julianDateRange
        self.observer = observer
        self.julianDateProvider = julianDateProvider
    }
}

public struct SingleSatelliteWrappingView: View {
    @ObservedObject var viewModel: ObservableViewModel<SingleSatelliteWrappingViewAction, SingleSatelliteWrappingViewState>
    let context: SingleSatelliteWrappingViewContext
    let allPassesViewProducer: ViewProducer<AllPassesViewContext, AllPassesView>

    public init(
        viewModel: ObservableViewModel<SingleSatelliteWrappingViewAction, SingleSatelliteWrappingViewState>,
        context: SingleSatelliteWrappingViewContext,
        allPassesViewProducer: ViewProducer<AllPassesViewContext, AllPassesView>
    ) {
        self.viewModel = viewModel
        self.context = context
        self.allPassesViewProducer = allPassesViewProducer
    }

    private var satellite: Loadable<SatelliteInfo, ElementsLoaderError> {
        let category: SatelliteCategory = if context.selectedNoradIndex == 25544 {
            .iss
        } else {
            .tianhe
        }
        return viewModel.state.elementsLoader.info[category]?.flatMap { satellites in
            satellites[context.selectedNoradIndex]
        } ?? .notLoaded
    }

    @ViewBuilder func satelliteContent<Content: View, FailedContent: View>(
        @ViewBuilder contentBuilder: (SatelliteInfo) -> Content,
        @ViewBuilder failedContentBuilder: (UInt, ElementsLoaderError) -> FailedContent
    ) -> some View {
        Group {
            switch satellite {
            case .notLoaded:
                Text("The satellites are not loaded.", bundle: .module)
            case .loading:
                ProgressView {
                    Text("Loading...", bundle: .module)
                }
            case let .loaded(satellite):
                contentBuilder(satellite)
            case let .failed(error):
                failedContentBuilder(context.selectedNoradIndex, error)
            }
        }
    }

    public var body: some View {
        satelliteContent { satelliteInfo in
            allPassesViewProducer.view(
                AllPassesViewContext(
                    satelliteInfo: satelliteInfo,
                    julianDateRange: context.julianDateRange,
                    observer: context.observer,
                    julianDateProvider: context.julianDateProvider
                )
            )
        }
        failedContentBuilder: { noradIndex, error in
            VStack(spacing: 16) {
                Text(error.localizedDescription)

                if let observer = context.observer {
                    Button(
                        "Retry",
                        action: {
                            viewModel.dispatch(
                                .loadSingleSatellite(
                                    .init(
                                        selectedNoradIndex: noradIndex,
                                        julianDateRange: context.julianDateRange,
                                        observer: observer
                                    )
                                )
                            )
                        }
                    )
                    .font(Font.headline)
                    .foregroundColor(Color(UIColor.systemBlue))
                }
            }
        }
    }
}

#if DEBUG

struct SingleSatelliteWrappingView_Previews: PreviewProvider {
    static var previews: some View {
        SingleSatelliteWrappingView(
            viewModel: .mock(state: .init()),
            context: SingleSatelliteWrappingViewContext(
                selectedNoradIndex: 0,
                julianDateRange: Date(daysSince1950: 1000).julianDate...Date(daysSince1950: 1002).julianDate,
                observer: nil,
                julianDateProvider: { Date(daysSince1950: 1001).julianDate }
            ),
            allPassesViewProducer: .crash
        )
    }
}

#endif
