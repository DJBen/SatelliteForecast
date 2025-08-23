//
//  TutorialVideoView.swift
//  SatelliteForecast
//
//  Created by AI on 8/21/25.
//

import SwiftUI
import AVKit
import AVFoundation

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
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VideoPlayerReader { proxy in
            TutorialVideoPlayerView(
                videoName: "sky_chart_tutorial",
                onVideoFinished: {
                    hasVideoFinished = true
                    overlayText = "Learn how to use the sky chart to track satellites in real time!"
                }
            )
            .overlay(alignment: .topLeading) {
                // Dismiss button (X) at top left
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .padding(16)
            }
            .overlay(alignment: .bottom) {
                // Bottom overlay with text and rewatch button
                if hasVideoFinished {
                    VStack(spacing: 16) {
                        if let overlayText = overlayText {
                            Text(overlayText)
                                .font(.headline)
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
                                    Text("Rewatch")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }

                            Button {
                                onDismiss()
                            } label: {
                                Text("Got it!")
                                    .font(.headline)
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.white)
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
    }
}

private struct TutorialVideoPlayerView: UIViewRepresentable {
    let videoName: String
    let onVideoFinished: () -> Void
    @EnvironmentObject private var proxy: VideoPlayerProxy

    func makeUIView(context: Context) -> UIView {
        let uiView = TutorialVideoPlayerUIView(videoName: videoName, onVideoFinished: onVideoFinished)
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
    
    init(videoName: String, onVideoFinished: @escaping () -> Void) {
        self.videoName = videoName
        self.onVideoFinished = onVideoFinished
        super.init(frame: .zero)

        setupVideoPlayer(videoName: videoName)
        setupNotifications()
        setupcaptionTextLabel()
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
    
    private func setupcaptionTextLabel() {
        // Create the dummy text label
        captionTextLabel = UILabel()
        captionTextLabel?.text = NSLocalizedString("Lift up your device towards the sky", bundle: .module, comment: "Text shown when the tutorial video is playing")
        captionTextLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        captionTextLabel?.textColor = .white
        captionTextLabel?.textAlignment = .center
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
                label.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -32),
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
            
            if currentSeconds >= 0.0 && currentSeconds <= 3.0 {
                self?.showCaptionText()
            } else {
                self?.hideCaptionText()
            }
        }
    }
    
    private func showCaptionText() {
        guard let label = captionTextLabel, label.alpha == 0 else { return }

        UIView.animate(withDuration: 0.3) {
            label.alpha = 1.0
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
