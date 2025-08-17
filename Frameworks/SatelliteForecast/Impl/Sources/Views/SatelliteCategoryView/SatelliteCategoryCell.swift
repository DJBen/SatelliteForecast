//
//  SatelliteCategoryCell.swift
//  SatelliteForecastPackage
//
//  Created by Sihao Lu on 6/27/25.
//

import SatelliteForecast
import SwiftUI

struct SatelliteCategoryCell: View {
    let category: SatelliteCategory

    @ViewBuilder private func background(category: SatelliteCategory) -> some View {
        let imageName = switch category {
        case .active:
            "active_satellites"
        case .brightest100:
            "brightest_satellites"
        case .last30DayLaunches:
            "recent_launches"
        default:
            "" // Won't happen
        }
        Image(imageName, bundle: .module)
            .resizable()
            .aspectRatio(contentMode: .fill)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title section
            HStack {
                Text(SatelliteCategoryCell.categoryLocalizedString(category))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .background(Color(UIColor.systemBackground))

            // Background image
            background(category: category)
                .frame(height: 168)
                .clipped()
        }
    }
}

extension SatelliteCategoryCell {
    static func categoryLocalizedString(_ category: SatelliteCategory) -> String {
        switch category {
        case .brightest100:
            return NSLocalizedString(
                "SatelliteOverview.sectionOverviewCell.category.brightest100",
                tableName: nil,
                bundle: .module,
                value: "Brightest 100 satellites",
                comment: "The section header for the brightest 100 satellites"
            )
        case .last30DayLaunches:
            return NSLocalizedString(
                "SatelliteOverview.sectionOverviewCell.category.last30DayLaunches",
                tableName: nil,
                bundle: .module,
                value: "Launches in the past 30 days",
                comment: "The section header for launches in the past 30 days"
            )
        case .active:
            return NSLocalizedString(
                "SatelliteOverview.sectionOverviewCell.category.active",
                tableName: nil,
                bundle: .module,
                value: "All active satellites",
                comment: "The section header for all active satellites"
            )
        default:
            fatalError()
        }
    }
}
