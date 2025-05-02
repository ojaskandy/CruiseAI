import Foundation
import UIKit
import AVKit
import AVFoundation

class BackgroundManager: NSObject {
    static let shared = BackgroundManager()
    
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var pipController: AVPictureInPictureController?
    private var audioSession: AVAudioSession?
    private var backgroundTimer: DispatchSourceTimer?
    
    // Background state tracking
    private(set) var isBackgroundSessionActive = false
    private var processingInterval: TimeInterval = 0.033 // Process at ~30fps (same as foreground)
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    // MARK: - Background Task Management
    
    func startBackgroundSession() {
        guard !isBackgroundSessionActive else { return }
        
        // Register background task
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundSession()
        }
        
        // Configure audio session for background
        try? audioSession?.setActive(true)
        
        // Start background timer for full-speed processing
        startBackgroundTimer()
        
        isBackgroundSessionActive = true
        print("Background session started at full processing speed")
    }
    
    func endBackgroundSession() {
        guard isBackgroundSessionActive else { return }
        
        // Stop background timer
        backgroundTimer?.cancel()
        backgroundTimer = nil
        
        // End background task if valid
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        
        // Deactivate audio session
        try? audioSession?.setActive(false)
        
        isBackgroundSessionActive = false
        print("Background session ended")
    }
    
    // MARK: - Picture in Picture Setup
    
    func setupPictureInPicture(with playerLayer: AVPlayerLayer) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            print("PiP not supported on this device")
            return
        }
        
        pipController = AVPictureInPictureController(playerLayer: playerLayer)
        pipController?.delegate = self
    }
    
    func startPictureInPicture() {
        pipController?.startPictureInPicture()
    }
    
    func stopPictureInPicture() {
        pipController?.stopPictureInPicture()
    }
    
    // MARK: - Private Helpers
    
    private func setupAudioSession() {
        audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession?.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession?.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func startBackgroundTimer() {
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .userInitiated))
        timer.schedule(deadline: .now(), repeating: processingInterval)
        
        timer.setEventHandler { [weak self] in
            // Notify observers that it's time to process
            NotificationCenter.default.post(name: .backgroundProcessingTick, object: nil)
        }
        
        timer.resume()
        backgroundTimer = timer
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension BackgroundManager: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("PiP will start")
    }
    
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("PiP started")
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        print("PiP failed to start: \(error)")
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let backgroundProcessingTick = Notification.Name("backgroundProcessingTick")
} 