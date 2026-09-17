import SatelliteForecast
import SatelliteKit
import UIKit

actor NotificationPreview {
  static func render(
    _ notification: PassNotification, snapshots passSnapshots: PassSnapshots,
    catalog: AppStarCatalog
  ) async throws -> UIImage {
    let pass = notification.pass
    let stars = catalog.brightestStars()
    let constellations = catalog.allConstellations()

    // Force dark theme
    let traitCollection = UITraitCollection(userInterfaceStyle: .dark)
    var image: UIImage!
    traitCollection.performAsCurrent {
      let rect = CGRect(x: 0, y: 0, width: 350, height: 350)
      let imageRect = rect.insetBy(dx: 5, dy: 5)
      let renderer = UIGraphicsImageRenderer(size: rect.size)
      image = renderer.image { ctx in
        SkyChartUtils.addRasterizedBackgroundSkyPath(
          to: ctx,
          params: BackgroundSkyRenderParams(
            rect: imageRect,
            stars: stars,
            constellations: constellations,
            observer: notification.observer,
            julianDate: pass.rise.julianDate,
            starColor: SkyChartTheme.starColor(
              traitCollection: traitCollection
            ),
            constellationLineColor: SkyChartTheme.constellationLineColor(
              traitCollection: traitCollection
            ),
            drawPlanaryBodies: true,
            backgroundFillColor: UIColor.secondarySystemBackground,
            border: BackgroundSkyRenderParams.Border(
              borderColor: SkyChartTheme.skyChartStrokeColor(
                traitCollection: traitCollection
              )
            ),
            magToRadius: { BackgroundSkyConfigs.StarMagToDisplayRadiusMappingFunction.pointSourceRadius(magnitude: $0) }
          ),
          starManager: catalog
        )

        SkyChartUtils.addRasterizedSatellitePassPath(
          to: ctx,
          params: SatellitePassPathRenderParams(
            rect: imageRect,
            snapshotsDuringPass: passSnapshots.snapshots,
            illuminatedColor: SkyChartTheme.satellitePathColor(
              illuminated: true,
              traitCollection: traitCollection
            ),
            unlitColor: SkyChartTheme.satellitePathColor(
              illuminated: false,
              traitCollection: traitCollection
            )
          )
        )
      }

    }
    return image
  }
}
