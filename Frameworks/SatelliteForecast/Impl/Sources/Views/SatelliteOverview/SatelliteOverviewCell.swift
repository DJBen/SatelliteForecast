//
//  SatelliteOverviewCell.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/25/21.
//

@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
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
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color(UIColor.systemBackground))
            
            // Background video
            let videoName = satellite == .iss ? "iss" : "tiangong"
            AutoPlayVideoView(videoName: videoName, bundle: .module)
                .frame(height: 225)
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
                                isDarkBackground: true
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
                                isDarkBackground: true
                            )
                        }
                        if nextPass.nextVisiblePass == nil && nextPass.nextProminentPass == nil {
                            Text("No upcoming visible passes; check back after 7 days", bundle: .module)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                case .loading:
                    if isMissingLocation {
                        Text(SatelliteOverviewCell.satelliteOfSpecialInterestLocalizedDescription(satellite))
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                            .foregroundColor(.secondary)
                    } else {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle())
                            Text("Loading pass information...", bundle: .module)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                case .notLoaded:
                    Text(SatelliteOverviewCell.satelliteOfSpecialInterestLocalizedDescription(satellite))
                        .font(.subheadline)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.systemBackground))
            .animation(.easeInOut(duration: 0.2), value: nextPassLoadingState)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
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
                                colors: [.cyan, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                } else {
                    Text("Evening ", bundle: .module)
                        .font(.subheadline)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                let countdownText = Text(durationFormatter.localizedString(fromTimeInterval: timeUntilRise))
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(isDarkBackground ? .white : .secondary)
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
                    .foregroundColor(isDarkBackground ? .white : .secondary)
                
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
                            // Default state with no passes loaded
                            SatelliteOverviewCell(
                                satellite: .iss,
                                nextPassLoadingState: .notLoaded,
                                currentDate: Date(timeIntervalSinceReferenceDate: 0),
                                julianDateOffset: 0,
                                isMissingLocation: false,
                            )

                            // Loading state
                            SatelliteOverviewCell(
                                satellite: .iss,
                                nextPassLoadingState: .loading,
                                currentDate: Date(timeIntervalSinceReferenceDate: 0),
                                julianDateOffset: 0,
                                isMissingLocation: false,
                            )
                            
                            // Error state
                            SatelliteOverviewCell(
                                satellite: .iss,
                                nextPassLoadingState: .failed(URLError(.notConnectedToInternet)),
                                currentDate: Date(timeIntervalSinceReferenceDate: 0),
                                julianDateOffset: 0,
                                isMissingLocation: false,
                            )
                            
                            // Loaded state with both visible and prominent passes
                            SatelliteOverviewCell(
                                satellite: .iss, 
                                nextPassLoadingState: .loaded(
                                    NextPass(
                                        nextVisiblePass: Pass(
                                            noradIndex: 25544,
                                            rise: Pass.DatePosition(julianDate: Date().addingTimeInterval(7200).julianDate, azim: 45, elev: 10),
                                            set: Pass.DatePosition(julianDate: Date().addingTimeInterval(8100).julianDate, azim: 225, elev: 10),
                                            culmination: Pass.DatePosition(julianDate: Date().addingTimeInterval(7650).julianDate, azim: 135, elev: 35),
                                            illumination: Pass.Illumination(initiallyIlluminated: true, changes: []),
                                            sunElevationAtTransit: -20
                                        ),
                                        nextProminentPass: Pass(
                                            noradIndex: 25544,
                                            rise: Pass.DatePosition(julianDate: Date().addingTimeInterval(86400).julianDate, azim: 90, elev: 10),
                                            set: Pass.DatePosition(julianDate: Date().addingTimeInterval(87300).julianDate, azim: 270, elev: 10),
                                            culmination: Pass.DatePosition(julianDate: Date().addingTimeInterval(86850).julianDate, azim: 180, elev: 65),
                                            illumination: Pass.Illumination(initiallyIlluminated: true, changes: []),
                                            sunElevationAtTransit: -18
                                        )
                                    )
                                ),
                                currentDate: Date(timeIntervalSinceReferenceDate: 0),
                                julianDateOffset: 0,
                                isMissingLocation: false,
                            )
                            
                            // Loaded state with no upcoming passes
                            SatelliteOverviewCell(
                                satellite: .tianhe, 
                                nextPassLoadingState: .loaded(
                                    NextPass(nextVisiblePass: nil, nextProminentPass: nil)
                                ),
                                currentDate: Date(timeIntervalSinceReferenceDate: 0),
                                julianDateOffset: 0,
                                isMissingLocation: false,
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
