//
//  SkyChartGestureModifier.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 4/10/22.
//

import SwiftUI

struct SkyChartGestureModifier: ViewModifier {
    let isGestureEnabled: Bool
    let contentRect: CGRect

    func body(content: Content) -> some View {
        if isGestureEnabled {
            content
            .gesture(
                DragGesture(
                    minimumDistance: 0
                )
                .onChanged { value in
                    let aziEle = SkyChart.aziEle(at: value.location, in: contentRect)
                    print("changed \(value.location)")
                    print("changed \(aziEle)")
                }
                .onEnded { value in
                    print("end \(value.location)")
                }
                .simultaneously(
                    with: TapGesture(
                    )
                    .onEnded {
                        print("tapped")
                    }
                )
            )
        } else {
            content
        }
    }
}
