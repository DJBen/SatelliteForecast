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
    var currentDate: Double = 0
    
    static func project(state: AppState) -> AlarmSettingsViewState {
        AlarmSettingsViewState(
            notificationItems: state.notificationState.scheduledPassNotifications.compactMap { scheduledNotification -> Item? in
                return Item(
                    id: scheduledNotification.id,
                    passNotification: scheduledNotification.notification
                )
            }
            .sorted(by: { $0.passNotification.pass.rise.julianDate < $1.passNotification.pass.rise.julianDate }),
            currentDate: state.julianDate
        )
    }
    
    static var empty: AlarmSettingsViewState {
        AlarmSettingsViewState()
    }
}

struct AlarmSettingsView: View {
    @ObservedObject var viewModel: ObservableViewModel<AlarmSettingsViewAction, AlarmSettingsViewState>
    
    @ViewBuilder private func itemView(_ item: AlarmSettingsViewState.Item) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.passNotification.satelliteName)
                    .font(.headline)
                    .foregroundColor(Color(UIColor.label))
                
                Spacer()
                
                Text(Date(julianDate: item.passNotification.alertJulianDate).formatted())
                    .font(.subheadline)
                    .foregroundColor(Color(UIColor.secondaryLabel))
            }

            HStack {
                Text(CLLocation(item.passNotification.observer).coordinate.formattedString)
                    .font(.caption)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if item.passNotification.timeOffset != 0 {
                    Text(LocalizedStrings.AlarmSettingsView.alarmOffsetDescription(timeInterval: item.passNotification.timeOffset))
                        .font(.caption)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
            }
                        
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStrings.AlarmSettingsView.passDescription(pass: item.passNotification.pass))
                    .font(.caption)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)
                
                Text(LocalizedStrings.AlarmSettingsView.passVisibilityDescription(pass: item.passNotification.pass))
                    .font(.caption)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)
            }
        }
        .padding([.top, .bottom], 4)
    }
    
    @ViewBuilder var alarmList: some View {
        if viewModel.state.notificationItems.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "bell.circle")
                    .font(.title)
                Text(
                    """
                    Your alarms will appear here. You may swipe on a pass to schedule an alarm.
                    """
                )
                .foregroundColor(Color(UIColor.secondaryLabel))
                .multilineTextAlignment(.center)
                .padding(EdgeInsets(top: 0, leading: 32, bottom: 0, trailing: 32))
            }
        } else {
            List {
                ForEach(viewModel.state.notificationItems) { item in
                    itemView(item)
                }
                .onDelete { indexSet in
                    let ids = indexSet.map {
                        viewModel.state.notificationItems[$0]
                    }
                    .reduce(into: Set<String>(), { $0.insert($1.id) })
                    
                    viewModel.dispatch(.deleteNotifications(ids: ids))
                }
            }
            .listStyle(.insetGrouped)
        }
    }
    
    var body: some View {
        alarmList
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
        let tle = try! TLE(
            raw: """
            ISS (ZARYA)
            1 25544U 98067A   21155.08058252  .00001489  00000-0  35252-4 0  9997
            2 25544  51.6446  47.5538 0003512  61.1482  91.5411 15.48950578286563
            """
        )
        let sat = Satellite(withTLE: tle)
        // 2000 Broadway, Redwood City, CA 94063
        let observer = LatLonAlt(lat: 37.486743000691185, lon: -122.22655970246515, alt: 0)
        // Date range
        let startDate = Date(timeIntervalSinceReferenceDate: 20 * 365 * 86400)
        let julianDateRange = startDate.advanced(by: -60 * 60 * 2).julianDate..<startDate.advanced(by: 60 * 60 * 30).julianDate
        let coarseSnapshots = sat.snapshots(
            observer: observer,
            julianDateRange: julianDateRange,
            interval: 60
        )
        let (passes, _) = sat.findPasses(
            noradIndex: tle.noradIndex,
            observer: observer,
            coarseSnapshots: coarseSnapshots
        )
        
        let items = passes.enumerated().map { index, pass in
            AlarmSettingsViewState.Item(
                id: "id_\(index)",
                passNotification: PassNotification(
                    pass: pass,
                    satelliteName: "ISS (Zarya)",
                    observer: observer,
                    timeOffset: Double.random(in: -7200...600)
                )
            )
        }
        
        AlarmSettingsView(
            viewModel: .mock(
                state: AlarmSettingsViewState(
                    notificationItems: items,
                    currentDate: startDate.julianDate
                )
            )
        )
    }
}
#endif
