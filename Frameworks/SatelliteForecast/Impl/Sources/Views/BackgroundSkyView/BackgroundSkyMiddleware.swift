//
//  BackgroundSkyMiddleware.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 3/3/22.
//

import Combine
@preconcurrency import CombineRex
import StarryNight
@preconcurrency import SatelliteKit
import SatelliteForecast
import UIKit

public typealias BackgroundSkyEffectMiddleware = EffectMiddleware<BackgroundSkyViewAction, BackgroundSkyViewOutput, BackgroundSkyResources, any StarManaging>

extension EffectMiddleware where InputActionType == BackgroundSkyViewAction, OutputActionType == BackgroundSkyViewOutput, StateType == BackgroundSkyResources, Dependencies == Void {
    
    public static var backgroundSky: MiddlewareReader<any StarManaging, BackgroundSkyEffectMiddleware> {
        BackgroundSkyEffectMiddleware.onAction { action, _, getState in
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
                                        return context.dependencies.stars(maximumMagnitude: mag)
                                    }
                                }(),
                                constellations: key.configs.showConstellationLines ? context.dependencies.allConstellations() : [],
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
                            ),
                            starManager: context.dependencies
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
