//
//  ObserverCell.swift
//  ObserverCell
//
//  Created by Ben Lu on 7/31/21.
//

import Contacts
@preconcurrency import CombineRex
import MapKit
import SwiftUI
@preconcurrency import SatelliteKit
import SatelliteForecast
import SwiftUIVisualEffects

public enum ObserverCellAction {

}

public struct ObserverCellState {
    var locationResources: LocationResources = .init()

    public init(locationResources: LocationResources = .init()) {
        self.locationResources = locationResources
    }
}

extension ObserverCellState: Equatable {}

public struct ObserverCell: View {
    @ObservedObject var viewModel: ObservableViewModel<ObserverCellAction, ObserverCellState>

    public init(
        viewModel: ObservableViewModel<ObserverCellAction, ObserverCellState>
    ) {
        self.viewModel = viewModel
    }

    @State private var textRegionSize: CGSize = .zero

    @Environment(\.colorScheme) private var colorScheme

    private func region(coordinate: CLLocationCoordinate2D, parentRect: CGRect, delta: CLLocationDegrees) -> MKCoordinateRegion {
        let offset = delta / Double(parentRect.width) * 60
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: coordinate.latitude - offset, longitude: coordinate.longitude),
            span: MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)
        )
    }

    struct CustomLocationMarker: Identifiable {
        let autocompletion: MKLocalSearchCompletion
        var location: MapMarker

        var id: String {
            autocompletion.title + autocompletion.subtitle
        }
    }

    private var annotationItems: [CustomLocationMarker] {
        let locationResources = viewModel.state.locationResources
        switch locationResources.selection {
        case let .custom(completion, placemark):
            return [
                CustomLocationMarker(
                    autocompletion: completion,
                    location: MapMarker(coordinate: placemark.coordinate)
                )
            ]
        case .currentLocation:  
            return []
        }
    }

    @ViewBuilder func map(coordinate: CLLocationCoordinate2D, rect: CGRect, delta: CLLocationDegrees = 0.1) -> some View {
        Map(
            coordinateRegion: Binding<MKCoordinateRegion>(
                get: {
                    self.region(
                        coordinate: coordinate,
                        parentRect: rect,
                        delta: delta
                    )
                },
                set: { region in

                }
            ),
            interactionModes: [],
            showsUserLocation: true,
            annotationItems: annotationItems,
            annotationContent: { $0.location }
        )
    }

    @ViewBuilder var background: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)

            if rect.isEmpty {
                EmptyView()
            } else {
                let locationResources = viewModel.state.locationResources
                switch locationResources.authorizationStatus {
                case .authorizedAlways, .authorizedWhenInUse:
                    if let location = viewModel.state.locationResources.location {
                        map(coordinate: location.coordinate, rect: rect)
                    } else {
                        ZStack {
                            Color.gray
                            ProgressView()
                                .offset(x: 0, y: -(rect.height - 140) / 2)
                        }
                    }
                case .denied, .restricted:
                    if let location = viewModel.state.locationResources.location {
                        map(coordinate: location.coordinate, rect: rect)
                    } else {
                        ZStack {
                            map(coordinate: CLLocationCoordinate2D(), rect: rect, delta: 90)
                            Text("\(Image(systemName: "dot.circle.and.hand.point.up.left.fill").symbolRenderingMode(.hierarchical)) Select a location")
                                .foregroundColor(Color("locationAccessDenied_foreground", bundle: .module))
                                .fontWeight(.semibold)
                                .offset(x: 0, y: -(rect.height - 140) / 2)
                        }
                    }
                case .notDetermined:
                    EmptyView()
                @unknown default:
                    EmptyView()
                }
            }
        }
    }

    var secondaryLabelText: String? {
        let locationResources = viewModel.state.locationResources

        switch locationResources.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if let placemark = locationResources.placemark {
                return placemark.formattedString
            } else {
                return nil
            }
        case .denied:
            if let placemark = locationResources.placemark {
                return placemark.formattedString
            } else {
                return "You have declined sharing the location."
            }
        case .restricted, .notDetermined:
            if let placemark = locationResources.placemark {
                return placemark.formattedString
            } else {
                return "Location access is restricted."
            }
        @unknown default:
            return nil
        }
    }

    var titleText: String {
        let locationResources = viewModel.state.locationResources

        switch locationResources.selection {
        case .currentLocation:
            switch locationResources.authorizationStatus {
            case .denied, .restricted:
                return ObserverCell.Title.requiresLocationSelection
            default:
                return ObserverCell.Title.currentLocation
            }
        case let .custom(completion, _):
            return completion.title
        }
    }

    private struct SecondaryLabelModifier: ViewModifier {
        @Environment(\.colorScheme) private var colorScheme

        func body(content: Content) -> some View {
            content.font(.caption)
                .multilineTextAlignment(.leading)
                .foregroundColor(colorScheme == .light ? Color(UIColor.systemGray2) : Color(UIColor.systemGray4))
        }
    }

    public var body: some View {
        VStack(alignment: .leading) {
            Spacer()
                .frame(height: 135)

            ZStack {
                Color.clear
                    .blurEffect()

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(titleText)
                            .font(.headline)
                            .foregroundColor(Color(UIColor.label))
                        Spacer()
                        Image(systemName: "chevron.forward")
                            .font(.headline)
                            .foregroundColor(Color(UIColor.label))
                    }

                    if let secondaryLabelText = secondaryLabelText {
                        Text(secondaryLabelText)
                            .modifier(SecondaryLabelModifier())
                            .vibrancyEffect()
                    }

                    if let coordinate = viewModel.state.locationResources.location?.coordinate {
                        Text(coordinate.formattedString)
                            .modifier(SecondaryLabelModifier())
                            .vibrancyEffect()
                    }
                }
                .padding()
            }
            .blurEffectStyle(colorScheme == .light ? .systemChromeMaterialLight : .systemChromeMaterialDark)
            .vibrancyEffectStyle(.fill)
        }
        .background(background)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 8,
                style: .continuous
            )
        )
    }
}

extension ObserverCell {
    enum Title {
        static let currentLocation: String = NSLocalizedString(
            "SatelliteListView.observerCell.title.currentLocation",
            tableName: nil,
            bundle: .module,
            value: "Current location",
            comment: "The current location text, indicating that the observer location is the current location."
        )

        static let requiresLocationSelection: String = NSLocalizedString(
            "SatelliteListView.observerCell.title.requiresLocationSelection",
            tableName: nil,
            bundle: .module,
            value: "Open to select location",
            comment: "The text indicating that location service is not available, nor has the user selecetd a location manually."
        )
    }
}

#if DEBUG
struct ObserverCell_Previews: PreviewProvider {
    static var previews: some View {
        // 2000 Broadway, Redwood City, CA 94063
        let location = CLLocation(latitude: 37.486743000691185, longitude: -122.22655970246515)
        ObserverCell(
            viewModel: .mock(
                state: ObserverCellState(
                    locationResources: LocationResources(
                        authorizationStatus: .authorizedAlways,
                        currentLocation: location
                    )
                )
            )
        )
        .previewLayout(.fixed(width: 200, height: 200))

        ObserverCell(
            viewModel: .mock(
                state: ObserverCellState(
                    locationResources: LocationResources(
                        authorizationStatus: .denied
                    )
                )
            )
        )
        .previewLayout(.fixed(width: 200, height: 200))

    }
}
#endif
