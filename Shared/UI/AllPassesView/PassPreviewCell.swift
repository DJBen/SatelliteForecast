//
//  PassPreviewCell.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/15/21.
//

import BTree
import SwiftUI
import SatelliteForecastCore
import SatelliteKit
import CombineRex
import CombineRextensions

struct PassPreviewCell: View {
    var satelliteInfo: SatelliteInfo
    var snapshots: BTree<Double, SatelliteSnapshot>
    var observer: LatLonAlt
    var pass: Pass
    var referenceDate: Double
    var hasScheduledAlert: Bool
    
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
        GeometryReader { geometry in
            let shortEdge = min(geometry.size.width, geometry.size.height)
            
            HStack(alignment: .center) {
                Rectangle()
                    .foregroundColor(visiblityColor)
                    .frame(width: 12, alignment: .leading)

                HStack(alignment: .top) {
                    VStack(alignment: .leading) {
                        Text(LocalizedStrings.PassPreviewCell.titleForPassVisibility(pass.visibility))
                            .font(.headline)
                        Text("∠\(Self.numberFormatter.string(from: NSNumber(value: pass.transit.elev))!)°")
                            .font(.body)
                        if hasScheduledAlert {
                            Spacer(minLength: 8)
                            Image(systemName: "bell.fill")
                                .font(.title3)
                        }
                    }
                    .frame(width: 72)

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
                        
                        Spacer(minLength: 4)
                        
                        Text(LocalizedStrings.PassPreviewCell.relativeDate(pass: pass, referenceDate: referenceDate))
                            .font(.caption)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                    }
                }
                .fixedSize()
            
                skyChartProducer.view(
                    SkyChartContext(
                        satelliteInfo: satelliteInfo,
                        snapshots: snapshots,
                        observer: observer,
                        pass: pass,
                        configs: .preview,
                        quality: .preview
                    )
                )
                .padding(5)
                .frame(width: shortEdge, height: shortEdge)
            }
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
        let observer = LatLonAlt(lat: 37.486743000691185, lon: -122.22655970246515, alt: 0)
        // Date range
        let startDate = Date(timeIntervalSinceReferenceDate: 20 * 365 * 86400)
        let julianDateRange = startDate.advanced(by: -60 * 60 * 2).julianDate..<startDate.advanced(by: 60 * 60 * 30).julianDate
        let coarseSnapshots = sat.snapshots(
            observer: observer,
            julianDateRange: julianDateRange,
            interval: 60
        )
        let (passes, snapshots) = sat.findPasses(
            noradIndex: tle.noradIndex,
            observer: observer,
            coarseSnapshots: coarseSnapshots
        )

        func viewAtPassIndex(_ index: Int) -> some View {
            let pass = passes[index]
            return PassPreviewCell(
                satelliteInfo: SatelliteInfo(noradIndex: 25544, satellite: sat),
                snapshots: snapshots,
                observer: observer,
                pass: pass,
                referenceDate: startDate.julianDate,
                hasScheduledAlert: false,
                skyChartProducer: .pure(
                    SkyChart(
                        viewModel: .mock(
                            state: SkyChartViewState(
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
                                referenceDate: pass.rise.julianDate
                            )
                        ),
                        context: SkyChartContext(
                            satelliteInfo: SatelliteInfo(noradIndex: 25544, satellite: sat),
                            snapshots: snapshots,
                            observer: observer,
                            pass: pass,
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
                            ),
                            quality: .preview
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
        }
    }
}
#endif
