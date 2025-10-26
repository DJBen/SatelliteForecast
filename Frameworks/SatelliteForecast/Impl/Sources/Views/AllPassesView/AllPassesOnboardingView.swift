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

struct SatelliteData {
    let satelliteInfo: SatelliteInfo
    let observer: LatLonAlt
    let selectedPass: PassSnapshots
}

struct AllPassesOnboardingView: View {
    let onComplete: () -> Void
    let skyChartProducer: ViewProducer<SkyChartContext<EmptyView, EmptyView>, SkyChart<EmptyView, EmptyView>>
    
    @State private var satelliteData: Loadable<SatelliteData, Error> = .loading
    @State private var handTapOffset: CGPoint = CGPoint(x: 0, y: 0)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    Text("This screen lists all upcoming passes in 7 days. Each row shows when it will be visible from your location.", bundle: .module, comment: "Onboarding description for AllPassesView")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)


                    // Mock PassPreviewCell using preview data
                    NavigationLink(
                        destination: TutorialVideoView(
                            onDismiss: {
                                onComplete()
                            }
                        )
                        .ignoresSafeArea(.container, edges: .top)
                    ) {
                        HStack(alignment: .center, spacing: 0) {
                            mockPassPreviewCell()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                                .padding(.trailing, 8)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.2))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "hand.tap.fill")
                                .font(.largeTitle)
                                .foregroundStyle(Color.orange)
                                .shadow(color: Color.yellow, radius: 8)
                                .symbolRenderingMode(.hierarchical)
                                .symbolEffect(.bounce.up.byLayer, options: .repeat(.periodic(delay: 1.0)))
                                .padding(16)
                                .offset(x: handTapOffset.x, y: handTapOffset.y)
                                .animation(
                                    .easeInOut(duration: 2.0),
                                    value: handTapOffset
                                )
                        }
                    }

                    // Explanation text
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "arrow.up.to.line")
                                .foregroundColor(.orange)
                            Text("Highest point in the sky (best for viewing)", bundle: .module, comment: "Onboarding explanation for culmination")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("Pass quality rating (3 stars are best)", bundle: .module, comment: "Onboarding explanation for star rating")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Image(systemName: "arrow.up")
                                .foregroundColor(.secondary)
                            Text("Times when satellite rises above horizon", bundle: .module, comment: "Onboarding explanation for satellite rises above horizon")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Image(systemName: "arrow.down")
                                .foregroundColor(.secondary)
                            Text("Times when satellite sets below horizon", bundle: .module, comment: "Onboarding explanation for satellite sets below horizon")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Image(systemName: "eye")
                                .foregroundColor(.secondary)
                            Text("Times when the space station becomes visible", bundle: .module, comment: "Onboarding explanation for visible times")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Image(systemName: "eye.slash")
                                .foregroundColor(.secondary)
                            Text("Times when the space station becomes invisible", bundle: .module, comment: "Onboarding explanation for invisible times")
                                .font(.body)
                                .foregroundColor(.secondary)

                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .navigationTitle(Text("Pass explained", bundle: .module, comment: "Onboarding title for explaining a satellite pass"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onComplete) {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .task {
            await loadSatelliteData()
        }
        .onAppear {
            handTapOffset = CGPoint(x: -60, y: -10)
        }
    }
    
    private func loadSatelliteData() async {
        // Don't reload if already loaded
        if case .loaded = satelliteData {
            return
        }
        
        satelliteData = .loading
        
        do {
            let elements = try Elements(
                raw: """
                ISS (ZARYA)             
                1 25544U 98067A   25224.47423135  .00010254  00000+0  18430-3 0  9994
                2 25544  51.6349  28.0780 0001172 181.8871 178.2114 15.50477111523893
                """
            )
            
            let observer = LatLonAlt(37.4253, -122.1399, 0)
            let formatter = ISO8601DateFormatter()
            let startDate = formatter.date(from: "2025-08-19T04:00:00-07:00")!
            let julianDateRange = startDate.julianDate...startDate.advanced(by: 3600 * 24 * 7).julianDate
            let satelliteInfo = try SatelliteInfo(elements: elements)
            let coarseSnapshots = try satelliteInfo.generateSnapshots(
                observer: observer,
                julianDateRange: julianDateRange,
                interval: 60
            )
            let passSnapshots = try satelliteInfo.findPasses(
                observer: observer,
                coarseSnapshots: coarseSnapshots
            )
            
            if let selectedPass = passSnapshots.first(where: { $0.notableSnapshots.visibleCulminationElevation > 45 }) {
                satelliteData = .loaded(SatelliteData(
                    satelliteInfo: satelliteInfo,
                    observer: observer,
                    selectedPass: selectedPass
                ))
            } else {
                satelliteData = .failed(NSError(domain: "SatelliteData", code: 1, userInfo: [NSLocalizedDescriptionKey: "No suitable pass found"]))
            }
        } catch {
            satelliteData = .failed(error)
        }
    }
    
    @ViewBuilder
    private func mockPassPreviewCell() -> some View {
        let formatter = ISO8601DateFormatter()
        let startDate = formatter.date(from: "2025-08-19T04:00:00-07:00")!
        
        switch satelliteData {
        case .notLoaded:
            // Not possible
            EmptyView()
                
        case .loading:
            ProgressView()
                .scaleEffect(1.5)

        case .loaded(let data):
            PassPreviewCell(
                satelliteInfo: data.satelliteInfo,
                observer: data.observer,
                passSnapshots: data.selectedPass,
                hasScheduledAlert: false,
                skyChartProducer: skyChartProducer,
                julianDateOffset: 0,
                starManager: StarManagerMock(),
                julianDateProvider: { startDate.julianDate }
            )
            .frame(height: 135)
            .padding(16)
            
        case .failed(let error):
            // Error state with retry button
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                
                Text("Failed to load satellite data")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Retry") {
                    Task {
                        await loadSatelliteData()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(height: 135)
            .padding(16)
        }
    }
}
