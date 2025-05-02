//
//  SoundManager.swift
//  CruiseAIios
//
//  Created by Ojas Kandhare on 4/10/25.
//

import Foundation
import AVFoundation
import UIKit

class SoundManager {
    // Singleton instance
    static let shared = SoundManager()
    
    // Audio players
    private var personSound: AVAudioPlayer?
    private var bikeSound: AVAudioPlayer?
    private var trafficLightSound: AVAudioPlayer?
    private var stopSignSound: AVAudioPlayer?
    
    // Audio session
    private var audioSession: AVAudioSession {
        return AVAudioSession.sharedInstance()
    }
    
    // Cooldown tracking
    private var lastPlayedTimes: [String: Date] = [:]
    private let cooldownTime: TimeInterval = 3.0 // 3 seconds between same object sounds
    
    private init() {
        setupAudioSession()
        loadSounds()
    }
    
    private func setupAudioSession() {
        do {
            // Configure audio session to play even when device is in silent mode
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers, .mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("⚠️ Failed to set up audio session: \(error.localizedDescription)")
        }
    }
    
    private func loadSounds() {
        // Create URLs for the embedded sound files
        if let personURL = createSoundFileURL(for: "person_sound") {
            createSoundPlayer(from: personURL, player: &personSound)
        }
        
        if let bikeURL = createSoundFileURL(for: "bike_sound") {
            createSoundPlayer(from: bikeURL, player: &bikeSound)
        }
        
        if let trafficLightURL = createSoundFileURL(for: "traffic_light_sound") {
            createSoundPlayer(from: trafficLightURL, player: &trafficLightSound)
        }
        
        if let stopSignURL = createSoundFileURL(for: "stop_sign_sound") {
            createSoundPlayer(from: stopSignURL, player: &stopSignSound)
        }
    }
    
    private func createSoundFileURL(for name: String) -> URL? {
        // Check if sound file exists in the bundle
        if let url = Bundle.main.url(forResource: name, withExtension: "wav") {
            return url
        }
        
        // If not in bundle, create the sound file in documents directory for this session
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let soundURL = docsDir.appendingPathComponent("\(name).wav")
        
        // Only create if it doesn't exist yet
        if !FileManager.default.fileExists(atPath: soundURL.path) {
            // Create a simple sound file using AudioToolbox's system sounds as a fallback
            // In a real app, we'd embed actual wav files in the bundle
            createDefaultSoundFile(at: soundURL)
        }
        
        return soundURL
    }
    
