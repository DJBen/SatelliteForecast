//
//  SingleSatelliteWrappingView.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 7/9/21.
//

import SwiftUI
import CombineRex
import CombineRextensions
import SatelliteForecastCore
import SatelliteKit

enum SingleSatelliteWrappingViewAction {
    struct LoadSingleSatelliteParams: Equatable {
        let selectedNoradIndex: UInt
        let julianDateRange: ClosedRange<Double>
        let observer: LatLonAlt?
    }
    case loadSingleSatellite(LoadSingleSatelliteParams)
}

struct SingleSatelliteWrappingViewState: Equatable {
    var satellite: Loadable<SatelliteInfo, ElementsLoaderError> = .notLoaded

    static func project(state: AppState, context: SingleSatelliteWrappingViewContext) -> SingleSatelliteWrappingViewState {
        let noradIndex = context.selectedNoradIndex

        return SingleSatelliteWrappingViewState(
            satellite: state.elementsLoader.info[.brightest100]?.flatMap { satellites in
                satellites[noradIndex]
            } ?? .notLoaded
        )
    }
}

struct SingleSatelliteWrappingView: View {
    @ObservedObject var viewModel: ObservableViewModel<SingleSatelliteWrappingViewAction, SingleSatelliteWrappingViewState>
    let context: SingleSatelliteWrappingViewContext
    let allPassesViewProducer: ViewProducer<AllPassesViewContext, AllPassesView>

    @ViewBuilder func satelliteContent<Content: View, FailedContent: View>(
        @ViewBuilder contentBuilder: (SatelliteInfo) -> Content,
        @ViewBuilder failedContentBuilder: (UInt, ElementsLoaderError) -> FailedContent
    ) -> some View {
        let satellite = viewModel.state.satellite
        Group {
            switch satellite {
            case .notLoaded:
                Text(verbatim: "The satellites are not loaded.")
            case .loading:
                ProgressView("Loading...")
            case let .loaded(satellite):
                contentBuilder(satellite)
            case let .failed(error):
                failedContentBuilder(context.selectedNoradIndex, error)
            }
        }
    }

    var body: some View {
        satelliteContent { satelliteInfo in
            allPassesViewProducer.view(
                AllPassesViewContext(
                    selectedNoradIndex: satelliteInfo.noradIndex,
                    satelliteInfo: satelliteInfo,
                    julianDateRange: context.julianDateRange,
                    observer: context.observer
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

struct SingleSatelliteWrappingViewContext {
    let selectedNoradIndex: UInt
    let julianDateRange: ClosedRange<Double>
    let observer: LatLonAlt?
}

extension ViewProducer where Context == SingleSatelliteWrappingViewContext, ProducedView == SingleSatelliteWrappingView {
    static func singleSatelliteWrappingView<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            SingleSatelliteWrappingView(
                viewModel: viewModel.projection(
                    action: AppAction.singleSatelliteWrappingView,
                    state: { appAction in 
                        SingleSatelliteWrappingViewState.project(
                            state: appAction,
                            context: context
                        )
                    }
                )
                .asObservableViewModel(initialState: .init(), emitsValue: .whenDifferent),
                context: context,
                allPassesViewProducer: ViewProducer<AllPassesViewContext, AllPassesView>
                    .allPassesView(viewModel: viewModel)
            )
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
                observer: nil
            ),
            allPassesViewProducer: .crash
        )
    }
}
#endif
