//
//  PassPreviewCell.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/15/21.
//

import BTree
import SwiftUI
import SatelliteForcastCore
import SatelliteKit
import CombineRex
import CombineRextensions

struct PassPreviewCell: View, Equatable {
    static func == (lhs: PassPreviewCell, rhs: PassPreviewCell) -> Bool {
        return lhs.pass == rhs.pass && lhs.indexOfPass == rhs.indexOfPass
    }

    var pass: Pass
    var indexOfPass: Int
    var skyChartProducer: ViewProducer<SkyChartContext, SkyChart>

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("H:mm:ss")
        return formatter
    }()

    static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
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
        HStack(alignment: .center) {
            Rectangle()
                .foregroundColor(visiblityColor)
                .frame(width: 12, alignment: .leading)

            VStack(alignment: .leading) {
                Text(LocalizedStrings.PassPreviewCell.titleForPassVisibility(pass.visibility))
                    .font(.headline)
                Text("∠\(Self.numberFormatter.string(from: NSNumber(value: pass.transit.elev))!)°")
                    .font(.body)
            }
            .frame(width: 80)

            VStack(alignment: .leading) {
                Text(Self.dateFormatter.string(from: Date(julianDate: pass.rise.julianDate)))
                    .font(.headline)
                    .padding([.bottom], 1)

                HStack(spacing: 0) {
                    Image(systemName: "arrow.up")
                        .font(.subheadline)
                        .foregroundColor(Color(UIColor.secondaryLabel))

                    Text(Self.timeFormatter.string(from: Date(julianDate: pass.rise.julianDate)))
                        .font(.subheadline)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
                HStack(spacing: 0) {
                    Image(systemName: "arrow.up.to.line")
                        .font(.subheadline)
                        .foregroundColor(Color(UIColor.secondaryLabel))

                    Text(Self.timeFormatter.string(from: Date(julianDate: pass.transit.julianDate)))
                        .font(.subheadline)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
                HStack(spacing: 0) {
                    Image(systemName: "arrow.down")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .foregroundColor(Color(UIColor.secondaryLabel))

                    Text(Self.timeFormatter.string(from: Date(julianDate: pass.set.julianDate)))
                        .font(.subheadline)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
            }

            skyChartProducer.view(
                SkyChartContext(
                    usage: .preview(index: indexOfPass)
                )
            )
            .padding(5)
        }
    }
}

#if DEBUG
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
        let coarseSnapshots = sat.snapshots(
            observer: observerCoordinate,
            julianDateRange: julianDateRange,
            interval: 60
        )
        let (passes, snapshots) = sat.findPasses(
            noradIndex: tle.noradIndex,
            observer: observerCoordinate,
            coarseSnapshots: coarseSnapshots
        )

        func viewAtPassIndex(_ index: Int) -> some View {
            let pass = passes[index]
            return PassPreviewCell(
                pass: pass,
                indexOfPass: index,
                skyChartProducer: .pure(
                    SkyChart(
                        viewModel: .mock(
                            state: SkyChartViewState(
                                pass: pass,
                                observer: observerCoordinate,
                                snapshots: SkyChartViewState.NotableSnapshots(
                                    rise: SkyChartViewState.snapshotsAroundPass(
                                        snapshots,
                                        julianDate: pass.rise.julianDate,
                                        selector: .first
                                    )!,
                                    transit: SkyChartViewState.snapshotsAroundPass(
                                        snapshots,
                                        julianDate: pass.transit.julianDate,
                                        selector: .first
                                    )!,
                                    set: SkyChartViewState.snapshotsAroundPass(
                                        snapshots,
                                        julianDate: pass.set.julianDate,
                                        selector: .last
                                    )!,
                                    illuminationChanges: BTree()
                                ),
                                referenceDate: pass.rise.julianDate,
                                quality: .preview
                            )
                        ),
                        configs: SkyChartConfigs(
                            backgroundSky: SkyChartConfigs.BackgroundSky(
                                stars: .limitedMagnitude(2),
                                showConstellationLines: false,
                                visibleBodies: [.sun, .moon],
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
            .previewLayout(.fixed(width: 375, height: 125))
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
#endif
