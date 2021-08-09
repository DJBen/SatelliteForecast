//
//  LocationSettingsView.swift
//  LocationSettingsView
//
//  Created by Ben Lu on 8/1/21.
//

import SwiftUI
import Combine
import CombineRex
import MapKit

struct LocationSettingsViewState: Equatable {
    static func == (lhs: LocationSettingsViewState, rhs: LocationSettingsViewState) -> Bool {
        return lhs.currentLocation == rhs.currentLocation &&
        lhs.currentLocationPlacemark == rhs.currentLocationPlacemark &&
        lhs.locationSelection == rhs.locationSelection &&
        lhs.autocompletionResult?.successValue == rhs.autocompletionResult?.successValue
    }

    var currentLocation: CLLocation?
    var currentLocationPlacemark: CLPlacemark?
    var locationSelection: LocationState.Selection
    var autocompletionResult: Result<[MKLocalSearchCompletion], Error>?

    static func project(state: AppState) -> LocationSettingsViewState {
        LocationSettingsViewState(
            currentLocation: state.locationState.currentLocation,
            currentLocationPlacemark: state.locationState.currentLocationPlacemark,
            locationSelection: state.locationState.selection,
            autocompletionResult: state.locationState.autocompletionResult
        )
    }

    static var empty: LocationSettingsViewState {
        LocationSettingsViewState(locationSelection: .currentLocation)
    }
}

fileprivate class SearchDebouncer: NSObject, ObservableObject {
    @Published var searchTerm = ""
    @Published var debouncedSearchTerm = ""

    @Published var selectedAutoCompletion: MKLocalSearchCompletion?
    @Published var autocompletionPlacemark: MKPlacemark?

    private var cancellables : Set<AnyCancellable> = []

    private static func reconcileLocation(location: MKLocalSearchCompletion?) -> AnyPublisher<MKPlacemark?, Error> {
        guard let location = location else {
            return Just(nil)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }

        let searchRequest = MKLocalSearch.Request(completion: location)
        let search = MKLocalSearch(request: searchRequest)
        return Future() { promise in
            search.start { (response, error) in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(response?.mapItems.first?.placemark))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    override init() {
        super.init()

        $searchTerm
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .removeDuplicates()
            .assign(to: \.debouncedSearchTerm, on: self)
            .store(in: &cancellables)

        $selectedAutoCompletion
            .removeDuplicates()
            .flatMap { autoCompletion in
                Self.reconcileLocation(location: autoCompletion)
            }
            .sink { completion in

            } receiveValue: { [unowned self] coordinate in
                self.autocompletionPlacemark = coordinate
            }
            .store(in: &cancellables)
    }
}

struct LocationSettingsView: View {
    @ObservedObject var viewModel: ObservableViewModel<LocationAction, LocationSettingsViewState>
    @StateObject private var searchDebouncer = SearchDebouncer()
    @State private var selection: String?
    @State private var nextLocationSelection: LocationState.Selection?

    @ViewBuilder private func autocompletionCell(locationAutoCompletion: MKLocalSearchCompletion) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(locationAutoCompletion.title)
                Text(locationAutoCompletion.subtitle)
                    .font(.system(.caption))
                    .foregroundColor(Color.secondary)
                    .tint(nil)
            }

            switch viewModel.state.locationSelection {
            case .currentLocation:
                EmptyView()
            case let .custom(completion, _):
                if completion == locationAutoCompletion {
                    Spacer()
                    Image(systemName: "checkmark")
                }
            }
        }
    }

    var body: some View {
        List {
            Section(content: {
                Button(action: {
                    if viewModel.state.locationSelection != .currentLocation {
                        nextLocationSelection = .currentLocation
                    }
                }) {
                    LocationSettingsCurrentLocationCell(
                        currentLocation: viewModel.state.currentLocation,
                        currentLocationPlacemark: viewModel.state.currentLocationPlacemark,
                        isSelected: viewModel.state.locationSelection == .currentLocation
                    )
                }
            }, header: {
                Text("Current location")
            })

            switch viewModel.state.locationSelection {
            case .currentLocation:
                EmptyView()
            case let .custom(completion, _):
                Section(content: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(completion.title)
                            Text(completion.subtitle)
                                .font(.system(.caption))
                                .tint(nil)
                        }
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }, header: {
                    Text("Custom location")
                })
            }

            Section {
                ForEach(viewModel.state.autocompletionResult?.successValue ?? [], id: \.self) { locationAutoCompletion in
                    Button(action: {
                        searchDebouncer.selectedAutoCompletion = locationAutoCompletion
                    }) {
                        autocompletionCell(locationAutoCompletion: locationAutoCompletion)
                    }
                }
            }
        }
        .searchable(
            text: $searchDebouncer.searchTerm,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Enter address"
        )
        .navigationTitle(Text("Select Location"))
        .onReceive(
            searchDebouncer.$debouncedSearchTerm
        ) { newSearchTerm in
            viewModel.dispatch(.requestAutoCompletion(newSearchTerm))
        }
        .onReceive(
            searchDebouncer.$autocompletionPlacemark
        ) { placemark in
            guard let autoCompletion = searchDebouncer.selectedAutoCompletion,
                    let placemark = placemark else {
                return
            }
            nextLocationSelection = .custom(autoCompletion, placemark)
        }
        .alert(
            Text("Location change"),
            isPresented: Binding<Bool>(
                get: {
                    nextLocationSelection != nil
                },
                set: { _ in
                }
            )
        ) {
            Button("No", role: .cancel) {
                nextLocationSelection = nil
            }

            Button("Confirm", role: .none) {
                guard let nextLocationSelection = nextLocationSelection else {
                    fatalError()
                }
                viewModel.dispatch(.selectLocation(nextLocationSelection))
                self.nextLocationSelection = nil
            }
        } message: {
            Text(LocalizedStrings.LocationSettingsView.alertMessage(from: nextLocationSelection ?? .currentLocation))
        }
    }


}

import CombineRextensions

extension ViewProducer where Context == Void, ProducedView == LocationSettingsView {
    static func locationSettings<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            LocationSettingsView(
                viewModel: viewModel
                    .projection(
                        action: { AppAction.location($0) },
                        state: LocationSettingsViewState.project(state:)
                    )
                    .asObservableViewModel(initialState: .empty, emitsValue: .whenDifferent)
            )
        }
    }
}

#if DEBUG
struct LocationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        LocationSettingsView(
            viewModel: .mock(state: .empty)
        )
    }
}
#endif
