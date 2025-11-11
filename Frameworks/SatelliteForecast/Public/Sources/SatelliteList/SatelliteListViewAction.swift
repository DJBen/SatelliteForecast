@preconcurrency import SatelliteKit
import BTree

public enum SatelliteListViewAction {
    public struct SelectSatelliteParams {
        public let noradIndex: UInt
        public let satelliteInfo: SatelliteInfo
        public let julianDateRange: ClosedRange<Double>
        public let observer: LatLonAlt?

        public init(
            noradIndex: UInt,
            satelliteInfo: SatelliteInfo,
            julianDateRange: ClosedRange<Double>,
            observer: LatLonAlt?
        ) {
            self.noradIndex = noradIndex
            self.satelliteInfo = satelliteInfo
            self.julianDateRange = julianDateRange
            self.observer = observer
        }
    }

    case loadSatellite(SelectSatelliteParams?)
    case selectSatellite(SelectSatelliteParams, category: SatelliteCategory)
    case searchSatellites(String, category: SatelliteCategory)
    case retryLoadingSatelliteList(category: SatelliteCategory)
    case reloadSatellites(category: SatelliteCategory)
}

public enum SatelliteListViewOutput {
    case filteredSatellites(
        Map<UInt, SatelliteInfo>?,
        searchText: String,
        category: SatelliteCategory
    )
}
