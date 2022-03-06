//
//  BackgroundSkyView.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/3/22.
//

import BTree
import CombineRex
import SatelliteForecastCore
import SatelliteKit
import SwiftRex
import SwiftUI

/// A key uniquely determining the rendering of a sky chart's background. Same key is guaranteed to render the same background.
struct BackgroundSkyKey: Equatable, Hashable {
    let observer: LatLonAlt
    let configs: BackgroundSkyConfigs
}

enum BackgroundSkyViewAction {
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

enum BackgroundSkyViewOutput {
    case rasterizedBackgroundSky(
        UIImage,
        quality: ChartQuality,
        julianDate: Double,
        key: BackgroundSkyKey
    )
}

struct BackgroundSkyViewState {
    var resources: BackgroundSkyResources = .init()
}

extension BackgroundSkyViewState: Equatable {}

struct BackgroundSkyViewContext {
    let observer: LatLonAlt
    let basicChartConfigs: BasicChartConfigs
    let configs: BackgroundSkyConfigs
    let quality: ChartQuality
    let backgroundSkyJulianDateKey: Double
}

struct BackgroundSkyView: View {
    @ObservedObject var viewModel: ObservableViewModel<BackgroundSkyViewAction, BackgroundSkyViewState>
    let context: BackgroundSkyViewContext

    @State private var contentSize: CGSize = .zero

    @Environment(\.colorScheme) var colorScheme

    private var rasterizedBackgroundSky: UIImage? {
        let imageCache: [BackgroundSkyKey: BTree<Double, UIImage>] = (
            context.quality == .full ?
            viewModel.state.resources.rasterizedBackgroundSky
            : viewModel.state.resources.previewBackgroundSkies
        )

        return imageCache[
            BackgroundSkyKey(
                observer: context.observer,
                configs: context.configs
            )
        ]?.value(
            closestTo: context.backgroundSkyJulianDateKey,
            within: TimeConstants.min2day
        )
    }

    private var sunElevation: Double {
        azel(
            julianDate: context.backgroundSkyJulianDateKey,
            site: (context.observer.lat, context.observer.lon),
            cele: solarGeo(
                julianDays: context.backgroundSkyJulianDateKey
            )
        ).alt
    }

    @ViewBuilder var backgroundSky: some View {
        GeometryReader { geometry in
            Group {
                let rect = geometry.frame(in: .local)
                if !(sunElevation > -6 &&
                     context.configs.hidesStarsDuringDay),
                   let image = rasterizedBackgroundSky {
                    Image(uiImage: image)
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
                        julianDate: context.backgroundSkyJulianDateKey,
                        key: BackgroundSkyKey(
                            observer: context.observer,
                            configs: context.configs
                        ),
                        traitCollection: UITraitCollection(userInterfaceStyle: UIUserInterfaceStyle(colorScheme))
                    )
                )
            }
            .onChange(of: context.backgroundSkyJulianDateKey) { backgroundSkyJulianDateKey in

                guard !contentSize.width.isZero && !contentSize.height.isZero else {
                    return
                }

                viewModel.dispatch(
                    .requestRasterizedBackgroundSky(
                        size: contentSize,
                        quality: context.quality,
                        // Round date to nearest minute
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

    @ViewBuilder var planetaryBodiesView: some View {
        ZStack {
            ForEach(context.configs.visibleBodies, id: \.self) { body in
                PlanetaryBodyView(
                    planetaryBody: body,
                    label: context.configs.bodySymbol,
                    referenceDate: context.backgroundSkyJulianDateKey,
                    observer: context.observer,
                    sunElevation: sunElevation
                )
            }
        }
    }

    var body: some View {
        SkyChartBackground(
            state: SkyChartBackgroundState(observer: context.observer),
            configs: context.basicChartConfigs
        )
        .background(
            backgroundSky.overlay(
                planetaryBodiesView
            )
            .clipShape(Circle())
        )
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
                quality: .full,
                backgroundSkyJulianDateKey: 0
            )
        )
    }
}

#endif
