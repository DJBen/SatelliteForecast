//
//  SkyChart+Static.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/17/21.
//

import BTree
import SatelliteForecastCore
import SatelliteKit
import StarryNight

extension SkyChartViewState {
    static func snapshotsAroundPass(_ tree: BTree<Double, SatelliteSnapshot>, julianDate: Double, selector: BTreeKeySelector) -> SnapshotsAroundPass? {
        var index = tree.index(forInserting: julianDate, at: selector)
        if index == tree.endIndex {
            index = tree.index(before: tree.endIndex)
        }
        if tree.count < 2 {
            return nil
        }

        if selector == .first {
            if index == tree.index(before: tree.endIndex) {
                // Use before index
                let beforeIndex = tree.index(before: index)
                return SnapshotsAroundPass(tree[index].1, tree[beforeIndex].1)
            } else {
                // Use after index
                let afterIndex = tree.index(after: index)
                return SnapshotsAroundPass(tree[index].1, tree[afterIndex].1)
            }
        } else {
            if index == tree.startIndex {
                // Use after index
                let afterIndex = tree.index(after: index)
                return SnapshotsAroundPass(tree[index].1, tree[afterIndex].1)
            } else {
                // Use before index
                let beforeIndex = tree.index(before: index)
                return SnapshotsAroundPass(tree[index].1, tree[beforeIndex].1)
            }
        }
    }
}

struct SatellitePassPathRenderParams: Equatable {
    var rect: CGRect
    var snapshotsDuringPass: BTree<Double, SatelliteSnapshot>
    var lineWidth: CGFloat = 1
    var illuminatedColor: UIColor
    var unlitColor: UIColor
    var arrowSize: CGFloat = 8
}

struct BackgroundSkyRenderParams {
    var rect: CGRect
    var stars: [Star]
    var constellations: Set<Constellation>
    var observer: LatLonAlt
    var julianDate: Double
    var starColor: UIColor
    var constellationLineColor: UIColor
    var constellationLineWidth: CGFloat = 1
    var drawPlanaryBodies: Bool = false
    
    struct Border {
        var borderColor: UIColor
        var borderWidth: CGFloat = 1
    }

    var border: Border? = nil
    var magToRadius: (Double) -> CGFloat
}

