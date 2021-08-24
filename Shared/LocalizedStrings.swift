//
//  LocalizedStrings.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/5/21.
//

import Foundation
import SatelliteCatalog
import SatelliteForecastCore
import SatelliteKit

enum LocalizedStrings {
    enum Directions {
        static let north = NSLocalizedString(
            "Directions.north",
            tableName: nil,
            bundle: .main,
            value: "north",
            comment: ""
        )
        
        static let northEast = NSLocalizedString(
            "Directions.northeast",
            tableName: nil,
            bundle: .main,
            value: "northeast",
            comment: ""
        )
        
        static let east = NSLocalizedString(
            "Directions.east",
            tableName: nil,
            bundle: .main,
            value: "east",
            comment: ""
        )
        
        static let southeast = NSLocalizedString(
            "Directions.southeast",
            tableName: nil,
            bundle: .main,
            value: "southeast",
            comment: ""
        )
        
        static let south = NSLocalizedString(
            "Directions.south",
            tableName: nil,
            bundle: .main,
            value: "south",
            comment: ""
        )
        
        static let southwest = NSLocalizedString(
            "Directions.southwest",
            tableName: nil,
            bundle: .main,
            value: "southwest",
            comment: ""
        )
        
        static let west = NSLocalizedString(
            "Directions.west",
            tableName: nil,
            bundle: .main,
            value: "west",
            comment: ""
        )
        
        static let northwest = NSLocalizedString(
            "Directions.northwest",
            tableName: nil,
            bundle: .main,
            value: "northwest",
            comment: ""
        )
        
