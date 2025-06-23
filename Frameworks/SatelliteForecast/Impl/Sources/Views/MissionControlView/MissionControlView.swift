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
    var currentDateCoordinate: DateCoordinate
    var satelliteGroundTrack: [DateCoordinate]

    @State var viewportIsOriginal: Bool = true
    var showResetButton: Bool {
        !viewportIsOriginal
    }

    enum ZoomLevel: Equatable, Hashable {
        case global
        case close
    }

    @State var zoomLevel: ZoomLevel = .global

    @State private var resetButtonPublisher = PassthroughSubject<Void, Never>()

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .topLeading) {
            MissionControlViewControllerWrapperView(
                currentDateCoordinate: currentDateCoordinate,
                satelliteGroundTrack: satelliteGroundTrack,
                viewportIsOriginal: $viewportIsOriginal,
                zoomLevel: $zoomLevel,
                resetButtonTappedPublisher: resetButtonPublisher.eraseToAnyPublisher()
            )

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
                        Text(verbatim: "Select zoom level")
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

                if showResetButton {
                    Button(
                        NSLocalizedString(
                            "MissionControlView.resetButton.title",
                            tableName: nil,
                            bundle: .module,
                            value: "Recenter",
                            comment: """
                            The title for the reset button within mission control view to restore the
                            viewport to its orignal position.
                            """
                        )
                    ) {
                        resetButtonPublisher.send(())
                    }
                    .padding([.top, .bottom], 8)
                    .padding([.leading, .trailing], 8)
                    .vibrancyEffect()
                    .background(
                        Color.clear.blurEffect()
                    )
                    .cornerRadius(8)
                    .blurEffectStyle(colorScheme == .light ? .systemChromeMaterialLight : .systemChromeMaterialDark)
                    .vibrancyEffectStyle(.fill)
                }
            }
            .padding(8)
        }
        .cornerRadius(16)
    }
}

struct MissionControlViewControllerWrapperView: UIViewControllerRepresentable {
    class Coordinator: NSObject, MissionControlViewControllerDelegate {
        @Binding var viewportIsOriginal: Bool

        init(viewportIsOriginal: Binding<Bool>) {
            self._viewportIsOriginal = viewportIsOriginal
        }

        func missionControlDidChangeViewPort(_ viewController: MissionControlViewController) {
            viewportIsOriginal = false
        }

        func missionControlDidResetViewport(_ viewController: MissionControlViewController) {
            viewportIsOriginal = true
        }
    }

    var currentDateCoordinate: DateCoordinate
    var satelliteGroundTrack: [DateCoordinate]
    @Binding var viewportIsOriginal: Bool
    @Binding var zoomLevel: MissionControlView.ZoomLevel
    var resetButtonTappedPublisher: AnyPublisher<Void, Never>

    func makeUIViewController(context: Context) -> MissionControlViewController {
        let viewController = MissionControlViewController(
            resetButtonTappedPublisher: resetButtonTappedPublisher
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
            viewportIsOriginal: $viewportIsOriginal
        )
    }
}

@objc protocol MissionControlViewControllerDelegate {
    func missionControlDidChangeViewPort(_ viewController: MissionControlViewController)
    func missionControlDidResetViewport(_ viewController: MissionControlViewController)
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

    var cancellables = Set<AnyCancellable>()

    init(
        resetButtonTappedPublisher: AnyPublisher<Void, Never>
    ) {
        super.init(nibName: nil, bundle: nil)

        resetButtonTappedPublisher.sink(receiveValue: { [unowned self] in
            self.resetViewport()
        })
        .store(in: &cancellables)
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
    }

    func setState(
        currentDateCoordinate: DateCoordinate,
        dateCoordinates: [DateCoordinate],
        zoomLevel: MissionControlView.ZoomLevel
    ) {
        // Rezoom camera if zoom level has changed
        if mapView.camera.centerCoordinateDistance != 0 && abs(mapView.camera.centerCoordinateDistance - centerCoordinateDistance(for: zoomLevel)) > 1 {
            let camera = MKMapCamera(
                lookingAtCenter: CLLocationCoordinate2D(currentDateCoordinate.coordinate),
                fromEyeCoordinate: CLLocationCoordinate2D(currentDateCoordinate.coordinate),
                eyeAltitude: centerCoordinateDistance(for: zoomLevel)
            )
            mapView.setCamera(camera, animated: true)
        }

        if self.currentDateCoordinate == currentDateCoordinate && self.dateCoordinates == dateCoordinates {
            return
        }

        if self.currentDateCoordinate == nil {
            mapView.setCenter(CLLocationCoordinate2D(currentDateCoordinate.coordinate), animated: true)
        }
        self.currentDateCoordinate = currentDateCoordinate

        mapView.overlays
            .filter { $0 is MKGeodesicPolyline }
            .forEach { mapView.removeOverlay($0) }
        let beforeDataset = dateCoordinates.prefix(
            while: { $0.julianDate <= currentDateCoordinate.julianDate }
        )
        let polyline = MKGeodesicPolyline(
            points: beforeDataset
            .map(\.coordinate).map { MKMapPoint(CLLocationCoordinate2D($0)) },
            count: beforeDataset.count
        )
        polyline.sf_identifier = "before"
        mapView.addOverlay(polyline)
        let afterDataset = dateCoordinates.drop(
            while: { $0.julianDate < currentDateCoordinate.julianDate }
        )
        let afterPolyline = MKGeodesicPolyline(
            points: Array(afterDataset)
            .map(\.coordinate).map { MKMapPoint(CLLocationCoordinate2D($0)) },
            count: afterDataset.count
        )
        afterPolyline.sf_identifier = "after"
        mapView.addOverlay(afterPolyline)

        var currentPositionAnnotation: CurrentPositionAnnotation
        if let existingAnnotation = mapView.annotations.first(where: { $0 is CurrentPositionAnnotation }) as? CurrentPositionAnnotation {
            currentPositionAnnotation = existingAnnotation
        } else {
            currentPositionAnnotation = CurrentPositionAnnotation()
            mapView.addAnnotation(currentPositionAnnotation)
        }
        UIView.animate(withDuration: 5, delay: 0, options: [.curveLinear]) {
            currentPositionAnnotation.coordinate = CLLocationCoordinate2D(currentDateCoordinate.coordinate)
        }
        self.dateCoordinates = dateCoordinates
    }

    func resetViewport() {
        if let currentDateCoordinate = currentDateCoordinate {
            mapView.setCenter(CLLocationCoordinate2D(currentDateCoordinate.coordinate), animated: true)
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
}

extension MissionControlViewController: MKMapViewDelegate {
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        guard let coordinate = self.currentDateCoordinate?.coordinate else {
            return
        }
        let tolerance = mapView.camera.centerCoordinateDistance == 0 ? 1e-5 : mapView.camera.centerCoordinateDistance * 1e-10
        if mapView.centerCoordinate.close(to: CLLocationCoordinate2D(coordinate), tolerance: tolerance) {
            delegate?.missionControlDidResetViewport(self)
        } else {
            delegate?.missionControlDidChangeViewPort(self)
        }
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let identifier = "currentPosition"
        guard let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView else {
            return nil
        }
        annotationView.canShowCallout = false
        annotationView.glyphImage = UIImage(
            named: "glyph_satellite",
            in: .module,
            compatibleWith: nil
        )
        annotationView.markerTintColor = .systemOrange
        annotationView.glyphTintColor = .white
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
        .frame(width: 368, height: 280)
    }
}

#endif
