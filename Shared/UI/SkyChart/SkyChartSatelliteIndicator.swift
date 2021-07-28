//
//  SatellitePositionIndicator.swift
//  SatellitePositionIndicator
//
//  Created by Ben Lu on 7/25/21.
//

import SwiftUI
import SatelliteForecastCore
import SatelliteKit

struct SkyChartSatelliteIndicatorState: Equatable {
    let coordinate: AziEleDst
}

struct SkyChartSatelliteIndicator: View {
    let state: SkyChartSatelliteIndicatorState

    @State private var radius: CGFloat = 0
    @State private var opacity: CGFloat = 1

    private var repeatingAnimation: Animation {
        Animation
            .easeInOut(duration: 3)
            .repeatForever(autoreverses: false)
    }

    var body: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)

            ZStack {
                Circle(
                )
                .strokeBorder(Color.black, lineWidth: 2)
                .overlay(Circle().fill(Color.white).padding(2))
                .background(
                    Circle().shadow(color: .black, radius: radius, x: 0, y: 0)
                        .opacity(opacity)
                )
                .frame(width: 12, height: 12)
                .onAppear {
                    withAnimation(repeatingAnimation) {
                        self.radius = 10
                        self.opacity = 0
                    }
                }
            }
            .position(
                SkyChart.point(
                    at: AziEleDst(azim: state.coordinate.azim, elev: state.coordinate.elev, dist: 0),
                    rect: rect
                )
            )
        }
    }
}

#if DEBUG
struct SkyChartSatelliteIndicator_Previews: PreviewProvider {
    static var previews: some View {
        SkyChartSatelliteIndicator(
            state: SkyChartSatelliteIndicatorState(
                coordinate: AziEleDst(azim: 0, elev: 30, dist: 0)
            )
        )
        .previewLayout(.fixed(width: 200, height: 200))
    }
}
#endif
