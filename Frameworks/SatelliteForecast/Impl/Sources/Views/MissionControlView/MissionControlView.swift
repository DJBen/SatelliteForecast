import Combine
import SwiftUI
import MapKit
import SatelliteForecast
@preconcurrency import SatelliteKit
import SwiftUIVisualEffects

class SatelliteTimeLabelAnnotation: MKPointAnnotation {
    let displayTime: String
    init(coordinate: CLLocationCoordinate2D, displayTime: String) {
        self.displayTime = displayTime
        super.init()
        self.coordinate = coordinate
        self.title = displayTime
    }
}

/// A world map showing the satellite ground tracks akin to that of mission control room of space agencies.
struct MissionControlView: View {
    let satelliteInfo: SatelliteInfo
    let julianDateProvider: () -> Double
    let julianDateOffset: Double
    /// Optional user location for visibility circle
    let userLocation: CLLocationCoordinate2D?

    @State private var currentDateCoordinate: DateCoordinate?
    @State private var satelliteGroundTrack: [DateCoordinate] = []
    @State private var satelliteLabelTrack: [DateCoordinate] = []
    
    enum ZoomLevel: Equatable, Hashable {
        case global
        case close
    }

    @State var zoomLevel: ZoomLevel = .global
    
    // Timer for updating satellite position
    @State private var positionTimer = Timer.publish(
        every: 0.2,
        on: .main,
        in: .common
    ).autoconnect()

    // Timer for updating ground tracks and label track
    @State private var trackTimer = Timer.publish(
        every: 10.0,
        on: .main,
        in: .common
    ).autoconnect()

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let currentDateCoordinate = currentDateCoordinate {
                MissionControlViewControllerWrapperView(
                    currentDateCoordinate: currentDateCoordinate,
                    satelliteGroundTrack: satelliteGroundTrack,
                    satelliteLabelTrack: satelliteLabelTrack,
                    zoomLevel: $zoomLevel,
                    userLocation: userLocation // pass down
                )
            } else {
                // Show loading state while computing initial position
                Color.gray.opacity(0.3)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    )
            }

            VStack(alignment: .leading) {
                Picker(
                    selection: $zoomLevel,
                    content: {
                        Image(
                            systemName: "globe"
                        )
                        .tag(ZoomLevel.global)

                        Image(
                            systemName: "eyeglasses"
                        )
                        .tag(ZoomLevel.close)
                    },
                    label: {
                        Text("Select zoom level", bundle: .module)
                    }
                )
                .pickerStyle(.segmented)
                .frame(width: 84)
                .vibrancyEffect()
                .background(
                    Color.clear.blurEffect()
                )
                .cornerRadius(8)
                .blurEffectStyle(colorScheme == .light ? .systemChromeMaterialLight : .systemChromeMaterialDark)
                .vibrancyEffectStyle(.fill)
            }
            .padding(8)
        }
        .cornerRadius(16)
        .onAppear {
            updateAllTracks()
            updateSatellitePositionOnly()
        }
        .onReceive(positionTimer) { _ in
            updateSatellitePositionOnly()
        }
        .onReceive(trackTimer) { _ in
            updateAllTracks()
        }
    }
    

    private func updateSatellitePositionOnly() {
        let jd = julianDateProvider() + julianDateOffset
        do {
            let satelliteCoordinate = try Satellite(
                withTLE: satelliteInfo.elements
            ).geoPosition(
                julianDays: jd
            )
            currentDateCoordinate = DateCoordinate(julianDate: jd, coordinate: satelliteCoordinate)
        } catch {
            print("Error updating satellite position: \(error)")
        }
    }

    private func updateAllTracks() {
        let jd = julianDateProvider() + julianDateOffset
        do {
            // Generate label track at every 30-min interval for the next 4 hours
            let now = Date()
            let calendar = Calendar.current
            var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
            let minute = comps.minute ?? 0
            // Find next :00 or :30
            if minute < 30 {
                comps.minute = 30
            } else {
                comps.hour = (comps.hour ?? 0) + 1
                comps.minute = 0
            }
            comps.second = 0
            comps.nanosecond = 0
            let firstMark = calendar.date(from: comps) ?? now
            let min2day = 1.0 / (24.0 * 60.0)
            let interval = 30.0 * min2day // 30 minutes in Julian days
            let startJD = firstMark.julianDate
            let endJD = startJD + 4.0 * TimeConstants.hrs2day // 4 hours later
            let labelTrack = try satelliteInfo.elements.generateGroundTrack(
                julianDateRange: startJD...endJD,
                interval: interval
            )
            satelliteLabelTrack = labelTrack

            let groundTrack = try satelliteInfo.elements.generateGroundTrack(
                julianDateRange: jd...(endJD - 30 * TimeConstants.min2day),
                interval: 10 * TimeConstants.min2day
            )
            satelliteGroundTrack = groundTrack
        } catch {
            print("Error generating ground track: \(error)")
            satelliteGroundTrack = []
            satelliteLabelTrack = []
        }
    }
}

