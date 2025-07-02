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

struct SatelliteOverviewCell: View {
    let satellite: SatelliteCategory
    let nextPassLoadingState: Loadable<NextPass, Error>
    let julianDateOffset: Double
    let isMissingLocation: Bool
    
    @Environment(\.colorScheme) private var colorScheme

    @ViewBuilder private func background(satellite: SatelliteCategory) -> some View {
        if let noradIndex = satellite.noradIndex {
            Image(String(noradIndex), bundle: .module)
                .resizable()
                .aspectRatio(contentMode: .fill)
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Spacer()
                .frame(height: 180)
            
            ZStack {
                Color.clear
                    .blurEffect()
                
                Group {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(SatelliteOverviewCell.satelliteOfSpecialInterestLocalizedTitle(satellite))
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(Color(UIColor.label))
                            Spacer()
                            Image(systemName: "chevron.forward")
                                .font(.title2)
                                .foregroundColor(Color(UIColor.label))
                        }
                        
                        switch nextPassLoadingState {
                        case .failed(_):
                            Text("Unable to load pass information")
                                .font(.body)
                                .foregroundColor(.red)
                            .multilineTextAlignment(.leading)
                            .vibrancyEffect()
                        case .loaded(let nextPass):
                            VStack(alignment: .leading, spacing: 4) {
                                if let nextVisiblePass = nextPass.nextVisiblePass, let highestIlluminated = nextVisiblePass.highestIlluminated {
                                    SatelliteOverviewCell.PassCountdownView(
                                        pass: nextVisiblePass,
                                        title: Text("Visible pass \(Image(systemName: "angle"))\(Int(highestIlluminated.elev.rounded()))°"),
                                        julianDateOffset: julianDateOffset,
                                    )
                                }
                                if let nextProminentPass = nextPass.nextProminentPass, let highestIlluminated = nextProminentPass.highestIlluminated {
                                    SatelliteOverviewCell.PassCountdownView(
                                        pass: nextProminentPass,
                                        title: Text("Prominent pass \(Image(systemName: "angle"))\(Int(highestIlluminated.elev.rounded()))°"),
                                        julianDateOffset: julianDateOffset,
                                    )
                                }
                                if nextPass.nextVisiblePass == nil && nextPass.nextProminentPass == nil {
                                    Text("No upcoming visible passes")
                                        .font(.subheadline)
                                        .foregroundColor(colorScheme == .light ? Color(UIColor.systemGray2) : Color(UIColor.systemGray4))
                                        .vibrancyEffect()
                                }
                            }
                        case .loading:
                            if isMissingLocation {
                                fallbackText
                            } else {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Loading pass information...")
                                        .font(.subheadline)
                                        .foregroundColor(colorScheme == .light ? Color(UIColor.systemGray2) : Color(UIColor.systemGray4))
                                }
                                .vibrancyEffect()
                            }
                        case .notLoaded:
                            fallbackText
                        }
                    }
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
    
    @ViewBuilder private var fallbackText: some View {
        Text(SatelliteOverviewCell.satelliteOfSpecialInterestLocalizedDescription(satellite))
            .font(.subheadline)
            .multilineTextAlignment(.leading)
            .foregroundColor(colorScheme == .light ? Color(UIColor.systemGray2) : Color(UIColor.systemGray4))
            .vibrancyEffect()
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
    struct PassCountdownView: View {
        let pass: Pass
        let title: Text
        let julianDateOffset: Double
        
        @Environment(\.colorScheme) private var colorScheme
        @State private var isFlashing = false

        private static let durationFormatter: RelativeDateTimeFormatter = {
            let formatter = RelativeDateTimeFormatter()
            formatter.dateTimeStyle = .named
            formatter.formattingContext = .middleOfSentence
            return formatter
        }()
        
        @ViewBuilder private var countdownText: some View {
            let currentJulianDate = Date().julianDate + julianDateOffset
            let timeUntilRise = (pass.rise.julianDate - currentJulianDate) * TimeConstants.day2sec
            
            if currentJulianDate >= pass.rise.julianDate && currentJulianDate <= pass.set.julianDate {
                Text("Passing now!")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(isFlashing ? .pink : .orange)
                    .onAppear {
                        withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            isFlashing = true
                        }
                    }
            } else {
                let calendar = Calendar.current
                let hour = calendar.component(.hour, from: Date(julianDate: pass.culmination.julianDate))
                let amOrPmText = if hour < 12 {
                    Text("Morning ")
                        .font(.subheadline)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                } else {
                    Text("Afternoon ")
                        .font(.subheadline)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.5, green: 0.2, blue: 0.8), Color(red: 0.8, green: 0.2, blue: 0.5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                let countdownText = Text(Self.durationFormatter.localizedString(fromTimeInterval: timeUntilRise))
                    .font(.subheadline)
                    .foregroundColor(.primary)
                amOrPmText + countdownText
            }
        }
        
        var body: some View {
            HStack(alignment: .center, spacing: 4) {
                title
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                countdownText
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
                                julianDateOffset: 0,
                                isMissingLocation: false
                            )

                            // Loading state
                            SatelliteOverviewCell(
                                satellite: .iss,
                                nextPassLoadingState: .loading,
                                julianDateOffset: 0,
                                isMissingLocation: false
                            )
                            
                            // Error state
                            SatelliteOverviewCell(
                                satellite: .iss,
                                nextPassLoadingState: .failed(URLError(.notConnectedToInternet)),
                                julianDateOffset: 0,
                                isMissingLocation: false
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
                                julianDateOffset: 0,
                                isMissingLocation: false
                            )
                            
                            // Loaded state with no upcoming passes
                            SatelliteOverviewCell(
                                satellite: .tianhe, 
                                nextPassLoadingState: .loaded(
                                    NextPass(nextVisiblePass: nil, nextProminentPass: nil)
                                ),
                                julianDateOffset: 0,
                                isMissingLocation: false
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
