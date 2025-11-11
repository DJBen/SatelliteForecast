@preconcurrency import SatelliteKit

public enum SingleSatelliteWrappingViewAction {
    public struct LoadSingleSatelliteParams: Equatable {
        public let selectedNoradIndex: UInt
        public let julianDateRange: ClosedRange<Double>
        public let observer: LatLonAlt?

        public init(selectedNoradIndex: UInt, julianDateRange: ClosedRange<Double>, observer: LatLonAlt?) {
            self.selectedNoradIndex = selectedNoradIndex
            self.julianDateRange = julianDateRange
            self.observer = observer
        }
    }
    case loadSingleSatellite(LoadSingleSatelliteParams)
    case reloadSingleSatellite(LoadSingleSatelliteParams)
}

extension SingleSatelliteWrappingViewAction: Equatable {}
