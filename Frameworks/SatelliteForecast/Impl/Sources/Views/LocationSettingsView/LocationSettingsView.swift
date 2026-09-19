//
//  LocationSettingsView.swift
//  LocationSettingsView
//
//  Created by Ben Lu on 8/1/21.
//

import MapKit
import SatelliteForecast
import SwiftUI

public struct LocationSettingsViewState: Equatable {
    var locationSelection: LocationResources.Selection = .currentLocation
    var currentLocation: CLLocation?
    var currentLocationPlacemark: CLPlacemark?

    public init(locationSelection: LocationResources.Selection = .currentLocation, currentLocation: CLLocation? = nil, currentLocationPlacemark: CLPlacemark? = nil) {
        self.locationSelection = locationSelection
        self.currentLocation = currentLocation
        self.currentLocationPlacemark = currentLocationPlacemark
    }

    public static func == (lhs: LocationSettingsViewState, rhs: LocationSettingsViewState) -> Bool {
        return lhs.currentLocation == rhs.currentLocation &&
        lhs.currentLocationPlacemark == rhs.currentLocationPlacemark &&
        lhs.locationSelection == rhs.locationSelection
    }
}

public struct LocationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let state: LocationSettingsViewState
    let selectLocation: (LocationResources.Selection) -> Void

    public init(
        state: LocationSettingsViewState,
        selectLocation: @escaping (LocationResources.Selection) -> Void
    ) {
        self.state = state
        self.selectLocation = selectLocation
    }

    @State private var search = LocationSearchModel()

    @ViewBuilder private func autocompletionCell(locationAutoCompletion: MKLocalSearchCompletion) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(locationAutoCompletion.title)
                Text(locationAutoCompletion.subtitle)
                    .font(.system(.caption))
                    .foregroundColor(Color.secondary)
                    .tint(nil)
            }

            switch state.locationSelection {
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

    public var body: some View {
        List {
            Section(content: {
                Button(action: {
                    if state.currentLocation == nil {
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                    } else if state.locationSelection != .currentLocation {
                        search.useCurrentLocation()
                    }
                }) {
                    LocationSettingsCurrentLocationCell(
                        currentLocation: state.currentLocation,
                        currentLocationPlacemark: state.currentLocationPlacemark,
                        isSelected: state.locationSelection == .currentLocation
                    )
                }
            }, header: {
                Text("Current location", bundle: .module)
            })

            switch state.locationSelection {
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
                    Text("Custom location", bundle: .module)
                })
            }

            if let message = search.errorMessage {
                Section { Text(message).foregroundStyle(.secondary) }
            }
            Section {
                ForEach(search.results, id: \.self) { locationAutoCompletion in
                    Button(action: {
                        search.select(locationAutoCompletion)
                    }) {
                        autocompletionCell(locationAutoCompletion: locationAutoCompletion)
                    }
                }
            }
        }
        .searchable(
            text: $search.query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text("Enter address", bundle: .module)
        )
        .modifier(AppSurface())
        .navigationTitle(Text("Select Location", bundle: .module))
        .analyticsScreen(.location)
        .task(id: search.query) { await search.search() }
        .onDisappear { search.cancel() }
        .overlay(alignment: .bottom) {
            if search.isResolving { ProgressView(AppLocalization.text("Finding location…")).padding().background(.regularMaterial) }
        }
        .alert(
            Text("Location change", bundle: .module),
            isPresented: Binding<Bool>(
                get: {
                    search.pendingSelection != nil
                },
                set: { if !$0 { search.pendingSelection = nil } }
            ),
            presenting: search.pendingSelection
        ) { selection in
            Button(AppLocalization.text("No"), role: .cancel) {
                search.pendingSelection = nil
            }

            Button(AppLocalization.text("Confirm"), role: .none) {
                guard selection != .currentLocation || state.currentLocation != nil else { return }
                selectLocation(selection)
                dismiss()
                search.pendingSelection = nil
            }
        } message: { selection in
            Text(LocationSettingsView.alertMessage(from: selection))
        }
    }
}

extension LocationSettingsView {
    static func alertMessage(from locationSelection: LocationResources.Selection) -> String {
        switch locationSelection {
        case .currentLocation:
            return NSLocalizedString(
                "SatelliteListView.locationSettingsView.alert.message.currentLocation",
                tableName: nil,
                bundle: .module,
                value: "Please confirm to change location to your current location. This will affect all the satellite predictions.",
                comment: "The alert message to confirm that the user is changing into his/her current location."
            )
        case let .custom(completion, _):
            let format = NSLocalizedString(
                "SatelliteListView.locationSettingsView.alert.message.custom",
                tableName: nil,
                bundle: .module,
                value: "Please confirm to change location to %@. This will affect all the satellite predictions.",
                comment: "The alert message to confirm that the user is changing into a custom location."
            )
            return String(format: format, completion.title)
        }
    }
}
