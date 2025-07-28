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
                    VStack(spacing: 24) {
                        VStack(spacing: 16) {
                            Text("Satellite Pass List", bundle: .module, comment: "Onboarding title for AllPassesView")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            Text("This is your pass forecast. Each row shows when a satellite will be visible from your location.", bundle: .module, comment: "Onboarding description for AllPassesView")
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        
                        // Example PassPreviewCell
                        VStack(spacing: 16) {
                            Text("Example Pass", bundle: .module, comment: "Label for example pass in onboarding")
                                .font(.headline)
                                .foregroundColor(.white)
                            
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
                                .padding(.horizontal, 16)
                        }
                        
                        // Explanation text
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "eye")
                                    .foregroundColor(.blue)
                                Text("Times when the satellite becomes visible", bundle: .module, comment: "Onboarding explanation for visible times")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            
                            HStack {
                                Image(systemName: "arrow.up.to.line")
                                    .foregroundColor(.orange)
                                Text("Highest point in the sky (best viewing)", bundle: .module, comment: "Onboarding explanation for culmination")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text("Pass quality rating (more stars = brighter)", bundle: .module, comment: "Onboarding explanation for star rating")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 32)
                    }
                    
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
                    .padding(.bottom, 50)
                }
            }
            .navigationBarHidden(true)
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
        let startDate = Date(timeIntervalSinceReferenceDate: 20 * 365 * 86400)
        let julianDateRange = startDate.advanced(by: -60 * 60 * 2).julianDate...startDate.advanced(by: 60 * 60 * 30).julianDate
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
        
        if let firstPass = passSnapshots.first {
            PassPreviewCell(
                satelliteInfo: satelliteInfo,
                snapshots: firstPass.snapshots,
                notableSnapshots: firstPass.notableSnapshots,
                observer: observer,
                pass: firstPass.pass,
                hasScheduledAlert: false,
                skyChartProducer: skyChartProducer,
                julianDateOffset: 0,
                julianDateProvider: { startDate.julianDate }
            )
            .frame(height: 135)
        } else {
            // Fallback empty view
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 135)
                .overlay(
                    Text("Example Pass", bundle: .module)
                        .foregroundColor(.secondary)
                )
        }
    }
}
