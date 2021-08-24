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
    case loadSingleSatellite
    case calculateSingleSatellitePass(noradIndex: Int)
}

struct SingleSatelliteWrappingViewState: Equatable {
    var satellite: Result<SatelliteInfo, SatelliteLoaderError>?

    static var empty: SingleSatelliteWrappingViewState {
        SingleSatelliteWrappingViewState()
    }

    static func project(state: AppState, context: SingleSatelliteWrappingViewContext) -> SingleSatelliteWrappingViewState {
        let noradIndex = context.selectedNoradIndex
        let satellite: Result<SatelliteInfo, SatelliteLoaderError>?
        switch state.satelliteLoaderState.info[.brightest100] {
        case .none:
            satellite = nil
        case let .success(satellites):
            satellite = satellites[noradIndex].map { .success($0) }
        case let .failure(error):
            satellite = .failure(error)
        }

        return SingleSatelliteWrappingViewState(
            satellite: satellite
        )
    }
}

struct SingleSatelliteWrappingView: View {
    @ObservedObject var viewModel: ObservableViewModel<SingleSatelliteWrappingViewAction, SingleSatelliteWrappingViewState>
    let context: SingleSatelliteWrappingViewContext
    let allPassesViewProducer: ViewProducer<AllPassesViewContext, AllPassesView>

    @ViewBuilder func satelliteContent<Content: View, FailedContent: View>(
        @ViewBuilder contentBuilder: (SatelliteInfo) -> Content,
        @ViewBuilder failedContentBuilder: (Int, SatelliteLoaderError) -> FailedContent
    ) -> some View {
        let satellite = viewModel.state.satellite
        Group {
            switch satellite {
            case .none:
                ProgressView("Loading...")
            case let .success(satellite):
                contentBuilder(satellite)
            case let .failure(error):
                failedContentBuilder(context.selectedNoradIndex, error)
            }
        }
        .onAppear {
            if case .success(_) = satellite {
                viewModel.dispatch(.calculateSingleSatellitePass(noradIndex: context.selectedNoradIndex))
            }
        }
        .onChange(of: satellite) { newValue in
            if newValue == .none {
                return
            }
            
            viewModel.dispatch(.calculateSingleSatellitePass(noradIndex: context.selectedNoradIndex))
        }
    }

    var body: some View {
        satelliteContent { satelliteInfo in
            allPassesViewProducer.view(
                AllPassesViewContext(
                    selectedNoradIndex: satelliteInfo.noradIndex,
                    satelliteInfo: satelliteInfo,
                    julianDateRange: context.julianDateRange
                )
            )
        }
        failedContentBuilder: { noradIndex, error in
            VStack(spacing: 16) {
                Text(error.localizedDescription)

                Button(
                    "Retry",
                    action: { viewModel.dispatch(.loadSingleSatellite) }
                )
                .font(Font.headline)
                .foregroundColor(Color(UIColor.systemBlue))
            }
        }
    }
}

struct SingleSatelliteWrappingViewContext {
    var selectedNoradIndex: Int
    var julianDateRange: Range<Double>
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
                .asObservableViewModel(initialState: .empty, emitsValue: .whenDifferent),
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
            viewModel: .mock(state: .empty),
            context: SingleSatelliteWrappingViewContext(
                selectedNoradIndex: 0,
                julianDateRange: Date(daysSince1950: 1000).julianDate..<Date(daysSince1950: 1002).julianDate
            ),
            allPassesViewProducer: .crash
        )
    }
}
#endif
