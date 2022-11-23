//
//  DetailedPassViewBackgroundAnnotationView.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 11/22/22.
//

import SwiftUI
import SatelliteForecast
import SatelliteKit
import StarryNight

public struct DetailedPassViewBackgroundAnnotationView: View {
    let selectedBackgroundStar: Star?
    let mappingFunction: BackgroundSkyConfigs.StarMagToDisplayRadiusMappingFunction
    let raDecToPoint: (RADec) -> CGPoint

    public init(
        selectedBackgroundStar: Star?,
        mappingFunction: BackgroundSkyConfigs.StarMagToDisplayRadiusMappingFunction,
        raDecToPoint: @escaping (RADec) -> CGPoint
    ) {
        self.selectedBackgroundStar = selectedBackgroundStar
        self.mappingFunction = mappingFunction
        self.raDecToPoint = raDecToPoint
    }

    public var body: some View {
        GeometryReader { geometry in
            if let selectedBackgroundStar = selectedBackgroundStar {
                Path { path in
                    let point = raDecToPoint(RADec(vector: selectedBackgroundStar.physicalInfo.coordinate))
                    let len = mappingFunction.apply(selectedBackgroundStar.physicalInfo.apparentMagnitude) + 4

                    path.move(to: CGPoint(x: point.x - len, y: point.y))
                    path.addLine(to: CGPoint(x: point.x - len - 4, y: point.y))
                    path.move(to: CGPoint(x: point.x + len, y: point.y))
                    path.addLine(to: CGPoint(x: point.x + len + 4, y: point.y))
                    path.move(to: CGPoint(x: point.x, y: point.y - len))
                    path.addLine(to: CGPoint(x: point.x, y: point.y - len - 4))
                    path.move(to: CGPoint(x: point.x, y: point.y + len))
                    path.addLine(to: CGPoint(x: point.x, y: point.y + len + 4))

                    path.addEllipse(
                        in: CGRect(x: point.x - len - 2, y: point.y - len - 2, width: len * 2 + 4, height: len * 2 + 4)
                    )
                }
                .stroke(.white, lineWidth: 1)
            }
        }
    }
}


#if DEBUG

struct DetailedPassViewBackgroundAnnotationView_Previews: PreviewProvider {
    static var previews: some View {
        DetailedPassViewBackgroundAnnotationView(
            selectedBackgroundStar: Star.hr(7001)!,
            mappingFunction: BackgroundSkyConfigs.StarMagToDisplayRadiusMappingFunction(
                multipler: 6,
                exponent: -0.4
            )
        ) { _ in
            CGPoint(x: 25, y: 25)
        }
        .background(Color.black)
        .previewLayout(.fixed(width: 100, height: 100))
    }
}

#endif
