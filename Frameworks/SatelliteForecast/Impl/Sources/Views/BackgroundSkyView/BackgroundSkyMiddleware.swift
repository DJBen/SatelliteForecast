//
//  BackgroundSkyMiddleware.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 3/3/22.
//

import Combine
import CombineRex
import StarryNight
import SatelliteKit
import SatelliteForecast
import UIKit

extension EffectMiddleware where InputActionType == BackgroundSkyViewAction, OutputActionType == BackgroundSkyViewOutput, StateType == BackgroundSkyResources, Dependencies == Void {
    public static var backgroundSky: EffectMiddleware<BackgroundSkyViewAction, BackgroundSkyViewOutput, BackgroundSkyResources, Void> {
        EffectMiddleware.onAction { action, _, getState in
            switch action {
            case .requestRasterizedBackgroundSky(
                size: let size,
                quality: let quality,
                julianDate: let julianDate,
                key: let key,
                traitCollection: let traitCollection
            ):
                return .promise(token: "") { context, sink in
                    backgroundSkyRasterizationQueue.async {
                        let state = getState()
                        let dataSource = state.dataSource(for: quality)
                        // Skip if image already generated.
                        if let _ = dataSource[key]?[julianDate] {
                            return
                        }

                        let image = SkyChartUtils.rasterizedBackgroundSkyPath(
                            params: BackgroundSkyRenderParams(
                                rect: CGRect(origin: .zero, size: size),
                                stars: {
                                    switch key.configs.stars {
                                    case .none:
                                        return []
                                    case let .limitedMagnitude(mag):
                                        return Star.magitudeLessThan(mag)
                                    }
                                }(),
                                constellations: key.configs.showConstellationLines ? Constellation.all : [],
                                observer: key.observer,
                                julianDate: julianDate,
                                starColor: UIColor(
                                    named: "star",
                                    in: .module,
                                    compatibleWith: traitCollection
                                )!,
                                constellationLineColor: UIColor(
                                    named: "constellationLine",
                                    in: .module,
                                    compatibleWith: traitCollection
                                )!,
                                magToRadius: key.configs.starMagToDisplayRadiusMappingFunction.apply
                            )
                        )

                        //                            logger.debug("Rasterized background sky at observer coodinate \(String(describing: key.observer)) @ JD \(julianDate).")

                        sink(
                            .rasterizedBackgroundSky(image, quality: quality, julianDate: julianDate, key: key)
                        )
                    }
                }
            }
        }
    }
}
