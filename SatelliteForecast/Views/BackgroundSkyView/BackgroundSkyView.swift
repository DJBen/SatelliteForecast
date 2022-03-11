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
}

struct BackgroundSkyJulianDateKeyEnvironmentKey: EnvironmentKey {
    static let defaultValue: Double? = nil
}

extension EnvironmentValues {
    var backgroundSkyJulianDateKey: Double? {
        get { self[BackgroundSkyJulianDateKeyEnvironmentKey.self] }
        set { self[BackgroundSkyJulianDateKeyEnvironmentKey.self] = newValue }
    }
}

struct BackgroundSkyView: View {
    @ObservedObject var viewModel: ObservableViewModel<BackgroundSkyViewAction, BackgroundSkyViewState>
    let context: BackgroundSkyViewContext

    @State private var contentSize: CGSize = .zero

    @Environment(\.backgroundSkyJulianDateKey) var backgroundSkyJulianDateKey
    @Environment(\.colorScheme) var colorScheme

    private var rasterizedBackgroundSky: UIImage? {
        guard let backgroundSkyJulianDateKey = backgroundSkyJulianDateKey else {
            return nil
        }

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
            closestTo: backgroundSkyJulianDateKey,
            within: TimeConstants.min2day
        )
    }

    private func sunElevation(julianDate: Double) -> Double {
        azel(
            julianDate: julianDate,
            site: (context.observer.lat, context.observer.lon),
            cele: solarGeo(
                julianDays: julianDate
            )
        ).alt
    }

    @ViewBuilder func backgroundSky(julianDate: Double) -> some View {
        GeometryReader { geometry in
            Group {
                let rect = geometry.frame(in: .local)
                if !(sunElevation(julianDate: julianDate) > -6 &&
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
                        julianDate: julianDate,
                        key: BackgroundSkyKey(
                            observer: context.observer,
                            configs: context.configs
                        ),
                        traitCollection: UITraitCollection(userInterfaceStyle: UIUserInterfaceStyle(colorScheme))
                    )
                )
            }
            .onChange(of: backgroundSkyJulianDateKey) { backgroundSkyJulianDateKey in

                guard !contentSize.width.isZero && !contentSize.height.isZero else {
                    return
                }

                viewModel.dispatch(
                    .requestRasterizedBackgroundSky(
                        size: contentSize,
                        quality: context.quality,
                        // Round date to nearest minute
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
                    sunElevation: sunElevation(julianDate: julianDate)
                )
            }
        }
    }

    var body: some View {
        if let backgroundSkyJulianDateKey = backgroundSkyJulianDateKey {
            SkyChartBackground(
                state: SkyChartBackgroundState(observer: context.observer),
                configs: context.basicChartConfigs
            )
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
