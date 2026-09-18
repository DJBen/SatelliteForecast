//
//  OnboardingView.swift
//  SatelliteForecast
//
//  Created by Copilot on 7/22/25.
//

import SwiftUI
import AVKit
import AVFoundation

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
    let session: AppSession
    
    public init(session: AppSession, initialPage: Int = 0, onComplete: @escaping () -> Void) {
        self.session = session
        self.onComplete = onComplete
        _currentPage = State(initialValue: min(max(initialPage, 0), 1))
    }
    
    public var body: some View {
        let isReplayActive = currentPage == 1
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
                videoName: "",
                videoExtension: "",
                customView: { geometry in
                    AnyView(
                        OnboardingPassAnimation(session: session, isActive: isReplayActive)
                            .frame(height: geometry.size.height * 0.58)
                            .padding(.horizontal, 24)
                            .padding(.top, geometry.safeAreaInsets.top + 48)
                            .frame(maxHeight: .infinity, alignment: .top)
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
                    onContinue: {
                        withAnimation {
                            currentPage = min(index + 1, pages.count - 1)
                        }
                    },
                    videoPlaybackTimes: $videoPlaybackTimes
                )
                .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
        .analyticsScreen(.onboarding)
        .onChange(of: currentPage, initial: true) { _, page in
            AppAnalytics.event("onboarding_step", screen: .onboarding, parameters: ["step": page + 1])
        }
        .modifier(CompactHeightLayout())
        .background(Color.black)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all)
    }
}

private struct OnboardingPageView: View {
    @Environment(\.compactHeightLayout) private var compactHeight
    let page: OnboardingPage
    let isLastPage: Bool
    let onComplete: () -> Void
    let onContinue: () -> Void
    @Binding var videoPlaybackTimes: [String: CMTime]
    
    @State private var player: AVPlayer?
    @State private var timeObserver: Any?
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                // Background video or gradient
                if !page.videoName.isEmpty,
                   let videoURL = Bundle.module.url(forResource: page.videoName, withExtension: page.videoExtension) {
                    if SnapshotEnvironment.isEnabled {
                        Image(uiImage: SnapshotEnvironment.videoFrame(url: videoURL) ?? UIImage())
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    } else {
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
                
                // Linear gradient overlay for better text readability
                LinearGradient(
                    gradient: Gradient(stops: [
                        Gradient.Stop(color: Color.clear, location: 0.0),
                        Gradient.Stop(color: Color.black.opacity(0.10), location: 0.35),
                        Gradient.Stop(color: Color.black.opacity(0.88), location: 0.75),
                        Gradient.Stop(color: Color.black.opacity(0.88), location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.all)
                // Custom view overlay (if present)
                if let customView = page.customView {
                    customView(geometry)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .ignoresSafeArea(.all)
                        .clipped()
                }

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
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 32)
                    
                    Button(action: isLastPage ? onComplete : onContinue) {
                        HStack {
                            Text(isLastPage ? "Get Started" : "Continue", bundle: .module)
                            if isLastPage {
                                Image(systemName: "arrow.right")
                            }
                        }
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, compactHeight ? 0 : 8)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .foregroundStyle(.white)
                    .environment(\.colorScheme, .dark)
                    .padding(.horizontal, 32)
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
