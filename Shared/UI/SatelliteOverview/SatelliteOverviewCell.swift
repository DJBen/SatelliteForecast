//
//  SatelliteOverviewCell.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/25/21.
//

import SwiftUI
import SwiftUIVisualEffects
import CombineRex
import CombineRextensions

struct SatelliteOverviewCellModel {
    let item: SatelliteOverviewItem
}

/// An overview cell contains a category of satellites.
struct SatelliteOverviewCell: View {
    let model: SatelliteOverviewCellModel
    let observerCellViewProducer: ViewProducer<Void, ObserverCell>
    let alarmSettingsCellProducer: ViewProducer<Void, AlarmSettingsCell>

    @ViewBuilder var body: some View {
        switch model.item {
        case let .specialSatellites(satellite):
            SatelliteOverviewSpecialSatelliteCell(satellite: satellite)
        case let .category(category):
            SatelliteOverviewCategoryCell(category: category)
        case let .settings(settings):
            switch settings {
            case .observer:
                observerCellViewProducer.view()
            case .alert:
                alarmSettingsCellProducer.view()
            }
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
                        Text(LocalizedStrings.SatelliteOverviewCell.satelliteOfSpecialInterestLocalizedTitle(satellite))
                            .font(.headline)
                            .foregroundColor(Color(UIColor.label))
                        Spacer()
                    }

                    Text(LocalizedStrings.SatelliteOverviewCell.satelliteOfSpecialInterestLocalizedDescription(satellite))
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
            LocalizedStrings.SatelliteOverviewCell.categoryLocalizedString(category)
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
                                ),
                                observerCellViewProducer: .crash,
                                alarmSettingsCellProducer: .crash
                            )
                            SatelliteOverviewCell(
                                model: SatelliteOverviewCellModel(
                                    item: .specialSatellites(.tianhe)
                                ),
                                observerCellViewProducer: .crash,
                                alarmSettingsCellProducer: .crash
                            )
                            SatelliteOverviewCell(
                                model: SatelliteOverviewCellModel(
                                    item: .category(.brightest100)
                                ),
                                observerCellViewProducer: .crash,
                                alarmSettingsCellProducer: .crash
                            )
                            SatelliteOverviewCell(
                                model: SatelliteOverviewCellModel(
                                    item: .category(.active)
                                ),
                                observerCellViewProducer: .crash,
                                alarmSettingsCellProducer: .crash
                            )
                            SatelliteOverviewCell(
                                model: SatelliteOverviewCellModel(
                                    item: .category(.last30DayLaunches)
                                ),
                                observerCellViewProducer: .crash,
                                alarmSettingsCellProducer: .crash
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
