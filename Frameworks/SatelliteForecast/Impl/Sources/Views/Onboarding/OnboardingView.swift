//
//  OnboardingView.swift
//  SatelliteForecast
//
//  Created by Copilot on 7/22/25.
//

import SwiftUI
import AVKit
import AVFoundation

public enum OnboardingAction {
    case complete
    case pageChanged(Int)
    case reset
}

public struct OnboardingViewState {
    public var hasCompletedOnboarding: Bool = false
    public var currentPage: Int = 0
    
    public init(hasCompletedOnboarding: Bool = false, currentPage: Int = 0) {
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.currentPage = currentPage
    }
}

extension OnboardingViewState: Equatable {}

public struct OnboardingPage {
    let title: String
    let description: String
    let videoName: String
    let videoExtension: String
    let customView: ((GeometryProxy) -> AnyView)?
    
    public init(title: String, description: String, videoName: String, videoExtension: String, customView: ((GeometryProxy) -> AnyView)? = nil) {
        self.title = title
        self.description = description
        self.videoName = videoName
        self.videoExtension = videoExtension
        self.customView = customView
    }
}

public struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var videoPlaybackTimes: [String: CMTime] = [:]
    let onComplete: () -> Void
    
    public init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }
    
    public var body: some View {
        let pages: [OnboardingPage] = [
            OnboardingPage(
                title: NSLocalizedString("Welcome to Space Station Passes", bundle: .module, comment: "Onboarding page 1 title"),
                description: NSLocalizedString("Track the International Space Station, Tiangong and others as they pass overhead. Never miss a spectacular sight in the evening sky.", bundle: .module, comment: "Onboarding page 1 description"),
                videoName: "iss_pass_compilation",
                videoExtension: "mov"
            ),
            OnboardingPage(
                title: NSLocalizedString("Predictions for You", bundle: .module, comment: "Onboarding page 2 title"),
                description: NSLocalizedString("Get accurate pass predictions for your location. We'll notify you when viewing opportunities arise.", bundle: .module, comment: "Onboarding page 2 description"),
                videoName: "pass_demo",
                videoExtension: "mov",
                customView: { geometry in
                    AnyView(
                        VStack {
                            FlippingCityText()
                                .padding(.top, geometry.safeAreaInsets.top + 60)
                            Spacer()
                        }
                    )
                }
            ),
        ]
        
        return TabView(selection: $currentPage) {
            ForEach(0..<pages.count, id: \.self) { index in
                OnboardingPageView(
                    page: pages[index],
                    isLastPage: index == pages.count - 1,
                    onComplete: onComplete,
                    videoPlaybackTimes: $videoPlaybackTimes
                )
                .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
        .background(Color.black)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all)
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    let isLastPage: Bool
    let onComplete: () -> Void
    @Binding var videoPlaybackTimes: [String: CMTime]
    
    @State private var player: AVPlayer?
    @State private var timeObserver: Any?
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                // Background video or gradient
                if !page.videoName.isEmpty,
                   let videoURL = Bundle.module.url(forResource: page.videoName, withExtension: page.videoExtension) {
                    VideoPlayer(player: player)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .offset(y: -40)
                        .ignoresSafeArea(.all)
                        .clipped()
                        .onAppear {
                            setupPlayer(with: videoURL)
                        }
                        .onDisappear {
                            saveCurrentPlaybackTime()
                            player?.pause()
                            removeTimeObserver()
                        }
                } else {
                    // Fallback gradient background
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black,
                            Color.blue.opacity(0.3),
                            Color.black
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea(.all)
                }
                
                // Custom view overlay (if present)
                if let customView = page.customView {
                    customView(geometry)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .ignoresSafeArea(.all)
                        .clipped()
                }
                
                // Linear gradient overlay for better text readability
                LinearGradient(
                    gradient: Gradient(stops: [
                        Gradient.Stop(color: Color.clear, location: 0.0),
                        Gradient.Stop(color: Color.clear, location: 0.7),
                        Gradient.Stop(color: Color.black.opacity(0.5), location: 0.75),
                        Gradient.Stop(color: Color.black.opacity(0.5), location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.all)
            }
            
            // Content overlay
            VStack(spacing: 0) {
                Spacer()
                
                // Bottom text area
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(page.title)
                            .font(.title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.leading)
                        
                        Text(page.description)
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color(UIColor.secondaryLabel))
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 32)
                    
                    if isLastPage {
                            Button(action: onComplete) {
                                HStack {
                                    Text("Get Started", bundle: .module)
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    
                                    Image(systemName: "arrow.right")
                                        .font(.headline)
                                }
                                .foregroundColor(.black)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 16)
                                .background(Color.white)
                                .cornerRadius(25)
                            }
                            .padding(.top, 8)
                    } else {
                        HStack {
                            Text("Swipe to continue", bundle: .module)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 32)
                    }
                }
                .padding(.bottom, 48)
            }
        }.ignoresSafeArea()
    }
    
    private func setupPlayer(with videoURL: URL) {
        player = AVPlayer(url: videoURL)
        player?.isMuted = true
        
        // Restore previous playback time if available
        let videoKey = page.videoName
        if let savedTime = videoPlaybackTimes[videoKey] {
            player?.seek(to: savedTime)
        }
        
        player?.play()
        
        // Setup time observer to periodically save playback progress
        setupTimeObserver()
        
        // Loop the video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { _ in
            // Reset the saved time when video completes and loops
            videoPlaybackTimes[videoKey] = CMTime.zero
            player?.seek(to: .zero)
            player?.play()
        }
    }
    
    private func setupTimeObserver() {
        guard let player = player else { return }
        
        // Update playback time every 0.5 seconds
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            let videoKey = page.videoName
            videoPlaybackTimes[videoKey] = time
        }
    }
    
    private func removeTimeObserver() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
    }
    
    private func saveCurrentPlaybackTime() {
        guard let player = player else { return }
        let videoKey = page.videoName
        videoPlaybackTimes[videoKey] = player.currentTime()
    }
    
    private var currentPageIndex: Int {
        if page.videoName == "iss_pass_compilation" { return 0 }
        if page.videoName == "solar_transit" { return 1 }
        return 2
    }
}

#if DEBUG
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(onComplete: {})
    }
}
#endif
