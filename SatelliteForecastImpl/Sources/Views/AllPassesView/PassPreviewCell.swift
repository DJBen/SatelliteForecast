//
//  PassPreviewCell.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 6/15/21.
//

import BTree
import SwiftUI
import SatelliteForecast
import SatelliteKit
import CombineRex
import CombineRextensions

struct PassPreviewCell: View {
    var satelliteInfo: SatelliteInfo
    var snapshots: [SatelliteSnapshot]
    var notableSnapshots: NotableSnapshots
    var observer: LatLonAlt
    var pass: Pass
    var hasScheduledAlert: Bool
    var skyChartProducer: ViewProducer<SkyChartContext, SkyChart>
    var julianDateOffset: Double
    var julianDateProvider: () -> Double

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

                HStack(alignment: .top, spacing: 0) {
                    // Column 1: Day light and elevation
                    if geometry.size.width >= 305 {
                        VStack(alignment: .leading) {
                            Text(PassPreviewCell.titleForPassVisibility(pass.visibility))
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
                    }

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
                        
                        Text(PassPreviewCell.relativeDate(pass: pass, referenceDate: julianDateProvider() + julianDateOffset))
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
                        notableSnapshots: notableSnapshots,
                        configs: .preview,
                        quality: .preview,
                        julianDateProvider: julianDateProvider
                    )
                )
                .padding(5)
                .frame(width: shortEdge, height: shortEdge)
            }
        }
    }
}

extension PassPreviewCell {
    static func titleForPassVisibility(_ visibility: Pass.Visibility) -> String {
        switch visibility {
        case .visible:
            return NSLocalizedString(
                "PassPreviewCell.visibilityText.visible",
                tableName: nil,
                bundle: .main,
                value: "Visible",
                comment: "The pass is visible"
            )
        case .daylight:
            return NSLocalizedString(
                "PassPreviewCell.visibilityText.daylight",
                tableName: nil,
                bundle: .main,
                value: "Daylight",
                comment: "The pass happens during daylight"
            )
        case .unlit:
            return NSLocalizedString(
                "PassPreviewCell.visibilityText.unlit",
                tableName: nil,
                bundle: .main,
                value: "Unlit",
                comment: "The pass happens entirely unlit"
            )
        }
    }

    private static let durationFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.formattingContext = .beginningOfSentence
        return formatter
    }()

    static func relativeDate(pass: Pass, referenceDate: Double) -> String {
        if referenceDate < pass.rise.julianDate {
            let format = NSLocalizedString(
                "PassPreviewCell.relativeDate.riseInTheFuture",
                tableName: nil,
                bundle: .main,
                value: "%@",
                comment: "A string describing that the satellite rises in a specific time in the future"
            )
            return String(
                format: format,
                durationFormatter.localizedString(
                    fromTimeInterval: (pass.rise.julianDate - referenceDate) * TimeConstants.day2sec)
            )
        } else if referenceDate > pass.set.julianDate {
            let format = NSLocalizedString(
                "PassPreviewCell.relativeDate.alreadyPassed",
                tableName: nil,
                bundle: .main,
                value: "%@",
                comment: "A string describing that the satellite has already set in a specific time in the past"
            )
            return String(
                format: format,
                durationFormatter.localizedString(
                    fromTimeInterval: (pass.set.julianDate - referenceDate) * TimeConstants.day2sec)
            )
        } else {
            return NSLocalizedString(
                "PassPreviewCell.relativeDate.passing",
                tableName: nil,
                bundle: .main,
                value: "Passing now",
                comment: "A string describing that the satellite is currently passing"
            )
        }
    }

}

#if DEBUG
struct PassPreviewCell_Previews: PreviewProvider {
    static var previews: some View {
        let elements = try! Elements(
            raw: """
            ISS (ZARYA)
            1 25544U 98067A   21155.08058252  .00001489  00000-0  35252-4 0  9997
            2 25544  51.6446  47.5538 0003512  61.1482  91.5411 15.48950578286563
            """
        )
        // 2000 Broadway, Redwood City, CA 94063
        let observer = LatLonAlt(lat: 37.486743000691185, lon: -122.22655970246515, alt: 0)
        // Date range
        let startDate = Date(timeIntervalSinceReferenceDate: 20 * 365 * 86400)
        let julianDateRange = startDate.advanced(by: -60 * 60 * 2).julianDate...startDate.advanced(by: 60 * 60 * 30).julianDate
        let satelliteInfo = SatelliteInfo(elements: elements)
        let coarseSnapshots = try! satelliteInfo.generateSnapshots(
            observer: observer,
            julianDateRange: julianDateRange,
            interval: 60
        )
        let passSnapshots = try! satelliteInfo.findPasses(
            observer: observer,
            coarseSnapshots: coarseSnapshots
        )

        func viewAtPassIndex(_ index: Int) -> some View {
            let passSnapshot = passSnapshots[index]
            return PassPreviewCell(
                satelliteInfo: SatelliteInfo(elements: elements),
                snapshots: passSnapshot.snapshots,
                notableSnapshots: passSnapshot.notableSnapshots,
                observer: observer,
                pass: passSnapshot.pass,
                hasScheduledAlert: false,
                skyChartProducer: .pure(
                    SkyChart(
                        viewModel: .mock(
                            state: SkyChartViewState()
                        ),
                        context: SkyChartContext(
                            satelliteInfo: satelliteInfo,
                            snapshots: passSnapshot.snapshots,
                            observer: observer,
                            pass: passSnapshot.pass,
                            notableSnapshots: passSnapshot.notableSnapshots,
                            configs: SkyChartConfigs(
                                backgroundSkyConfigs: BackgroundSkyConfigs(
                                    stars: .limitedMagnitude(2),
                                    showConstellationLines: false,
                                    visibleBodies: [.sun, .moon],
                                    bodySymbol: .symbol
                                ),
                                basicChartConfigs: BasicChartConfigs(
                                    showAzimuthTexts: false,
                                    azimuthMarkInterval: 90,
                                    azimuthMarkLength: 2,
                                    showDirections: false
                                ),
                                showPassInfoLabels: false
                            ),
                            quality: .preview,
                            julianDateProvider: { passSnapshot.pass.rise.julianDate }
                        ),
                        backgroundSkyViewProducer: .pure(
                            BackgroundSkyView(
                                viewModel: .mock(
                                    state: BackgroundSkyViewState()
                                ),
                                context: BackgroundSkyViewContext(
                                    observer: observer,
                                    basicChartConfigs: .init(),
                                    configs: .preset,
                                    quality: .full
                                )
                            )
                        )
                    )
                ),
                julianDateOffset: 0,
                julianDateProvider: { startDate.julianDate }
            )
            .environment(\.backgroundSkyJulianDateKey, passSnapshot.pass.rise.julianDate.roundJulianDate(.toMins(1)))
        }

        return Group {
            Group {
                viewAtPassIndex(0)
                viewAtPassIndex(2)
                viewAtPassIndex(3)
                viewAtPassIndex(4)
            }
            .previewLayout(.fixed(width: 375, height: 125))
            
            Group {
                viewAtPassIndex(0)
                viewAtPassIndex(2)
                viewAtPassIndex(3)
                viewAtPassIndex(4)
            }
            .previewLayout(.fixed(width: 325, height: 125))
        }
    }
}
#endif