        static let angles = [north, northEast, east, southeast, south, southwest, west, northwest, north]
    }
    
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
            case .settings:
                return NSLocalizedString(
                    "SatelliteListView.sectionOverviewView.section.settings",
                    tableName: nil,
                    bundle: .main,
                    value: "Settings",
                    comment: "The section title for settings"
                )
            }
        }
    }

    enum ObserverCell {
        enum Title {
            static let currentLocation: String = NSLocalizedString(
                "SatelliteListView.observerCell.title.currentLocation",
                tableName: nil,
                bundle: .main,
                value: "Current location",
                comment: "The current location text, indicating that the observer location is the current location."
            )

            static let requiresLocationSelection: String = NSLocalizedString(
                "SatelliteListView.observerCell.title.requiresLocationSelection",
                tableName: nil,
                bundle: .main,
                value: "Requires location selection",
                comment: "The text indicating that location service is not available, nor has the user selecetd a location manually."
            )
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
                    A multinational collaborative project featuring the largest spacecraft in orbit. 
                    """,
                    comment: "The description of ISS in overview page."
                )
            case .tianhe:
                return NSLocalizedString(
                    "SatelliteOverview.sectionOverviewCell.description.satellite.tianhe",
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
    
    enum AlarmSettingsCell {
        static var title: String {
            NSLocalizedString(
                "SatelliteOverview.alarmSettingsCell.title",
                tableName: nil,
                bundle: .main,
                value: "Manage alarms",
                comment: "The title for alarm settings cell"
            )
        }
        
        static func description(numberOfAlerts: Int) -> String {
            if numberOfAlerts == 0 {
                return NSLocalizedString(
                    "SatelliteOverview.alarmSettingsCell.description.zero",
                    tableName: nil,
                    bundle: .main,
                    value: "You currently haven't set up any alarms.",
                    comment: "The description for alarm settings cell when the seller hasn't set up any alarms"
                )
            } else {
                let format = NSLocalizedString(
                    "SatelliteOverview.alarmSettingsCell.description.nonZero",
                    tableName: nil,
                    bundle: .main,
                    value: "You have %d pending alarm(s)",
                    comment: "The description for alarm settings cell when the seller has set up some alarms"
                )
                
                return String(format: format, numberOfAlerts)
            }
        }
    }
    
    enum AlarmSettingsView {
        static func alarmOffsetDescription(timeInterval: TimeInterval) -> String {
            let beforeFormat = NSLocalizedString(
                "AlarmSettingsView.alarmOffsetDescription.before",
                tableName: nil,
                bundle: .main,
                value: "%@ before rise",
                comment: "The time interval description for each alarm in the alarm settings view"
            )
            
            let afterFormat = NSLocalizedString(
                "AlarmSettingsView.alarmOffsetDescription.after",
                tableName: nil,
                bundle: .main,
                value: "%@ after rise",
                comment: "The time interval description for each alarm in the alarm settings view"
            )
            
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute]
            formatter.unitsStyle = .short

            return String(
                format: timeInterval > 0 ? afterFormat : beforeFormat,
                formatter.string(from: abs(timeInterval))!
            )
        }
        
        static func passDescription(pass: Pass) -> String {
            let format = NSLocalizedString(
                "AlarmSettingsView.passDescription",
                tableName: nil,
                bundle: .main,
                value: "Rises at %@ and sets at %@.",
                comment: "The pass description for each alarm in the alarm settings view"
            )
            
            return String(
                format: format,
                Date(julianDate: pass.rise.julianDate).formatted(date: .omitted, time: .standard),
                Date(julianDate: pass.set.julianDate).formatted(date: .omitted, time: .standard)
            )
        }
        
        static func passVisibilityDescription(pass: Pass) -> String {
            let visibleFormat = NSLocalizedString(
                "AlarmSettingsView.passVisibilityDescription.visible",
                tableName: nil,
                bundle: .main,
                value: "Max visible elevation %.1f degrees.",
                comment: "The pass description for each alarm in the alarm settings view"
            )
            
            let daytimeFormat = NSLocalizedString(
                "AlarmSettingsView.passVisibilityDescription.daytime",
                tableName: nil,
                bundle: .main,
                value: "The pass occurs during daylight with a max elevation of %.1f degrees.",
                comment: "The pass description for each alarm in the alarm settings view"
            )
            
            let unlitFormat = NSLocalizedString(
                "AlarmSettingsView.passVisibilityDescription.unlit",
                tableName: nil,
                bundle: .main,
                value: "The pass is not illuminated with a max elevation of %.1f degrees.",
                comment: "The pass description for each alarm in the alarm settings view"
            )
                        
            switch pass.visibility {
            case .visible:
                return String(
                    format: visibleFormat,
                    pass.highestIlluminatedElevation
                )
            case .daylight:
                return String(
                    format: daytimeFormat,
                    pass.transit.elev
                )
            case .unlit:
                return String(
                    format: unlitFormat,
                    pass.transit.elev
                )
            }
        }
    }

    enum LocationSettingsView {
        static func alertMessage(from locationSelection: LocationState.Selection) -> String {
            switch locationSelection {
            case .currentLocation:
                return NSLocalizedString(
                    "SatelliteListView.locationSettingsView.alert.message.currentLocation",
                    tableName: nil,
                    bundle: .main,
                    value: "Please confirm to change location to your current location. This will affect all the satellite predictions.",
                    comment: "The alert message to confirm that the user is changing into his/her current location."
                )
            case let .custom(completion, _):
                let format = NSLocalizedString(
                    "SatelliteListView.locationSettingsView.alert.message.custom",
                    tableName: nil,
                    bundle: .main,
                    value: "Please confirm to change location to %@. This will affect all the satellite predictions.",
                    comment: "The alert message to confirm that the user is changing into a custom location."
                )
                return String(format: format, completion.title)
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

    enum AllPassesView {
        private static let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter
        }()

        static func searchPassRangeToolbarText(range: Range<Double>, now: Double) -> String {
            let format = NSLocalizedString(
                "AllPassesView.searchPassRangeToolbar.text",
                tableName: nil,
                bundle: .main,
                value: "Showing passes up to %1$@",
                comment: "The auxiliary text under the navigation title detailing the search date range of the passes."
            )

            return String(
                format: format,
                dateFormatter.string(from: Date(julianDate: range.upperBound))
            )
        }

        enum Section {
            enum VisiblePasses {
                static var header: String {
                    NSLocalizedString(
                        "AllPassesView.section.visible.header",
                        tableName: nil,
                        bundle: .main,
                        value: "Visible Passes",
                        comment: "The header of visible passes"
                    )
                }

                static var headerCaption: String {
                    NSLocalizedString(
                        "AllPassesView.section.visible.headerCaption",
                        tableName: nil,
                        bundle: .main,
                        value: "Satellite is illuminated by the sun for a significant portion of the pass in contrast to a sufficiently dark sky.",
                        comment: "The caption under the header of visible passes"
                    )
                }
            }

            enum InvisiblePasses {
                static var header: String {
                    NSLocalizedString(
                        "AllPassesView.section.invisible.header",
                        tableName: nil,
                        bundle: .main,
                        value: "Invisible Passes",
                        comment: "The header of invisible passes"
                    )
                }

                static var headerCaption: String {
                    NSLocalizedString(
                        "AllPassesView.section.invisible.headerCaption",
                        tableName: nil,
                        bundle: .main,
                        value: "Satellite is either blocked by earth's shadow or outshone by the sunlight.",
                        comment: "The caption under the header of invisible passes"
                    )
                }
            }
        }
    }

    enum PassView {
        static func descriptionToolbarText(for pass: Pass) -> String {
            let riseDirection = Directions.angles[Int(floor(limit360(pass.rise.azim) / 45))]
            let setDirection = Directions.angles[Int(floor(limit360(pass.set.azim) / 45))]
            let format = NSLocalizedString(
                "PassView.descriptionToolbar.text",
                tableName: nil,
                bundle: .main,
                value: "Rises from %2$@ and sets into %3$@",
                comment: "The toolbar of the pass view describing the direction of the pass. The first and second arguments correspond to the directions of rising and setting."
            )
            return String(format: format, riseDirection, setDirection)
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

        private static let durationFormatter: RelativeDateTimeFormatter = {
            let formatter = RelativeDateTimeFormatter()
            formatter.dateTimeStyle = .named
            return formatter
        }()

        static func relativeDate(pass: Pass, referenceDate: Double) -> String {
            if referenceDate < pass.rise.julianDate {
                let format = NSLocalizedString(
                    "PassPreviewCell.relativeDate.riseInTheFuture",
                    tableName: nil,
                    bundle: .main,
                    value: "Rising %@",
                    comment: "A string describing that the satellite rises in a specific time in the future"
                )
                return String(
                    format: format,
                    durationFormatter.localizedString(
                        fromTimeInterval: (pass.rise.julianDate - referenceDate) * TimeConstants.day2sec)
                )
            } else if referenceDate > pass.set.julianDate {
                let format = NSLocalizedString(
                    "PassPreviewCell.relativeDate.alreadyPassed",
                    tableName: nil,
                    bundle: .main,
                    value: "Passed %@",
                    comment: "A string describing that the satellite has already set in a specific time in the past"
                )
                return String(
                    format: format,
                    durationFormatter.localizedString(
                        fromTimeInterval: (pass.set.julianDate - referenceDate) * TimeConstants.day2sec)
                )
            } else {
                return NSLocalizedString(
                    "PassPreviewCell.relativeDate.passing",
                    tableName: nil,
                    bundle: .main,
                    value: "Passing now",
                    comment: "A string describing that the satellite is currently passing"
                )
            }
        }
    }

    enum SkyChart {
        enum PassLabel {
            static func textForIlluminationChange(
                _ change: Pass.Illumination.Change,
                dateFormatter: DateFormatter
            ) -> String {
                switch change {
                case let .entersShadow(datePosition):
                    let format = NSLocalizedString(
                        "SkyChart.PassLabel.text.illuminationChange.entersShadow",
                        tableName: nil,
                        bundle: .main,
                        value: """
                        Enters shadow
                        %@
                        """,
                        comment: "The pass label format text of an illumination change: enters shadow"
                    )
                    return String(format: format, dateFormatter.string(from: Date(julianDate: datePosition.julianDate)))
                case let .exitsShadow(datePosition):
                    let format = NSLocalizedString(
                        "SkyChart.PassLabel.text.illuminationChange.exitsShadow",
                        tableName: nil,
                        bundle: .main,
                        value: """
                        Exits shadow
                        %@
                        """,
                        comment: "The pass label format text of an illumination change: exits shadow"
                    )
                    return String(format: format, dateFormatter.string(from: Date(julianDate: datePosition.julianDate)))
                }
            }
        }
    }
}
