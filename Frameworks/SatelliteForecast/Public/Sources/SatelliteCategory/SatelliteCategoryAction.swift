import SwiftUI
@preconcurrency import SatelliteKit

public enum SatelliteCategoryViewAction {
    case navigate(
        NavigationPath
    )
    
    case loadCategory(
        SatelliteCategory,
        julianDateRange: ClosedRange<Double>,
        observer: LatLonAlt?
    )
}