    private func createDefaultSoundFile(at url: URL) {
        // Create soothing instrumental sounds for each object type
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        
        do {
            let audioFile = try AVAudioFile(forWriting: url, settings: settings)
            let format = AVAudioFormat(settings: settings)!
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(44100))!
            
            // Get the filename to determine which tone to create
            let filename = url.lastPathComponent
            
            // Generate a unique tone based on the type of object
            let sampleRate = format.sampleRate
            var duration: Double = 0.5 // default half second
            var frequency: Double = 440.0 // default A4 note
            var waveType = "sine" // default sine wave
            
            // Create a unique soothing sound for each object type
            if filename.contains("person") {
                // Person - gentle harp-like sound (higher frequency sine wave)
                frequency = 698.46 // F5 note
                duration = 0.6
                waveType = "sine"
            } else if filename.contains("bike") {
                // Bike - more complex bell-like sound (mid-range triangle wave)
                frequency = 587.33 // D5 note
                duration = 0.5
                waveType = "triangle"
            } else if filename.contains("traffic_light") {
                // Traffic light - soft chime (mid-low frequency with sine wave)
                frequency = 523.25 // C5 note
                duration = 0.7
                waveType = "sine"
            } else if filename.contains("stop_sign") {
                // Stop sign - attention-grabbing but not harsh (lower frequency with smooth square wave)
                frequency = 440.0 // A4 note
                duration = 0.8
                waveType = "square"
            }
            
            // Fill the buffer with the appropriate tone
            let frameCount = Int(duration * sampleRate)
            for i in 0..<frameCount {
                let value = simpleTone(for: i, sampleRate: sampleRate, frequency: frequency, waveType: waveType)
                
                // Apply envelope for smoother sound (attack and decay)
                let envelope = calculateEnvelope(position: Double(i) / Double(frameCount), duration: duration)
                
                // Apply the envelope to the tone
                let envelopedValue = value * envelope
                
                buffer.floatChannelData?[0][i] = envelopedValue
                buffer.floatChannelData?[1][i] = envelopedValue
                buffer.frameLength = AVAudioFrameCount(i + 1)
            }
            
            try audioFile.write(from: buffer)
            print("Created instrumental sound file at: \(url.path)")
        } catch {
            print("Failed to create sound file: \(error)")
        }
    }
    
    private func calculateEnvelope(position: Double, duration: Double) -> Float {
        // Create an ADSR (Attack, Decay, Sustain, Release) envelope
        let attackPct = 0.1 // 10% of sound is attack
        let decayPct = 0.1 // 10% of sound is decay
        let sustainLevel = 0.7 // 70% volume for sustain
        let releasePct = 0.3 // 30% of sound is release
        
        if position < attackPct {
            // Attack phase - linear ramp up from 0 to 1
            return Float(position / attackPct)
        } else if position < (attackPct + decayPct) {
            // Decay phase - exponential decay from 1 to sustainLevel
            let decayPosition = (position - attackPct) / decayPct
            return Float(1.0 - (1.0 - sustainLevel) * decayPosition)
        } else if position < (1.0 - releasePct) {
            // Sustain phase - constant level
            return Float(sustainLevel)
        } else {
            // Release phase - exponential decay from sustainLevel to 0
            let releasePosition = (position - (1.0 - releasePct)) / releasePct
            return Float(sustainLevel * (1.0 - releasePosition))
        }
    }
    
    private func simpleTone(for sample: Int, sampleRate: Double, frequency: Double, waveType: String) -> Float {
        let period = sampleRate / frequency
        let phase = Double(sample) / period
        
        switch waveType {
        case "sine":
            return Float(sin(2.0 * .pi * phase))
        case "square":
            return phase.truncatingRemainder(dividingBy: 1.0) < 0.5 ? 0.8 : -0.8
        case "sawtooth":
            return Float(2.0 * (phase.truncatingRemainder(dividingBy: 1.0)) - 1.0)
        case "triangle":
            let value = phase.truncatingRemainder(dividingBy: 1.0)
            return Float(value < 0.5 ? 4.0 * value - 1.0 : 3.0 - 4.0 * value)
        default:
            return Float(sin(2.0 * .pi * phase))
        }
    }
    
    private func createSoundPlayer(from url: URL, player: inout AVAudioPlayer?) {
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.volume = 0.7 // 70% volume
        } catch {
            print("⚠️ Failed to create audio player: \(error.localizedDescription)")
        }
    }
    
    // Public methods to play sounds based on detected object type
    func playSoundForObject(_ objectType: String) {
        // Check cooldown
        let currentTime = Date()
        if let lastPlayed = lastPlayedTimes[objectType], 
           currentTime.timeIntervalSince(lastPlayed) < cooldownTime {
            // Still in cooldown period, don't play
            return
        }
        
        // Update last played time
        lastPlayedTimes[objectType] = currentTime
        
        // Choose and play the appropriate sound
        switch objectType.lowercased() {
        case "person":
            playSound(personSound, type: "person")
        case "bicycle", "motorcycle", "bike":
            playSound(bikeSound, type: "bike")
        case "traffic light":
            playSound(trafficLightSound, type: "traffic light")
        case "stop sign":
            playSound(stopSignSound, type: "stop sign")
            // Also vibrate for stop signs
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        default:
            // Unknown object type
            print("No sound configured for object type: \(objectType)")
        }
    }
    
    private func playSound(_ player: AVAudioPlayer?, type: String) {
        guard let player = player else {
            print("⚠️ No sound player available for \(type)")
            return
        }
        
        if player.isPlaying {
            player.stop()
        }
        
        player.currentTime = 0
        player.play()
        
        print("🔊 Playing sound for: \(type)")
    }
    
    // Preload and precache sounds to reduce latency
    func precacheSounds() {
        personSound?.prepareToPlay()
        bikeSound?.prepareToPlay()
        trafficLightSound?.prepareToPlay()
        stopSignSound?.prepareToPlay()
    }
} 