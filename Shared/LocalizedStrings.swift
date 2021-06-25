//
//  LocalizedStrings.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/5/21.
//

import Foundation
import SatelliteForcastCore

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
