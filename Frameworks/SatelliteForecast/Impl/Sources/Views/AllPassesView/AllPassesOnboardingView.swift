//
//  AllPassesOnboardingView.swift
//  SatelliteForecastImpl
//
//  Created by Copilot on 7/27/25.
//

import SwiftUI
import SatelliteForecast
@preconcurrency import SatelliteKit
@preconcurrency import CombineRex
@preconcurrency import CombineRextensions

struct AllPassesOnboardingView: View {
    let onComplete: () -> Void
    let onDismiss: () -> Void
    let skyChartProducer: ViewProducer<SkyChartContext<EmptyView, EmptyView>, SkyChart<EmptyView, EmptyView>>
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Dark background
                Color.black
                    .ignoresSafeArea(.all)
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    // Title and description
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Pass explained", bundle: .module, comment: "Onboarding title for explaining a satellite pass")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        
                        Text("This screen lists all upcoming passes in 7 days. Each row shows when it will be visible from your location.", bundle: .module, comment: "Onboarding description for AllPassesView")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    
                    
                        Text("Tap on passes to see more details!", bundle: .module, comment: "CTA label in onboarding")
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        
                        // Mock PassPreviewCell using preview data
                        mockPassPreviewCell()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.2))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        
                        // Explanation text
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "arrow.up.to.line")
                                    .foregroundColor(.orange)
                                Text("Highest point in the sky (best for viewing)", bundle: .module, comment: "Onboarding explanation for culmination")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text("Pass quality rating (3 stars are best)", bundle: .module, comment: "Onboarding explanation for star rating")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Image(systemName: "arrow.up")
                                    .foregroundColor(.secondary)
                                Text("Times when satellite rises above horizon", bundle: .module, comment: "Onboarding explanation for satellite rises above horizon")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Image(systemName: "arrow.down")
                                    .foregroundColor(.secondary)
                                Text("Times when satellite sets below horizon", bundle: .module, comment: "Onboarding explanation for satellite sets below horizon")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Image(systemName: "eye")
                                    .foregroundColor(.secondary)
                                Text("Times when the space station becomes visible", bundle: .module, comment: "Onboarding explanation for visible times")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Image(systemName: "eye.slash")
                                    .foregroundColor(.secondary)
                                Text("Times when the space station becomes invisible", bundle: .module, comment: "Onboarding explanation for invisible times")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    Spacer()
                    
                    // Get Started button
                    Button(action: onComplete) {
                        HStack {
                            Text("Got it!", bundle: .module, comment: "Button to complete AllPassesView onboarding")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Image(systemName: "checkmark")
                                .font(.headline)
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .cornerRadius(25)
                    }
                    .padding(.bottom, 16)
                }
            }
            .navigationBarHidden(true)
            .onDisappear {
                // If the view disappears without the user tapping "Got it!", 
                // it means they dismissed by swiping or other means
                onDismiss()
            }
        }
    }
    
    @ViewBuilder
    private func mockPassPreviewCell() -> some View {
        // Create mock data for preview
        let elements = try! Elements(
            raw: """
            ISS (ZARYA)
            1 25544U 98067A   21155.08058252  .00001489  00000-0  35252-4 0  9997
            2 25544  51.6446  47.5538 0003512  61.1482  91.5411 15.48950578286563
            """
        )
        
        let observer = LatLonAlt(lat: 37.486743000691185, lon: -122.22655970246515, alt: 0)
        let startDate = Date(timeIntervalSinceReferenceDate: 25 * 365 * 86400)
        let julianDateRange = startDate.julianDate...startDate.advanced(by: 3600 * 24 * 7).julianDate
        let satelliteInfo = try! SatelliteInfo(elements: elements)
        let coarseSnapshots = try! satelliteInfo.generateSnapshots(
            observer: observer,
            julianDateRange: julianDateRange,
            interval: 60
        )
        let passSnapshots = try! satelliteInfo.findPasses(
            observer: observer,
            coarseSnapshots: coarseSnapshots
        )
        
        let selectedPass = passSnapshots.first { $0.notableSnapshots.visibleCulminationElevation > 45 }!
        PassPreviewCell(
            satelliteInfo: satelliteInfo,
            observer: observer,
            passSnapshots: selectedPass,
            hasScheduledAlert: false,
            skyChartProducer: skyChartProducer,
            julianDateOffset: 0,
            julianDateProvider: { startDate.julianDate }
        )
        .frame(height: 135)
        .padding(16)
    }
}
