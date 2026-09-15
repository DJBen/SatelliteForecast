//
//  PassPreviewCell.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 6/15/21.
//

import BTree
import SwiftUI
import SatelliteForecast
import Shimmer
@preconcurrency import SatelliteKit
import StarryNight

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}()

private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.setLocalizedDateFormatFromTemplate("H:mm:ss")
    return formatter
}()

private let numberFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.maximumFractionDigits = 1
    return formatter
}()

struct PassPreviewCell: View {
    var satelliteInfo: SatelliteInfo
    var observer: LatLonAlt
    var passSnapshots: PassSnapshots
    var hasScheduledAlert: Bool
    var skyChartFactory: ViewFactory<SkyChartContext<EmptyView, EmptyView>, SkyChart<EmptyView, EmptyView>>
    var julianDateOffset: Double
    var starManager: AppStarCatalog
    var julianDateProvider: () -> Double

    var snapshots: [SatelliteSnapshot] {
        passSnapshots.snapshots
    }
    
    var notableSnapshots: NotableSnapshots {
        passSnapshots.notableSnapshots
    }
    
    var pass: Pass {
        passSnapshots.pass
    }

    @Environment(\.colorScheme) var colorScheme

    @ViewBuilder private var starRatingView: some View {
        HStack(spacing: 0) {
            Image(systemName: "star.fill")
                .if(notableSnapshots.visibleCulminationElevation < 30, transform: { $0.hidden() })
            Image(systemName: "star.fill")
                .if(notableSnapshots.visibleCulminationElevation < 45, transform: { $0.hidden() })
            Image(systemName: "star.fill")
                .if(notableSnapshots.visibleCulminationElevation < 75, transform: { $0.hidden() })
        }
        .foregroundStyle(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 230 / 255, green: 158 / 255, blue: 25 / 255),
                    Color(red: 239 / 255, green: 193 / 255, blue: 108 / 255)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let shortEdge = min(geometry.size.width, geometry.size.height)
            
            HStack(alignment: .top, spacing: 4) {
                HStack(alignment: .top) {
                    // Column 1: Day light and elevation
                    if geometry.size.width >= 320 {
                        VStack(alignment: .leading) {
                            Text(PassPreviewCell.titleForPassVisibility(pass.visibility))
                                .font(.headline)
                                .foregroundColor(Color(UIColor.label))
                            if notableSnapshots.visibleCulminationElevation > 0 {
                                Text(verbatim: "∠\(numberFormatter.string(from: NSNumber(value: notableSnapshots.visibleCulminationElevation))!)°")
                                    .font(.body)
                                    .foregroundColor(Color(UIColor.label))
                            }
                            if hasScheduledAlert {
                                Spacer(minLength: 8)
                                Image(systemName: "bell.fill")
                                    .font(.title3)
                                    .foregroundColor(Color(UIColor.label))
                            }
                        }
                        .frame(width: 80)
                    }

                    VStack(alignment: .leading) {
                        ViewThatFits(in: .horizontal) {
                            Text(dateFormatter.string(from: Date(julianDate: pass.rise.julianDate)))
                                .fixedSize()
                            Text(Date(julianDate: pass.rise.julianDate), format: .dateTime.year().month(.twoDigits).day(.twoDigits))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                            .font(.headline)
                            .padding([.bottom], 1)
                            .foregroundColor(Color(UIColor.label))

                        if let exitsShadowJulianDate = notableSnapshots.exitsShadow?.first.julianDate {
                            HStack(spacing: 0) {
                                Image(systemName: "eye")
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.muted)
                                
                                Text(timeFormatter.string(from: Date(julianDate: exitsShadowJulianDate)))
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.muted)
                            }
                            if exitsShadowJulianDate < pass.culmination.julianDate && exitsShadowJulianDate < pass.set.julianDate {
                                HStack(spacing: 0) {
                                    Image(systemName: "arrow.up.to.line")
                                        .font(.subheadline)
                                        .foregroundColor(AppTheme.muted)
                                        .bold()

                                    Text(timeFormatter.string(from: Date(julianDate: pass.culmination.julianDate)))
                                        .font(.subheadline)
                                        .foregroundColor(Color(UIColor.label))
                                        .bold()
                                        .shimmering(gradient: Gradient(colors: [
                                            AppTheme.muted,
                                            Color(UIColor.label),
                                            AppTheme.muted
                                        ]), bandSize: 0.5)
                                }
                            }
                        } else {
                            HStack(spacing: 0) {
                                Image(systemName: "arrow.up")
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.muted)

                                Text(timeFormatter.string(from: Date(julianDate: pass.rise.julianDate)))
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.muted)
                            }
                        }
                        
                        if notableSnapshots.exitsShadow?.first.julianDate == nil && notableSnapshots.entersShadow?.first.julianDate == nil {
                            HStack(spacing: 0) {
                                Image(systemName: "arrow.up.to.line")
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.muted)
                                    .bold()

                                Text(timeFormatter.string(from: Date(julianDate: pass.culmination.julianDate)))
                                    .font(.subheadline)
                                    .foregroundColor(Color(UIColor.label))
                                    .bold()
                                    .shimmering(gradient: Gradient(colors: [
                                        AppTheme.muted,
                                        Color(UIColor.label),
                                        AppTheme.muted
                                    ]), bandSize: 0.5)
                            }
                        }

