//
//  SkyChart+Static.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/17/21.
//

import BTree
import SatelliteForecast
import SatelliteKit
import StarryNight
import SolarSystem

public struct SatellitePassPathRenderParams: Equatable {
    public var rect: CGRect
    public var snapshotsDuringPass: [SatelliteSnapshot]
    public var lineWidth: CGFloat = 1
    public var illuminatedColor: UIColor
    public var unlitColor: UIColor
    public var arrowSize: CGFloat = 8

    public init(rect: CGRect, snapshotsDuringPass: [SatelliteSnapshot], lineWidth: CGFloat = 1, illuminatedColor: UIColor, unlitColor: UIColor, arrowSize: CGFloat = 8) {
        self.rect = rect
        self.snapshotsDuringPass = snapshotsDuringPass
        self.lineWidth = lineWidth
        self.illuminatedColor = illuminatedColor
        self.unlitColor = unlitColor
        self.arrowSize = arrowSize
    }
}

public struct BackgroundSkyRenderParams {
    public var rect: CGRect
    public var stars: [Star]
    public var constellations: Set<Constellation>
    public var observer: LatLonAlt
    public var julianDate: Double
    public var starColor: UIColor
    public var constellationLineColor: UIColor
    public var constellationLineWidth: CGFloat = 1
    public var drawPlanaryBodies: Bool = false
    public var backgroundFillColor: UIColor = .clear
    
    public struct Border {
        var borderColor: UIColor
        var borderWidth: CGFloat = 1

        public init(borderColor: UIColor, borderWidth: CGFloat = 1) {
            self.borderColor = borderColor
            self.borderWidth = borderWidth
        }
    }

    public var border: Border? = nil
    public var magToRadius: (Double) -> CGFloat

    public init(rect: CGRect, stars: [Star], constellations: Set<Constellation>, observer: LatLonAlt, julianDate: Double, starColor: UIColor, constellationLineColor: UIColor, constellationLineWidth: CGFloat = 1, drawPlanaryBodies: Bool = false, backgroundFillColor: UIColor = .clear, border: BackgroundSkyRenderParams.Border? = nil, magToRadius: @escaping (Double) -> CGFloat) {
        self.rect = rect
        self.stars = stars
        self.constellations = constellations
        self.observer = observer
        self.julianDate = julianDate
        self.starColor = starColor
        self.constellationLineColor = constellationLineColor
        self.constellationLineWidth = constellationLineWidth
        self.drawPlanaryBodies = drawPlanaryBodies
        self.backgroundFillColor = backgroundFillColor
        self.border = border
        self.magToRadius = magToRadius
    }
}