extension SkyChart {
    static let labelDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("H:mm:ss")
        return formatter
    }()

    static let labelAngleFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 0
        return formatter
    }()

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

    /// The rotation angle in radians, and the rotation angle for the text to be the most easily legible.
    /// - Parameters:
    ///   - snapshotPair: A pair of satellite snapshots.
    ///   - rect: The rectangle of the view.
    /// - Returns: The rotation angle in radians, and the rotation angle for the text to be the most easily legible.
    static func rotationAndTextRotation(snapshotPair: SkyChartViewState.SnapshotsAroundPass, rect: CGRect) -> (Double, Double) {
        let position = Self.point(at: snapshotPair.first.position, rect: rect)
        let afterPosition = Self.point(at: snapshotPair.second.position, rect: rect)
        let satellitePositionVector = Vector(Double(afterPosition.x - position.x), Double(afterPosition.y - position.y), 0)
        // A vector from origin to the position
        let originVector = Vector(Double(afterPosition.x - rect.midX), Double(afterPosition.y - rect.midY), 0)
        let normal = crossProduct(satellitePositionVector, originVector)
        let rot = atan2(Double(afterPosition.y - position.y), Double(afterPosition.x - position.x))
        let factor: Double = normal.z > 0 ? -1 : 1
        let adjustedRot = factor > 0 ? rot + .pi / 2 : rot - .pi / 2
        let textRot = fmod2pi_0(adjustedRot) > .pi / 2 || fmod2pi_0(adjustedRot) < -.pi / 2 ? .pi : 0
        return (adjustedRot, textRot)
    }
    
    static func addRasterizedSatellitePassPath(
        to ctx: UIGraphicsImageRendererContext,
        params: SatellitePassPathRenderParams
    ) {
        let snapshotsByIllumination = params.snapshotsDuringPass.split(inclusivity: .includesSecondElementsInPreviousGroup) { (e1, e2) -> Bool in
            return e1.1.isIlluminated != e2.1.isIlluminated
        }
        ctx.cgContext.saveGState()
        for index in snapshotsByIllumination.indices {
            let isIlluminated = snapshotsByIllumination[index].first!.1.isIlluminated
            let color = isIlluminated ? params.illuminatedColor : params.unlitColor
            let snapshotsGroup = snapshotsByIllumination[index]

            if snapshotsGroup.count > 3 {
                ctx.cgContext.saveGState()
                let e1 = snapshotsGroup[snapshotsGroup.index(ofOffset: snapshotsGroup.count / 2 - 1)].1.position
                let e2 = snapshotsGroup[snapshotsGroup.index(ofOffset: snapshotsGroup.count / 2)].1.position
                let p1 = point(at: e1, rect: params.rect)
                let p2 = point(at: e2, rect: params.rect)
                let rot = atan2pi(Double(p2.y - p1.y), Double(p2.x - p1.x))
                ctx.cgContext.translateBy(x: p1.x, y: p1.y)
                ctx.cgContext.rotate(by: CGFloat(rot))
                ctx.cgContext.setFillColor(color.cgColor)
                let image = UIImage(systemName: "arrowtriangle.right.fill")!
                let imageRect = CGRect(origin: CGPoint(x: -params.arrowSize / 2, y: -params.arrowSize / 2), size: CGSize(width: params.arrowSize, height: params.arrowSize))
                image.draw(in: imageRect)
                ctx.cgContext.setBlendMode(.sourceAtop)
                ctx.cgContext.fill(imageRect)
                ctx.cgContext.restoreGState()
            }

            ctx.cgContext.setStrokeColor(color.cgColor)
            ctx.cgContext.setLineWidth(params.lineWidth)
            for i in snapshotsGroup.indices where i < snapshotsGroup.index(before: snapshotsGroup.endIndex) {
                if i == snapshotsGroup.startIndex {
                    let point = point(at: snapshotsGroup[i].1.position, rect: params.rect)
                    ctx.cgContext.move(to: point)
                }
                let nextPoint = point(at: snapshotsGroup[snapshotsGroup.index(after: i)].1.position, rect: params.rect)
                ctx.cgContext.addLine(to: nextPoint)
            }
            ctx.cgContext.drawPath(using: .stroke)
        }
        ctx.cgContext.restoreGState()
    }

    static func rasterizedSatellitePassPath(
        params: SatellitePassPathRenderParams
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: params.rect.size)

        return renderer.image { ctx in
            addRasterizedSatellitePassPath(to: ctx, params: params)
        }
    }

    static func addRasterizedBackgroundSkyPath(
        to ctx: UIGraphicsImageRendererContext,
        params: BackgroundSkyRenderParams
    ) {
        if let border = params.border {
            ctx.cgContext.saveGState()
            ctx.cgContext.setStrokeColor(border.borderColor.cgColor)
            ctx.cgContext.addEllipse(in: params.rect)
            ctx.cgContext.setLineWidth(border.borderWidth)
            ctx.cgContext.drawPath(using: .stroke)
            ctx.cgContext.restoreGState()
        }
        
        // -- Constellations --
        
        ctx.cgContext.saveGState()
        ctx.cgContext.setStrokeColor(params.constellationLineColor.cgColor)
        ctx.cgContext.setLineWidth(params.constellationLineWidth)

        for constellation in params.constellations {
            guard let center = constellation.displayCenter else {
                continue
            }
            let (alt, _) = azel(
                julianDate: params.julianDate,
                site: (params.observer.lat, params.observer.lon),
                cele: cartesianToRaDec(center)
            )
            if alt < 0 {
                continue
            }
            for line in constellation.connectionLines {
                let (alt1, azi1) = azel(julianDate: params.julianDate, site: (params.observer.lat, params.observer.lon), cele: cartesianToRaDec(line.star1.physicalInfo.coordinate))
                let (alt2, azi2) = azel(julianDate: params.julianDate, site: (params.observer.lat, params.observer.lon), cele: cartesianToRaDec(line.star2.physicalInfo.coordinate))
                if alt1 < 0 || alt2 < 0 {
                    continue
                }
                let point1 = Self.point(at: AziEleDst(azim: azi1, elev: alt1, dist: 0), rect: params.rect)
                let point2 = Self.point(at: AziEleDst(azim: azi2, elev: alt2, dist: 0), rect: params.rect)

                ctx.cgContext.move(to: point1)
                ctx.cgContext.addLine(to: point2)
            }
            ctx.cgContext.drawPath(using: .stroke)
        }
        ctx.cgContext.restoreGState()
        
        // -- Stars --
        
        ctx.cgContext.saveGState()
        ctx.cgContext.setFillColor(params.starColor.cgColor)

        for star in params.stars {
            let (alt, azi) = azel(
                julianDate: params.julianDate,
                site: (params.observer.lat, params.observer.lon),
                cele: cartesianToRaDec(star.physicalInfo.coordinate))
            if alt < 0 {
                continue
            }
            let point = Self.point(at: AziEleDst(azim: azi, elev: alt, dist: 0), rect: params.rect)

            ctx.cgContext.move(to: point)

            let radius = params.magToRadius(star.physicalInfo.apparentMagnitude)

            ctx.cgContext.addEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
        }
        ctx.cgContext.drawPath(using: .fill)
        ctx.cgContext.restoreGState()
        
        guard params.drawPlanaryBodies else {
            return
        }
        
        // -- Plantary bodies
        
        let (sunAlt, sunAzi) = azel(julianDate: params.julianDate, site: (params.observer.lat, params.observer.lon), cele: solarGeo(julianDays: params.julianDate))
        let sunPoint = Self.point(at: AziEleDst(azim: sunAzi, elev: sunAlt, dist: 0), rect: params.rect)
        
        ctx.cgContext.saveGState()
        ctx.cgContext.addEllipse(in: params.rect)
        ctx.cgContext.clip()
        
        ctx.cgContext.setFillColor(UIColor.systemYellow.cgColor)
        ctx.cgContext.setShadow(offset: .zero, blur: 16, color: UIColor.systemYellow.cgColor)
        ctx.cgContext.addEllipse(in: CGRect(x: sunPoint.x - 7, y: sunPoint.y - 7, width: 14, height: 14))
        ctx.cgContext.drawPath(using: .fill)

        let (moonAlt, moonAzi) = azel(julianDate: params.julianDate, site: (params.observer.lat, params.observer.lon), cele: lunarGeo(julianDays: params.julianDate))
        let moonPoint = Self.point(at: AziEleDst(azim: moonAzi, elev: moonAlt, dist: 0), rect: params.rect)
        ctx.cgContext.setFillColor(UIColor.gray.cgColor)
        ctx.cgContext.setShadow(offset: .zero, blur: 12, color: UIColor.systemYellow.cgColor)
        ctx.cgContext.addEllipse(in: CGRect(x: moonPoint.x - 5, y: moonPoint.y - 5, width: 10, height: 10))

        ctx.cgContext.fillPath()

        ctx.cgContext.restoreGState()
    }
        
    static func rasterizedBackgroundSkyPath(
        params: BackgroundSkyRenderParams
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: params.rect.size)

        return renderer.image { ctx in
            addRasterizedBackgroundSkyPath(to: ctx, params: params)
        }
    }
}

