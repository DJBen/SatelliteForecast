//
//  DetailedPassView.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 5/3/22.
//

import ActivityView
import CombineRex
import CombineRextensions
import SatelliteForecast
import SatelliteKit
import StarryNight
import SwiftRex
import SwiftUI

public enum DetailedPassViewAction {
    case dismissModal
}

extension DetailedPassViewAction: Equatable {}

public struct DetailedPassViewState {
    public var showsDetailedPassView: Bool

    public init(
        showsDetailedPassView: Bool = false
    ) {
        self.showsDetailedPassView = showsDetailedPassView
    }
}

extension DetailedPassViewState: Equatable {}

/// An enlarged pass view with ability to display details of stars upon tapping.
public struct DetailedPassView: View {
    @ObservedObject var viewModel: ObservableViewModel<DetailedPassViewAction, DetailedPassViewState>
    let skyChartProducer: ViewProducer<SkyChartContext<ConstellationLabel, DetailedPassViewBackgroundAnnotationView>, SkyChart<ConstellationLabel, DetailedPassViewBackgroundAnnotationView>>
    let context: DetailPassViewContext

    /// If a star is selected in the background, we expect to show indicator and star information.
    @State var selectedBackgroundStar: Star?

    public init(
        viewModel: ObservableViewModel<DetailedPassViewAction, DetailedPassViewState>,
        context: DetailPassViewContext,
        skyChartProducer: ViewProducer<SkyChartContext<ConstellationLabel, DetailedPassViewBackgroundAnnotationView>, SkyChart<ConstellationLabel, DetailedPassViewBackgroundAnnotationView>>
    ) {
        self.viewModel = viewModel
        self.context = context
        self.skyChartProducer = skyChartProducer
    }

    public var body: some View {
        NavigationStack {
            VStack {
                ScrollView(
                    [.horizontal, .vertical],
                    showsIndicators: true
                ) {
                    skyChartProducer.view(
                        SkyChartContext<ConstellationLabel, DetailedPassViewBackgroundAnnotationView>(
                            satelliteInfo: context.satelliteInfo,
                            snapshots: context.passSnapshots.snapshots,
                            observer: context.observer,
                            pass: context.passSnapshots.pass,
                            notableSnapshots: context.passSnapshots.notableSnapshots,
                            configs: SkyChartConfigs(
                                backgroundSkyConfigs: BackgroundSkyConfigs(
                                    stars: .limitedMagnitude(5.5),
                                    starMagToDisplayRadiusMappingFunction: BackgroundSkyConfigs.StarMagToDisplayRadiusMappingFunction(
                                        multipler: 6,
                                        exponent: -0.4
                                    ),
                                    hidesStarsDuringDay: true,
                                    showConstellationLines: true,
                                    bodySymbol: .text
                                ),
                                basicChartConfigs: BasicChartConfigs(),
                                showPassInfoLabels: true
                            ),
                            quality: .detailed,
                            julianDateProvider: context.julianDateProvider,
                            constellationLabel: { text in
                                ConstellationLabel(text: text)
                            },
                            backgroundAnnotationView: { raDecToPoint in
                                DetailedPassViewBackgroundAnnotationView(
                                    selectedBackgroundStar: selectedBackgroundStar,
                                    mappingFunction: BackgroundSkyConfigs.StarMagToDisplayRadiusMappingFunction(
                                        multipler: 6,
                                        exponent: -0.4
                                    ),
                                    raDecToPoint: raDecToPoint
                                )
                            },
                            backgroundStarTapped: { star in
                                if let selectedBackgroundStar = selectedBackgroundStar, selectedBackgroundStar == star {
                                    self.selectedBackgroundStar = nil
                                } else {
                                    self.selectedBackgroundStar = star
                                }
                            }
                        )
                    )
                    .environment(\.selectedBackgroundStarKey, selectedBackgroundStar)
                    .frame(width: 1000, height: 1000)
                }

                if let selectedBackgroundStar = selectedBackgroundStar {
                    SelectedStarLabel(
                        star: selectedBackgroundStar
                    )
                    .padding(.horizontal, 16)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(
                        NavigationBar.dismiss,
                        role: .cancel
                    ) {
                        viewModel.dispatch(.dismissModal)
                    }
                }
            }
        }
    }
}

extension DetailedPassView {
    enum NavigationBar {
        static let title = NSLocalizedString(
            "DetailedPassView.navigationBar.title",
            tableName: nil,
            bundle: .module,
            value: "Schedule alarm",
            comment: "Navigation title of detailed pass view."
        )

        static let dismiss = NSLocalizedString(
            "DetailedPassView.navigationBar.discard",
            tableName: nil,
            bundle: .module,
            value: "Dismiss",
            comment: "Title of dismiss button of detailed pass view."
        )
    }
}

public struct DetailPassViewContext {
    public let satelliteInfo: SatelliteInfo
    public let category: SatelliteCategory?
    public let julianDateRange: ClosedRange<Double>
    public let observer: LatLonAlt
    public let passSnapshots: PassSnapshots
    public let julianDateProvider: () -> Double

    public init(satelliteInfo: SatelliteInfo, category: SatelliteCategory?, julianDateRange: ClosedRange<Double>, observer: LatLonAlt, passSnapshots: PassSnapshots, julianDateProvider: @escaping () -> Double) {
        self.satelliteInfo = satelliteInfo
        self.category = category
        self.julianDateRange = julianDateRange
        self.observer = observer
        self.passSnapshots = passSnapshots
        self.julianDateProvider = julianDateProvider
    }
}

#if DEBUG

struct DetailedPassView_Previews: PreviewProvider {
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

        DetailedPassView(
            viewModel: .mock(state: .init()),
            context: DetailPassViewContext(
                satelliteInfo: SatelliteInfo(elements: elements),
                category: nil,
                julianDateRange: julianDateRange,
                observer: observer,
                passSnapshots: passSnapshots[0],
                julianDateProvider: { Date().julianDate }
            ),
            skyChartProducer: .crash
        )
    }
}

#endif
