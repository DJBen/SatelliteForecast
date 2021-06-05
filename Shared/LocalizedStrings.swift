//
//  LocalizedStrings.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/5/21.
//

import Foundation

enum LocalizedStrings {
    enum SatelliteListView {
        static func sectionHeader(from category: TLECategory) -> String {
            switch category {
            case .brightest100:
                return NSLocalizedString(
                    "SatelliteListView.sectionHeader.category.brightest100",
                    tableName: nil,
                    bundle: .main,
                    value: "Brightest 100 Satellites",
                    comment: "The section header for the brightest 100 satellites"
                )
            }
        }
    }
}