struct MissionControlViewControllerWrapperView: UIViewControllerRepresentable {
    class Coordinator: NSObject, MissionControlViewControllerDelegate {

    }

    var currentDateCoordinate: DateCoordinate
    var satelliteGroundTrack: [DateCoordinate]
    var satelliteLabelTrack: [DateCoordinate]
    @Binding var zoomLevel: MissionControlView.ZoomLevel
    var userLocation: CLLocationCoordinate2D? // add property

    func makeUIViewController(context: Context) -> MissionControlViewController {
        let viewController = MissionControlViewController(
            currentDateCoordinate: currentDateCoordinate,
            dateCoordinates: satelliteGroundTrack,
            labelTrack: satelliteLabelTrack,
            userLocation: userLocation
        )
        viewController.delegate = context.coordinator
        return viewController
    }

    func updateUIViewController(_ uiViewController: MissionControlViewController, context: Context) {
        uiViewController.setState(
            currentDateCoordinate: currentDateCoordinate,
            dateCoordinates: satelliteGroundTrack,
            labelTrack: satelliteLabelTrack,
            zoomLevel: zoomLevel,
            userLocation: userLocation // pass down
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            
        )
    }
}

@objc protocol MissionControlViewControllerDelegate {
}

// Subclassing `MKGeodesicPolyline` leads to a strange crash.
// Instead we use the good old `objc_getAssociatedObject`.
extension MKGeodesicPolyline {
    static nonisolated(unsafe) private var sf_identifierAssociationKey: UInt8 = 0

    var sf_identifier: String! {
        get {
            return objc_getAssociatedObject(self, &MKGeodesicPolyline.sf_identifierAssociationKey) as? String
        }
        set(newValue) {
            objc_setAssociatedObject(self, &MKGeodesicPolyline.sf_identifierAssociationKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        }
    }
}

class CurrentPositionAnnotation: MKPointAnnotation {
}


class UserLocationAnnotation: MKPointAnnotation {}

class UserVisibilityLabelAnnotation: MKPointAnnotation {}


class MissionControlViewController: UIViewController {
    var mapView: MKMapView!
    weak var delegate: MissionControlViewControllerDelegate?

    var currentDateCoordinate: DateCoordinate?
    var dateCoordinates: [DateCoordinate]?
    var labelTrack: [DateCoordinate]?
    var currentZoomLevel: MissionControlView.ZoomLevel?
    var userLocation: CLLocationCoordinate2D? // add property

    private var currentPositionAnnotation: CurrentPositionAnnotation?
    private var userCircleOverlay: MKCircle? // store overlay
    private var userLocationAnnotation: UserLocationAnnotation? // store user pin
    private var userVisibilityLabelAnnotation: UserVisibilityLabelAnnotation? // store label annotation
    private var satelliteTimeLabelAnnotations: NSHashTable<SatelliteTimeLabelAnnotation> = .init()

    var cancellables = Set<AnyCancellable>()

    init(
        currentDateCoordinate: DateCoordinate,
        dateCoordinates: [DateCoordinate],
        labelTrack: [DateCoordinate],
        userLocation: CLLocationCoordinate2D?
    ) {
        super.init(nibName: nil, bundle: nil)
        self.currentDateCoordinate = currentDateCoordinate
        self.dateCoordinates = dateCoordinates
        self.labelTrack = labelTrack
        self.userLocation = userLocation // assign
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        mapView = MKMapView()
        mapView.delegate = self
        mapView.mapType = .hybridFlyover
        mapView.isZoomEnabled = false
        mapView.isRotateEnabled = false
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "currentPosition")
        let camera = MKMapCamera(
            lookingAtCenter: CLLocationCoordinate2D(),
            fromEyeCoordinate: CLLocationCoordinate2D(),
            eyeAltitude: 20_000_000
        )
        mapView.setCamera(camera, animated: true)
        mapView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mapView)

        mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        mapView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        mapView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        
        // Create initial satellite annotation immediately
        currentPositionAnnotation = CurrentPositionAnnotation()
        
        // Use the provided initial coordinate data
        let coordinate = CLLocationCoordinate2D(currentDateCoordinate!.coordinate)
        currentPositionAnnotation!.coordinate = coordinate
        mapView.setCenter(coordinate, animated: false)
        
        // Add initial ground track overlays
        addGroundTrackOverlays(dateCoordinates: dateCoordinates!, currentCoordinate: currentDateCoordinate!)
        
        mapView.addAnnotation(currentPositionAnnotation!)
        
        // Add initial user circle overlay and pin if needed
        if let userLocation = userLocation {
            addOrUpdateUserCircleOverlay(userLocation: userLocation)
            addOrUpdateUserLocationAnnotation(userLocation: userLocation)
        }
    }
    
    private func addGroundTrackOverlays(
        dateCoordinates: [DateCoordinate],
        currentCoordinate: DateCoordinate
    ) {
        // Remove existing overlays
        mapView.overlays
            .filter { $0 is MKGeodesicPolyline }
            .forEach { mapView.removeOverlay($0) }

        let afterPolyline = MKGeodesicPolyline(
            points: Array(dateCoordinates)
            .map(\.coordinate).map { MKMapPoint(CLLocationCoordinate2D($0)) },
            count: dateCoordinates.count
        )
        afterPolyline.sf_identifier = "after"
        mapView.addOverlay(afterPolyline)

        // --- Stable time label annotations logic ---
        // Use labelTrack passed in from SwiftUI
        guard let labelTrack = self.labelTrack else { return }

        // Build set of displayTimes needed
        let dateFormatter: DateFormatter = {
            let df = DateFormatter()
            df.timeStyle = .short
            df.dateStyle = .none
            df.timeZone = TimeZone.current
            return df
        }()
        let neededDisplayTimes: Set<String> = Set(labelTrack.map { dc in
            dateFormatter.string(from: Date(julianDate: dc.julianDate))
        })

        // Remove annotations whose displayTime is not needed
        for annotation in satelliteTimeLabelAnnotations.allObjects {
            if !neededDisplayTimes.contains(annotation.displayTime) {
                mapView.removeAnnotation(annotation)
                satelliteTimeLabelAnnotations.remove(annotation)
            }
        }

        // Add new annotations for displayTimes not already present
        let existingDisplayTimes: Set<String> = Set(satelliteTimeLabelAnnotations.allObjects.map { $0.displayTime })
        for dc in labelTrack {
            let timeString = dateFormatter.string(from: Date(julianDate: dc.julianDate))
            if !existingDisplayTimes.contains(timeString) {
                let annotation = SatelliteTimeLabelAnnotation(coordinate: CLLocationCoordinate2D(dc.coordinate), displayTime: timeString)
                satelliteTimeLabelAnnotations.add(annotation)
                mapView.addAnnotation(annotation)
            }
        }
        // (Existing annotations for marks in window are left untouched)
    }

    func setState(
        currentDateCoordinate: DateCoordinate,
        dateCoordinates: [DateCoordinate],
        labelTrack: [DateCoordinate],
        zoomLevel: MissionControlView.ZoomLevel,
        userLocation: CLLocationCoordinate2D?
    ) {
        let isInitialSetup = self.currentDateCoordinate == nil
        let coordinateChanged = self.currentDateCoordinate != currentDateCoordinate
        let dateCoordinatesChanged = self.dateCoordinates != dateCoordinates
        let zoomLevelChanged = self.currentZoomLevel != zoomLevel
        let userLocationChanged = self.userLocation != userLocation

        // Only recenter and zoom when zoom level is explicitly changed by user
        if zoomLevelChanged {
            let camera = MKMapCamera(
                lookingAtCenter: CLLocationCoordinate2D(currentDateCoordinate.coordinate),
                fromEyeCoordinate: CLLocationCoordinate2D(currentDateCoordinate.coordinate),
                eyeAltitude: centerCoordinateDistance(for: zoomLevel)
            )
            mapView.setCamera(camera, animated: true)
            self.currentZoomLevel = zoomLevel
        }

        // Early return if nothing changed
        if !coordinateChanged && !dateCoordinatesChanged {
            return
        }

        // Only set initial center once, without interrupting user interaction
        if isInitialSetup {
            mapView.setCenter(CLLocationCoordinate2D(currentDateCoordinate.coordinate), animated: false)
            self.currentZoomLevel = zoomLevel
        }
        
        // Update stored values
        self.currentDateCoordinate = currentDateCoordinate
        
        // Only update overlays if the date coordinates array actually changed
        if dateCoordinatesChanged {
            self.labelTrack = labelTrack
            addGroundTrackOverlays(dateCoordinates: dateCoordinates, currentCoordinate: currentDateCoordinate)
            self.dateCoordinates = dateCoordinates
        }

        // Handle satellite annotation updates
        let targetCoordinate = CLLocationCoordinate2D(currentDateCoordinate.coordinate)
        
        // Ensure annotation exists and is positioned correctly
        if currentPositionAnnotation == nil {
            currentPositionAnnotation = CurrentPositionAnnotation()
            mapView.addAnnotation(currentPositionAnnotation!)
        }
        
        // Always update the satellite position when we get new coordinates
        if isInitialSetup {
            // For initial setup, position annotation immediately
            updateSatellitePosition(targetCoordinate)
            // Also center the map on the satellite for initial view
            mapView.setCenter(targetCoordinate, animated: false)
        } else if coordinateChanged {
            // Update satellite position immediately
            updateSatellitePosition(targetCoordinate)
        }

        // Update user circle overlay and pin if needed
        if userLocationChanged {
            if let userLocation = userLocation {
                addOrUpdateUserCircleOverlay(userLocation: userLocation)
                addOrUpdateUserLocationAnnotation(userLocation: userLocation)
            } else {
                removeUserCircleOverlay()
                removeUserLocationAnnotation()
            }
            self.userLocation = userLocation
        }
    }

    func centerCoordinateDistance(for zoomLevel: MissionControlView.ZoomLevel) -> Double {
        switch zoomLevel {
        case .global:
            return 20_000_000
        case .close:
            return 2_000_000
        }
    }
    
    private func updateSatellitePosition(_ coordinate: CLLocationCoordinate2D) {
        // Ensure we have an annotation
        if currentPositionAnnotation == nil {
            currentPositionAnnotation = CurrentPositionAnnotation()
            mapView.addAnnotation(currentPositionAnnotation!)
        }
        
        currentPositionAnnotation?.coordinate = coordinate
    }

    private func addOrUpdateUserCircleOverlay(userLocation: CLLocationCoordinate2D) {
        // Remove existing overlay if present
        if let overlay = userCircleOverlay {
            mapView.removeOverlay(overlay)
        }
        let circle = MKCircle(center: userLocation, radius: 1_312_000) // 1312 km in meters
        userCircleOverlay = circle
        mapView.addOverlay(circle)
    }

    private func removeUserCircleOverlay() {
        if let overlay = userCircleOverlay {
            mapView.removeOverlay(overlay)
            userCircleOverlay = nil
        }
    }

    private func addOrUpdateUserLocationAnnotation(userLocation: CLLocationCoordinate2D) {
        // User pin
        if let annotation = userLocationAnnotation {
            annotation.coordinate = userLocation
        } else {
            let annotation = UserLocationAnnotation()
            annotation.coordinate = userLocation
            userLocationAnnotation = annotation
            mapView.addAnnotation(annotation)
        }

        // Label annotation
        if let labelAnnotation = userVisibilityLabelAnnotation {
            labelAnnotation.coordinate = userLocation
        } else {
            let labelAnnotation = UserVisibilityLabelAnnotation()
            labelAnnotation.coordinate = userLocation
            userVisibilityLabelAnnotation = labelAnnotation
            mapView.addAnnotation(labelAnnotation)
        }
    }

    private func removeUserLocationAnnotation() {
        if let annotation = userLocationAnnotation {
            mapView.removeAnnotation(annotation)
            userLocationAnnotation = nil
        }
        if let labelAnnotation = userVisibilityLabelAnnotation {
            mapView.removeAnnotation(labelAnnotation)
            userVisibilityLabelAnnotation = nil
        }
    }
}

