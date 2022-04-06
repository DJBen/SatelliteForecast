//
//  BackgroundSkyView.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/3/22.
//

import CombineRex
import SatelliteForecast
import SatelliteKit
import SolarSystem
import SwiftRex
import SwiftUI

public enum BackgroundSkyViewAction {
    /// Request a rasterized version of the background sky.
    /// The caller should group the call and reduce frequency by rounding the date to a nearest minute, for example.
    case requestRasterizedBackgroundSky(
        size: CGSize,
        quality: ChartQuality,
        julianDate: Double,
        key: BackgroundSkyKey,
        traitCollection: UITraitCollection
    )
}

extension BackgroundSkyViewAction: Equatable {}

public enum BackgroundSkyViewOutput {
    case rasterizedBackgroundSky(
        UIImage,
        quality: ChartQuality,
        julianDate: Double,
        key: BackgroundSkyKey
    )
}

public struct BackgroundSkyViewState {
    public var resources: BackgroundSkyResources = .init()

    public init(resources: BackgroundSkyResources = .init()) {
        self.resources = resources
    }
}

extension BackgroundSkyViewState: Equatable {}

public struct BackgroundSkyViewContext {
    public let observer: LatLonAlt
    public let basicChartConfigs: BasicChartConfigs
    public let configs: BackgroundSkyConfigs
    public let quality: ChartQuality

    public init(observer: LatLonAlt, basicChartConfigs: BasicChartConfigs, configs: BackgroundSkyConfigs, quality: ChartQuality) {
        self.observer = observer
        self.basicChartConfigs = basicChartConfigs
        self.configs = configs
        self.quality = quality
    }
}

public struct BackgroundSkyView: View {
    @ObservedObject var viewModel: ObservableViewModel<BackgroundSkyViewAction, BackgroundSkyViewState>
    let context: BackgroundSkyViewContext

    @State private var contentSize: CGSize = .zero

    @Environment(\.backgroundSkyJulianDateKey) var backgroundSkyJulianDateKey
    @Environment(\.colorScheme) var colorScheme

    public init(
        viewModel: ObservableViewModel<BackgroundSkyViewAction, BackgroundSkyViewState>,
        context: BackgroundSkyViewContext
    ) {
        self.viewModel = viewModel
        self.context = context
    }

    private var rasterizedBackgroundSky: UIImage? {
        guard let backgroundSkyJulianDateKey = backgroundSkyJulianDateKey else {
            return nil
        }

        let imageCache: [BackgroundSkyKey: [Double: UIImage]] = (
            context.quality == .full ?
            viewModel.state.resources.rasterizedBackgroundSky
            : viewModel.state.resources.previewBackgroundSkies
        )

        let images = imageCache[
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

    @ViewBuilder func backgroundSky(julianDate: Double) -> some View {
        GeometryReader { geometry in
            Group {
                let rect = geometry.frame(in: .local)
                if !(SolarSystemBody.sun.aziEle(julianDay: julianDate, observer: context.observer).elev > -6 &&
                     context.configs.hidesStarsDuringDay),
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
        }
    }

    @ViewBuilder func planetaryBodiesView(julianDate: Double) -> some View {
        ZStack {
            ForEach(context.configs.visibleBodies, id: \.self) { body in
                PlanetaryBodyView(
                    planetaryBody: body,
                    label: context.configs.bodySymbol,
                    referenceDate: julianDate,
                    observer: context.observer,
                    sunElevation: SolarSystemBody.sun.aziEle(julianDay: julianDate, observer: context.observer).elev
                )
            }
        }
    }

    public var body: some View {
        Group {
            if let backgroundSkyJulianDateKey = backgroundSkyJulianDateKey {
                SkyChartBackground(
                    state: SkyChartBackgroundState(observer: context.observer),
                    configs: context.basicChartConfigs
                )
                .equatable()
                .background(
                    backgroundSky(
                        julianDate: backgroundSkyJulianDateKey
                    )
                    .overlay(
                        planetaryBodiesView(julianDate: backgroundSkyJulianDateKey)
                    )
                    .clipShape(Circle())
                )
            } else {
                SkyChartBackground(
                    state: SkyChartBackgroundState(observer: context.observer),
                    configs: context.basicChartConfigs
                )
            }
        }
        .onChange(of: backgroundSkyJulianDateKey) { backgroundSkyJulianDateKey in
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
                observer: LatLonAlt(lat: 0, lon: 0, alt: 0),
                basicChartConfigs: .init(),
                configs: .preset,
                quality: .full
            )
        )
        .environment(\.backgroundSkyJulianDateKey, 0)
    }
}

#endif
