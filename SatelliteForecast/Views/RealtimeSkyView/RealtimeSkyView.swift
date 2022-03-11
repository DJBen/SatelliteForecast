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
    case propagateCurrentEphemerides([SatelliteInfo], observer: LatLonAlt, julianDate: Double)
    case setRealtimeSkyViewActive(Bool)
}

extension RealtimeSkyViewAction: Equatable {}

enum RealtimeSkyViewOutput {
    case propagatedCurrentEphemerides(
        results: [UInt: RealtimePropagationResult],
        satellites: [SatelliteInfo],
        partialErrors: [Error],
        observer: LatLonAlt,
        julianDate: Double
    )

    case failedToPropagateCurrentEphemerides(
        error: Error,
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
    var satellites: [SatelliteInfo]?
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
        every: 0.5,
        on: .main,
        in: .common
    )
    .autoconnect()
    .map(\.julianDate)

    @State var julianDate: Double?

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
        }.sorted(by: { result1, result2 in
            if let mag1 = result1.satelliteInfo.qsMag?.magnitude, let mag2 = result1.satelliteInfo.qsMag?.magnitude {
                return mag1 < mag2
            } else if let _ = result1.satelliteInfo.qsMag?.magnitude {
                return true
            } else if let _ = result2.satelliteInfo.qsMag?.magnitude {
                return false
            } else {
                return result1.snapshot.position.dist < result2.snapshot.position.dist
            }
        }))
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
                switch result.satelliteInfo.tle.orbitTypeByAltitude {
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

    @ViewBuilder private var satellitePlot: some View {
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

    @ViewBuilder private func backgroundSkyView(observer: LatLonAlt) -> some View {
        backgroundSkyViewProducer.view(
            BackgroundSkyViewContext(
                observer: observer,
                basicChartConfigs: context.basicChartConfigs,
                configs: context.backgroundSkyConfigs,
                quality: .full
            )
        )
        .environment(
            \.backgroundSkyJulianDateKey,
             julianDate.map { $0.julianDateRoundedToNearestMinute() }
        )
        .overlay {
            satellitePlot
        }
        .onReceive(refreshTimer) { timerJulianDate in
            self.julianDate = timerJulianDate + viewModel.state.julianDateOffset

            guard viewModel.state.resources.isRealtimeSkyViewActive else {
                return
            }
            if viewModel.state.resources.isPropagatingEphemerides {
                return
            }

            guard let satellites = viewModel.state.satellites else {
                return
            }

            viewModel.dispatch(
                .propagateCurrentEphemerides(
                    satellites,
                    observer: observer,
                    julianDate: julianDate!
                )
            )
        }
    }

    @ViewBuilder private var satelliteList: some View {
        List {
            ForEach(visiblePropagationResults.prefix(10), id: \.self) { result in
                RealtimeSkySatelliteCell(
                    satelliteName: result.satelliteInfo.tle.commonName,
                    snapshot: result.snapshot
                )
            }
        }
        .listStyle(.inset)
    }

    var body: some View {
        NavigationView {
            locationView { observer in
                GeometryReader { geometry in
                    let rect = geometry.frame(in: .local)
                    VStack(spacing: 24) {
                        backgroundSkyView(
                            observer: observer
                        )
                        .frame(
                            width: min(rect.width, rect.height),
                            height: min(rect.width, rect.height)
                        )
                        satelliteList
                    }
                    .padding(.top, 16)
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
