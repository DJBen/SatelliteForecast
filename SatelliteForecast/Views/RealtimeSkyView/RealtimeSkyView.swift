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
        results: [UInt: RealtimePropagationResult],
        tles: [TLE],
        observer: LatLonAlt,
        julianDate: Double
    )
}

struct RealtimeSkyViewResources {
    /// The propagation results containing the satellite snapshot, and an "expiration date" of the snapshot.
    var results: [UInt: RealtimePropagationResult] = [:]
    var isRealtimeSkyViewActive: Bool = false
    var isPropagatingEphemerides: Bool = false
}

extension RealtimeSkyViewResources: Equatable {}

struct RealtimeSkyViewState {
    var resources: RealtimeSkyViewResources = .init()
    var tles: [TLE] = []
    var observer: LatLonAlt?
    var julianDateOffset: Double = 0
}

extension RealtimeSkyViewState: Equatable {}

struct RealtimeSkyViewContext {
    let basicChartConfigs: BasicChartConfigs
    let backgroundSkyConfigs: BackgroundSkyConfigs
}

protocol RealtimeSkyView: View {}

struct RealtimeSkyViewImpl: RealtimeSkyView {
    @ObservedObject var viewModel: ObservableViewModel<RealtimeSkyViewAction, RealtimeSkyViewState>
    let context: RealtimeSkyViewContext

    let backgroundSkyViewProducer: ViewProducer<BackgroundSkyViewContext, BackgroundSkyView>

    let refreshTimer = Timer.publish(
        every: 1,
        on: .main,
        in: .common
    )
    .autoconnect()
    .map(\.julianDate)

    @State var julianDate: Double = 0

    @ViewBuilder private func locationView<Content: View, NoLocationContent: View>(
        @ViewBuilder contentBuilder: (LatLonAlt) -> Content,
        @ViewBuilder noLocationContentBuilder: () -> NoLocationContent
    ) -> some View {
        if let observer = viewModel.state.observer {
            contentBuilder(observer)
        } else {
            noLocationContentBuilder()
        }
    }

    private var visiblePropagationResults: [RealtimePropagationResult] {
        Array(viewModel.state.resources.results.values.filter {
            $0.snapshot.position.elev > 0
        })
    }

    @ViewBuilder private func satellitePoint(result: RealtimePropagationResult, rect: CGRect) -> some View {
        HStack(spacing: 0) {
            Path { path in
                path.addArc(
                    center: CGPoint(x: rect.midX, y: rect.midY),
                    radius: 1,
                    startAngle: Angle(degrees: 0),
                    endAngle: Angle(degrees: 360),
                    clockwise: false
                )
                path.closeSubpath()
            }
            .fill()
            .foregroundColor({
                switch result.tle.orbitTypeByAltitude {
                case .leo:
                    return .blue
                case .geo:
                    return .yellow
                case .meo, .heo:
                    return .green
                }
            }())

//            Text(
//                "\(result.noradIndex)"
//            )
//                .font(.system(size: 6, weight: .regular, design: .default))
//                .foregroundColor(.blue)
//                .offset(x: 1 + 2)
//                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private func satellitePlot() -> some View {
        ForEach(
            visiblePropagationResults,
            id: \.noradIndex
        ) { result in
            GeometryReader { geometry in
                let rect = geometry.frame(in: .local)
                satellitePoint(
                    result: result,
                    rect: rect
                )
                .position(
                    SkyChart.point(
                        at: result.snapshot.position,
                        rect: rect
                    )
                )
            }
        }
    }

    var body: some View {
        NavigationView {
            locationView { observer in
                backgroundSkyViewProducer.view(
                    BackgroundSkyViewContext(
                        observer: observer,
                        basicChartConfigs: context.basicChartConfigs,
                        configs: context.backgroundSkyConfigs,
                        quality: .full
                    )
                )
                .environment(\.backgroundSkyJulianDateKey, julianDate.julianDateRoundedToNearestMinute())
                .overlay {
                    satellitePlot()
                }
                .onReceive(refreshTimer) { timerJulianDate in
                    self.julianDate = timerJulianDate + viewModel.state.julianDateOffset

                    guard viewModel.state.resources.isRealtimeSkyViewActive else {
                        return
                    }
                    if viewModel.state.resources.isPropagatingEphemerides {
                        return
                    }

                    viewModel.dispatch(
                        .propagateCurrentEphemerides(
                            viewModel.state.tles,
                            observer: observer,
                            julianDate: julianDate
                        )
                    )
                }
            } noLocationContentBuilder: {
                Text(verbatim: "Location not available")
            }
            .navigationTitle(Self.Navigation.title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
        .onAppear {
            viewModel.dispatch(.setRealtimeSkyViewActive(true))
        }
        .onDisappear {
            viewModel.dispatch(.setRealtimeSkyViewActive(false))
        }
    }
}

extension RealtimeSkyViewImpl {
    enum Navigation {
        static var title: String {
            NSLocalizedString(
                "realtimeSkyView.navigation.title",
                tableName: nil,
                bundle: .main,
                value: "Realtime sky",
                comment: "The navigation title of the realtime sky view"
            )
        }
    }
}

#if DEBUG

struct RealtimeSkyView_Previews: PreviewProvider {
    static var previews: some View {
        RealtimeSkyViewImpl(
            viewModel: .mock(
                state: .init()
            ),
            context: RealtimeSkyViewContext(
                basicChartConfigs: .init(),
                backgroundSkyConfigs: .init()
            ),
            backgroundSkyViewProducer: .pure(
                BackgroundSkyView(
                    viewModel: .mock(
                        state: BackgroundSkyViewState()
                    ),
                    context: BackgroundSkyViewContext(
                        observer: LatLonAlt(lat: 0, lon: 0, alt: 0),
                        basicChartConfigs: .init(),
                        configs: .init(),
                        quality: .full
                    )
                )
            )
        )
        .environment(\.backgroundSkyJulianDateKey, 0)
    }
}

#endif
