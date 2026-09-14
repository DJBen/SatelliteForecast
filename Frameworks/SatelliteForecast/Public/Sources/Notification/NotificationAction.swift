import SatelliteKit

/// Notification delegate input, independent of application state.
public enum NotificationAction {
    case deepLink(category: SatelliteCategory, noradIndex: UInt, observer: LatLonAlt, passIdentifier: String)
}
