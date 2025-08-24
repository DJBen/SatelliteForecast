//
//  TutorialVideoView.swift
//  SatelliteForecast
//
//  Created by AI on 8/21/25.
//

import SwiftUI
import AVKit
import AVFoundation

// MARK: - Caption Model

struct VideoCaption {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let attributedText: AttributedString
    
    init(startTime: TimeInterval, endTime: TimeInterval, text: String) {
        self.startTime = startTime
        self.endTime = endTime
        
        var attributedString = AttributedString(text)
        // Use UIFont instead of SwiftUI Font for proper UILabel compatibility
        attributedString.uiKit.font = UIFont.preferredFont(forTextStyle: .title1)
        attributedString.uiKit.foregroundColor = UIColor.white

        self.attributedText = attributedString
    }
    
    init(startTime: TimeInterval, endTime: TimeInterval, attributedText: AttributedString) {
        self.startTime = startTime
        self.endTime = endTime
        self.attributedText = attributedText
    }
    
    func isActive(at time: TimeInterval) -> Bool {
        return time >= startTime && time <= endTime
    }
}

// MARK: - VideoPlayerProxy

class VideoPlayerProxy: ObservableObject {
    private var restartVideoAction: (() -> Void)?
    
    func setRestartAction(_ action: @escaping () -> Void) {
        restartVideoAction = action
    }
    
    func restartVideo() {
        restartVideoAction?()
    }
}

struct VideoPlayerReader<Content: View>: View {
    let content: (VideoPlayerProxy) -> Content
    @StateObject private var proxy = VideoPlayerProxy()
    
    init(@ViewBuilder content: @escaping (VideoPlayerProxy) -> Content) {
        self.content = content
    }
    
    var body: some View {
        content(proxy)
            .environmentObject(proxy)
    }
}

struct TutorialVideoView: View {
    let onDismiss: () -> Void
    
    @State private var hasVideoFinished = false
    @State private var overlayText: String?

    var body: some View {
        VideoPlayerReader { proxy in
            TutorialVideoPlayerView(
                videoName: "sky_chart_tutorial",
                onVideoFinished: {
                    hasVideoFinished = true
                    overlayText = NSLocalizedString(
                        "At the time of the pass, the space station will be visible as a bright dot in the sky.",
                        bundle: .module,
                        comment: "Video caption final text"
                    )
                },
                captions: [
                    VideoCaption(
                        startTime: 0.0,
                        endTime: 4.0,
                        text: NSLocalizedString(
                            "Lift up your device towards the sky", 
                            bundle: .module,
                            comment: "Video caption text #1"
                        )
                    ),
                    VideoCaption(
                        startTime: 4.5,
                        endTime: 9,
                        text: NSLocalizedString(
                            "Sky chart points north, showing the path of space station pass", 
                            bundle: .module,
                            comment: "Video caption text #2"
                        )
                    )
                ]
            )
            .overlay {
                // Satellite animation overlay
                if hasVideoFinished {
                    SatelliteAnimationView()
                }
            }
            .overlay(alignment: .bottom) {
                // Bottom overlay with text and rewatch button
                if hasVideoFinished {
                    VStack(spacing: 16) {
                        if let overlayText = overlayText {
                            Text(overlayText)
                                .font(.title)
                                .minimumScaleFactor(0.75)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }

                        HStack(spacing: 24) {
                            Button {
                                hasVideoFinished = false
                                overlayText = nil
                                proxy.restartVideo()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Rewatch", bundle: .module, comment: "As in, 'rewatch' a video")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.secondary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }

                            Button {
                                onDismiss()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark")
                                    Text("Got it!", bundle: .module, comment: "Text of button to dismiss a tutorial video")
                                }
                                .font(.headline)
                                .foregroundColor(.black)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(.bottom, 40)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.easeInOut(duration: 0.3), value: hasVideoFinished)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)
                }
            }
        }
    }
}

// MARK: - Satellite Animation View

struct SatelliteAnimationView: View {
    @State private var animationProgress: CGFloat = 0.0001
    private let animationDuration: CGFloat = 10.0
    
    private let timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            let arcHeight = screenHeight * 0.1
            
            // Create arc path from left to right
            let path = Path { path in
                let startPoint = CGPoint(x: -10, y: screenHeight * 0.2)
                let endPoint = CGPoint(x: screenWidth + 10, y: screenHeight * 0.2)
                let controlPoint = CGPoint(x: screenWidth * 0.5, y: screenHeight * 0.2 - arcHeight)
                
                path.move(to: startPoint)
                path.addQuadCurve(to: endPoint, control: controlPoint)
            }
            
            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)
                .position(path.trimmedPath(from: 0, to: animationProgress).currentPoint!)
                .onReceive(timer) { _ in
                    if animationProgress < 1.0 {
                        withAnimation(.smooth(duration: 0.02)) {
                            animationProgress += 0.02 / animationDuration
                        }
                    }
                }
                .onAppear {
                    animationProgress = 0.0001
                }
        }
    }
}

