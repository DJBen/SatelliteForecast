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
            case .observerSettings:
                return NSLocalizedString(
                    "SatelliteListView.sectionOverviewView.section.locationSettings",
                    tableName: nil,
                    bundle: .main,
                    value: "Location settings",
                    comment: "The section title for location settings"
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
                value: "Current Location",
                comment: "The current location text, indicating that the observer location is the current location."
            )
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
            let north = NSLocalizedString(
                "PassView.direction.north",
                tableName: nil,
                bundle: .main,
                value: "north",
                comment: ""
            )
            let northEast = NSLocalizedString(
                "PassView.direction.northeast",
                tableName: nil,
                bundle: .main,
                value: "northeast",
                comment: ""
            )
            let east = NSLocalizedString(
                "PassView.direction.east",
                tableName: nil,
                bundle: .main,
                value: "east",
                comment: ""
            )
            let southeast = NSLocalizedString(
                "PassView.direction.southeast",
                tableName: nil,
                bundle: .main,
                value: "southeast",
                comment: ""
            )
            let south = NSLocalizedString(
                "PassView.direction.south",
                tableName: nil,
                bundle: .main,
                value: "south",
                comment: ""
            )
            let southwest = NSLocalizedString(
                "PassView.direction.southwest",
                tableName: nil,
                bundle: .main,
                value: "southwest",
                comment: ""
            )
            let west = NSLocalizedString(
                "PassView.direction.west",
                tableName: nil,
                bundle: .main,
                value: "west",
                comment: ""
            )
            let northwest = NSLocalizedString(
                "PassView.direction.northwest",
                tableName: nil,
                bundle: .main,
                value: "northwest",
                comment: ""
            )
            let angles: [String] = [north, northEast, east, southeast, south, southwest, west, northwest, north]
            let riseDirection = angles[Int(floor(limit360(pass.rise.azim) / 45))]
            let setDirection = angles[Int(floor(limit360(pass.set.azim) / 45))]
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
