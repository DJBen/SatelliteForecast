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
    enum SatelliteOverviewView {
        static func sectionTitle(_ section: SatelliteOverviewSection) -> String {
            switch section {
            case .satellitesOfSpecialInterest(_):
                return NSLocalizedString(
                    "SatelliteListView.sectionOverviewView.section.satellitesOfSpecialInterest",
                    tableName: nil,
                    bundle: .main,
                    value: "Satellites of special interest",
                    comment: "The section title for satellites of special interest"
                )
            case .categories(_):
                return NSLocalizedString(
                    "SatelliteListView.sectionOverviewView.section.satellitesByCategories",
                    tableName: nil,
                    bundle: .main,
                    value: "Satellites by categories",
                    comment: "The section title for satellites grouped by categories"
                )
            case .management(_):
                return NSLocalizedString(
                    "SatelliteListView.sectionOverviewView.section.Management",
                    tableName: nil,
                    bundle: .main,
                    value: "Management",
                    comment: "The section title for management"
                )
            }
        }
    }

    enum SatelliteOverviewCell {
        static func satelliteOfSpecialInterestLocalizedTitle(_ satellite: SatelliteOverviewItem.SatellitesOfSpecialInterest) -> String {
            switch satellite {
            case .iss:
                return NSLocalizedString(
                    "SatelliteListView.sectionOverviewCell.title.satellite.iss",
                    tableName: nil,
                    bundle: .main,
                    value: "International Space Station",
                    comment: "The title of ISS, displayed in the 'Satellite of special interest' section."
                )
            case .tianhe:
                return NSLocalizedString(
                    "SatelliteListView.sectionOverviewCell.title.satellite.tianhe",
                    tableName: nil,
                    bundle: .main,
                    value: "Tianhe (CSS Core Module)",
                    comment: "The title of Tianhe, displayed in the 'Satellite of special interest' section."
                )
            }
        }
        static func satelliteOfSpecialInterestLocalizedDescription(_ satellite: SatelliteOverviewItem.SatellitesOfSpecialInterest) -> String {
            switch satellite {
            case .iss:
                return NSLocalizedString(
                    "SatelliteListView.sectionOverviewCell.description.satellite.iss",
                    tableName: nil,
                    bundle: .main,
                    value: """
                    A multinational collaborative project featuring the largest spacecraft in orbit. 
                    """,
                    comment: "The description of ISS in overview page."
                )
            case .tianhe:
                return NSLocalizedString(
                    "SatelliteListView.sectionOverviewCell.description.satellite.tianhe",
                    tableName: nil,
                    bundle: .main,
                    value: "The first module to launch of the Tiangong space station.",
                    comment: "The description of Tianhe in overview page."
                )
            }
        }
        static func categoryLocalizedString(_ category: SatelliteCategory) -> String {
            switch category {
            case .brightest100:
                return NSLocalizedString(
                    "SatelliteListView.sectionOverviewCell.category.brightest100",
                    tableName: nil,
                    bundle: .main,
                    value: "Brightest 100 satellites",
                    comment: "The section header for the brightest 100 satellites"
                )
            case .last30DayLaunches:
                return NSLocalizedString(
                    "SatelliteListView.sectionOverviewCell.category.last30DayLaunches",
                    tableName: nil,
                    bundle: .main,
                    value: "Launches in the past 30 days",
                    comment: "The section header for launches in the past 30 days"
                )
            case .active:
                return NSLocalizedString(
                    "SatelliteListView.sectionOverviewCell.category.active",
                    tableName: nil,
                    bundle: .main,
                    value: "All active satellites",
                    comment: "The section header for all active satellites"
                )
            }
        }

        static func itemLocalizedString(_ item: SatelliteOverviewItem) -> String {
            switch item {
            case .specialSatellites(_):
                return ""
            case let .category(category):
                return categoryLocalizedString(category)
            case .management(_):
                return ""
            }
        }
    }

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
