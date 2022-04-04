//
//  MissionControlView.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 4/3/22.
//

import SwiftUI
import MapKit
import SatelliteForecast
import SatelliteKit

/// A world map showing the satellite ground tracks akin to that of mission control room of space agencies.
struct MissionControlView: View {
    var currentDateCoordinate: DateCoordinate
    var satelliteGroundTrack: [DateCoordinate]

    @State var showResetButton: Bool = false

    var body: some View {
        MissionControlViewControllerWrapperView(
            currentDateCoordinate: currentDateCoordinate,
            satelliteGroundTrack: satelliteGroundTrack,
            viewPortWillChange: {
                showResetButton = true
            }
        )
    }
}

struct MissionControlViewControllerWrapperView: UIViewControllerRepresentable {
    class Coordinator: NSObject, MissionControlViewControllerDelegate {
        let viewPortWillChange: () -> Void

        init(viewPortWillChange: @escaping () -> Void) {
            self.viewPortWillChange = viewPortWillChange
        }

        func missionControlWillChangeViewPort(_ viewController: MissionControlViewController) {
            viewPortWillChange()
        }
    }

    var currentDateCoordinate: DateCoordinate
    var satelliteGroundTrack: [DateCoordinate]
    var viewPortWillChange: () -> Void

    func makeUIViewController(context: Context) -> MissionControlViewController {
        return MissionControlViewController()
    }

    func updateUIViewController(_ uiViewController: MissionControlViewController, context: Context) {
        uiViewController.setState(
            currentDateCoordinate: currentDateCoordinate,
            dateCoordinates: satelliteGroundTrack
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewPortWillChange: viewPortWillChange)
    }
}

@objc protocol MissionControlViewControllerDelegate {
    func missionControlWillChangeViewPort(_ viewController: MissionControlViewController)
}

class GroundTrackOverlay: MKPolyline {
    private(set) var id: String!
    private(set) var dateCoordinates: [DateCoordinate]!

    public convenience init(
        id: String,
        dateCoordinates: [DateCoordinate]
    ) {
        self.init(
            coordinates: dateCoordinates.map(\.coordinate).map { CLLocationCoordinate2D($0) },
            count: dateCoordinates.count
        )

        self.id = id
        self.dateCoordinates = dateCoordinates
    }
}

class CurrentPositionAnnotation: MKPointAnnotation {

}

class MissionControlViewController: UIViewController, MKMapViewDelegate {
    var mapView: MKMapView!
    weak var delegate: MissionControlViewControllerDelegate?

    var currentDateCoordinate: DateCoordinate?
    var dateCoordinates: [DateCoordinate]?

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
        mapView.setCamera(camera, animated: false)
        mapView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mapView)

        mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        mapView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        mapView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
    }

    func setState(
        currentDateCoordinate: DateCoordinate,
        dateCoordinates: [DateCoordinate]
    ) {
        if self.currentDateCoordinate == currentDateCoordinate && self.dateCoordinates == dateCoordinates {
            return
        }

        if self.currentDateCoordinate == nil {
            mapView.setCenter(CLLocationCoordinate2D(currentDateCoordinate.coordinate), animated: true)
        }
        self.currentDateCoordinate = currentDateCoordinate

        mapView.overlays
            .filter { $0 is GroundTrackOverlay }
            .forEach { mapView.removeOverlay($0) }
        let polyline = GroundTrackOverlay(
            id: "before",
            dateCoordinates: dateCoordinates.prefix(
                while: { $0.julianDate <= currentDateCoordinate.julianDate }
            )
        )
        mapView.addOverlay(polyline)
        let afterPolyline = GroundTrackOverlay(
            id: "after",
            dateCoordinates: Array(dateCoordinates.drop(
                while: { $0.julianDate < currentDateCoordinate.julianDate }
            ))
        )
        mapView.addOverlay(afterPolyline)

        if let existingAnnotation = mapView.annotations.first(where: { $0 is CurrentPositionAnnotation }) {
            mapView.removeAnnotation(existingAnnotation)
        }
        let currentPositionAnnotation = CurrentPositionAnnotation()
        currentPositionAnnotation.coordinate = CLLocationCoordinate2D(currentDateCoordinate.coordinate)
        mapView.addAnnotation(currentPositionAnnotation)
        self.dateCoordinates = dateCoordinates
    }

    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        delegate?.missionControlWillChangeViewPort(self)
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? CurrentPositionAnnotation {
            let identifier = "currentPosition"
            guard var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView else {
                return nil
            }

            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            }
            annotationView.canShowCallout = false
            annotationView.glyphImage = UIImage(
                named: "glyph_satellite",
                in: .satelliteForecastImplResourcesBundle,
                compatibleWith: nil
            )
            annotationView.markerTintColor = .systemOrange
            annotationView.glyphTintColor = .white
            return annotationView
        } else {
            return nil
        }
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? GroundTrackOverlay,
           let firstGroundTrack = polyline.dateCoordinates.first,
           let lastGroundTrack = polyline.dateCoordinates.last {
            let isBefore = polyline.id.contains("before")

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
            renderer.lineWidth = 20
            return renderer
        }

        return MKOverlayRenderer()
    }
}

#if DEBUG

struct MissionControlView_Previews: PreviewProvider {
    static let issGroundTrack: [DateCoordinate] = {
        let elements = try! Elements(
            raw: """
            ISS (ZARYA)
            1 25544U 98067A   21152.11066515  .00000451  00000-0  16375-4 0  9992
            2 25544  51.6453  62.2423 0003364  52.3737  88.5313 15.48937685286109
            """
        )

        let formatter = ISO8601DateFormatter()

        return try! elements.generateGroundTrack(
            julianDateRange: formatter.date(from: "2021-06-02T20:32:00+0800")!.julianDate...formatter.date(from: "2021-06-02T22:32:00+0800")!.julianDate,
            interval: 60 * TimeConstants.sec2day
        )
    }()

    static var previews: some View {
        MissionControlView(
            currentDateCoordinate: issGroundTrack[issGroundTrack.count / 2],
            satelliteGroundTrack: issGroundTrack
        )
        .previewLayout(.fixed(width: 368, height: 240))
    }
}

#endif
