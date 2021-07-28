//
//  SatelliteOverviewCell.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/25/21.
//

import SwiftUI
import SwiftUIVisualEffects

enum SatelliteOverviewSection: Equatable, Hashable {
    case satellitesOfSpecialInterest([SatelliteOverviewItem])
    case categories([SatelliteOverviewItem])
    case management([SatelliteOverviewItem])

    var items: [SatelliteOverviewItem] {
        switch self {
        case let .satellitesOfSpecialInterest(items),
             let .categories(items),
             let .management(items):
            return items
        }
    }
}

enum SatelliteOverviewItem: Equatable, Hashable {
    enum SatellitesOfSpecialInterest: Int, Equatable, Hashable {
        case iss = 25544
        case tianhe = 48274
    }
    case specialSatellites(SatellitesOfSpecialInterest)
    case category(SatelliteCategory)

    enum Management: Equatable, Hashable {
        case alert
    }
    case management(Management)
}

struct SatelliteOverviewCellModel {
    let item: SatelliteOverviewItem
}

/// An overview cell contains a category of satellites.
struct SatelliteOverviewCell: View {
    let model: SatelliteOverviewCellModel

    var body: some View {
        switch model.item {
        case let .specialSatellites(satellite):
            return AnyView(SatelliteOverviewSpecialSatelliteCell(satellite: satellite))
        case let .category(category):
            return AnyView(SatelliteOverviewCategoryCell(category: category))
        case .management(_):
            return AnyView(EmptyView())
        }
    }
}

struct SatelliteOverviewSpecialSatelliteCell: View {
    let satellite: SatelliteOverviewItem.SatellitesOfSpecialInterest

    @Environment(\.colorScheme) private var colorScheme

    private func background(satellite: SatelliteOverviewItem.SatellitesOfSpecialInterest) -> some View {
        switch satellite {
        case .iss:
            return AnyView(Image("25544")
                .resizable()
                .aspectRatio(contentMode: .fill)
            )
        case .tianhe:
            return AnyView(Image("48274")
                .resizable()
                .aspectRatio(contentMode: .fill)
            )
        }
    }

    var body: some View {
        HStack(alignment: .center) {
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

            Image(systemName: "chevron.right")
                .foregroundColor(Color(UIColor.secondaryLabel))
        }
    }
}

fileprivate extension UIColor {
    func darken(by val: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0
        var b: CGFloat = 0, a: CGFloat = 0

        guard getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            else {return self}

        return UIColor(
            hue: h,
            saturation: s,
            brightness: max(b - val, 0.0),
            alpha: a
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
            colors = [UIColor.systemTeal, UIColor.systemPurple]
        case .active:
            colors = [UIColor.systemTeal, UIColor.systemGreen]
        case .last30DayLaunches:
            colors = [UIColor.systemYellow, UIColor.systemOrange]
        }

        if colorScheme == .dark {
            colors = colors.map { $0.darken(by: 0.3) }
        }

        return AnyView(LinearGradient(
            gradient: Gradient(colors: colors.map(Color.init)),
            startPoint: UnitPoint(x: 0, y: 0),
            endPoint: UnitPoint(x: 1, y: 1)
        ))
    }

    var body: some View {
        HStack {
            HStack {
                Text(LocalizedStrings.SatelliteOverviewCell.categoryLocalizedString(category))
                    .font(.headline)
                    .foregroundColor(Color(UIColor.label))

                Spacer()
            }
            .padding()
            .background(background(category: category))
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                )
            )

            Image(systemName: "chevron.right")
                .foregroundColor(Color(UIColor.secondaryLabel))
        }
    }
}

#if DEBUG
struct SatelliteOverviewCell_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(ColorScheme.allCases, id: \.self) { colorScheme in
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
            .padding()
            .preferredColorScheme(colorScheme)
        }
    }
}
#endif
