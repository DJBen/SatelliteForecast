import SwiftUI
@preconcurrency import SatelliteKit

public enum SatelliteOverviewViewAction {
    case navigate(
        NavigationPath
    )
    
    case selectSatellite(
        specialSatellite: SpecialSatellite,
        julianDateRange: ClosedRange<Double>,
        observer: LatLonAlt?
    )
    
}
