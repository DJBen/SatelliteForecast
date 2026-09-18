//
//  DetailedPassView.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 5/3/22.
//

import ActivityView
import SatelliteForecast
@preconcurrency import SatelliteKit
import StarryNight
import SwiftUI

/// An enlarged pass view with ability to display details of stars upon tapping.
public struct DetailedPassView: View {
    @Environment(\.dismiss) private var dismiss
    let skyChartFactory: ViewFactory<SkyChartContext<ConstellationLabel, DetailedPassViewBackgroundAnnotationView>, SkyChart<ConstellationLabel, DetailedPassViewBackgroundAnnotationView>>
    let context: DetailPassViewContext

    /// If a star is selected in the background, we expect to show indicator and star information.
    @State var selectedBackgroundStar: Star?

    public init(
        context: DetailPassViewContext,
        skyChartFactory: ViewFactory<SkyChartContext<ConstellationLabel, DetailedPassViewBackgroundAnnotationView>, SkyChart<ConstellationLabel, DetailedPassViewBackgroundAnnotationView>>
    ) {
        self.context = context
        self.skyChartFactory = skyChartFactory
    }

    public var body: some View {
        let magFunc = BackgroundSkyConfigs.StarMagToDisplayRadiusMappingFunction(
            id: "detail"
        ) { mag in
            BackgroundSkyConfigs.StarMagToDisplayRadiusMappingFunction.pointSourceRadius(magnitude: mag, scale: 1.35)
        }

        NavigationStack {
            VStack {
                ScrollView(
                    [.horizontal, .vertical],
                    showsIndicators: true
                ) {
                    skyChartFactory.view(
                        SkyChartContext<ConstellationLabel, DetailedPassViewBackgroundAnnotationView>(
                            satelliteInfo: context.satelliteInfo,
                            observer: context.observer,
                            passSnapshots: context.passSnapshots,
                            configs: SkyChartConfigs(
                                backgroundSkyConfigs: BackgroundSkyConfigs(
                                    stars: .limitedMagnitude(6),
                                    starMagToDisplayRadiusMappingFunction: magFunc,
                                    hidesStarsDuringDay: true,
                                    showConstellationLines: true,
                                    bodySymbol: .text
                                ),
                                basicChartConfigs: BasicChartConfigs(),
                                showPassInfoLabels: true
                            ),
                            quality: .detailed,
                            starManager: context.starManager,
                            julianDateProvider: context.julianDateProvider,
                            constellationLabel: { text in
                                ConstellationLabel(text: text)
                            },
                            backgroundAnnotationView: { raDecToPoint in
                                DetailedPassViewBackgroundAnnotationView(
                                    selectedBackgroundStar: selectedBackgroundStar,
                                    mappingFunction: magFunc,
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
                    .analyticsScreen(.skyDetail)
                    .environment(\.selectedBackgroundStarKey, selectedBackgroundStar)
                    .frame(width: 1000, height: 1000)
                }

                if let selectedBackgroundStar = selectedBackgroundStar {
                    SelectedStarLabel(
                        starManager: context.starManager,
                        star: selectedBackgroundStar,
                    )
                    .padding(.horizontal, 16)
                }
            }
            .background(Color.black)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(
                        NavigationBar.dismiss,
                        role: .cancel
                    ) {
                        dismiss()
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
    public let starManager: AppStarCatalog
    public let julianDateProvider: () -> Double

    public init(
        satelliteInfo: SatelliteInfo,
        category: SatelliteCategory?,
        julianDateRange: ClosedRange<Double>,
        observer: LatLonAlt,
        passSnapshots: PassSnapshots,
        starManager: AppStarCatalog,
        julianDateProvider: @escaping () -> Double
    ) {
        self.satelliteInfo = satelliteInfo
        self.category = category
        self.julianDateRange = julianDateRange
        self.observer = observer
        self.passSnapshots = passSnapshots
        self.starManager = starManager
        self.julianDateProvider = julianDateProvider
    }
}
