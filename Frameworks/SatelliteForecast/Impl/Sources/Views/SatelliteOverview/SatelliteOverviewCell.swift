//
//  SatelliteOverviewCell.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/25/21.
//

import SatelliteForecast
@preconcurrency import SatelliteKit
import SwiftUI
import SwiftUIVisualEffects
import AVKit

private let durationFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.dateTimeStyle = .named
    formatter.formattingContext = .middleOfSentence
    return formatter
}()

struct SatelliteOverviewCell: View {
    let satellite: SatelliteCategory
    let nextPassLoadingState: Loadable<NextPass, Error>
    let currentDate: Date
    let julianDateOffset: Double
    let isMissingLocation: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Title section
            HStack {
                Text(SatelliteOverviewCell.satelliteOfSpecialInterestLocalizedTitle(satellite))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.muted)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(AppTheme.surface)
            
            // Background video
            let videoName = satellite == .iss ? "iss" : "tiangong"
            AutoPlayVideoView(videoName: videoName, bundle: .module)
                .frame(height: 184)
                .clipped()
            
            // Pass information section
            Group {
                switch nextPassLoadingState {
                case .failed(_):
                    Text("Unable to load pass information", bundle: .module)
                        .font(.body)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.leading)
                case .loaded(let nextPass):
                    VStack(alignment: .leading, spacing: 4) {
                        if let nextVisiblePass = nextPass.nextVisiblePass, let highestIlluminated = nextVisiblePass.highestIlluminated {
                            SatelliteOverviewCell.PassCountdownView(
                                pass: nextVisiblePass,
                                title: Text("Visible pass \(Image(systemName: "angle"))\(Int(highestIlluminated.elev.rounded()))°", bundle: .module)
                                    .minimumScaleFactor(0.75)
                                    .lineLimit(1),
                                currentDate: currentDate,
                                julianDateOffset: julianDateOffset,
                                isDarkBackground: false
                            )
                        }
                        if let nextProminentPass = nextPass.nextProminentPass, let highestIlluminated = nextProminentPass.highestIlluminated {
                            SatelliteOverviewCell.PassCountdownView(
                                pass: nextProminentPass,
                                title: Text("Prominent pass \(Image(systemName: "angle"))\(Int(highestIlluminated.elev.rounded()))°", bundle: .module)
                                    .minimumScaleFactor(0.75)
                                    .lineLimit(1),
                                currentDate: currentDate,
                                julianDateOffset: julianDateOffset,
                                isDarkBackground: false
                            )
                        }
                        if nextPass.nextVisiblePass == nil && nextPass.nextProminentPass == nil {
                            Text("No upcoming visible passes; check back after a few days!", bundle: .module)
                                .font(.subheadline)
                                .foregroundColor(AppTheme.muted)
                                .multilineTextAlignment(.leading)
                        }
                    }
                case .loading:
                    if isMissingLocation {
                        Text(SatelliteOverviewCell.satelliteOfSpecialInterestLocalizedDescription(satellite))
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                            .foregroundColor(AppTheme.muted)
                    } else {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle())
                            Text("Loading pass information...", bundle: .module)
                                .font(.subheadline)
                                .foregroundColor(AppTheme.muted)
                        }
                    }
                case .notLoaded:
                    Text(SatelliteOverviewCell.satelliteOfSpecialInterestLocalizedDescription(satellite))
                        .font(.subheadline)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(AppTheme.muted)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surface)
            .animation(.easeInOut(duration: 0.2), value: nextPassLoadingState)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: AppTheme.cardRadius).stroke(AppTheme.border, lineWidth: 1))
        )
    }
}

extension SatelliteOverviewCell {
    static func satelliteOfSpecialInterestLocalizedTitle(_ satellite: SatelliteCategory) -> String {
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

    static func satelliteOfSpecialInterestLocalizedDescription(_ satellite: SatelliteCategory) -> String {
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
    
    /// A reusable view component for displaying pass countdown information
    struct PassCountdownView<TextView: View>: View {
        let pass: Pass
        let title: TextView
        let currentDate: Date
        let julianDateOffset: Double
        let isDarkBackground: Bool
        
        @Environment(\.colorScheme) private var colorScheme
        @State private var isFlashing = false
        
        @ViewBuilder private var countdownText: some View {
            let currentJulianDate = currentDate.julianDate + julianDateOffset
            let timeUntilRise = (pass.rise.julianDate - currentJulianDate) * TimeConstants.day2sec
            
            if currentJulianDate >= pass.rise.julianDate && currentJulianDate <= pass.set.julianDate {
                Text("Passing now!", bundle: .module, comment: "A string describing that the satellite is currently passing")
                    .font(.subheadline.monospacedDigit())
                    .fontWeight(.bold)
                    .foregroundColor(isFlashing ? .pink : .orange)
                    .onAppear {
                        withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            isFlashing = true
                        }
                    }
                    .onDisappear {
                        isFlashing = false
                    }
            } else {
                let calendar = Calendar.current
                let hour = calendar.component(.hour, from: Date(julianDate: pass.culmination.julianDate))
                let amOrPmText = if hour < 12 {
                    Text("Morning ", bundle: .module)
                        .font(.subheadline)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.accent, AppTheme.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                } else {
                    Text("Evening ", bundle: .module)
                        .font(.subheadline)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.warning, AppTheme.warning],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                let countdownText = Text(durationFormatter.localizedString(fromTimeInterval: timeUntilRise))
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(isDarkBackground ? .white : AppTheme.muted)
                (amOrPmText + countdownText)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
            }
        }
        
        var body: some View {
            HStack(alignment: .center, spacing: 4) {
                title
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isDarkBackground ? .white : AppTheme.muted)
                
                Spacer()
                
                // Fixed width container to prevent layout shifts
                HStack {
                    Spacer()
                    countdownText
                }
                .frame(minWidth: 120, alignment: .trailing)
                .animation(.easeInOut(duration: 0.2), value: currentDate)
            }
        }
    }
}
