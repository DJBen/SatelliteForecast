//
//  SatelliteElevationGraph+Static.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 6/19/21.
//

import BTree
import Foundation
import CoreGraphics
import SatelliteForecast
import SatelliteKit

extension SatelliteElevationGraph {
    private static func snapshotPoint(_ snapshot: SatelliteSnapshot, xPercent: CGFloat, rect: CGRect) -> CGPoint {
        let x = rect.width * xPercent
        let y = CGFloat(snapshot.position.elev + 90) / 180 * -rect.height + rect.height
        return CGPoint(x: x, y: y)
    }

    static func xPercentDatePair(julianDateRange: ClosedRange<Double>, configs: SatelliteElevationGraphConfigs) -> [PercentDate] {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: Date(julianDate: julianDateRange.lowerBound))
        var julianDate: Double = calendar.date(from: components)!.julianDate
        var results = [PercentDate]()
        while true {
            defer {
                julianDate += TimeConstants.sec2day * configs.timeGridLineInterval
            }
            if julianDate < julianDateRange.lowerBound {
                continue
            }
            let xPercent = (julianDate - julianDateRange.lowerBound) / (julianDateRange.upperBound - julianDateRange.lowerBound)
            if xPercent > 1 {
                break
            }
            results.append(PercentDate(percent: xPercent, julianDate: julianDate))
        }
        return results
    }

    static func rasterizedSatelliteElevationPath(
        rect: CGRect,
        snapshotsSplitByIllumination: [(illuminated: Bool, snapshots: [SatelliteSnapshot])],
        julianDateRange: ClosedRange<Double>,
        traitCollection: UITraitCollection
    ) -> UIImage {

        let renderer = UIGraphicsImageRenderer(size: rect.size)

        return renderer.image { ctx in
            ctx.cgContext.setLineWidth(2)
            ctx.cgContext.saveGState()

            snapshotsSplitByIllumination
                .forEach { isIlluminated, snapshotGroup in
                    if !isIlluminated {
                        return
                    }
                    for index in snapshotGroup.indices {
                        let snapshot = snapshotGroup[index]
                        let xPercent = CGFloat((snapshot.julianDate - julianDateRange.lowerBound) / (julianDateRange.upperBound - julianDateRange.lowerBound))
                        if index == snapshotGroup.startIndex {
                            ctx.cgContext.move(to: snapshotPoint(snapshot, xPercent: xPercent, rect: rect))
                        } else {
                            ctx.cgContext.addLine(to: snapshotPoint(snapshot, xPercent: xPercent, rect: rect))
                        }
                    }
                }

            ctx.cgContext.replacePathWithStrokedPath()
            ctx.cgContext.clip()

            traitCollection.performAsCurrent {
                ctx.cgContext.drawLinearGradient(
                    CGGradient(
                        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                        colors: [UIColor.systemRed.cgColor, UIColor.systemBlue.cgColor] as CFArray,
                        locations: [0.0, 1.0]
                    )!,
                    start: CGPoint(x: rect.midX, y: rect.minY),
                    end: CGPoint(x: rect.midX, y: rect.maxY),
                    options: []
                )
            }

            ctx.cgContext.restoreGState()

            ctx.cgContext.setStrokeColor(UIColor.lightGray.cgColor)
            snapshotsSplitByIllumination
                .forEach { isIlluminated, snapshotGroup in
                    if isIlluminated {
                        return
                    }
                    for index in snapshotGroup.indices {
                        let snapshot = snapshotGroup[index]
                        let xPercent = CGFloat((snapshot.julianDate - julianDateRange.lowerBound) / (julianDateRange.upperBound - julianDateRange.lowerBound))
                        if index == snapshotGroup.startIndex {
                            ctx.cgContext.move(to: snapshotPoint(snapshot, xPercent: xPercent, rect: rect))
                        } else {
                            ctx.cgContext.addLine(to: snapshotPoint(snapshot, xPercent: xPercent, rect: rect))
                        }
                    }
                }
            ctx.cgContext.drawPath(using: .stroke)
        }
    }
}
