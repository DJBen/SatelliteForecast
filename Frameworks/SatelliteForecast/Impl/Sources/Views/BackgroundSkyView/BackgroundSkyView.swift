//
//  BackgroundSkyView.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 3/3/22.
//

@preconcurrency import CombineRex
import SatelliteForecast
@preconcurrency import SatelliteKit
import SolarSystem
import StarryNight
import SwiftRex
import SwiftUI

public struct BackgroundSkyViewState {
    public var resources: BackgroundSkyResources = .init()

    public init(resources: BackgroundSkyResources = .init()) {
        self.resources = resources
    }
}

extension BackgroundSkyViewState: Equatable {}

public struct BackgroundSkyViewContext<ConstellationLabel: View, AnnotationView: View> {
    public let observer: LatLonAlt
    public let basicChartConfigs: BasicChartConfigs
    public let configs: BackgroundSkyConfigs
    public let quality: ChartQuality
    public let starManager: any StarManaging
    public let constellationLabel: (String) -> ConstellationLabel
    public let annotationView: (@escaping (RADec) -> CGPoint) -> AnnotationView
    public let starTapped: (Star?) -> Void

    public init(
        observer: LatLonAlt,
        basicChartConfigs: BasicChartConfigs,
        configs: BackgroundSkyConfigs,
        quality: ChartQuality,
        starManager: any StarManaging,
        @ViewBuilder constellationLabel: @escaping (String) -> ConstellationLabel,
        @ViewBuilder annotationView: @escaping (@escaping (RADec) -> CGPoint) -> AnnotationView,
        starTapped: @escaping (Star?) -> Void
    ) {
        self.observer = observer
        self.basicChartConfigs = basicChartConfigs
        self.configs = configs
        self.quality = quality
        self.starManager = starManager
        self.constellationLabel = constellationLabel
        self.annotationView = annotationView
        self.starTapped = starTapped
    }
}

/// A view that renders a alt-alz projection of background sky.
public struct BackgroundSkyView<ConstellationLabel: View, AnnotationView: View>: View {
    @ObservedObject var viewModel: ObservableViewModel<BackgroundSkyViewAction, BackgroundSkyViewState>
    let context: BackgroundSkyViewContext<ConstellationLabel, AnnotationView>

    @State private var contentSize: CGSize = .zero

    @Environment(\.backgroundSkyJulianDateKey) var backgroundSkyJulianDate
    @Environment(\.selectedBackgroundStarKey) var selectedBackgroundStar
    @Environment(\.colorScheme) var colorScheme

    public init(
        viewModel: ObservableViewModel<BackgroundSkyViewAction, BackgroundSkyViewState>,
        context: BackgroundSkyViewContext<ConstellationLabel, AnnotationView>
    ) {
        self.viewModel = viewModel
        self.context = context
    }

    private var rasterizedBackgroundSky: UIImage? {
        guard let backgroundSkyJulianDateKey = backgroundSkyJulianDate else {
            return nil
        }

        let images = viewModel.state.resources.dataSource(for: context.quality)[
            BackgroundSkyKey(
                observer: context.observer,
                configs: context.configs
            )
        ]

        // When time moves forward the background image will be pointed at a new key,
        // causing temporary loss of background sky view.
        // We use the backup image in the past temporarily to fill the gap and ensure smooth display
        let backupKey = (backgroundSkyJulianDateKey - TimeConstants.min2day).roundJulianDate(.toMins(1))
        if let backgroundSkyImage = images?[backgroundSkyJulianDateKey] {
            return backgroundSkyImage
        } else if let backupImage = images?[backupKey] {
            return backupImage
        } else {
            return nil
        }
    }

    private func getStarCoordinateConverter(julianDate: Double, rect: CGRect) -> (RADec) -> CGPoint {
        return { raDec in
            let starAziEle = azel(
                time: Date(julianDate: julianDate),
                site: LatLon(context.observer),
                cele: raDec
            )

            return SkyChartUtils.point(
                at: starAziEle,
                rect: rect
            )
        }
    }

    private func rankedVisibleBodies(julianDate: Double) -> [SolarSystemBody] {
        context.configs.visibleBodies.sorted { body1, body2 in
            body1.distance(to: .earth, julianDate: julianDate) > body2.distance(to: .earth, julianDate: julianDate)
        }
    }

