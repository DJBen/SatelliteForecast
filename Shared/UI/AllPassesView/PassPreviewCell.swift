//
//  PassPreviewCell.swift
//  SatelliteForcast (iOS)
//
//  Created by Ben Lu on 6/15/21.
//

import BTree
import SwiftUI
import SatelliteForcastCore
import SatelliteKit
import CombineRex
import CombineRextensions

struct PassPreviewCell: View {
    var pass: PassInformation
    var indexOfPass: Int
    var skyChartProducer: ViewProducer<Int, SkyChart>

    static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("H:mm:ss")
        return formatter
    }()

    static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.usesSignificantDigits = true
        formatter.maximumSignificantDigits = 3
        return formatter
    }()

    var visiblityColor: Color {
        switch pass.visibility {
        case .visible:
            return .green
        case .unlit:
            return Color(.sRGB, red: 0 / 255, green: 3 / 255, blue: 61 / 255, opacity: 1)
        case .daylight:
            return Color(.sRGB, red: 255 / 255, green: 196 / 255, blue: 137 / 255, opacity: 1)
        }
    }

    var body: some View {
        HStack {
            Rectangle()
                .foregroundColor(visiblityColor)
                .frame(width: 8, alignment: .leading)

            VStack {
                Text(LocalizedStrings.PassPreviewCell.titleForPassVisibility(pass.visibility))
                    .font(.caption)
                    .italic()

                Text("∠\(Self.numberFormatter.string(from: NSNumber(value: pass.transit.elev))!)°")
                    .font(.body)

                HStack(spacing: 0) {
                    Image(systemName: "arrow.up")
                        .font(.caption)
                    Text(Self.formatter.string(from: Date(julianDate: pass.rise.julianDate)))
                        .font(.caption)
                }
                HStack(spacing: 0) {
                    Image(systemName: "arrow.up.to.line")
                        .font(.caption)
                    Text(Self.formatter.string(from: Date(julianDate: pass.transit.julianDate)))
                        .font(.caption)
                }
                HStack(spacing: 0) {
                    Image(systemName: "arrow.down")
                        .font(.caption)
                    Text(Self.formatter.string(from: Date(julianDate: pass.set.julianDate)))
                        .font(.caption)
                }
            }

            skyChartProducer.view(indexOfPass)
                .padding(5)
        }
    }
}

struct PassPreviewCell_Previews: PreviewProvider {
    static var previews: some View {
        let tle = try! TLE(
            raw: """
            ISS (ZARYA)
            1 25544U 98067A   21155.08058252  .00001489  00000-0  35252-4 0  9997
            2 25544  51.6446  47.5538 0003512  61.1482  91.5411 15.48950578286563
            """
        )
        let sat = Satellite(withTLE: tle)
        // 2000 Broadway, Redwood City, CA 94063
        let observerCoordinate = LatLonAlt(lat: 37.486743000691185, lon: -122.22655970246515, alt: 0)
        // Date range
        let startDate = Date(timeIntervalSinceReferenceDate: 20 * 365 * 86400)
        let julianDateRange = startDate.advanced(by: -60 * 60 * 2).julianDate..<startDate.advanced(by: 60 * 60 * 30).julianDate
        let snapshots = sat.snapshots(
            observer: observerCoordinate,
            julianDateRange: julianDateRange,
            interval: 60
        )
        let (passes, fineSnapshots) = sat.findPasses(
            observer: observerCoordinate,
            coarseSnapshots: snapshots
        )

        func viewAtPassIndex(_ index: Int) -> some View {
            let pass = passes[index]
            let snapshotsDuringPass = fineSnapshots.submap(from: pass.rise.julianDate, through: pass.set.julianDate)
            return PassPreviewCell(
                pass: pass,
                indexOfPass: 0,
                skyChartProducer: .pure(
                    SkyChart(
                        viewModel: .mock(
                            state: SkyChartViewState(
                                mode: .pass(
                                    pass,
                                    snapshotsDuringPass: snapshotsDuringPass,
                                    observer: observerCoordinate
                                )
                            )
                        ),
                        configs: SkyChartConfigs(
                            backgroundSky: SkyChartConfigs.BackgroundSky(
                                showStars: false,
                                showConstellationLines: false,
                                visibileBodies: [.sun, .moon],
                                bodySymbol: .symbol
                            ),
                            showAzimuthTexts: false,
                            azimuthMarkInterval: 90,
                            azimuthMarkLength: 2,
                            showDirections: false,
                            showPassInfoLabels: false
                        )
                    )
                )
            )
            .previewLayout(.fixed(width: 200, height: 100))
        }

        return Group {
            viewAtPassIndex(0)
            viewAtPassIndex(2)
            viewAtPassIndex(3)
            viewAtPassIndex(4)
            viewAtPassIndex(5)
        }
    }
}
