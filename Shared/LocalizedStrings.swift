//
//  LocalizedStrings.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/5/21.
//

import Foundation
import SatelliteForcastCore
import SatelliteCatalog

enum LocalizedStrings {
    enum SatelliteListView {
        static func sectionHeader(from category: SatelliteCategory) -> String {
            switch category {
            case .brightest100:
                return NSLocalizedString(
                    "SatelliteListView.sectionHeader.category.brightest100",
                    tableName: nil,
                    bundle: .main,
                    value: "Brightest 100 satellites",
                    comment: "The section header for the brightest 100 satellites"
                )
            case .last30DayLaunches:
                return NSLocalizedString(
                    "SatelliteListView.sectionHeader.category.last30DayLaunches",
                    tableName: nil,
                    bundle: .main,
                    value: "Launches in the past 30 days",
                    comment: "The section header for launches in the past 30 days"
                )
            case .active:
                return NSLocalizedString(
                    "SatelliteListView.sectionHeader.category.active",
                    tableName: nil,
                    bundle: .main,
                    value: "All active satellites",
                    comment: "The section header for all active satellites"
                )
            }
        }
    }

    enum SatelliteCell {
        static func operatorAndCountry(_ operator: String, country: String) -> String {
            let format = NSLocalizedString(
                "SatelliteCell.operatorAndCountry",
                tableName: nil,
                bundle: .main,
                value: "%@, %@",
                comment: "The cacatenated operator and country strings."
            )

            return String(format: format, `operator`, country);
        }

        static func operationalStatusLocalizedString(_ operationalStatus: SatCat.OperationalStatus) -> (String, String) {
            switch operationalStatus {
            case .operational:
                let string = NSLocalizedString(
                    "SatelliteCell.operationalStatusLocalizedString.operational",
                    tableName: nil,
                    bundle: .main,
                    value: "Operational",
                    comment: "The localized string for the status of an operational satellite"
                )
                return ("lightbulb.fill", string)
            case .partiallyOperational:
                let string = NSLocalizedString(
                    "SatelliteCell.operationalStatusLocalizedString.partiallyOperational",
                    tableName: nil,
                    bundle: .main,
                    value: "Partially operational",
                    comment: "The localized string for the status of a partially operational satellite"
                )
                return ("lightbulb.fill", string)
            case .extendedMission:
                let string = NSLocalizedString(
                    "SatelliteCell.operationalStatusLocalizedString.extendedMission",
                    tableName: nil,
                    bundle: .main,
                    value: "On extended mission",
                    comment: "The localized string for the status of a satellite on extended mission"
                )
                return ("lightbulb.fill", string)
            case .backup:
                let string = NSLocalizedString(
                    "SatelliteCell.operationalStatusLocalizedString.backup",
                    tableName: nil,
                    bundle: .main,
                    value: "Backup",
                    comment: "The localized string for the status of a backup satellite"
                )
                return ("lightbulb.fill", string)
            case .spare:
                let string = NSLocalizedString(
                    "SatelliteCell.operationalStatusLocalizedString.backup",
                    tableName: nil,
                    bundle: .main,
                    value: "Spare",
                    comment: "The localized string for the status of a spare satellite"
                )
                return ("lightbulb", string)
            case .nonoperational:
                let string = NSLocalizedString(
                    "SatelliteCell.operationalStatusLocalizedString.nonoperational",
                    tableName: nil,
                    bundle: .main,
                    value: "Nonoperational",
                    comment: "The localized string for the status of a nonoperational satellite"
                )
                return ("lightbulb.slash.fill", string)
            case .decayed:
                let string = NSLocalizedString(
                    "SatelliteCell.operationalStatusLocalizedString.decayed",
                    tableName: nil,
                    bundle: .main,
                    value: "Decayed",
                    comment: "The localized string for the status of a decayed satellite"
                )
                return ("flame", string)
            case .unknown:
                let string = NSLocalizedString(
                    "SatelliteCell.operationalStatusLocalizedString.unknown",
                    tableName: nil,
                    bundle: .main,
                    value: "Unknown status",
                    comment: "The localized string for the unknown status of satellite"
                )
                return ("questionmark", string)
            }
        }
    }

    enum PassPreviewCell {
        static func titleForPassVisibility(_ visibility: Pass.Visibility) -> String {
            switch visibility {
            case .visible:
                return NSLocalizedString(
                    "PassPreviewCell.visibilityText.visible",
                    tableName: nil,
                    bundle: .main,
                    value: "Visible",
                    comment: "The pass is visible"
                )
            case .daylight:
                return NSLocalizedString(
                    "PassPreviewCell.visibilityText.daylight",
                    tableName: nil,
                    bundle: .main,
                    value: "Daylight",
                    comment: "The pass happens during daylight"
                )
            case .unlit:
                return NSLocalizedString(
                    "PassPreviewCell.visibilityText.unlit",
                    tableName: nil,
                    bundle: .main,
                    value: "Unlit",
                    comment: "The pass happens entirely unlit"
                )
            }
        }
    }
}
