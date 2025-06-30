//
//  LocalizedStrings.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/5/21.
//

import Foundation
import SatelliteCatalog
import SatelliteForecast
@preconcurrency import SatelliteKit
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
                    formatter.string(from: -passNotification.timeOffset)!
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
                    formatter.string(from: -passNotification.timeOffset)!,
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
                        pass.highestIlluminated?.elev ?? 0
                    )
                } else {
                    visibilityString = String(
                        format: partiallyVisibleFormat,
                        pass.highestIlluminated?.elev ?? 0
                    )
                }
            case .daylight:
                visibilityString = String(
                    format: daytimeFormat,
                    pass.culmination.elev
                )
            case .unlit:
                visibilityString = String(
                    format: unlitFormat,
                    pass.culmination.elev
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
            default:
                fatalError()
            }
        }
    }
}
