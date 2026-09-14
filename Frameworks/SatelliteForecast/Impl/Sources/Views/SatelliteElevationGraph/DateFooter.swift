//
//  DateFooter.swift
//  DateFooter
//
//  Created by Ben Lu on 7/25/21.
//

import SwiftUI

extension SatelliteElevationGraph {
    struct DateFooterState: Equatable, Sendable {
        let julianDateRange: ClosedRange<Double>
        let configs: SatelliteElevationGraphConfigs
        // Derived data
        let xPercentDatePair: [PercentDate]

        @MainActor
        init(julianDateRange: ClosedRange<Double>, configs: SatelliteElevationGraphConfigs) {
            self.julianDateRange = julianDateRange
            self.configs = configs
            self.xPercentDatePair = SatelliteElevationGraph.xPercentDatePair(julianDateRange: julianDateRange, configs: configs)
        }
    }

    struct DateFooter: View, Equatable {
        let state: DateFooterState
        let width: CGFloat

        var body: some View {
            HStack(alignment: .center, spacing: 0) {
                ForEach(Array(state.xPercentDatePair.enumerated()), id: \.element.julianDate) { (index, pair) in
                    VStack {
                        Text(
                            Date(julianDate: pair.julianDate), format: .dateTime.hour().minute()
                        )
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(width: 80)
                        .offset(x: CGFloat(pair.percent) * width - CGFloat(index) * 80 - 40)
                    }
                }
            }
        }
    }
}

#if DEBUG
struct SatelliteElevationGraph_DateFooter_Previews: PreviewProvider {
    static var previews: some View {
        SatelliteElevationGraph.DateFooter(
            state: SatelliteElevationGraph.DateFooterState(
                julianDateRange: Date().julianDate...Date().julianDate + 2,
                configs: .init()
            ),
            width: 1000
        )
        .previewLayout(.fixed(width: 1000, height: 50))
    }
}
#endif