                        if let entersShadowJulianDate = notableSnapshots.entersShadow?.first.julianDate {
                            if entersShadowJulianDate > pass.culmination.julianDate && entersShadowJulianDate < pass.set.julianDate {
                                HStack(spacing: 0) {
                                    Image(systemName: "arrow.up.to.line")
                                        .font(.subheadline)
                                        .foregroundColor(AppTheme.muted)
                                        .bold()

                                    Text(timeFormatter.string(from: Date(julianDate: pass.culmination.julianDate)))
                                        .font(.subheadline)
                                        .foregroundColor(Color(UIColor.label))
                                        .bold()
                                        .shimmering(gradient: Gradient(colors: [
                                            AppTheme.muted,
                                            Color(UIColor.label),
                                            AppTheme.muted
                                        ]), bandSize: 0.5)
                                }
                            }
                            HStack(spacing: 0) {
                                Image(systemName: "eye.slash")
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.muted)

                                Text(timeFormatter.string(from: Date(julianDate: entersShadowJulianDate)))
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.muted)
                            }
                        } else {
                            HStack(spacing: 0) {
                                Image(systemName: "arrow.down")
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.muted)
                                
                                Text(timeFormatter.string(from: Date(julianDate: pass.set.julianDate)))
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.muted)
                            }
                        }
                        
                        Spacer(minLength: 4)
                        
                        starRatingView.padding(.bottom, 4)
                        
                        Text(PassPreviewCell.relativeDate(pass: pass, referenceDate: julianDateProvider() + julianDateOffset))
                            .font(.caption)
                            .foregroundColor(AppTheme.muted)
                    }
                    .frame(width: 120)
                }

                skyChartFactory.view(
                    SkyChartContext(
                        satelliteInfo: satelliteInfo,
                        observer: observer,
                        passSnapshots: passSnapshots,
                        configs: .preview,
                        quality: .onboarding,
                        starManager: starManager,
                        julianDateProvider: julianDateProvider
                    )
                )
                // Prevent consuming the tap events
                .allowsHitTesting(false)
                .frame(width: shortEdge, height: shortEdge)
            }
        }
    }
}

extension PassPreviewCell {
    static func titleForPassVisibility(_ visibility: Pass.Visibility) -> String {
        switch visibility {
        case .visible:
            return NSLocalizedString(
                "PassPreviewCell.visibilityText.visible",
                tableName: nil,
                bundle: .module,
                value: "Visible",
                comment: "The pass is visible"
            )
        case .daylight:
            return NSLocalizedString(
                "PassPreviewCell.visibilityText.daylight",
                tableName: nil,
                bundle: .module,
                value: "Daylight",
                comment: "The pass happens during daylight"
            )
        case .unlit:
            return NSLocalizedString(
                "PassPreviewCell.visibilityText.unlit",
                tableName: nil,
                bundle: .module,
                value: "Unlit",
                comment: "The pass happens entirely unlit"
            )
        }
    }

    private static let durationFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.formattingContext = .beginningOfSentence
        return formatter
    }()

    static func relativeDate(pass: Pass, referenceDate: Double) -> String {
        if referenceDate < pass.rise.julianDate {
            let format = NSLocalizedString(
                "PassPreviewCell.relativeDate.riseInTheFuture",
                tableName: nil,
                bundle: .module,
                value: "%@",
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
                bundle: .module,
                value: "%@",
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
                bundle: .module,
                value: "Passing now",
                comment: "A string describing that the satellite is currently passing"
            )
        }
    }

}
