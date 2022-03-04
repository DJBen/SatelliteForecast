//
//  RealtimeSkyView.swift
//  RealtimeSkyView
//
//  Created by Ben Lu on 3/2/22.
//

import CombineRex
import CombineRextensions
import SatelliteForecastCore
import SatelliteKit
import SwiftRex
import SwiftUI

enum RealtimeSkyViewAction {
    case propagateCurrentEphemerides([TLE], observer: LatLonAlt, julianDate: Double)
    case setRealtimeSkyViewActive(Bool)
}

extension RealtimeSkyViewAction: Equatable {}

enum RealtimeSkyViewOutput {
    case propagatedCurrentEphemerides(
        results: [Int: RealtimePropagationResult],
        tles: [TLE],
        observer: LatLonAlt,
        julianDate: Double
    )
}

struct RealtimeSkyViewResources {
    var results: [Int: RealtimePropagationResult] = [:]
    var nextCheckDates: [Int: Double] = [:]
}

extension RealtimeSkyViewResources: Equatable {}

struct RealtimeSkyViewState {
    var resources: RealtimeSkyViewResources = .init()
    var tles: [TLE] = []
    var observer: LatLonAlt = .init(lat: 0, lon: 0, alt: 0)
    var julianDateOffset: Double = 0
    var isRealtimeSkyViewActive: Bool = false
    var isPropagatingEphemerides: Bool = false
}

extension RealtimeSkyViewState: Equatable {}

struct RealtimeSkyView: View {
    @ObservedObject var viewModel: ObservableViewModel<RealtimeSkyViewAction, RealtimeSkyViewState>

    let refreshTimer = Timer.publish(
        every: 1,
        on: .main,
        in: .common
    )
    .autoconnect()
    .map(\.julianDate)

    var body: some View {
        Text(
            "Hello, World!"
        )
        .onReceive(refreshTimer) { timerJulianDate in
            guard viewModel.state.isRealtimeSkyViewActive else {
                return
            }
            if viewModel.state.isPropagatingEphemerides {
                return
            }
            let julianDate = timerJulianDate + viewModel.state.julianDateOffset
            viewModel.dispatch(
                .propagateCurrentEphemerides(
                    viewModel.state.tles,
                    observer: viewModel.state.observer,
                    julianDate: julianDate
                )
            )
        }
        .onAppear {
            viewModel.dispatch(.setRealtimeSkyViewActive(true))
        }
        .onDisappear {
            viewModel.dispatch(.setRealtimeSkyViewActive(false))
        }
    }
}

#if DEBUG

struct RealtimeSkyView_Previews: PreviewProvider {
    static var previews: some View {
        RealtimeSkyView(
            viewModel: .mock(state: .init())
        )
    }
}

#endif
