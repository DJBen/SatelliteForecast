import SwiftUI
@preconcurrency import SatelliteKit

public enum SatelliteOverviewViewAction {
    case navigate(
        NavigationPath
    )
    
    case onAppear(
        julianDateRange: ClosedRange<Double>,
        observer: LatLonAlt?
    )

    case selectSatellite(
        specialSatellite: SpecialSatellite,
        julianDateRange: ClosedRange<Double>,
        observer: LatLonAlt?
    )
    
    case deeplinkToLocationSelection
    case showLocationSettings
}
