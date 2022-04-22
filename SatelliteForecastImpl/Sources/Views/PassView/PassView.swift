//
//  PassView.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 6/5/21.
//

import BTree
import CombineRex
import CombineRextensions
import SatelliteForecast
import SatelliteKit
import SwiftUI
import CoreMotion

public enum PassViewAction {
    case showAlarmConfiguration(Bool)
}

public struct PassViewState {
    public var showAlarmConfigurationModal: Bool

    public init(
        showAlarmConfigurationModal: Bool = false
    ) {
        self.showAlarmConfigurationModal = showAlarmConfigurationModal
    }
}

extension PassViewState: Equatable {}

/// The satellite detail view shows satellite passes and the sky chart during the first visible pass (if available).
public struct PassView: View {
    @ObservedObject var viewModel: ObservableViewModel<PassViewAction, PassViewState>

    var context: PassViewContext
    var elevationGraphProducer: ViewProducer<SatelliteElevationGraphContext, SatelliteElevationGraph>
    var skyChartProducer: ViewProducer<SkyChartContext, SkyChart>
    var passAlarmSettingsProducer: ViewProducer<PassAlarmSettingsModalViewContext, PassAlarmSettingsModalView>

    public init(
        viewModel: ObservableViewModel<PassViewAction, PassViewState>,
        context: PassViewContext,
        elevationGraphProducer: ViewProducer<SatelliteElevationGraphContext, SatelliteElevationGraph>,
        skyChartProducer: ViewProducer<SkyChartContext, SkyChart>,
        passAlarmSettingsProducer: ViewProducer<PassAlarmSettingsModalViewContext, PassAlarmSettingsModalView>
    ) {
        self.viewModel = viewModel
        self.context = context
        self.elevationGraphProducer = elevationGraphProducer
        self.skyChartProducer = skyChartProducer
        self.passAlarmSettingsProducer = passAlarmSettingsProducer
    }

    public var body: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            VStack(spacing: 20) {
                elevationGraphProducer.view(
                    SatelliteElevationGraphContext(
                        satelliteInfo: context.satelliteInfo,
                        julianDateRange: context.julianDateRange,
                        observer: context.observer,
                        configs: .init(),
                        julianDateProvider: context.julianDateProvider
                    )
                )
                .environment(\.julianDateRangeKey, context.julianDateRange)
                .frame(minHeight: 180, idealHeight: 240, maxHeight: 275, alignment: .leading)

                skyChartProducer.view(
                    SkyChartContext(
                        satelliteInfo: context.satelliteInfo,
                        snapshots: context.passSnapshots.snapshots,
                        observer: context.observer,
                        pass: context.passSnapshots.pass,
                        notableSnapshots: context.passSnapshots.notableSnapshots,
                        configs: .preset,
                        quality: .full,
                        julianDateProvider: context.julianDateProvider,
                        deviceMotion: context.deviceMotion
                    )
                )
                .frame(height: min(rect.width, rect.height))
                Spacer(minLength: 10)
            }
            .clipShape(Rectangle())
            .navigationTitle(Date(julianDate: context.passSnapshots.pass.rise.julianDate).formatted(date: .abbreviated, time: .shortened))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(alignment: .center, spacing: 4) {
                        Text(Date(julianDate: context.passSnapshots.pass.rise.julianDate).formatted(date: .abbreviated, time: .shortened))
                            .font(.headline)
                            .frame(alignment: .center)
                            .multilineTextAlignment(.center)
                        Text(PassView.descriptionToolbarText(for: context.passSnapshots.pass))
                            .lineLimit(2)
                            .font(.caption)
                            .frame(alignment: .center)
                            .multilineTextAlignment(.center)
                        Color.clear
                    }
                }

                ToolbarItem(
                    placement: .primaryAction
                ) {
                    Button {
                        viewModel.dispatch(.showAlarmConfiguration(true)
                        )
                    } label: {
                        Image(systemName: "bell")
                    }
                }
            }
            .sheet(
                isPresented: $viewModel.state.showAlarmConfigurationModal,
                onDismiss: {
                    viewModel.dispatch(.showAlarmConfiguration(false)
                    )
                },
                content: {
                    passAlarmSettingsProducer.view(
                        PassAlarmSettingsModalViewContext(
                            satelliteName: context.satelliteInfo.ucsSat?.officialName ??  context.satelliteInfo.elements.commonName,
                            category: context.category,
                            passSnapshots: context.passSnapshots,
                            observer: context.observer
                        )
                    )
                }
            )
        }
    }
}

public struct PassViewContext {
    public let satelliteInfo: SatelliteInfo
    public let category: SatelliteCategory?
    public let julianDateRange: ClosedRange<Double>
    public let observer: LatLonAlt
    public let passSnapshots: PassSnapshots
    public let julianDateProvider: () -> Double
    public let deviceMotion: Loadable<CMDeviceMotion, Error>

