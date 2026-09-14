//
//  AlarmSettingsCell.swift
//  AlarmSettingsCell
//
//  Created by Ben Lu on 8/20/21.
//

import SwiftUI
@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import SatelliteForecast

public struct AlarmSettingsCellState: Equatable {
    public var scheduledPassNotifications: Set<ScheduledPassNotification> = []

    public init(scheduledPassNotifications: Set<ScheduledPassNotification> = []) {
        self.scheduledPassNotifications = scheduledPassNotifications
    }
}

public struct AlarmSettingsCell: View {
    @ObservedObject var viewModel: ObservableViewModel<AlarmSettingsCellAction, AlarmSettingsCellState>

    public init(
        viewModel: ObservableViewModel<AlarmSettingsCellAction, AlarmSettingsCellState>
    ) {
        self.viewModel = viewModel
    }

    @Environment(\.colorScheme) private var colorScheme

    private var background: some View { AppTheme.surface }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: viewModel.state.scheduledPassNotifications.isEmpty ? "bell" : "bell.fill")
                    .font(.headline)
                    .foregroundColor(Color(UIColor.label))
                
                Text(AlarmSettingsCell.title)
                    .font(.headline)
                    .foregroundColor(Color(UIColor.label))

                Spacer()
            }

            Text(
                AlarmSettingsCell.description(numberOfAlerts: viewModel.state.scheduledPassNotifications.count)
            )
            .font(.subheadline)
            .multilineTextAlignment(.leading)
            .foregroundColor(AppTheme.muted)
        }
        .padding()
        .background(background)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.cardRadius).stroke(AppTheme.border, lineWidth: 1))
        .clipShape(
            RoundedRectangle(
                cornerRadius: AppTheme.cardRadius,
                style: .continuous
            )
        )
    }
}

extension AlarmSettingsCell {
    static var title: String {
        NSLocalizedString(
            "SatelliteOverview.alarmSettingsCell.title",
            tableName: nil,
            bundle: .module,
            value: "Manage alarms",
            comment: "The title for alarm settings cell"
        )
    }

    static func description(numberOfAlerts: Int) -> String {
        return String(
            format: NSLocalizedString(
                "SatelliteOverview.alarmSettingsCell.description",
                tableName: nil,
                bundle: .module,
                value: "%#@alarmCount@",
                comment: "The description for alarm settings cell when the seller has a number of alarms"
            ),
            numberOfAlerts
        )
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