extension SkyChart {
    public static let labelDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("H:mm:ss")
        return formatter
    }()

    public static let labelAngleFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    public static func radius(fromRect rect: CGRect) -> CGFloat {
        return min(rect.width, rect.height) / 2
    }

    public static func point<Coordinate: AziEleProviding>(at coordinate: Coordinate, rect: CGRect) -> CGPoint {
        let dist = (90 - coordinate.elev) / 90.0 * Double(radius(fromRect: rect))
        let xOffset = sin(coordinate.azim * deg2rad) * dist
        let yOffset = cos(coordinate.azim * deg2rad) * dist
        return CGPoint(x: rect.midX - CGFloat(xOffset), y: rect.midY - CGFloat(yOffset))
    }

    public static func azimuthMarkPoints(azimuth: Double, length: CGFloat, rect: CGRect) -> (CGPoint, CGPoint) {
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
    public static func rotationAndTextRotation(snapshotPair: SnapshotsAroundPass, rect: CGRect) -> (Double, Double) {
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
    
    public static func addRasterizedSatellitePassPath(
        to ctx: UIGraphicsImageRendererContext,
        params: SatellitePassPathRenderParams
    ) {
        let snapshotsByIllumination = params.snapshotsDuringPass.split(inclusivity: .includesSecondElementsInPreviousGroup) { (e1, e2) -> Bool in
            return e1.isIlluminated != e2.isIlluminated
        }
        ctx.cgContext.saveGState()
        for index in snapshotsByIllumination.indices {
            let isIlluminated = snapshotsByIllumination[index].first!.isIlluminated
            let color = isIlluminated ? params.illuminatedColor : params.unlitColor
            let snapshotsGroup = snapshotsByIllumination[index]

            ctx.cgContext.setStrokeColor(color.cgColor)
            ctx.cgContext.setLineWidth(params.lineWidth)
            for i in snapshotsGroup.indices where i < snapshotsGroup.index(before: snapshotsGroup.endIndex) {
                if i == snapshotsGroup.startIndex {
                    let point = point(at: snapshotsGroup[i].position, rect: params.rect)
                    ctx.cgContext.move(to: point)
                }
                let nextPoint = point(at: snapshotsGroup[snapshotsGroup.index(after: i)].position, rect: params.rect)
                ctx.cgContext.addLine(to: nextPoint)
            }
            ctx.cgContext.drawPath(using: .stroke)
            
            if snapshotsGroup.count > 3 {
                ctx.cgContext.saveGState()

                let e1 = snapshotsGroup[snapshotsGroup.count / 2 - 1].position
                let e2 = snapshotsGroup[snapshotsGroup.count / 2].position
                let p1 = point(at: e1, rect: params.rect)
                let p2 = point(at: e2, rect: params.rect)
                let rot = atan2pi(Double(p2.y - p1.y), Double(p2.x - p1.x))
                ctx.cgContext.translateBy(x: p1.x, y: p1.y)
                ctx.cgContext.rotate(by: CGFloat(rot))
                ctx.cgContext.setFillColor(color.cgColor)
                let image = UIImage(systemName: "arrowtriangle.right.fill")!
                let imageRect = CGRect(origin: CGPoint(x: -params.arrowSize / 2, y: -params.arrowSize / 2), size: CGSize(width: params.arrowSize, height: params.arrowSize))
                ctx.cgContext.clip(to: imageRect, mask: image.cgImage!)
                ctx.cgContext.fill(imageRect)
                ctx.cgContext.restoreGState()
            }
        }
        ctx.cgContext.restoreGState()
    }

    public static func rasterizedSatellitePassPath(
        params: SatellitePassPathRenderParams
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: params.rect.size)

        return renderer.image { ctx in
            addRasterizedSatellitePassPath(to: ctx, params: params)
        }
    }

    public static func addRasterizedBackgroundSkyPath(
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
        
        // -- Background fill
        
        ctx.cgContext.saveGState()
        ctx.cgContext.setFillColor(params.backgroundFillColor.cgColor)
        ctx.cgContext.addEllipse(in: params.rect)
        ctx.cgContext.fillPath()
        ctx.cgContext.restoreGState()
        
        // -- Constellations --
        
        ctx.cgContext.saveGState()
        ctx.cgContext.setStrokeColor(params.constellationLineColor.cgColor)
        ctx.cgContext.setLineWidth(params.constellationLineWidth)

        for constellation in params.constellations {
            guard let center = constellation.displayCenter else {
                continue
            }
            let alt = azel(
                julianDate: params.julianDate,
                site: (params.observer.lat, params.observer.lon),
                cele: cartesianToRaDec(center)
            ).elev
            if alt < 0 {
                continue
            }
            for line in constellation.connectionLines {
                let aziElev1 = azel(julianDate: params.julianDate, site: (params.observer.lat, params.observer.lon), cele: cartesianToRaDec(line.star1.physicalInfo.coordinate))
                let aziElev2 = azel(julianDate: params.julianDate, site: (params.observer.lat, params.observer.lon), cele: cartesianToRaDec(line.star2.physicalInfo.coordinate))
                if aziElev1.elev < 0 || aziElev2.elev < 0 {
                    continue
                }
                let point1 = Self.point(at: AziEleDst(azim: aziElev1.azim, elev: aziElev1.elev, dist: 0), rect: params.rect)
                let point2 = Self.point(at: AziEleDst(azim: aziElev2.azim, elev: aziElev2.elev, dist: 0), rect: params.rect)

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
            let aziElev = azel(
                julianDate: params.julianDate,
                site: (params.observer.lat, params.observer.lon),
                cele: cartesianToRaDec(star.physicalInfo.coordinate))
            if aziElev.elev < 0 {
                continue
            }
            let point = Self.point(at: AziEleDst(azim: aziElev.azim, elev: aziElev.elev, dist: 0), rect: params.rect)

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


        let sunAziElev = SolarSystemBody.sun.aziEle(
            julianDay: params.julianDate,
            observer: params.observer
        )
        let sunPoint = Self.point(at: AziEleDst(azim: sunAziElev.azim, elev: sunAziElev.elev, dist: 0), rect: params.rect)
        
        ctx.cgContext.saveGState()
        ctx.cgContext.addEllipse(in: params.rect)
        ctx.cgContext.clip()
        
        ctx.cgContext.setFillColor(UIColor.systemYellow.cgColor)
        ctx.cgContext.setShadow(offset: .zero, blur: 16, color: UIColor.systemYellow.cgColor)
        ctx.cgContext.addEllipse(in: CGRect(x: sunPoint.x - 7, y: sunPoint.y - 7, width: 14, height: 14))
        ctx.cgContext.drawPath(using: .fill)

        let moonAziElev = azel(julianDate: params.julianDate, site: (params.observer.lat, params.observer.lon), cele: lunarGeo(julianDays: params.julianDate))
        let moonPoint = Self.point(at: AziEleDst(azim: moonAziElev.azim, elev: moonAziElev.elev, dist: 0), rect: params.rect)
        ctx.cgContext.setFillColor(UIColor.gray.cgColor)
        ctx.cgContext.setShadow(offset: .zero, blur: 12, color: UIColor.systemYellow.cgColor)
        ctx.cgContext.addEllipse(in: CGRect(x: moonPoint.x - 5, y: moonPoint.y - 5, width: 10, height: 10))

        ctx.cgContext.fillPath()

        ctx.cgContext.restoreGState()
    }
        
    public static func rasterizedBackgroundSkyPath(
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
    static let tianHePasses: [PassSnapshots] = {
        let elements = try! Elements(
            raw: """
            TIANHE
            1 48274U 21035A   21152.91865056  .00003057  00000-0  33542-4 0  9993
            2 48274  41.4713  16.3199 0005053  25.9394 109.3813 15.65195495  5304
            """
        )

        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: "2021-06-02T06:29:00-0600")!
        let satelliteInfo = SatelliteInfo(elements: elements)
        let observer = LatLonAlt(lat: -27.1570, lon: -109.4274, alt: 0)
        let snapshots = try! satelliteInfo.generateSnapshots(
            observer: observer,
            julianDateRange: date.julianDate...date.julianDate + 2
        )

        return try! satelliteInfo.findPasses(
            observer: observer,
            coarseSnapshots: snapshots
        )
    }()
    
    struct Preview: View {
        static let stars = Star.magitudeLessThan(4)
        static let constellations = Constellation.all
        
        let pass: Pass
        let snapshots: [SatelliteSnapshot]
        let notableSnapshots: NotableSnapshots
        let observer = LatLonAlt(lat: -27.1570, lon: -109.4274, alt: 0)
        
        @Environment(\.colorScheme) var colorScheme

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
                            UITraitCollection(userInterfaceStyle: colorScheme == .light ? .light : .dark).performAsCurrent {
                                SkyChart.addRasterizedBackgroundSkyPath(
                                    to: ctx,
                                    params: BackgroundSkyRenderParams(
                                        rect: rect,
                                        stars: Self.stars,
                                        constellations: Self.constellations,
                                        observer: observer,
                                        julianDate: pass.rise.julianDate,
                                        starColor: UIColor(named: "star")!,
                                        constellationLineColor: UIColor(named: "constellationLine")!,
                                        drawPlanaryBodies: true,
                                        backgroundFillColor: UIColor.secondarySystemBackground,
                                        border: BackgroundSkyRenderParams.Border(borderColor: UIColor(named: "skyChartStroke")!),
                                        magToRadius: { CGFloat(3 * exp(-0.425 * $0)) }
                                    )
                                )
                                
                                SkyChart.addRasterizedSatellitePassPath(
                                    to: ctx,
                                    params: SatellitePassPathRenderParams(
                                        rect: rect,
                                        snapshotsDuringPass: snapshots,
                                        illuminatedColor: UIColor(named: "satellitePath_illuminated")!,
                                        unlitColor: UIColor(named: "satellitePath_notIlluminated")!
                                    )
                                )
                            }
                        }
                    }()
                )
                .resizable()
                .aspectRatio(contentMode: .fit)
                .overlay(
                    SkyChart.PassLabel(
                        text: "Rise",
                        snapshotPair: notableSnapshots.rise,
                        rect: rect,
                        modifierFactory: PassLabelModifier.init(rotationAngle:)
                    )
                )
                .overlay(
                    SkyChart.PassLabel(
                        text: "Transit",
                        snapshotPair: notableSnapshots.transit,
                        rect: rect,
                        modifierFactory: PassLabelModifier.init(rotationAngle:)
                    )
                )
                .overlay(
                    SkyChart.PassLabel(
                        text: "Set",
                        snapshotPair: notableSnapshots.set,
                        rect: rect,
                        modifierFactory: PassLabelModifier.init(rotationAngle:)
                    )
                )
                .overlay(
                    SkyChart.PassLabel(
                        text: "Special",
                        snapshotPair: SnapshotsAroundPass(
                            first: snapshots[snapshots.index(snapshots.startIndex, offsetBy: snapshots.count / 3)],
                            second: snapshots[snapshots.index(snapshots.startIndex, offsetBy: snapshots.count / 3 + 1)]
                        ),
                        rect: rect,
                        modifierFactory: HighlightedPassLabelModifier.curry(shouldHighlight: true)
                    )
                )
            }
        }
    }

    static var previews: some View {
        ForEach(enumerated: tianHePasses, id: \.notableSnapshots.rise.first.julianDate) { index, passSnapshots in
            Preview(
                pass: passSnapshots.pass,
                snapshots: passSnapshots.snapshots,
                notableSnapshots: passSnapshots.notableSnapshots
            )
            .previewLayout(.fixed(width: 350, height: 350))
            .preferredColorScheme(Double.random(in: 0..<1) > 0.5 ? .light : .dark)
        }
    }
}
