//
//  SkyChartDynamicIndicator.swift
//  SkyChartDynamicIndicator
//
//  Created by Ben Lu on 7/28/21.
//

import Combine
import SwiftUI
import SatelliteForecastCore
import SatelliteKit

struct SkyChartDynamicIndicatorState: Equatable {
    let tle: TLE
    let pass: Pass
    let observer: LatLonAlt
    let julianDateOffset: Double
}

/// A dynamic indicator of the position of the passing satellite.
/// It is only visible when the satellite is currently above horizon.
struct SkyChartDynamicIndicator: View {
    var state: SkyChartDynamicIndicatorState

    @State var snapshotPairAtReferenceDate: SnapshotsAroundPass?

    let refreshTimer = Timer.publish(
        every: 0.2,
        on: .main,
        in: .common
    )
    .autoconnect()
    .map(\.julianDate)

    @Environment(\.colorScheme) var colorScheme

    static let labelDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("H:mm:ss.S")
        return formatter
    }()

    static let labelAngleFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    @ViewBuilder var currentPositionIndicator: some View {
        if let snapshotPair = snapshotPairAtReferenceDate {
            SkyChartSatelliteIndicator(
                state: SkyChartSatelliteIndicatorState(
                    coordinate: snapshotPair.first.position
                )
            )
        }
    }

    @ViewBuilder var currentPositionLabel: some View {
        if let snapshotPair = snapshotPairAtReferenceDate {
            GeometryReader { geometry in
                let rect = geometry.frame(in: .local)

                SkyChart.PassLabel(
                    text: """
                    ∠\(Self.labelAngleFormatter.string(from: NSNumber(value: snapshotPair.first.position.elev))!)°
                    \(Self.labelDateFormatter.string(from: Date(julianDate: snapshotPair.first.julianDate)))
                    """,
                    snapshotPair: snapshotPair,
                    rect: rect,
                    modifierFactory: HighlightedPassLabelModifier.curry(shouldHighlight: snapshotPair.first.isIlluminated)
                )
                .blurEffectStyle(colorScheme == .light ? .systemMaterialDark : .systemMaterialLight)
                .vibrancyEffectStyle(.fill)
            }
        }
    }

    var body: some View {
        currentPositionLabel
            .overlay(currentPositionIndicator)
            .onReceive(refreshTimer) { realJulianDate in
                let julianDate = realJulianDate + state.julianDateOffset
                if (state.pass.rise.julianDate..<state.pass.set.julianDate).contains(julianDate) {
                    do {
                        snapshotPairAtReferenceDate = SnapshotsAroundPass(
                            first: try state.tle.snapshot(
                                julianDate: julianDate,
                                observer: state.observer
                            ),
                            second: try state.tle.snapshot(
                                julianDate: julianDate + TimeConstants.sec2day * 1,
                                observer: state.observer
                            )
                        )
                    } catch {
                        snapshotPairAtReferenceDate = nil
                    }
                } else {
                    snapshotPairAtReferenceDate = nil
                }
            }
    }
}

#if DEBUG
struct SkyChartDynamicIndicator_Previews: PreviewProvider {
    static var previews: some View {
        EmptyView()
        .previewLayout(.fixed(width: 200, height: 200))
    }
}
#endif