    @ViewBuilder func backgroundSky(julianDate: Double) -> some View {
        GeometryReader { geometry in
            Group {
                let rect = geometry.frame(in: .local)
                if !(
                    azel(
                        time: Date(julianDate: julianDate),
                        site: LatLon(context.observer),
                        cele: RADec(
                            SolarSystemBody.sun.eci(
                                julianDay: julianDate
                            )
                        )
                    ).elev > -6 &&
                    context.configs.hidesStarsDuringDay
                ),
                let image = rasterizedBackgroundSky {
                    Image(
                        uiImage: image
                    )
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: rect.width, height: rect.height, alignment: .center)
                } else {
                    // Needs to have a non-empty view so that views on top of it will have a non-zero size
                    Color.clear
                }
            }
            .modifier(SizeModifier())
            .onPreferenceChange(SizePreferenceKey.self) { contentSize in
                guard !contentSize.width.isZero && !contentSize.height.isZero else {
                    return
                }

                self.contentSize = contentSize

                viewModel.dispatch(
                    .requestRasterizedBackgroundSky(
                        size: contentSize,
                        quality: context.quality,
                        julianDate: julianDate,
                        key: BackgroundSkyKey(
                            observer: context.observer,
                            configs: context.configs
                        ),
                        traitCollection: UITraitCollection(userInterfaceStyle: UIUserInterfaceStyle(colorScheme))
                    )
                )
            }
            .modifier(
                TapGestureDetectionModifier(
                    isEnabled: true
                ) { (point, rect) in
                    switch context.configs.stars {
                    case .none:
                        break
                    case .brightest300:
                        let aziEle = SkyChartUtils.aziEle(at: point, in: rect)
                        let raDec = azelToRADec(aziEle: aziEle, julianDate: julianDate, site: (context.observer.lat, context.observer.lon))
                        let vec = SIMD3<Double>(raDec: raDec)
                        if let star = context.starManager.closestStar(to: vec, maximumMagnitude: 3.52, maximumAngularDistance: nil) {
                            context.starTapped(star)
                        }
                    case .limitedMagnitude(let magnitude):
                        let aziEle = SkyChartUtils.aziEle(at: point, in: rect)
                        let raDec = azelToRADec(aziEle: aziEle, julianDate: julianDate, site: (context.observer.lat, context.observer.lon))
                        let vec = SIMD3<Double>(raDec: raDec)
                        if let star = context.starManager.closestStar(to: vec, maximumMagnitude: magnitude, maximumAngularDistance: nil) {
                            context.starTapped(star)
                        }
                    }
                }
            )
        }
    }

    @ViewBuilder func planetaryBodiesView(julianDate: Double) -> some View {
        ZStack {
            ForEach(rankedVisibleBodies(julianDate: julianDate), id: \.self) { body in
                PlanetaryBodyView(
                    planetaryBody: body,
                    label: context.configs.bodySymbol,
                    magFunction: context.configs.starMagToDisplayRadiusMappingFunction,
                    referenceDate: julianDate,
                    observer: context.observer,
                    sunElevation: azel(
                        time: Date(julianDate: julianDate),
                        site: LatLon(context.observer),
                        cele: RADec(
                            SolarSystemBody.sun.eci(
                                julianDay: julianDate
                            )
                        )
                    ).elev
                )
            }
        }
    }

    @ViewBuilder func constellationLabelView(julianDate: Double) -> some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            ZStack {
                ForEach(viewModel.state.resources.allConstellations) { constellation in
                    let displayCenter = constellation.center
                    let raDec = RADec(displayCenter)
                    let coordinate = azel(
                        time: Date(julianDate: julianDate),
                        site: LatLon(context.observer),
                        cele: raDec
                    )

                    context.constellationLabel(
                        constellation.localizedName
                    )
                    .position(
                        SkyChartUtils.point(
                            at: coordinate,
                            rect: rect
                        )
                    )
                }

                context.annotationView(
                    getStarCoordinateConverter(julianDate: julianDate, rect: rect)
                )
            }
        }
    }

    public var body: some View {
        Group {
            if let backgroundSkyJulianDate = backgroundSkyJulianDate {
                SkyChartLegend(
                    state: SkyChartLegendState(observer: context.observer),
                    configs: context.basicChartConfigs
                )
                .equatable()
                .background(
                    backgroundSky(
                        julianDate: backgroundSkyJulianDate
                    )
                    .overlay(
                        planetaryBodiesView(julianDate: backgroundSkyJulianDate)
                    )
                    .overlay {
                        if context.configs.showConstellationLines {
                            constellationLabelView(julianDate: backgroundSkyJulianDate)
                        }
                    }
                    .clipShape(Circle())
                )
            } else {
                SkyChartLegend(
                    state: SkyChartLegendState(observer: context.observer),
                    configs: context.basicChartConfigs
                )
            }
        }
        .onChange(of: backgroundSkyJulianDate) { _, backgroundSkyJulianDateKey in
            guard !contentSize.width.isZero && !contentSize.height.isZero else {
                return
            }

            guard let backgroundSkyJulianDateKey = backgroundSkyJulianDateKey else {
                return
            }

            viewModel.dispatch(
                .requestRasterizedBackgroundSky(
                    size: contentSize,
                    quality: context.quality,
                    julianDate: backgroundSkyJulianDateKey,
                    key: BackgroundSkyKey(
                        observer: context.observer,
                        configs: context.configs
                    ),
                    traitCollection: UITraitCollection(userInterfaceStyle: UIUserInterfaceStyle(colorScheme))
                )
            )
        }
    }
}

#if DEBUG

struct BackgroundSkyView_Previews: PreviewProvider {
    static var previews: some View {
        BackgroundSkyView(
            viewModel: .mock(
                state: .init()
            ),
            context: BackgroundSkyViewContext(
                observer: LatLonAlt(0, 0, 0),
                basicChartConfigs: .init(),
                configs: .preset,
                quality: .full,
                starManager: StarManagerMock(),
                constellationLabel: { _ in EmptyView() },
                annotationView: { _ in EmptyView() },
                starTapped: { _ in }
            )
        )
        .environment(\.backgroundSkyJulianDateKey, 0)
    }
}

#endif
