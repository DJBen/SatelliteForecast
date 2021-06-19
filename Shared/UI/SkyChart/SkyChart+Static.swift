//
//  SkyChart+Static.swift
//  SatelliteForcast (iOS)
//
//  Created by Ben Lu on 6/17/21.
//

import BTree
import SatelliteForcastCore
import SatelliteKit
import StarryNight

extension SkyChart {
    static func radius(fromRect rect: CGRect) -> CGFloat {
        return min(rect.width, rect.height) / 2
    }

    static func point(at coordinate: AziEleDst, rect: CGRect) -> CGPoint {
        let dist = (90 - coordinate.elev) / 90.0 * Double(radius(fromRect: rect))
        let xOffset = sin(coordinate.azim * deg2rad) * dist
        let yOffset = cos(coordinate.azim * deg2rad) * dist
        return CGPoint(x: rect.midX - CGFloat(xOffset), y: rect.midY - CGFloat(yOffset))
    }

    static func azimuthMarkPoints(azimuth: Double, length: CGFloat, rect: CGRect) -> (CGPoint, CGPoint) {
        func point(_ azim: Double, dist: Double) -> CGPoint {
            let xOffset = sin(azim * deg2rad) * dist
            let yOffset = cos(azim * deg2rad) * dist
            return CGPoint(x: rect.midX - CGFloat(xOffset), y: rect.midY - CGFloat(yOffset))
        }
        return (
            point(azimuth, dist: Double(radius(fromRect: rect))),
            point(azimuth, dist: Double(radius(fromRect: rect) + length))
        )
    }

    static func rasterizedPath(
        rect: CGRect,
        snapshotsDuringPass: Map<Double, SatelliteSnapshot>,
        lineWidth: CGFloat = 1,
        illuminatedColor: UIColor,
        unlitColor: UIColor
    ) -> UIImage {
        let snapshotsByIllumination = snapshotsDuringPass.split(inclusivity: .includesSecondElementsInPreviousGroup) { (e1, e2) -> Bool in
            return e1.1.isIlluminated != e2.1.isIlluminated
        }
        let renderer = UIGraphicsImageRenderer(size: rect.size)

        return renderer.image { ctx in
            for index in snapshotsByIllumination.indices {
                let color = snapshotsByIllumination[index].first!.1.isIlluminated ? illuminatedColor : unlitColor

                ctx.cgContext.setStrokeColor(color.cgColor)
                ctx.cgContext.setLineWidth(lineWidth)
                let snapshotsGroup = snapshotsByIllumination[index]
                for i in snapshotsGroup.indices where i < snapshotsGroup.index(before: snapshotsGroup.endIndex) {
                    if i == snapshotsGroup.startIndex {
                        let point = point(at: snapshotsGroup[i].1.position, rect: rect)
                        ctx.cgContext.move(to: point)
                    }
                    let nextPoint = point(at: snapshotsGroup[snapshotsGroup.index(after: i)].1.position, rect: rect)
                    ctx.cgContext.addLine(to: nextPoint)
                }
                ctx.cgContext.drawPath(using: .stroke)
            }
        }
    }

    func rasterizedStarPath(
        rect: CGRect,
        stars: [Star],
        constellations: [Constellation],
        observer: LatLonAlt,
        julianDate: Double,
        starColor: UIColor,
        constellationLineColor: UIColor,
        constellationLineWidth: CGFloat = 1,
        magToRadius: (Double) -> CGFloat = { CGFloat(3 * exp(0.425 * -$0)) }
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: rect.size)

        return renderer.image { ctx in
            ctx.cgContext.saveGState()
            ctx.cgContext.setFillColor(starColor.cgColor)

            for star in stars {
                let (alt, azi) = azel(
                    julianDate: julianDate,
                    site: (observer.lat, observer.lon),
                    cele: cartesianToRaDec(star.physicalInfo.coordinate))
                if alt < 0 {
                    continue
                }
                let point = Self.point(at: AziEleDst(azim: azi, elev: alt, dist: 0), rect: rect)

                ctx.cgContext.move(to: point)

                let radius = magToRadius(star.physicalInfo.apparentMagnitude)

                ctx.cgContext.addEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
            }
            ctx.cgContext.drawPath(using: .fill)

            ctx.cgContext.restoreGState()
            ctx.cgContext.setStrokeColor(constellationLineColor.cgColor)
            ctx.cgContext.setLineWidth(constellationLineWidth)

            for constellation in constellations {
                guard let center = constellation.displayCenter else {
                    continue
                }
                let (alt, _) = azel(
                    julianDate: julianDate,
                    site: (observer.lat, observer.lon),
                    cele: cartesianToRaDec(center)
                )
                if alt < 0 {
                    continue
                }
                for line in constellation.connectionLines {
                    let (alt1, azi1) = azel(julianDate: julianDate, site: (observer.lat, observer.lon), cele: cartesianToRaDec(line.star1.physicalInfo.coordinate))
                    let (alt2, azi2) = azel(julianDate: julianDate, site: (observer.lat, observer.lon), cele: cartesianToRaDec(line.star2.physicalInfo.coordinate))
                    let point1 = Self.point(at: AziEleDst(azim: azi1, elev: alt1, dist: 0), rect: rect)
                    let point2 = Self.point(at: AziEleDst(azim: azi2, elev: alt2, dist: 0), rect: rect)

                    ctx.cgContext.move(to: point1)
                    ctx.cgContext.addLine(to: point2)
                }
                ctx.cgContext.drawPath(using: .stroke)
            }
        }
    }
}

import SwiftUI

struct ImageRenderer_Previews: PreviewProvider {
    static let tianHePasses: (passes: [PassInformation], snapshots: Map<Double, SatelliteSnapshot>) = {
        let tle = try! TLE(
            raw: """
            TIANHE
            1 48274U 21035A   21152.91865056  .00003057  00000-0  33542-4 0  9993
            2 48274  41.4713  16.3199 0005053  25.9394 109.3813 15.65195495  5304
            """
        )
        let sat = Satellite(withTLE: tle)

        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: "2021-06-02T06:29:00-0600")!

        let observer = LatLonAlt(lat: -27.1570, lon: -109.4274, alt: 0)
        let snapshots = sat.snapshots(
            observer: observer,
            julianDateRange: date.julianDate..<date.julianDate + 2
        )

        return sat.findPasses(
            noradIndex: tle.noradIndex,
            observer: observer,
            coarseSnapshots: snapshots
        )
    }()

    static var previews: some View {
        let (passes, snapshots) = tianHePasses
        let pass = passes.first!
        let snapshotsDuringPass = snapshots.submap(from: pass.rise.julianDate, through: pass.set.julianDate)
        Image(
            uiImage: SkyChart.rasterizedPath(
                rect: CGRect(origin: .zero, size: CGSize(width: 375, height: 375)),
                snapshotsDuringPass: snapshotsDuringPass,
                illuminatedColor: UIColor.black,
                unlitColor: UIColor.gray
            )
        )
        .resizable()
        .aspectRatio(contentMode: .fit)
        .previewLayout(.fixed(width: 250, height: 250))
    }
}
