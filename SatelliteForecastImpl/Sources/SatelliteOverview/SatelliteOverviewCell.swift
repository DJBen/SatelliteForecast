//
//  SatelliteOverviewCell.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/25/21.
//

import CombineRex
import CombineRextensions
import SatelliteForecast
import SwiftUI
import SwiftUIVisualEffects

struct SatelliteOverviewCellModel {
    let item: SatelliteOverviewItem
}

/// An overview cell contains a category of satellites.
struct SatelliteOverviewCell: View {
    let model: SatelliteOverviewCellModel

    @ViewBuilder var body: some View {
        switch model.item {
        case let .specialSatellites(satellite):
            SatelliteOverviewSpecialSatelliteCell(satellite: satellite)
        case let .category(category):
            SatelliteOverviewCategoryCell(category: category)
        }
    }
}

struct SatelliteOverviewSpecialSatelliteCell: View {
    let satellite: SatelliteOverviewItem.SatellitesOfSpecialInterest

    @Environment(\.colorScheme) private var colorScheme

    @ViewBuilder private func background(satellite: SatelliteOverviewItem.SatellitesOfSpecialInterest) -> some View {
        switch satellite {
        case .iss:
            Image("25544")
                .resizable()
                .aspectRatio(contentMode: .fill)
            
        case .tianhe:
            Image("48274")
                .resizable()
                .aspectRatio(contentMode: .fill)
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Spacer()
                .frame(height: 120)

            ZStack {
                Color.clear
                    .blurEffect()

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(SatelliteOverviewCell.satelliteOfSpecialInterestLocalizedTitle(satellite))
                            .font(.headline)
                            .foregroundColor(Color(UIColor.label))
                        Spacer()
                    }

                    Text(SatelliteOverviewCell.satelliteOfSpecialInterestLocalizedDescription(satellite))
                        .font(.caption)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(colorScheme == .light ? Color(UIColor.systemGray2) : Color(UIColor.systemGray4))
                        .vibrancyEffect()
                }
                .padding()
            }
            .blurEffectStyle(colorScheme == .light ? .systemChromeMaterialLight : .systemChromeMaterialDark)
            .vibrancyEffectStyle(.fill)
        }
        .background(background(satellite: satellite))
        .clipShape(
            RoundedRectangle(
                cornerRadius: 8,
                style: .continuous
            )
        )
    }
}

struct SatelliteOverviewCategoryCell: View {
    let category: SatelliteCategory

    @Environment(\.colorScheme) private var colorScheme

    private func background(category: SatelliteCategory) -> some View {
        var colors: [UIColor]
        switch category {
        case .brightest100:
            colors = [UIColor.systemGreen, UIColor.systemTeal]
        case .active:
            colors = [UIColor.systemTeal, UIColor.systemPurple]
        case .last30DayLaunches:
            colors = [UIColor.systemGreen, UIColor.systemTeal]
        }

        if colorScheme == .dark {
            colors = colors.map { $0.darken(by: 0.3) }
        } else {
            colors = colors.map { $0.darken(by: -0.3) }
        }

        return AnyView(
            LinearGradient(
                gradient: Gradient(colors: colors.map(Color.init)),
                startPoint: UnitPoint(x: 0, y: 0),
                endPoint: UnitPoint(x: 1, y: 1)
            )
        )
    }

    var body: some View {
        Text(
            SatelliteOverviewCell.categoryLocalizedString(category)
        )
        .font(.headline)
        .foregroundColor(Color(UIColor.label))
        .multilineTextAlignment(.leading)
        .padding()
        .frame(maxWidth: .infinity, idealHeight: 80, alignment: .leading)
        .background(background(category: category))
        .clipShape(
            RoundedRectangle(
                cornerRadius: 8,
                style: .continuous
            )
        )
        .fixedSize(horizontal: false, vertical: true)
    }
}

extension SatelliteOverviewCell {
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

#if DEBUG
struct SatelliteOverviewCell_Previews: PreviewProvider {
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
                            SatelliteOverviewCell(
                                model: SatelliteOverviewCellModel(
                                    item: .specialSatellites(.iss)
                                )
                            )
                            SatelliteOverviewCell(
                                model: SatelliteOverviewCellModel(
                                    item: .specialSatellites(.tianhe)
                                )
                            )
                            SatelliteOverviewCell(
                                model: SatelliteOverviewCellModel(
                                    item: .category(.brightest100)
                                )
                            )
                            SatelliteOverviewCell(
                                model: SatelliteOverviewCellModel(
                                    item: .category(.active)
                                )
                            )
                            SatelliteOverviewCell(
                                model: SatelliteOverviewCellModel(
                                    item: .category(.last30DayLaunches)
                                )
                            )
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