private struct TutorialVideoPlayerView: UIViewRepresentable {
    let videoName: String
    let onVideoFinished: () -> Void
    let captions: [VideoCaption]
    @EnvironmentObject private var proxy: VideoPlayerProxy

    init(videoName: String, onVideoFinished: @escaping () -> Void, captions: [VideoCaption] = []) {
        self.videoName = videoName
        self.onVideoFinished = onVideoFinished
        self.captions = captions
    }

    func makeUIView(context: Context) -> UIView {
        let uiView = TutorialVideoPlayerUIView(
            videoName: videoName, 
            onVideoFinished: onVideoFinished,
            captions: captions
        )
        proxy.setRestartAction {
            uiView.restartVideo()
        }
        return uiView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let view = uiView as? TutorialVideoPlayerUIView else {
            return
        }
    }
}

private class TutorialVideoPlayerUIView: UIView {
    let videoName: String
    private var playerLayer: AVPlayerLayer?
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private let onVideoFinished: () -> Void
    private var hasNotifiedFinish = false
    private var captionTextLabel: UILabel?
    private var timeObserver: Any?
    private let captions: [VideoCaption]
    private var currentCaptionIndex: Int = -1
    
    init(videoName: String, onVideoFinished: @escaping () -> Void, captions: [VideoCaption] = []) {
        self.videoName = videoName
        self.onVideoFinished = onVideoFinished
        self.captions = captions
        super.init(frame: .zero)

        setupVideoPlayer(videoName: videoName)
        setupNotifications()
        setupCaptionTextLabel()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    private func setupCaptionTextLabel() {
        // Create the caption text label
        captionTextLabel = UILabel()
        captionTextLabel?.textAlignment = .natural
        captionTextLabel?.layer.cornerRadius = 8
        captionTextLabel?.clipsToBounds = true
        captionTextLabel?.numberOfLines = 0
        captionTextLabel?.translatesAutoresizingMaskIntoConstraints = false
        captionTextLabel?.alpha = 0 // Initially hidden

        if let label = captionTextLabel {
            addSubview(label)
            
            // Center the label on screen
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: centerXAnchor),
                label.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -80),
                label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
                label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20)
            ])
        }
    }
    
    @objc private func playerDidFinishPlaying() {
        if !hasNotifiedFinish {
            hasNotifiedFinish = true
            DispatchQueue.main.async {
                self.onVideoFinished()
            }
        }
    }
    
    @objc private func applicationDidEnterBackground() {
        player?.pause()
    }
    
    @objc private func applicationWillEnterForeground() {
        player?.play()
    }
    
    private func setupVideoPlayer(videoName: String) {
        guard let videoURL = Bundle.module.url(forResource: videoName, withExtension: "mov") else {
            print("Could not find video file: \(videoName).mov")
            return
        }
        
        // Create player item
        playerItem = AVPlayerItem(url: videoURL)
        
        // Create regular player (not queue player, since we don't want looping)
        player = AVPlayer(playerItem: playerItem)
        
        // Create and configure player layer
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspect
        playerLayer?.frame = bounds
        
        if let playerLayer = playerLayer {
            layer.addSublayer(playerLayer)
        }
        
        // Configure audio session to not interrupt other audio
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        } catch {
            print("Failed to set audio session category: \(error)")
        }
        
        player?.play()
        
        // Add time observer to show/hide dummy text
        setupTimeObserver()
    }
    
    private func setupTimeObserver() {
        guard let player = player else { return }
        
        // Create time observer to monitor playback time
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            let currentSeconds = CMTimeGetSeconds(time)
            self?.updateCaptionForTime(currentSeconds)
        }
    }
    
    private func updateCaptionForTime(_ currentTime: TimeInterval) {
        // Find the active caption for the current time
        let activeCaptionIndex = captions.firstIndex { $0.isActive(at: currentTime) }
        
        // If the active caption has changed
        if activeCaptionIndex != currentCaptionIndex {
            currentCaptionIndex = activeCaptionIndex ?? -1
            
            if let index = activeCaptionIndex {
                // Show the new caption
                showCaption(captions[index])
            } else {
                // Hide caption if no active caption
                hideCaptionText()
            }
        }
    }
    
    private func showCaption(_ caption: VideoCaption) {
        guard let label = captionTextLabel else { return }
        
        // Convert AttributedString to NSAttributedString for UILabel
        label.attributedText = NSAttributedString(caption.attributedText)
        
        // Animate in if not already visible
        if label.alpha == 0 {
            UIView.animate(withDuration: 0.3) {
                label.alpha = 1.0
            }
        }
    }
    
    private func hideCaptionText() {
        guard let label = captionTextLabel, label.alpha > 0 else { return }

        UIView.animate(withDuration: 0.3) {
            label.alpha = 0.0
        }
    }
    
    func restartVideo() {
        hasNotifiedFinish = false
        currentCaptionIndex = -1 // Reset caption state
        hideCaptionText() // Hide text immediately when restarting
        player?.seek(to: .zero)
        player?.play()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        player?.pause()
        playerLayer?.removeFromSuperlayer()
    }
}