    public init(satelliteInfo: SatelliteInfo, category: SatelliteCategory?, julianDateRange: ClosedRange<Double>, observer: LatLonAlt, passSnapshots: PassSnapshots, julianDateProvider: @escaping () -> Double, deviceMotion: Loadable<CMDeviceMotion, Error> = .notLoaded) {
        self.satelliteInfo = satelliteInfo
        self.category = category
        self.julianDateRange = julianDateRange
        self.observer = observer
        self.passSnapshots = passSnapshots
        self.julianDateProvider = julianDateProvider
        self.deviceMotion = deviceMotion
    }
}

extension PassView {
    static func descriptionToolbarText(for pass: Pass) -> String {
        let riseDirection = Directions.angles[Int(floor(limit360(pass.rise.azim) / 45))]
        let setDirection = Directions.angles[Int(floor(limit360(pass.set.azim) / 45))]
        let format = NSLocalizedString(
            "PassView.descriptionToolbar.text",
            tableName: nil,
            bundle: .main,
            value: "Rises from %2$@ and sets into %3$@",
            comment: "The toolbar of the pass view describing the direction of the pass. The first and second arguments correspond to the directions of rising and setting."
        )
        return String(format: format, riseDirection, setDirection)
    }
}

import CoreLocation

#if DEBUG
struct PassView_Previews: PreviewProvider {
    static var previews: some View {
        let elements = try! Elements(
            raw: """
            TIANHE
            1 48274U 21035A   21152.91865056  .00003057  00000-0  33542-4 0  9993
            2 48274  41.4713  16.3199 0005053  25.9394 109.3813 15.65195495  5304
            """
        )
        let julianDateRange = Date().advanced(by: -60 * 60 * 2).julianDate...Date().advanced(by: 60 * 60 * 22).julianDate
        let satelliteInfo = SatelliteInfo(elements: elements)
        // 2000 Broadway, Redwood City, CA 94063
        let observer = LatLonAlt(lat: 37.486743000691185, lon: -122.22655970246515, alt: 0)
        let snapshots = try! satelliteInfo.generateSnapshots(
            observer: observer,
            julianDateRange: julianDateRange
        )
        let passSnapshots = try! satelliteInfo.findPasses(
            observer: observer,
            coarseSnapshots: snapshots
        )
        let skyChartContext = SkyChartContext(
            satelliteInfo: satelliteInfo,
            snapshots: snapshots,
            observer: observer,
            pass: passSnapshots.first!.pass,
            notableSnapshots: passSnapshots.first!.notableSnapshots,
            configs: .preview,
            quality: .preview,
            julianDateProvider: { Date().julianDate }
        )
        let brightest100: Map<UInt, SatelliteInfo> = [
            elements.noradIndex: satelliteInfo
        ]
        let elementPropagatorResources = ElementsPropagatorResources(
            satelliteTrails: [
                elements.noradIndex: SatelliteTrails(
                    observer: observer,
                    snapshots: snapshots,
                    passSnapshots: passSnapshots
                )
            ]
        )
        let satelliteGraphState = SatelliteElevationGraphState(
            satelliteElevationGraphResources: SatelliteElevationGraphResources(),
            elementsPropagatorResources: elementPropagatorResources,
            selectedNoradIndex: elements.noradIndex,
            highlightedDateRange: nil
        )
        let skyChartState = SkyChartViewState(
            julianDateOffset: 0,
            resources: SkyChartResources(
                rasterizedSatellitePaths: [:],
                previewSatellitePaths: [:]
            ),
            backgroundSky: BackgroundSkyResources(),
            elementsPropagatorResources: elementPropagatorResources
        )
        let context = PassViewContext(
            satelliteInfo: SatelliteInfo(elements: elements),
            category: nil,
            julianDateRange: julianDateRange,
            observer: observer,
            passSnapshots: passSnapshots[0],
            julianDateProvider: { Date().julianDate }
        )
        let elevationGraphContext = SatelliteElevationGraphContext(
            satelliteInfo: SatelliteInfo(elements: elements),
            julianDateRange: julianDateRange,
            observer: observer,
            configs: .init(),
            julianDateProvider: { Date().julianDate }
        )
        PassView(
            viewModel: .mock(
                state: PassViewState()
            ),
            context: context,
            elevationGraphProducer: .pure(
                SatelliteElevationGraph(
                    viewModel: .mock(
                        state: satelliteGraphState
                    ),
                    context: elevationGraphContext
                )
            ),
            skyChartProducer: .pure(
                SkyChart(
                    viewModel: .mock(
                        state: skyChartState
                    ),
                    context: skyChartContext,
                    backgroundSkyViewProducer: .pure(
                        BackgroundSkyView(
                            viewModel: .mock(
                                state: BackgroundSkyViewState()
                            ),
                            context: BackgroundSkyViewContext(
                                observer: observer,
                                basicChartConfigs: .init(),
                                configs: .preset,
                                quality: .full
                            )
                        )
                    )
                )
            ),
            passAlarmSettingsProducer: .crash
        )
        .environment(\.julianDateRangeKey, julianDateRange)
        .environment(\.backgroundSkyJulianDateKey, passSnapshots[0].pass.rise.julianDate.roundJulianDate(.toMins(1)))
    }
}
#endif
