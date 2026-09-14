import Foundation
import SatelliteForecast
import SatelliteKit
import StarryNight
import UIKit

/// Core Graphics rasterization is serialized off the main actor. Views retain only
/// their current images; no process-wide image dictionary grows with browsing.
public actor ChartRenderer {
  public init() {}
  public func background(
    size: CGSize, quality: ChartQuality, julianDate: Double, key: BackgroundSkyKey,
    traitCollection: UITraitCollection, catalog: AppStarCatalog
  ) throws -> UIImage {
    try Task.checkCancellation()
    var image: UIImage!
    traitCollection.performAsCurrent {
      image = SkyChartUtils.rasterizedBackgroundSkyPath(
        params: BackgroundSkyRenderParams(
          rect: CGRect(origin: .zero, size: size),
          stars: {
            switch key.configs.stars {
            case .none:
              return []
            case .brightest300:
              return catalog.brightestStars()
            case .limitedMagnitude(let mag):
              return catalog.stars(maximumMagnitude: mag)
            }
          }(),
          constellations: key.configs.showConstellationLines ? catalog.allConstellations() : [],
          observer: key.observer,
          julianDate: julianDate,
          starColor: UIColor(
            named: "star",
            in: .module,
            compatibleWith: traitCollection
          )!,
          constellationLineColor: UIColor(
            named: "constellationLine",
            in: .module,
            compatibleWith: traitCollection
          )!,
          magToRadius: key.configs.starMagToDisplayRadiusMappingFunction.apply
        ),
        starManager: catalog
      )
    }

    try Task.checkCancellation()
    return image
  }
  public func path(
    size: CGSize, quality: ChartQuality, passSnapshots: PassSnapshots,
    traitCollection: UITraitCollection
  ) throws -> UIImage {
    try Task.checkCancellation()
    var image: UIImage!
    traitCollection.performAsCurrent {
      // Rasterize satellite paths in sky charts
      image = SkyChartUtils.rasterizedSatellitePassPath(
        params: SatellitePassPathRenderParams(
          rect: CGRect(origin: .zero, size: size),
          snapshotsDuringPass: passSnapshots.snapshots,
          illuminatedColor: UIColor(
            named: "satellitePath_illuminated",
            in: .module,
            compatibleWith: nil
          )!,
          unlitColor: UIColor(
            named: "satellitePath_notIlluminated",
            in: .module,
            compatibleWith: nil
          )!,
          arrowSize: quality == .preview ? 8 : 16
        )
      )
    }
    return image
  }
  public func elevation(
    size: CGSize, snapshots: [SatelliteSnapshot], range: ClosedRange<Double>,
    traits: UITraitCollection
  ) throws -> UIImage {
    try Task.checkCancellation()
    return SatelliteElevationGraph.rasterizedSatelliteElevationPath(
      rect: CGRect(origin: .zero, size: size),
      snapshotsSplitByIllumination: snapshots.split(
        inclusivity: .includesSecondElementsInPreviousGroup,
        shouldSplit: { $0.isIlluminated != $1.isIlluminated }
      ).map { ($0.first!.isIlluminated, $0) }, julianDateRange: range, traitCollection: traits)
  }
}
