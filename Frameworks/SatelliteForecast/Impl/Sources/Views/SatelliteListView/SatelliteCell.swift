//
//  SatelliteCell.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/25/21.
//

import SwiftUI
import SatelliteCatalog
@preconcurrency import SatelliteKit
import SatelliteForecast

struct SatelliteCell: View {
    let info: SatelliteInfo

    @ViewBuilder var body: some View {
        if let ucsSat = info.ucsSat, let satCat = info.satCat {
            UCSSatCell(cat: satCat, sat: ucsSat)
        } else if let satCat = info.satCat {
            CatSatCell(cat: satCat)
        } else {
            Text(info.elements.commonName)
        }
    }

    static func image(cat: SatCat) -> UIImage? {
        if let image = UIImage(named: "\(cat.noradID)", in: .module, compatibleWith: nil) {
            return image
        } else if cat.name.contains("STARLINK") {
            return UIImage(named: "starlink", in: .module, compatibleWith: nil)?.withTintColor(.white)
        }
        return nil
    }
}

struct CatSatCell: View {
    let cat: SatCat

    let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        return dateFormatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top) {
                Text(cat.name)
                    .font(.headline)
                    .bold()
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                VStack(alignment: .trailing) {
                    Text(String("NORAD #\(cat.noradID)"))
                        .secondaryStyle()

                    Text(cat.cosparID)
                        .secondaryStyle()
                }
            }

            Spacer().frame(height: 8)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading) {
                    if let (imageSystemName, status) = cat.operationalStatus
                        .map(SatelliteCell.operationalStatusLocalizedString) {
                        Text("\(Image(systemName: imageSystemName)) \(status)")
                            .secondaryStyle()
                    }

                    Text("\(Image(systemName: "calendar")) \(dateFormatter.string(from: cat.launchDate))")
                        .secondaryStyle()

                    if let launchSite = cat.launchSite.fullName {
                        Text("\(Image(systemName: "mappin.and.ellipse")) \(launchSite)")
                            .secondaryStyle()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let image = SatelliteCell.image(cat: cat) {
                    VStack(alignment: .leading) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                    .frame(
                        maxWidth: 150,
                        alignment: .trailing
                    )
                }
            }
        }
    }
}

struct UCSSatCell: View {
    let cat: SatCat
    let sat: UCSSat

    let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        return dateFormatter
    }()

    let massFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.maximumFractionDigits = 1
        return numberFormatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    Text(sat.officialName)
                        .font(.headline)
                        .bold()
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                    let unofficialName: String? = {
                        if let indexOfLeftParens = sat.name.firstIndex(of: "("),
                           let indexOfRightParens = sat.name.lastIndex(of: ")") {
                            let startIndex = sat.name.index(after: indexOfLeftParens)
                            return String(sat.name[startIndex..<indexOfRightParens])
                        } else {
                            return nil
                        }
                    }()

                    if let unofficialName = unofficialName {
                        Text(unofficialName)
                            .font(.subheadline)
                            .lineLimit(nil)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text(String("NORAD #\(sat.noradID)"))
                        .secondaryStyle()

                    Text(sat.cosparID)
                        .secondaryStyle()
                }
            }

            Spacer().frame(height: 8)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading) {
                    HStack(alignment: .firstTextBaseline) {
                        Image(systemName: "target")
                            .secondaryStyle()

                        Text(sat.purpose)
                            .secondaryStyle()
                    }

                    if let dateOfLaunch = sat.dateOfLaunch {
                        HStack(alignment: .firstTextBaseline) {
                            Image(systemName: "calendar")
                                .secondaryStyle()
                            
                            Text(dateFormatter.string(from: dateOfLaunch))
                                .secondaryStyle()
                        }
                    }

                    HStack(alignment: .firstTextBaseline) {
                        Image(systemName: "mappin.and.ellipse")
                            .secondaryStyle()

                        if let launchSite = sat.launchSite {
                            Text(launchSite)
                            .secondaryStyle()
                        }
                    }

                    if let dryMass = sat.dryMass {
                        HStack(alignment: .firstTextBaseline) {
                            Image(systemName: "scalemass")
                                .secondaryStyle()

                            Text("\(massFormatter.string(from: dryMass as NSNumber)!) kg")
                                .secondaryStyle()

                        }
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Image(systemName: "building.columns")
                            .secondaryStyle()

                        Text(SatelliteCell.operatorAndCountry(sat.operatorOrOwner, country: sat.countryOfOperatorOrOwner))
                            .secondaryStyle()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let image = SatelliteCell.image(cat: cat) {
                    VStack(alignment: .leading) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                    .frame(
                        maxWidth: 135,
                        alignment: .trailing
                    )
                }
            }
        }
    }
}

fileprivate extension View {
    func secondaryStyle() -> some View {
        font(.caption2)
        .foregroundColor(AppTheme.muted)
    }
}

extension SatelliteCell {
    static func operatorAndCountry(_ operator: String, country: String) -> String {
        let format = NSLocalizedString(
            "SatelliteCell.operatorAndCountry",
            tableName: nil,
            bundle: .module,
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
                bundle: .module,
                value: "Operational",
                comment: "The localized string for the status of an operational satellite"
            )
            return ("lightbulb.fill", string)
        case .partiallyOperational:
            let string = NSLocalizedString(
                "SatelliteCell.operationalStatusLocalizedString.partiallyOperational",
                tableName: nil,
                bundle: .module,
                value: "Partially operational",
                comment: "The localized string for the status of a partially operational satellite"
            )
            return ("lightbulb.fill", string)
        case .extendedMission:
            let string = NSLocalizedString(
                "SatelliteCell.operationalStatusLocalizedString.extendedMission",
                tableName: nil,
                bundle: .module,
                value: "On extended mission",
                comment: "The localized string for the status of a satellite on extended mission"
            )
            return ("lightbulb.fill", string)
        case .backup:
            let string = NSLocalizedString(
                "SatelliteCell.operationalStatusLocalizedString.backup",
                tableName: nil,
                bundle: .module,
                value: "Backup",
                comment: "The localized string for the status of a backup satellite"
            )
            return ("lightbulb.fill", string)
        case .spare:
            let string = NSLocalizedString(
                "SatelliteCell.operationalStatusLocalizedString.backup",
                tableName: nil,
                bundle: .module,
                value: "Spare",
                comment: "The localized string for the status of a spare satellite"
            )
            return ("lightbulb", string)
        case .nonoperational:
            let string = NSLocalizedString(
                "SatelliteCell.operationalStatusLocalizedString.nonoperational",
                tableName: nil,
                bundle: .module,
                value: "Nonoperational",
                comment: "The localized string for the status of a nonoperational satellite"
            )
            return ("lightbulb.slash.fill", string)
        case .decayed:
            let string = NSLocalizedString(
                "SatelliteCell.operationalStatusLocalizedString.decayed",
                tableName: nil,
                bundle: .module,
                value: "Decayed",
                comment: "The localized string for the status of a decayed satellite"
            )
            return ("flame", string)
        case .unknown:
            let string = NSLocalizedString(
                "SatelliteCell.operationalStatusLocalizedString.unknown",
                tableName: nil,
                bundle: .module,
                value: "Unknown status",
                comment: "The localized string for the unknown status of satellite"
            )
            return ("questionmark", string)
        }
    }

}
