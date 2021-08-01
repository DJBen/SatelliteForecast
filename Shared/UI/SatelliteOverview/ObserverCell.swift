//
//  ObserverCell.swift
//  ObserverCell
//
//  Created by Ben Lu on 7/31/21.
//

import Contacts
import CombineRex
import CombineRextensions
import MapKit
import SwiftUI
import SatelliteKit
import SwiftUIVisualEffects

enum ObserverCellAction {

}

struct ObserverCellState: Equatable {
    var locationState: LocationState

    static func project(state: AppState) -> ObserverCellState {
        ObserverCellState(locationState: state.locationState)
    }

    static var empty: ObserverCellState {
        ObserverCellState(locationState: .empty)
    }
}

struct ObserverCell: View {
    @ObservedObject var viewModel: ObservableViewModel<ObserverCellAction, ObserverCellState>

    @Environment(\.colorScheme) private var colorScheme

    private func region(coordinate: CLLocationCoordinate2D, parentRect: CGRect, delta: CLLocationDegrees) -> MKCoordinateRegion {
        let offset = delta / Double(parentRect.width) * 60
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: coordinate.latitude - offset, longitude: coordinate.longitude),
            span: MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)
        )
    }

    @ViewBuilder func map(coordinate: CLLocationCoordinate2D, rect: CGRect, delta: CLLocationDegrees = 0.5) -> some View {
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
            showsUserLocation: true
        )
    }

    @ViewBuilder var background: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)

            if rect.isEmpty {
                EmptyView()
            } else {
                let locationState = viewModel.state.locationState
                switch locationState.authorizationStatus {
                case .authorizedAlways, .authorizedWhenInUse:
                    if let location = viewModel.state.locationState.location {
                        map(coordinate: location.coordinate, rect: rect)
                    } else {
                        ZStack {
                            Color.gray
                            ProgressView()
                                .offset(x: 0, y: -(rect.height - 120) / 2)
                        }
                    }
                case .denied, .restricted:
                    ZStack {
                        map(coordinate: CLLocationCoordinate2D(), rect: rect, delta: 90)
                        Text("\(Image(systemName: "nosign")) Location access denied")
                            .foregroundColor(Color("locationAccessDenied_foreground"))
                            .fontWeight(.semibold)
                            .offset(x: 0, y: -(rect.height - 120) / 2)
                    }
                case .notDetermined:
                    EmptyView()
                @unknown default:
                    EmptyView()
                }
            }
        }
    }

    static let addressFormatter: CNPostalAddressFormatter = {
        let formatter = CNPostalAddressFormatter()
        formatter.style = .mailingAddress
        return formatter
    }()

    var secondaryLabelText: String? {
        let locationState = viewModel.state.locationState

        switch locationState.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if let placemark = locationState.placemark {
                guard let postalAddress = placemark.postalAddress else { return nil }
                let formatterString = Self.addressFormatter.string(from: postalAddress)
                return formatterString.replacingOccurrences(of: "\n", with: ", ")
            } else {
                return nil
            }
        case .denied:
            return "Tap to manually select a location"
        case .restricted, .notDetermined:
            return nil
        @unknown default:
            return nil
        }
    }

    var titleText: String {
        let locationState = viewModel.state.locationState

        switch locationState.selection {
        case .userLocation:
            return LocalizedStrings.ObserverCell.Title.currentLocation
        case let .custom(name, _):
            return name
        }
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading) {
                Spacer()
                    .frame(height: 120)

                ZStack {
                    Color.clear
                        .blurEffect()

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(titleText)
                                .font(.headline)
                                .foregroundColor(Color(UIColor.label))
                            Spacer()
                        }

                        if let secondaryLabelText = secondaryLabelText {
                            Text(secondaryLabelText)
                                .font(.caption)
                                .multilineTextAlignment(.leading)
                                .foregroundColor(colorScheme == .light ? Color(UIColor.systemGray2) : Color(UIColor.systemGray4))
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

            Image(systemName: "chevron.right")
                .foregroundColor(Color(UIColor.secondaryLabel))
        }
    }
}

extension ViewProducer where Context == Void, ProducedView == ObserverCell {
    static func observerCell<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            ObserverCell(
                viewModel: viewModel.projection(
                    action: AppAction.observerCell,
                    state: ObserverCellState.project(state:)
                )
                .asObservableViewModel(initialState: .empty, emitsValue: .whenDifferent)
            )
        }
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
                    locationState: LocationState(
                        authorizationStatus: .authorizedAlways,
                        currentLocation: location
                    )
                )
            )
        )
        .fixedSize(horizontal: false, vertical: true)

        ObserverCell(
            viewModel: .mock(
                state: ObserverCellState(
                    locationState: LocationState(
                        authorizationStatus: .denied
                    )
                )
            )
        )
        .fixedSize(horizontal: false, vertical: true)
    }
}
#endif
