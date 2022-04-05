//
//  Background.swift
//  Background
//
//  Created by Ben Lu on 7/25/21.
//

import SwiftUI

struct SatelliteElevationGraphBackgroundState: Equatable {
    let julianDateRange: ClosedRange<Double>
    let configs: SatelliteElevationGraphConfigs
    // Derived data
    let xPercentDatePair: [SatelliteElevationGraph.PercentDate]

    init(julianDateRange: ClosedRange<Double>, configs: SatelliteElevationGraphConfigs) {
        self.julianDateRange = julianDateRange
        self.configs = configs
        self.xPercentDatePair = SatelliteElevationGraph.xPercentDatePair(julianDateRange: julianDateRange, configs: configs)
    }
}

struct SatelliteElevationGraphBackground: View, Equatable {
    static func == (lhs: SatelliteElevationGraphBackground, rhs: SatelliteElevationGraphBackground) -> Bool {
        return lhs.state == rhs.state && lhs.graphingRegionSize == rhs.graphingRegionSize
    }

    let state: SatelliteElevationGraphBackgroundState
    @Binding var graphingRegionSize: CGSize

    private var timeGrid: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)

            Path { path in
                for pair in state.xPercentDatePair {
                    let x = CGFloat(pair.percent) * rect.width
                    // Do not draw vertical lines that are too close to the edges
                    if x - rect.minX < 20 || rect.maxX - x < 20 {
                        continue
                    }
                    path.move(to: CGPoint(x: x, y: rect.minY))
                    path.addLine(to: CGPoint(x: x, y: rect.maxY))
                }
            }
            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        }
    }

    private var elevationGrid: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            let elevIterator = stride(from: -90.0, to: 90.0, by: state.configs.elevationGridLineInterval)
            ZStack {
                Path { path in
                    elevIterator.forEach { elev in
                        let y = CGFloat(elev + 90) / 180 * rect.height
                        path.move(to: CGPoint(x: rect.minX, y: y))
                        path.addLine(to: CGPoint(x: rect.maxX, y: y))
                    }
                }
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)

                Path { path in
                    path.move(to: CGPoint(x: rect.minX, y: rect.midY))
                    path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
                }
                .stroke(Color.gray, lineWidth: 1)
            }
            .modifier(SizeModifier())
            .onPreferenceChange(SizePreferenceKey.self) { size in
                if graphingRegionSize == size {
                    return
                }
                graphingRegionSize = size
            }
        }
    }

    var body: some View {
        timeGrid.overlay(elevationGrid)
    }
}


#if DEBUG
struct SatelliteElevationGraphBackground_Previews: PreviewProvider {
    static var previews: some View {
        SatelliteElevationGraphBackground(
            state: SatelliteElevationGraphBackgroundState(
                julianDateRange: Date().julianDate...Date().julianDate + 1  ,
                configs: .init()
            ),
            graphingRegionSize: .constant(CGSize(width: 1000, height: 250))
        )
        .previewLayout(.fixed(width: 1000, height: 250))
    }
}
#endif