import SwiftUI

struct ImageRenderer_Previews: PreviewProvider {
    static let tianHePasses: (passes: [Pass], snapshots: BTree<Double, SatelliteSnapshot>) = {
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
    
    struct Preview: View {
        static let stars = Star.magitudeLessThan(4)
        static let constellations = Constellation.all
        
        let pass: Pass
        let snapshots: BTree<Double, SatelliteSnapshot>
        let observer = LatLonAlt(lat: -27.1570, lon: -109.4274, alt: 0)

        var body: some View {
            GeometryReader { geometry in
                let rect: CGRect = {
                    let rect = geometry.frame(in: .local)
                    let dimension = min(rect.size.width, rect.size.height)
                    return CGRect(origin: rect.origin, size: CGSize(width: dimension, height: dimension))
                }()
                
                Image(
                    uiImage: {
                        let renderer = UIGraphicsImageRenderer(size: rect.size)

                        return renderer.image { ctx in
                            SkyChart.addRasterizedBackgroundSkyPath(
                                to: ctx,
                                params: BackgroundSkyRenderParams(
                                    rect: rect,
                                    stars: Self.stars,
                                    constellations: Self.constellations,
                                    observer: observer,
                                    julianDate: pass.rise.julianDate,
                                    starColor: UIColor.black,
                                    constellationLineColor: UIColor.lightGray.withAlphaComponent(0.4),
                                    drawPlanaryBodies: true,
                                    border: BackgroundSkyRenderParams.Border(borderColor: UIColor(named: "skyChartStroke")!),
                                    magToRadius: { CGFloat(3 * exp(-0.425 * $0)) }
                                )
                            )
                            
                            SkyChart.addRasterizedSatellitePassPath(
                                to: ctx,
                                params: SatellitePassPathRenderParams(
                                    rect: rect,
                                    snapshotsDuringPass: snapshots,
                                    illuminatedColor: UIColor.black,
                                    unlitColor: UIColor.lightGray
                                )
                            )
                        }
                    }()
                )
                .resizable()
                .aspectRatio(contentMode: .fit)
                .overlay(
                    SkyChart.PassLabel(
                        text: "Rise",
                        snapshotPair: SkyChartViewState.snapshotsAroundPass(snapshots, julianDate: pass.rise.julianDate, selector: .first)!,
                        rect: rect,
                        modifierFactory: PassLabelModifier.init(rotationAngle:)
                    )
                )
                .overlay(
                    SkyChart.PassLabel(
                        text: "Transit",
                        snapshotPair: SkyChartViewState.snapshotsAroundPass(snapshots, julianDate: pass.transit.julianDate, selector: .first)!,
                        rect: rect,
                        modifierFactory: PassLabelModifier.init(rotationAngle:)
                    )
                )
                .overlay(
                    SkyChart.PassLabel(
                        text: "Set",
                        snapshotPair: SkyChartViewState.snapshotsAroundPass(snapshots, julianDate: pass.set.julianDate, selector: .last)!,
                        rect: rect,
                        modifierFactory: PassLabelModifier.init(rotationAngle:)
                    )
                )
                .overlay(
                    SkyChart.PassLabel(
                        text: "Special",
                        snapshotPair: SkyChartViewState.snapshotsAroundPass(snapshots, julianDate: pass.rise.julianDate + 180 * TimeConstants.sec2day, selector: .last)!,
                        rect: rect,
                        modifierFactory: HighlightedPassLabelModifier.curry(shouldHighlight: true)
                    )
                )
            }
        }
    }

    static var previews: some View {
        let (passes, snapshots) = tianHePasses

        ForEach(enumerated: passes, id: \.self.rise.julianDate) { index, pass in
            Preview(pass: pass, snapshots: snapshots.subtree(from: pass.rise.julianDate, through: pass.set.julianDate))
                .previewLayout(.fixed(width: 350, height: 350))
        }
    }
}
