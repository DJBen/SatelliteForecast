//
//  SatellitePositionIndicator.swift
//  SatellitePositionIndicator
//
//  Created by Ben Lu on 7/25/21.
//

import SwiftUI
import SatelliteForcastCore
import SatelliteKit

extension SkyChart {
    struct SatellitePositionIndicatorState: Equatable {
        let coordinate: AziEleDst
    }

    struct SatellitePositionIndicator: View {
        let state: SatellitePositionIndicatorState

        @State private var scale: CGFloat = 1

        private var repeatingAnimation: Animation {
            Animation
                .easeInOut(duration: 3)
                .repeatForever(autoreverses: false)
        }

        var body: some View {
            GeometryReader { geometry in
                let rect = geometry.frame(in: .local)

                Circle(
                )
                .frame(width: 10, height: 10)
                .foregroundColor(.blue)
                .scaleEffect(scale)
                .position(
                    SkyChart.point(
                        at: AziEleDst(azim: state.coordinate.azim, elev: state.coordinate.elev, dist: 0),
                        rect: rect
                    )
                )
                .onAppear {
                    withAnimation(repeatingAnimation) {
                        self.scale = 2
                    }
                }
            }
        }
    }
}

#if DEBUG
struct SkyChart_SatellitePositionIndicator_Previews: PreviewProvider {
    static var previews: some View {
        SkyChart.SatellitePositionIndicator(
            state: SkyChart.SatellitePositionIndicatorState(
                coordinate: AziEleDst(azim: 0, elev: 30, dist: 0)
            )
        )
        .previewLayout(.fixed(width: 200, height: 200))
    }
}
#endif
