//
//  MissionControlView.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 4/3/22.
//

import Combine
import SwiftUI
import MapKit
import SatelliteForecast
@preconcurrency import SatelliteKit
import SwiftUIVisualEffects

/// A world map showing the satellite ground tracks akin to that of mission control room of space agencies.
struct MissionControlView: View {
    let satelliteInfo: SatelliteInfo
    let julianDateProvider: () -> Double
    let julianDateOffset: Double

    @State private var currentDateCoordinate: DateCoordinate?
    @State private var satelliteGroundTrack: [DateCoordinate] = []
    
    enum ZoomLevel: Equatable, Hashable {
        case global
        case close
    }

    @State var zoomLevel: ZoomLevel = .global
    
    // Timer for updating satellite position and ground track
    @State private var refreshTimer = Timer.publish(
        every: 0.25,
        on: .main,
        in: .common
    )
    .autoconnect()

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let currentDateCoordinate = currentDateCoordinate {
                MissionControlViewControllerWrapperView(
                    currentDateCoordinate: currentDateCoordinate,
                    satelliteGroundTrack: satelliteGroundTrack,
                    zoomLevel: $zoomLevel,
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
            updateMissionControlState()
        }
        .onReceive(refreshTimer) { _ in
            updateMissionControlState()
        }
    }
    
    private func updateMissionControlState() {
        let jd = julianDateProvider() + julianDateOffset
        do {
            let satelliteCoordinate = try Satellite(
                withTLE: satelliteInfo.elements
            ).geoPosition(
                julianDays: jd
            )
            let groundTrack = try satelliteInfo.elements.generateGroundTrack(
                julianDateRange: jd...(jd + TimeConstants.hrs2day * 4),
                interval: 10 * TimeConstants.min2day
            )
            currentDateCoordinate = DateCoordinate(julianDate: jd, coordinate: satelliteCoordinate)
            satelliteGroundTrack = groundTrack
        } catch {
            print("Error generating ground track: \(error)")
        }
    }
}

struct MissionControlViewControllerWrapperView: UIViewControllerRepresentable {
    class Coordinator: NSObject, MissionControlViewControllerDelegate {

    }

    var currentDateCoordinate: DateCoordinate
    var satelliteGroundTrack: [DateCoordinate]
    @Binding var zoomLevel: MissionControlView.ZoomLevel

    func makeUIViewController(context: Context) -> MissionControlViewController {
        let viewController = MissionControlViewController(
            currentDateCoordinate: currentDateCoordinate,
            dateCoordinates: satelliteGroundTrack
        )
        viewController.delegate = context.coordinator
        return viewController
    }

    func updateUIViewController(_ uiViewController: MissionControlViewController, context: Context) {
        uiViewController.setState(
            currentDateCoordinate: currentDateCoordinate,
            dateCoordinates: satelliteGroundTrack,
            zoomLevel: zoomLevel
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

class MissionControlViewController: UIViewController {
    var mapView: MKMapView!
    weak var delegate: MissionControlViewControllerDelegate?

    var currentDateCoordinate: DateCoordinate?
    var dateCoordinates: [DateCoordinate]?
    var currentZoomLevel: MissionControlView.ZoomLevel?
    
    private var currentPositionAnnotation: CurrentPositionAnnotation?

    var cancellables = Set<AnyCancellable>()

    init(
        currentDateCoordinate: DateCoordinate,
        dateCoordinates: [DateCoordinate]
    ) {
        super.init(nibName: nil, bundle: nil)

        // Set initial data
        self.currentDateCoordinate = currentDateCoordinate
        self.dateCoordinates = dateCoordinates
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
    }
    
    private func addGroundTrackOverlays(dateCoordinates: [DateCoordinate], currentCoordinate: DateCoordinate) {
        // Remove existing overlays
        mapView.overlays
            .filter { $0 is MKGeodesicPolyline }
            .forEach { mapView.removeOverlay($0) }
            
        // Create new overlays
        let beforeDataset = dateCoordinates.prefix(
            while: { $0.julianDate <= currentCoordinate.julianDate }
        )
        let polyline = MKGeodesicPolyline(
            points: beforeDataset
            .map(\.coordinate).map { MKMapPoint(CLLocationCoordinate2D($0)) },
            count: beforeDataset.count
        )
        polyline.sf_identifier = "before"
        mapView.addOverlay(polyline)
        
        let afterDataset = dateCoordinates.drop(
            while: { $0.julianDate < currentCoordinate.julianDate }
        )
        let afterPolyline = MKGeodesicPolyline(
            points: Array(afterDataset)
            .map(\.coordinate).map { MKMapPoint(CLLocationCoordinate2D($0)) },
            count: afterDataset.count
        )
        afterPolyline.sf_identifier = "after"
        mapView.addOverlay(afterPolyline)
    }

    func setState(
        currentDateCoordinate: DateCoordinate,
        dateCoordinates: [DateCoordinate],
        zoomLevel: MissionControlView.ZoomLevel
    ) {
        let isInitialSetup = self.currentDateCoordinate == nil
        let coordinateChanged = self.currentDateCoordinate != currentDateCoordinate
        let dateCoordinatesChanged = self.dateCoordinates != dateCoordinates
        let zoomLevelChanged = self.currentZoomLevel != zoomLevel
        
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
}

extension MissionControlViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard annotation is CurrentPositionAnnotation else {
            return nil
        }
        
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
        
        return annotationView
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKGeodesicPolyline {
            let isBefore = polyline.sf_identifier.contains("before")

            let colorsAndStops: [GradientPathRenderer.ColorAndStop]

            if isBefore {
                colorsAndStops = [
                    GradientPathRenderer.ColorAndStop(
                        color: UIColor.systemRed.withAlphaComponent(0.3).cgColor,
                        stop: 0
                    ),
                    GradientPathRenderer.ColorAndStop(
                        color: UIColor.systemOrange.withAlphaComponent(0.3).cgColor,
                        stop: 0.25
                    ),
                    GradientPathRenderer.ColorAndStop(
                        color: UIColor.systemYellow.withAlphaComponent(0.3).cgColor,
                        stop: 0.5
                    ),
                    GradientPathRenderer.ColorAndStop(
                        color: UIColor.systemGreen.withAlphaComponent(0.3).cgColor,
                        stop: 0.75
                    ),
                    GradientPathRenderer.ColorAndStop(
                        color: UIColor.systemBlue.withAlphaComponent(0.3).cgColor,
                        stop: 1
                    )
                ]
            } else {
                colorsAndStops = [
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
            }

            let renderer = GradientPathRenderer(
                polyline: polyline,
                colorsAndStops: colorsAndStops
            )
            renderer.lineWidth = 10
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
            julianDateOffset: 0
        )
        .frame(width: 368, height: 280)
    }
}

#endif