extension MissionControlViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is CurrentPositionAnnotation {
            let identifier = "currentPosition"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                annotationView?.annotation = annotation
            }
            annotationView?.canShowCallout = false
            annotationView?.glyphImage = UIImage(
                named: "glyph_satellite",
                in: .module,
                compatibleWith: nil
            )
            annotationView?.markerTintColor = .systemOrange
            annotationView?.glyphTintColor = .white
            annotationView?.displayPriority = .required
            return annotationView
        } else if annotation is UserVisibilityLabelAnnotation {
            let identifier = "userVisibilityLabel"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if annotationView == nil {
                let labelView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                let label = UILabel()
                label.text = NSLocalizedString(
                    "Visible",
                    bundle: .module,
                    comment: "Map annotation indicating the radius that space stations are visible for the user"
                )
                label.font = UIFont.boldSystemFont(ofSize: 14)
                label.textColor = .systemYellow
                label.backgroundColor = UIColor(white: 0, alpha: 0.5)
                label.layer.cornerRadius = 6
                label.layer.masksToBounds = true
                label.sizeToFit()
                label.textAlignment = .center
                label.frame = CGRect(x: 0, y: 0, width: label.frame.width + 16, height: label.frame.height + 6)
                labelView.addSubview(label)
                labelView.frame = label.frame
                labelView.centerOffset = CGPoint(x: 0, y: -40)
                annotationView = labelView
            } else {
                annotationView?.annotation = annotation
            }
            annotationView?.canShowCallout = false
            return annotationView
        } else if let timeLabelAnnotation = annotation as? SatelliteTimeLabelAnnotation {
            let identifier = "satelliteTimeLabel" + timeLabelAnnotation.displayTime
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if annotationView == nil {
                let labelView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                let label = UILabel()
                label.text = timeLabelAnnotation.displayTime
                label.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
                label.textColor = .white
                label.backgroundColor = UIColor(white: 0, alpha: 0.7)
                label.layer.cornerRadius = 4
                label.layer.masksToBounds = true
                label.sizeToFit()
                label.textAlignment = .center
                label.frame = CGRect(x: 0, y: 0, width: label.frame.width + 10, height: label.frame.height + 4)
                labelView.addSubview(label)
                labelView.frame = label.frame
                annotationView = labelView
            } else {
                annotationView?.annotation = annotation
            }
            annotationView?.canShowCallout = false
            return annotationView
        }
        return nil
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKGeodesicPolyline {
            let colorsAndStops: [GradientPathRenderer.ColorAndStop] = [
                GradientPathRenderer.ColorAndStop(
                    color: UIColor.systemBlue.cgColor,
                    stop: 0
                ),
                GradientPathRenderer.ColorAndStop(
                    color: UIColor.systemGreen.cgColor,
                    stop: 0.25
                ),
                GradientPathRenderer.ColorAndStop(
                    color: UIColor.systemYellow.cgColor,
                    stop: 0.5
                ),
                GradientPathRenderer.ColorAndStop(
                    color: UIColor.systemOrange.cgColor,
                    stop: 0.75
                ),
                GradientPathRenderer.ColorAndStop(
                    color: UIColor.systemRed.cgColor,
                    stop: 1
                )
            ]

            let renderer = GradientPathRenderer(
                polyline: polyline,
                colorsAndStops: colorsAndStops
            )
            renderer.lineWidth = 10
            return renderer
        }
        // Add circle overlay rendering for user visibility
        if let circle = overlay as? MKCircle {
            let renderer = MKCircleRenderer(circle: circle)
            renderer.fillColor = UIColor.systemYellow.withAlphaComponent(0.15)
            renderer.strokeColor = UIColor.systemYellow.withAlphaComponent(0.5)
            renderer.lineWidth = 2
            return renderer
        }
        return MKOverlayRenderer()
    }
}

#if DEBUG

struct MissionControlView_Previews: PreviewProvider {
    static var previews: some View {
        let elements = try! Elements(
            raw: """
            ISS (ZARYA)
            1 25544U 98067A   21152.11066515  .00000451  00000-0  16375-4 0  9992
            2 25544  51.6453  62.2423 0003364  52.3737  88.5313 15.48937685286109
            """
        )
        
        let satelliteInfo = try! SatelliteInfo(elements: elements)

        MissionControlView(
            satelliteInfo: satelliteInfo,
            julianDateProvider: { Date().julianDate },
            julianDateOffset: 0,
            userLocation: nil
        )
        .frame(width: 368, height: 280)
    }
}

#endif
