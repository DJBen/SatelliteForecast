import UIKit
import CoreGraphics

public enum SatelliteElevationGraphAction {
    case requestRasterizeElevationGraph(
        size: CGSize,
        noradIndex: UInt,
        julianDateRange: ClosedRange<Double>,
        traitCollection: UITraitCollection
    )
    case rasterizedElevationGraph(UIImage, size: CGSize, noradIndex: UInt, julianDateRange: ClosedRange<Double>)
}
