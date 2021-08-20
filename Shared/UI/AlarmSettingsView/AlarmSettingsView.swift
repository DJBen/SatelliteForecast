//
//  AlarmSettingsView.swift
//  AlarmSettingsView
//
//  Created by Ben Lu on 8/20/21.
//

import SwiftUI
import Combine
import CombineRex
import CombineRextensions
import CoreLocation
import SatelliteKit
import SatelliteForecastCore

enum AlarmSettingsViewAction {
    case deleteNotifications(ids: Set<String>)
}

struct AlarmSettingsViewState: Equatable {
    struct Item: Equatable, Identifiable {
        let id: String
        let passNotification: PassNotification
    }
    
    var notificationItems: [Item] = []
    
    static func project(state: AppState) -> AlarmSettingsViewState {
        AlarmSettingsViewState(
            notificationItems: state.notificationState.scheduledPassNotifications.compactMap { scheduledNotification -> Item? in
                return Item(
                    id: scheduledNotification.id,
                    passNotification: scheduledNotification.notification
                )
            }
        )
    }
    
    static var empty: AlarmSettingsViewState {
        AlarmSettingsViewState()
    }
}

struct AlarmSettingsView: View {
    @ObservedObject var viewModel: ObservableViewModel<AlarmSettingsViewAction, AlarmSettingsViewState>

    var body: some View {
        List {
            ForEach(viewModel.state.notificationItems) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.passNotification.satelliteName)
                            .font(.headline)
                            .foregroundColor(Color(UIColor.label))
                        Spacer()
                    }

                    Text(CLLocation(item.passNotification.observer).coordinate.formattedString)
                        .font(.caption)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.secondary)
                    
                    Text(LocalizedStrings.AlarmSettingsView.passDescription(pass: item.passNotification.pass))
                        .font(.caption)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.secondary)
                }
            }
            .onDelete { indexSet in
                let ids = indexSet.map {
                    viewModel.state.notificationItems[$0]
                }
                .reduce(into: Set<String>(), { $0.insert($1.id) })
                
                viewModel.dispatch(.deleteNotifications(ids: ids))
            }
        }
        .navigationBarTitle("Alarms", displayMode: .inline)
        .toolbar {
            EditButton()
        }
    }
}

extension ViewProducer where Context == Void, ProducedView == AlarmSettingsView {
    static func alarmSettingsView<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            AlarmSettingsView(
                viewModel: viewModel
                    .projection(
                        action: AppAction.alarmSettingsView,
                        state: AlarmSettingsViewState.project(state:)
                    )
                    .asObservableViewModel(initialState: .empty, emitsValue: .whenDifferent)
            )
        }
    }
}

#if DEBUG
struct AlarmSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AlarmSettingsView(viewModel: .mock(state: AlarmSettingsViewState()))
    }
}
#endif
