//
//  AlarmSettingsCell.swift
//  AlarmSettingsCell
//
//  Created by Ben Lu on 8/20/21.
//

import SwiftUI
import CombineRex
import CombineRextensions

enum AlarmSettingsCellAction {

}

struct AlarmSettingsCellState: Equatable {
    var scheduledPassNotifications: Set<ScheduledPassNotification> = []

    static func project(state: AppState) -> AlarmSettingsCellState {
        AlarmSettingsCellState(scheduledPassNotifications: state.notificationState.scheduledPassNotifications)
    }

    static var empty: AlarmSettingsCellState {
        AlarmSettingsCellState()
    }
}

struct AlarmSettingsCell: View {
    @ObservedObject var viewModel: ObservableViewModel<AlarmSettingsCellAction, AlarmSettingsCellState>

    @Environment(\.colorScheme) private var colorScheme

    private var background: some View {
        var colors = [UIColor.systemPink, UIColor.systemPurple]
        
        if colorScheme == .dark {
            colors = colors.map { $0.darken(by: 0.3) }
        }
        
        return LinearGradient(
            gradient: Gradient(colors: colors.map(Color.init)),
            startPoint: UnitPoint(x: 0, y: 0),
            endPoint: UnitPoint(x: 1, y: 1)
        )
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: viewModel.state.scheduledPassNotifications.isEmpty ? "bell" : "bell.fill")
                        .font(.headline)
                        .foregroundColor(Color(UIColor.label))
                    
                    Text(LocalizedStrings.AlarmSettingsCell.title)
                        .font(.headline)
                        .foregroundColor(Color(UIColor.label))

                    Spacer()
                }

                Text(LocalizedStrings.AlarmSettingsCell.description(numberOfAlerts: viewModel.state.scheduledPassNotifications.count))
                    .font(.caption)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.secondary)
            }
        
        }
        .padding()
        .background(background)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 8,
                style: .continuous
            )
        )
    }
}

extension ViewProducer where Context == Void, ProducedView == AlarmSettingsCell {
    static func alarmSettingsCell<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            AlarmSettingsCell(
                viewModel: viewModel.projection(
                    action: AppAction.alarmSettingsCell,
                    state: AlarmSettingsCellState.project(state:)
                )
                .asObservableViewModel(initialState: .empty, emitsValue: .whenDifferent)
            )
        }
    }
}

#if DEBUG
struct AlarmSettingsCell_Previews: PreviewProvider {
    static var previews: some View {
        AlarmSettingsCell(
            viewModel: .mock(state: AlarmSettingsCellState(scheduledPassNotifications: []))
        )
    }
}
#endif
