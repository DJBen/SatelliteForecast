//
//  AutoPlayVideoView.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 7/22/25.
//

import SwiftUI
import AVKit
import AVFoundation

struct AutoPlayVideoView: UIViewRepresentable {
    let videoName: String
    let bundle: Bundle
    
    init(videoName: String, bundle: Bundle = .module) {
        self.videoName = videoName
        self.bundle = bundle
    }
    
    func makeUIView(context: Context) -> UIView {
        return VideoPlayerUIView(videoName: videoName, bundle: bundle)
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No updates needed for static video content
    }
}

private class VideoPlayerUIView: UIView {
    private var playerLayer: AVPlayerLayer?
    private var player: AVPlayer?
    private var playerLooper: AVPlayerLooper?
    private var playerItem: AVPlayerItem?
    private var isVisible = false
    
    init(videoName: String, bundle: Bundle) {
        super.init(frame: .zero)
        setupVideoPlayer(videoName: videoName, bundle: bundle)
        setupNotifications()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupNotifications() {
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
    
    @objc private func applicationDidEnterBackground() {
        player?.pause()
    }
    
    @objc private func applicationWillEnterForeground() {
        if isVisible {
            player?.play()
        }
    }
    
    private func setupVideoPlayer(videoName: String, bundle: Bundle) {
        guard let videoURL = bundle.url(forResource: videoName, withExtension: "mp4") else {
            print("Could not find video file: \(videoName).mp4")
            return
        }
        
        // Create player item
        playerItem = AVPlayerItem(url: videoURL)
        
        // Create queue player for looping
        let queuePlayer = AVQueuePlayer()
        player = queuePlayer
        
        // Create player looper for seamless looping
        if let playerItem = playerItem {
            playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
        }
        
        // Create and configure player layer
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspectFill
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
        
        // Start playing
        player?.isMuted = true // Mute the video
        player?.play()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        player?.pause()
        playerLooper?.disableLooping()
        playerLayer?.removeFromSuperlayer()
    }
}

// MARK: - Lifecycle management
extension VideoPlayerUIView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        isVisible = window != nil
        if isVisible {
            player?.play()
        } else {
            player?.pause()
        }
    }
}
