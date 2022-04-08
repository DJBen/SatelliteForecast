//
//  LocalizedStrings.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/5/21.
//

import Foundation
import SatelliteCatalog
import SatelliteForecast
import SatelliteForecastImpl
import SatelliteKit
import CoreLocation

enum LocalizedStrings {    
    enum Notification {
        static func title(passNotification: PassNotification) -> String {
            let nowFormat = NSLocalizedString(
                "Notification.upcomingPass.title.now",
                tableName: nil,
                bundle: .main,
                value: "%1$@ is rising now",
                comment: "The title for the satellite pass notification."
            )
            
            let futureFormat = NSLocalizedString(
                "Notification.upcomingPass.title.future",
                tableName: nil,
                bundle: .main,
                value: "%1$@ will rise in %2$@",
                comment: "The title for the satellite pass notification."
            )
            
            if passNotification.timeOffset == 0 {
                return String(
                    format: nowFormat,
                    passNotification.satelliteName.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            } else {
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.hour, .minute]
                formatter.unitsStyle = .full
                return String(
                    format: futureFormat,
                    passNotification.satelliteName.trimmingCharacters(in: .whitespacesAndNewlines),
                    formatter.string(from: passNotification.timeOffset)!
                )
            }
        }
        
        static func description(passNotification: PassNotification) -> String {
            let pass = passNotification.pass
            let riseDirection = Directions.angles[Int(floor(limit360(pass.rise.azim) / 45))]
            let setDirection = Directions.angles[Int(floor(limit360(pass.set.azim) / 45))]
            
            let nowFormat = NSLocalizedString(
                "Notification.upcomingPass.description.now",
                tableName: nil,
                bundle: .main,
                value: "Rising now from %1$@ and sets into %2$@.",
                comment: "The description for the satellite pass notification."
            )
            
            let futureFormat = NSLocalizedString(
                "Notification.upcomingPass.description.future",
                tableName: nil,
                bundle: .main,
                value: "Will rise in %1$@ from %2$@ and sets into %3$@.",
                comment: "The description for the satellite pass notification."
            )
            
            let riseSetString: String
            
            if passNotification.timeOffset == 0 {
                riseSetString = String(
                    format: nowFormat,
                    riseDirection,
                    setDirection
                )
            } else {
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.hour, .minute]
                formatter.unitsStyle = .full
                
                riseSetString = String(
                    format: futureFormat,
                    formatter.string(from: passNotification.timeOffset)!,
                    riseDirection,
                    setDirection
                )
            }
            
            let entirelyVisibleFormat = NSLocalizedString(
                "Notification.upcomingPass.description.passVisibilityDescription.entirelyVisible",
                tableName: nil,
                bundle: .main,
                value: "The entirety of the pass is illuminated up to %.1f degrees of elevation.",
                comment: "The pass description in the notification."
            )

            let partiallyVisibleFormat = NSLocalizedString(
                "Notification.upcomingPass.description.passVisibilityDescription.partiallyVisible",
                tableName: nil,
                bundle: .main,
                value: "The pass is partially visible up to %.1f degrees of elevation.",
                comment: "The pass description in the notification."
            )
            
            let daytimeFormat = NSLocalizedString(
                "Notification.upcomingPass.description.passVisibilityDescription.daytime",
                tableName: nil,
                bundle: .main,
                value: "The pass has up to %.1f degrees of elevation. It may be too bright for the satellite to be visible, though.",
                comment: "The pass description in the notification."
            )
            
            let unlitFormat = NSLocalizedString(
                "Notification.upcomingPass.description.passVisibilityDescription.unlit",
                tableName: nil,
                bundle: .main,
                value: "The pass has up to %.1f degrees of elevation. Under earth's shadow, it will be too dim to be visible.",
                comment: "The pass description in the notification."
            )
            
            let format = NSLocalizedString(
                "Notification.upcomingPass.description.format",
                tableName: nil,
                bundle: .main,
                value: "%@ %@",
                comment: "The concatenation format of pass description in the notification."
            )
            
            let visibilityString: String
            
            switch pass.visibility {
            case .visible:
                if pass.illumination.changes.isEmpty {
                    visibilityString = String(
                        format: entirelyVisibleFormat,
                        pass.highestIlluminatedElevation
                    )
                } else {
                    visibilityString = String(
                        format: partiallyVisibleFormat,
                        pass.highestIlluminatedElevation
                    )
                }
            case .daylight:
                visibilityString = String(
                    format: daytimeFormat,
                    pass.transit.elev
                )
            case .unlit:
                visibilityString = String(
                    format: unlitFormat,
                    pass.transit.elev
                )
            }
            
            return String(format: format, riseSetString, visibilityString)
        }
    }

    enum SettingsOverviewView {
        static let title = NSLocalizedString(
            "SettingsOverviewView.title",
            tableName: nil,
            bundle: .main,
            value: "Settings",
            comment: "The title for settings"
        )
    }

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
            }
        }
    }

    enum SatelliteOverviewCell {
        static func satelliteOfSpecialInterestLocalizedTitle(_ satellite: SatelliteOverviewItem.SatellitesOfSpecialInterest) -> String {
            switch satellite {
            case .iss:
                return NSLocalizedString(
                    "SatelliteOverview.sectionOverviewCell.title.satellite.iss",
                    tableName: nil,
                    bundle: .main,
                    value: "International Space Station",
                    comment: "The title of ISS, displayed in the 'Satellite of special interest' section."
                )
            case .tianhe:
                return NSLocalizedString(
                    "SatelliteOverview.sectionOverviewCell.title.satellite.tianhe",
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
                    "SatelliteOverview.sectionOverviewCell.description.satellite.iss",
                    tableName: nil,
                    bundle: .main,
                    value: """
                    A multinational collaborative project featuring the largest spacecraft in orbit since 1998. 
                    """,
                    comment: "The description of ISS in overview page."
                )
            case .tianhe:
                return NSLocalizedString(
                    "SatelliteOverview.sectionOverviewCell.description.satellite.tianhe",
                    tableName: nil,
                    bundle: .main,
                    value: "The first module of China's Tiangong space station.",
                    comment: "The description of Tianhe in overview page."
                )
            }
        }

        static func categoryLocalizedString(_ category: SatelliteCategory) -> String {
            switch category {
            case .brightest100:
                return NSLocalizedString(
                    "SatelliteOverview.sectionOverviewCell.category.brightest100",
                    tableName: nil,
                    bundle: .main,
                    value: "Brightest 100 satellites",
                    comment: "The section header for the brightest 100 satellites"
                )
            case .last30DayLaunches:
                return NSLocalizedString(
                    "SatelliteOverview.sectionOverviewCell.category.last30DayLaunches",
                    tableName: nil,
                    bundle: .main,
                    value: "Launches in the past 30 days",
                    comment: "The section header for launches in the past 30 days"
                )
            case .active:
                return NSLocalizedString(
                    "SatelliteOverview.sectionOverviewCell.category.active",
                    tableName: nil,
                    bundle: .main,
                    value: "All active satellites",
                    comment: "The section header for all active satellites"
                )
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
}
