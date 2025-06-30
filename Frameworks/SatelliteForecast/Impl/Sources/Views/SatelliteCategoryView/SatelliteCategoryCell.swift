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

    @Environment(\.colorScheme) private var colorScheme

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
        VStack(alignment: .leading) {
            Spacer()
                .frame(height: 140)

            ZStack {
                Color.clear
                    .blurEffect()

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(SatelliteCategoryCell.categoryLocalizedString(category))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(UIColor.label))
                        Spacer()
                    }
                }
                .padding()
            }
            .blurEffectStyle(colorScheme == .light ? .systemChromeMaterialLight : .systemChromeMaterialDark)
            .vibrancyEffectStyle(.fill)
        }
        .background(background(category: category))
        .clipShape(
            RoundedRectangle(
                cornerRadius: 8,
                style: .continuous
            )
        )
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

#if DEBUG
struct SatelliteCategoryCell_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(["iPhone SE (2nd generation)", "iPhone 13 Pro Max"], id: \.self) { previewDevice in
            ForEach(ColorScheme.allCases, id: \.self) { colorScheme in
                VStack {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible())
                        ],
                        alignment: .leading,
                        spacing: 10,
                        content: {
                            SatelliteCategoryCell(category: .brightest100)

                            SatelliteCategoryCell(category: .active)

                            SatelliteCategoryCell(category: .last30DayLaunches)
                        }
                    )
                }
                .padding()
                .preferredColorScheme(colorScheme)
            }
            .previewDevice(PreviewDevice(rawValue:  previewDevice))
        }
    }
}
#endif
