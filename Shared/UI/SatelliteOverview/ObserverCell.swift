//
//  ObserverCell.swift
//  ObserverCell
//
//  Created by Ben Lu on 7/31/21.
//

import CombineRex
import CombineRextensions
import MapKit
import SwiftUI
import SatelliteKit
import SwiftUIVisualEffects

enum ObserverCellAction {

}

struct ObserverCellState: Equatable {
    var observer: CLLocation

    static func project(state: AppState) -> ObserverCellState? {
        state.locationState.location.map { ObserverCellState(observer: $0) }
    }
}

struct ObserverCell: View {
    @ObservedObject var viewModel: ObservableViewModel<ObserverCellAction, ObserverCellState?>

    @Environment(\.colorScheme) private var colorScheme

    private func region(coordinate: CLLocationCoordinate2D, parentRect: CGRect, delta: CLLocationDegrees = 1) -> MKCoordinateRegion {
        let offset = delta / Double(parentRect.width) * 60
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: coordinate.latitude - offset, longitude: coordinate.longitude),
            span: MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)
        )
    }

    @ViewBuilder private func unwrapState<Content: View>(@ViewBuilder content: (ObserverCellState) -> Content) -> some View {
        if let state = viewModel.state {
            content(state)
        }
    }

    @ViewBuilder func backgroundMap(rect: CGRect) -> some View {
        unwrapState { state in
            if rect.isEmpty {
                EmptyView()
            } else {
                Map(
                    coordinateRegion: Binding<MKCoordinateRegion>(
                        get: {
                            self.region(coordinate: state.observer.coordinate, parentRect: rect)
                        },
                        set: { region in

                        }
                    ),
                    interactionModes: [],
                    showsUserLocation: true
                )
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)

            HStack(alignment: .center) {
                VStack(alignment: .leading) {
                    Spacer()
                        .frame(height: 120)

                    ZStack {
                        Color.clear
                            .blurEffect()

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(LocalizedStrings.ObserverCell.Title.currentLocation)
                                    .font(.headline)
                                    .foregroundColor(Color(UIColor.label))
                                Spacer()
                            }

//                        Text(LocalizedStrings.SatelliteOverviewCell.satelliteOfSpecialInterestLocalizedDescription(satellite))
//                            .font(.caption)
//                            .multilineTextAlignment(.leading)
//                            .foregroundColor(colorScheme == .light ? Color(UIColor.systemGray2) : Color(UIColor.systemGray4))
//                            .vibrancyEffect()
                        }
                        .padding()
                    }
                    .blurEffectStyle(colorScheme == .light ? .systemChromeMaterialLight : .systemChromeMaterialDark)
                    .vibrancyEffectStyle(.fill)
                }
                .background(backgroundMap(rect: rect))
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
}

extension ViewProducer where Context == Void, ProducedView == ObserverCell {
    static func observerCell<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            ObserverCell(
                viewModel: viewModel.projection(
                    action: AppAction.observerCell,
                    state: ObserverCellState.project(state:)
                )
                .asObservableViewModel(initialState: nil, emitsValue: .whenDifferent)
            )
        }
    }
}

#if DEBUG
struct ObserverCell_Previews: PreviewProvider {
    static var previews: some View {
        // 2000 Broadway, Redwood City, CA 94063
        let observer = CLLocation(latitude: 37.486743000691185, longitude: -122.22655970246515)
        ObserverCell(viewModel: .mock(state: ObserverCellState(observer: observer)))
    }
}
#endif
