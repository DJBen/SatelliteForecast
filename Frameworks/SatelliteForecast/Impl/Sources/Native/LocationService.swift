import CoreLocation
import MapKit
import Observation
import SatelliteForecast
import SatelliteKit
import SatelliteWidgetSupport

@MainActor @Observable
public final class LocationService: NSObject, CLLocationManagerDelegate {
  public var resources: LocationResources
  @ObservationIgnored public var onLocationChanged: ((CLLocation) -> Void)?
  @ObservationIgnored private let openSettings: () -> Void
  @ObservationIgnored private let manager = CLLocationManager()
  @ObservationIgnored private let geocoder = CLGeocoder()
  @ObservationIgnored private var geocodeTask: Task<Void, Never>?
  public init(
    resources: LocationResources = .init(),
    openSettings: @escaping () -> Void = {
      UIApplication.shared.open(URL(string: UIApplication.unifiedSettingsURLString)!)
    }
  ) {
    self.openSettings = openSettings
    self.resources = resources
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyKilometer
    manager.distanceFilter = 2000
  }
  public func start() {
    resources.authorizationStatus = manager.authorizationStatus
    if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
    manager.startUpdatingLocation()
    manager.startMonitoringSignificantLocationChanges()
  }
  public func select(_ selection: LocationResources.Selection) {
    if selection == .currentLocation && resources.currentLocation == nil {
      AppAnalytics.event("flow_blocked", screen: .location, parameters: ["reason": "current_location_unavailable"])
      openSettings()
      return
    }
    AppAnalytics.event("location_selected", screen: .location, parameters: ["method": selection == .currentLocation ? "device" : "custom"])
    resources.selection = selection
    persist()
  }
  private func persist() {
    if let location = resources.location,
      let data = try? JSONEncoder().encode(LatLonAlt(location: location))
    {
      let previous = UserDefaults.standard.data(forKey: "lastUsedLocation")
        .flatMap { try? JSONDecoder().decode(LatLonAlt.self, from: $0) }
      if previous != LatLonAlt(location: location) {
        WidgetForecastStore.clear()
      }
      UserDefaults.standard.set(data, forKey: "lastUsedLocation")
    }
  }
  public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    resources.authorizationStatus = manager.authorizationStatus
  }
  public func locationManager(
    _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
  ) {
    guard let location = locations.last else { return }
    resources.currentLocation = location
    persist()
    onLocationChanged?(location)
    geocodeTask?.cancel()
    geocoder.cancelGeocode()
    geocodeTask = Task { [weak self] in
      guard let self else { return }
      do {
        let places = try await geocoder.reverseGeocodeLocation(location)
        try Task.checkCancellation()
        resources.currentLocationPlacemark = places.first
      } catch {}
    }
  }
  deinit { geocodeTask?.cancel() }
}
