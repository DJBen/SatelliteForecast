//
//  AuxiliaryCompassView.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 4/9/22.
//

import SwiftUI
import SatelliteForecast
@preconcurrency import SatelliteKit

public struct AuxiliaryCompassView<AziEleProvider: AziEleProviding>: View {
    var aziEleProvider: AziEleProvider

    public var body: some View {
        GeometryReader { geometry in
            let frame = geometry.frame(in: .local)
            let squareFrame = CGRect(
                origin: frame.origin,
                size: CGSize(
                    width: min(frame.width, frame.height),
                    height: min(frame.width, frame.height)
                )
            )
            let targetPoint = SkyChartUtils.point(at: aziEleProvider, rect: squareFrame)
            let rimPoint = SkyChartUtils.point(
                at: AziEle(azim: aziEleProvider.azim, elev: 0),
                rect: squareFrame
            )
            let rimPointInsetted = SkyChartUtils.point(
                at: AziEle(azim: aziEleProvider.azim, elev: 0),
                rect: squareFrame.inset(by: .init(top: 5, left: 5, bottom: 5, right: 5))
            )
            Path { path in
                path.addLines([rimPoint, targetPoint])
            }
            .stroke(Color.blue, lineWidth: 1)

            Image(
                systemName: "arrowtriangle.up.fill"
            )
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 10, height: 10)
            .foregroundColor(.blue)
            .rotationEffect(Angle(degrees: -aziEleProvider.azim))
            .position(rimPointInsetted)

            Image(
                systemName: "multiply"
            )
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 10, height: 10)
            .foregroundColor(.blue)
            .rotationEffect(Angle(degrees: -aziEleProvider.azim))
            .position(targetPoint)
        }
    }
}

#if DEBUG

struct AuxiliaryCompassView_Previews: PreviewProvider {
    static var previews: some View {
        AuxiliaryCompassView(
            aziEleProvider: AziEle(azim: 0, elev: 30)
        )
        .previewLayout(.fixed(width: 200, height: 200))

        AuxiliaryCompassView(
            aziEleProvider: AziEle(azim: 214, elev: 67)
        )
        .previewLayout(.fixed(width: 200, height: 200))

        AuxiliaryCompassView(
            aziEleProvider: AziEle(azim: 90, elev: 90)
        )
        .previewLayout(.fixed(width: 200, height: 200))
    }
}

#endif
