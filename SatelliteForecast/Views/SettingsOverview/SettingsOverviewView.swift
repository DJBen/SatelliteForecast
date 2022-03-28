//
//  SettingsOverviewView.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/19/22.
//

import CombineRex
import CombineRextensions
import SwiftRex
import SwiftUI

enum SettingsOverviewViewAction {
}

extension SettingsOverviewViewAction: Equatable {}

struct SettingsOverviewViewState {
}

extension SettingsOverviewViewState: Equatable {}

protocol SettingsOverviewView: View {}

struct SettingsOverviewViewImpl: SettingsOverviewView {
    @ObservedObject var viewModel: ObservableViewModel<SettingsOverviewViewAction, SettingsOverviewViewState>
    let alarmSettingsViewProducer: ViewProducer<Void, AlarmSettingsView>
    let locationSettingsViewProducer: ViewProducer<Void, LocationSettingsView>

    var body: some View {
        Text("Hello, World!")
    }
}

#if DEBUG

struct SettingsOverviewView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsOverviewViewImpl(
            viewModel: .mock(state: .init()),
            alarmSettingsViewProducer: .crash,
            locationSettingsViewProducer: .crash
        )
    }
}

#endif
