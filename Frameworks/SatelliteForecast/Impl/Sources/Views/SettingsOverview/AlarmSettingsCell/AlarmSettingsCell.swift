//
//  AlarmSettingsCell.swift
//  AlarmSettingsCell
//
//  Created by Ben Lu on 8/20/21.
//

import SwiftUI
import CombineRex
import CombineRextensions

public enum AlarmSettingsCellAction {

}

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

    private var background: some View {
        var colors = [UIColor.systemMint, UIColor.systemGreen]
        
        if colorScheme == .dark {
            colors = colors.map { $0.darken(by: 0.3) }
        } else {
            colors = colors.map { $0.darken(by: -0.3) }
        }
        
        return LinearGradient(
            gradient: Gradient(colors: colors.map(Color.init)),
            startPoint: UnitPoint(x: 0, y: 0),
            endPoint: UnitPoint(x: 1, y: 1)
        )
    }
    
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
            .font(.caption)
            .multilineTextAlignment(.leading)
            .foregroundColor(Color(UIColor.secondaryLabel))
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
