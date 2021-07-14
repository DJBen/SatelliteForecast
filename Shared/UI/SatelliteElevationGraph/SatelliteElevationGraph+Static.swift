//
//  SatelliteElevationGraph+Static.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/19/21.
//

import BTree
import Foundation
import CoreGraphics
import SatelliteForcastCore

extension SatelliteElevationGraph {
    private static func snapshotPoint(_ snapshot: SatelliteSnapshot, xPercent: CGFloat, rect: CGRect) -> CGPoint {
        let x = rect.width * xPercent
        let y = CGFloat(snapshot.position.elev + 90) / 180 * -rect.height + rect.height
        return CGPoint(x: x, y: y)
    }

    static func rasterizedSatelliteElevationPath(
        rect: CGRect,
        snapshotsSplitByIllumination: [(illuminated: Bool, snapshots: BTree<Double, SatelliteSnapshot>)],
        julianDateRange: Range<Double>,
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
                        let (julianDate, snapshot) = snapshotGroup[index]
                        let xPercent = CGFloat((julianDate - julianDateRange.lowerBound) / (julianDateRange.upperBound - julianDateRange.lowerBound))
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
                        let (julianDate, snapshot) = snapshotGroup[index]
                        let xPercent = CGFloat((julianDate - julianDateRange.lowerBound) / (julianDateRange.upperBound - julianDateRange.lowerBound))
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
