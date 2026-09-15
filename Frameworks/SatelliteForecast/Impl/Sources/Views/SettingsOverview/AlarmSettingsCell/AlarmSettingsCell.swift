//
//  AlarmSettingsCell.swift
//  AlarmSettingsCell
//
//  Created by Ben Lu on 8/20/21.
//

import SwiftUI
import SatelliteForecast

public struct AlarmSettingsCell: View {
    let numberOfAlerts: Int

    public init(
        numberOfAlerts: Int
    ) {
        self.numberOfAlerts = numberOfAlerts
    }

    @Environment(\.colorScheme) private var colorScheme

    private var background: some View { AppTheme.surface }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: numberOfAlerts == 0 ? "bell" : "bell.fill")
                    .font(.headline)
                    .foregroundColor(Color(UIColor.label))
                
                Text(AlarmSettingsCell.title)
                    .font(.headline)
                    .foregroundColor(Color(UIColor.label))

                Spacer()
            }

            Text(
                AlarmSettingsCell.description(numberOfAlerts: numberOfAlerts)
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
