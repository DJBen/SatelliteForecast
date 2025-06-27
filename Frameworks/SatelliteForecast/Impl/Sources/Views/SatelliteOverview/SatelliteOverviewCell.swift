//
//  SatelliteOverviewCell.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/25/21.
//

@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import SatelliteForecast
import SwiftUI
import SwiftUIVisualEffects

struct SatelliteOverviewSpecialSatelliteCell: View {
    let satellite: SatellitesOfSpecialInterest

    @Environment(\.colorScheme) private var colorScheme

    @ViewBuilder private func background(satellite: SatellitesOfSpecialInterest) -> some View {
        Image(String(satellite.noradIndex), bundle: .module)
            .resizable()
            .aspectRatio(contentMode: .fill)
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
                        Text(SatelliteOverviewSpecialSatelliteCell.satelliteOfSpecialInterestLocalizedTitle(satellite))
                            .font(.headline)
                            .foregroundColor(Color(UIColor.label))
                        Spacer()
                    }

                    Text(SatelliteOverviewSpecialSatelliteCell.satelliteOfSpecialInterestLocalizedDescription(satellite))
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

extension SatelliteOverviewSpecialSatelliteCell {
    static func satelliteOfSpecialInterestLocalizedTitle(_ satellite: SatellitesOfSpecialInterest) -> String {
        switch satellite {
        case .iss:
            return NSLocalizedString(
                "SatelliteOverview.sectionOverviewCell.title.satellite.iss",
                tableName: nil,
                bundle: .module,
                value: "International Space Station",
                comment: "The title of ISS, displayed in the 'Satellite of special interest' section."
            )
        case .tianhe:
            return NSLocalizedString(
                "SatelliteOverview.sectionOverviewCell.title.satellite.tianhe",
                tableName: nil,
                bundle: .module,
                value: "Tiangong Space Station",
                comment: "The title of Tianhe, displayed in the 'Satellite of special interest' section."
            )
        default:
            fatalError("Unsupported satellite")
        }
    }

    static func satelliteOfSpecialInterestLocalizedDescription(_ satellite: SatellitesOfSpecialInterest) -> String {
        switch satellite {
        case .iss:
            return NSLocalizedString(
                "SatelliteOverview.sectionOverviewCell.description.satellite.iss",
                tableName: nil,
                bundle: .module,
                value: """
                    A multinational collaborative project featuring the largest spacecraft in orbit since 1998.
                    """,
                comment: "The description of ISS in overview page."
            )
        case .tianhe:
            return NSLocalizedString(
                "SatelliteOverview.sectionOverviewCell.description.satellite.tianhe",
                tableName: nil,
                bundle: .module,
                value: "China's first long-term space station featuring three modules, fully assembled in 2022.",
                comment: "The description of Tianhe in overview page."
            )
        default:
            fatalError("Unsupported satellite")
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
                            SatelliteOverviewSpecialSatelliteCell(satellite: .iss)

                            SatelliteOverviewSpecialSatelliteCell(satellite: .tianhe)
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
