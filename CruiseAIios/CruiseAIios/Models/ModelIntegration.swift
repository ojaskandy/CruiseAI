//
//  ModelIntegration.swift
//  CruiseAIios
//
//  Created by Ojas Kandhare on 4/2/25.
//

import Foundation
import AVFoundation
import UIKit
import SwiftUI
import Vision
import AudioToolbox
import CoreML
import CoreImage

class ModelIntegration: ObservableObject {
    // MARK: - Properties
    
    @Published var detectedObjects: [DetectedObject] = []
    @Published var depthMapImage: UIImage?
    @Published var isProcessing = false
    @Published var averageDistanceToObjects: [String: Float] = [:]
    @Published var lastProcessedImage: UIImage?
    @Published var processingEnabled = true
    
    let objectDetectionManager: ObjectDetectionManager? = ObjectDetectionManager() // Made optional and public for sign tracking reset
    private let depthEstimationManager = DepthEstimationManager()
    
    // Processing queue to avoid blocking the main thread
    private let processingQueue = DispatchQueue(label: "com.cruiseai.modelProcessing", qos: .userInitiated)
    
    // Frame processing rate control
    private var lastProcessingTime = Date()
    private let processingInterval: TimeInterval = 0.016 // Process frames every ~16ms (60fps) for real-time detection
    
    // Object detection model
    private var visionModel: VNCoreMLModel?
    private var visionRequest: VNCoreMLRequest?
    
    // Object detection results
    var lastProcessedImageBuffer: CVPixelBuffer?
    
    // Minimum confidence threshold for detection
    private let confidenceThreshold: Float = 0.2  // Lowered to detect more objects at distance
    
    // Audio players for sounds that work even in silent mode
    private var stopSignPlayer: AVAudioPlayer?
    private var personPlayer: AVAudioPlayer?
    private var vehiclePlayer: AVAudioPlayer?
    private var bikePlayer: AVAudioPlayer?
    private var trafficLightPlayer: AVAudioPlayer?
    
    // Legacy SystemSoundIDs for fallback and vibration
    private let stopSignSound: SystemSoundID = 1304
    private let personSound: SystemSoundID = 1306
    private let vehicleSound: SystemSoundID = 1307
    private let bikeSound: SystemSoundID = 1309
    private let trafficLightSound: SystemSoundID = 1310
    
    // Speech synthesis
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    // Last alert time to avoid too frequent alerts
    private var lastAlertTimes: [String: Date] = [:]
    private let alertCooldown: TimeInterval = 1.5  // Reduced cooldown between alerts
    
    // Audio session
    private var audioSession: AVAudioSession {
        return AVAudioSession.sharedInstance()
    }
    
    // MARK: - Initialization
    
    init() {
        print("ModelIntegration initialized")
        setupAudioSession()
        setupAudioPlayers()
        setupVisionModel()
    }
    
    private func setupAudioSession() {
        do {
            // Configure audio session to play even in silent mode
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true)
            print("Audio session configured for playback even in silent mode")
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
    }
    
    private func setupAudioPlayers() {
        // Load sound files from app bundle
        // Note: These sound files need to be added to the project assets
        loadSoundPlayer(named: "stop_sign_alert.wav", player: &stopSignPlayer)
        loadSoundPlayer(named: "person_alert.wav", player: &personPlayer)
        loadSoundPlayer(named: "vehicle_alert.wav", player: &vehiclePlayer)
        loadSoundPlayer(named: "bike_alert.wav", player: &bikePlayer)
        loadSoundPlayer(named: "traffic_light_alert.wav", player: &trafficLightPlayer)
        
        // If sound files aren't available yet, create them
        createDefaultSoundsIfNeeded()
    }
    
    private func loadSoundPlayer(named filename: String, player: inout AVAudioPlayer?) {
        guard let soundURL = Bundle.main.url(forResource: filename.split(separator: ".").first?.description, withExtension: filename.split(separator: ".").last?.description) else {
            print("Sound file \(filename) not found in bundle")
            return
        }
        
        do {
            player = try AVAudioPlayer(contentsOf: soundURL)
            player?.prepareToPlay()
            player?.volume = 1.0
            print("Successfully loaded sound: \(filename)")
        } catch {
            print("Failed to load sound \(filename): \(error.localizedDescription)")
        }
    }
    
    // Create default sound files if needed (for testing purposes)
    private func createDefaultSoundsIfNeeded() {
        // This is a fallback to ensure sounds work even if files aren't bundled
        // For production, sound files should be properly included in the app bundle
        
        // We'll use the pre-existing system sounds as fallbacks
        if stopSignPlayer == nil || personPlayer == nil || vehiclePlayer == nil || 
           bikePlayer == nil || trafficLightPlayer == nil {
            print("Using system sounds as fallbacks")
        }
    }
    
    private func setupVisionModel() {
        print("ModelIntegration: Setting up Vision model for YOLOv3TinyFP16 object detection")
        
        do {
            // Load YOLOv3TinyFP16 model
            guard let modelURL = Bundle.main.url(forResource: "YOLOv3TinyFP16", withExtension: "mlmodelc") else {
                print("⚠️ ModelIntegration: Failed to find YOLOv3TinyFP16 model in bundle")
                return
            }
            
            // Create Vision model
            visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
            
            // Create request
            visionRequest = VNCoreMLRequest(model: visionModel!) { [weak self] request, error in
                self?.processDetections(for: request, error: error)
            }
            
            // Configure request
            visionRequest?.imageCropAndScaleOption = .scaleFill
            
            print("ModelIntegration: Successfully set up Vision model for YOLO object detection")
        } catch {
            print("⚠️ ModelIntegration: Failed to load Vision ML model: \(error)")
        }
    }
    
    // MARK: - Public Methods
    
    public func processFrame(_ pixelBuffer: CVPixelBuffer) {
        // Skip processing if we're already processing or it's disabled
        guard !isProcessing && processingEnabled else { return }
        
        // Limit processing frequency to avoid overwhelming the device
        let now = Date()
        let timeSinceLastProcess = now.timeIntervalSince(lastProcessingTime) 
        if timeSinceLastProcess < processingInterval {
            return 
        }
        
        // Mark as processing
        isProcessing = true
        lastProcessingTime = now
        
        // Store a copy of the pixel buffer for debugging
        if lastProcessedImage == nil || lastProcessingTime.timeIntervalSince1970.truncatingRemainder(dividingBy: 5) < 0.1 {
            // Update the reference image every ~5 seconds
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext(options: nil)
            if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                self.lastProcessedImage = UIImage(cgImage: cgImage)
                print("Updated frame captured for detection")
            }
        }
        
        // Store reference to the current frame
        lastProcessedImageBuffer = pixelBuffer
        
        // Process frames on background queue
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Perform object detection using YOLO
            if let request = self.visionRequest {
                do {
                    // Create a request handler for the current frame
                    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
                    
                    // Process the image with the YOLO model
                    try handler.perform([request])
                } catch {
                    print("⚠️ Error performing YOLO detection: \(error)")
                }
            } else {
                print("⚠️ Vision request not configured")
            }
            
            // Process depth estimation if available
            self.depthEstimationManager.estimateDepth(from: pixelBuffer) { depthMap in
                if let depthMap = depthMap {
                DispatchQueue.main.async {
                        self.depthMapImage = self.depthEstimationManager.visualizeDepthMap(depthMap)
                        
                        // Calculate distances to detected objects if we have both depth map and objects
                        if !self.detectedObjects.isEmpty {
                            var distances: [String: Float] = [:]
                            
                            // Get frame dimensions
                            let frameWidth = CVPixelBufferGetWidth(pixelBuffer)
                            let frameHeight = CVPixelBufferGetHeight(pixelBuffer)
                            
                            for object in self.detectedObjects {
                                // Calculate normalized rect from the bounding box
                                let normalizedRect = CGRect(
                                    x: object.boundingBox.origin.x / CGFloat(frameWidth),
                                    y: object.boundingBox.origin.y / CGFloat(frameHeight),
                                    width: object.boundingBox.width / CGFloat(frameWidth),
                                    height: object.boundingBox.height / CGFloat(frameHeight)
                                )
                                
                                // Use the normalized rect for depth calculation
                                let avgDepth = depthMap.averageDepthInRegion(rect: normalizedRect)
                                distances[object.label] = avgDepth
                                
                                // Log depth information for debugging
                                print("Depth for \(object.label): \(avgDepth) meters")
                            }
                            self.averageDistanceToObjects = distances
                        }
                    }
                }
            }
            
            // Mark as done processing
            self.isProcessing = false
        }
    }
    
    // Process detections from YOLO model
    private func processDetections(for request: VNRequest, error: Error?) {
        guard error == nil, let results = request.results as? [VNRecognizedObjectObservation] else {
            print("⚠️ ModelIntegration: No detection results or error: \(String(describing: error))")
            return
        }
        
        // Filter results with a lower confidence threshold for traffic lights
        let filteredResults = results.filter { observation in
            // Use a lower threshold specifically for traffic lights to improve detection range
            if let topLabel = observation.labels.first, 
               (topLabel.identifier.lowercased().contains("traffic") || 
                topLabel.identifier.lowercased().contains("signal")) {
                return observation.confidence >= confidenceThreshold * 0.7 // 30% lower threshold for traffic lights
            }
            return observation.confidence >= confidenceThreshold
        }
        
        // Get current time
        let currentTime = Date()
        
        // Convert Vision results to our DetectedObject format
        var newDetections: [DetectedObject] = []
        
        for observation in filteredResults {
            // Get the top label with highest confidence
            guard let topLabelObservation = observation.labels.first else { continue }
            
            let label = topLabelObservation.identifier
            let confidence = topLabelObservation.confidence
            
            // Normalize the class name to our target categories
            let normalizedLabel = normalizeLabel(label)
            
            // Skip if not one of our target categories
            if normalizedLabel == "Unknown" {
                continue
            }
            
            // Create a DetectedObject
            let detectedObject = DetectedObject(
                label: normalizedLabel,
                confidence: confidence,
                boundingBox: observation.boundingBox
            )
            
            // Add to detections
            newDetections.append(detectedObject)
            
            // Get frame dimensions (if available)
            var frameWidth: CGFloat = 0
            var frameHeight: CGFloat = 0
            if let pixelBuffer = lastProcessedImageBuffer {
                frameWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
                frameHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
            }
            
            // Calculate object size in pixels
            let width = observation.boundingBox.width * frameWidth
            let height = observation.boundingBox.height * frameHeight
            let size = max(width, height)
            
            // Calculate estimated distance
            let estimatedDistance = estimateDistanceToObject(size: size, objectType: normalizedLabel)
            
            // Determine if object is nearby - traffic lights get a larger detection range
            let isNearby: Bool
            if normalizedLabel == "Traffic Light" {
                isNearby = estimatedDistance < 50.0 // Increase traffic light detection range to 50 meters
            } else {
                isNearby = estimatedDistance < 15.0 // Others remain at 15 meters
            }
            
            // Play alert sounds and speech for the detected object
            if shouldPlayAlert(for: normalizedLabel, at: currentTime) {
                // Play appropriate sound based on object type
                switch normalizedLabel {
                case "Stop Sign":
                    playSound(soundID: stopSignSound)
                    speakDetection("Stop Sign detected")
                    print("🛑 ALERT: Stop sign detected, confidence: \(confidence), est. distance: \(estimatedDistance)m")
                    if isNearby {
                        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                    }
                
                case "Traffic Light":
                    playSound(soundID: trafficLightSound)
                    speakDetection("Traffic Light detected")
                    print("🚦 ALERT: Traffic light detected, confidence: \(confidence), est. distance: \(estimatedDistance)m")
                
                case "Person":
                    playSound(soundID: personSound)
                    speakDetection("Person detected")
                    print("🚶 ALERT: Person detected, confidence: \(confidence), est. distance: \(estimatedDistance)m")
                
                case "Bike":
                    playSound(soundID: bikeSound)
                    speakDetection("Bicycle detected")
                    print("🚲 ALERT: Bike detected, confidence: \(confidence), est. distance: \(estimatedDistance)m")
                
                case "Car":
                    playSound(soundID: vehicleSound)
                    speakDetection("Vehicle detected")
                    print("🚗 ALERT: Vehicle detected, confidence: \(confidence), est. distance: \(estimatedDistance)m")
                
                default:
                    break
                }
                
                // Update last alert time
                lastAlertTimes[normalizedLabel] = currentTime
            }
        }
        
        // Update detected objects on main thread
        DispatchQueue.main.async { [weak self] in
            self?.detectedObjects = newDetections
            
            // Post notification if objects were detected
            if !newDetections.isEmpty {
                NotificationCenter.default.post(
                    name: NSNotification.Name("ObjectsDetected"),
                    object: nil,
                    userInfo: ["count": newDetections.count]
                )
            }
        }
    }
    
    // Map YOLO class labels to our target categories
    private func normalizeLabel(_ yoloLabel: String) -> String {
        let lowercasedLabel = yoloLabel.lowercased()
        
        // Map YOLO labels to our target categories
        if lowercasedLabel.contains("stop") || lowercasedLabel.contains("stop sign") {
            return "Stop Sign"
        } else if lowercasedLabel.contains("traffic light") || lowercasedLabel.contains("trafficlight") || 
                  lowercasedLabel.contains("signal") || lowercasedLabel.contains("semaphore") || 
                  lowercasedLabel.contains("traffic signal") || lowercasedLabel.contains("stoplight") {
            return "Traffic Light"
        } else if lowercasedLabel.contains("person") || lowercasedLabel.contains("pedestrian") {
            return "Person"
        } else if lowercasedLabel.contains("bicycle") || lowercasedLabel.contains("bike") {
            return "Bike"
        } else if lowercasedLabel.contains("car") || lowercasedLabel.contains("truck") || 
                  lowercasedLabel.contains("bus") || lowercasedLabel.contains("vehicle") {
            return "Car"
        }
        
        return "Unknown"
    }
    
    // Helper method to determine if we should play an alert sound for an object type
    private func shouldPlayAlert(for objectType: String, at currentTime: Date) -> Bool {
        if let lastTime = lastAlertTimes[objectType] {
            // Use shorter cooldown periods to provide more frequent alerts
            let cooldownPeriod: TimeInterval
            
            switch objectType {
            case "Car":
                cooldownPeriod = alertCooldown + 2.0 // 3.5 seconds
            case "Bike":
                cooldownPeriod = alertCooldown + 1.0 // 2.5 seconds
            case "Person":
                cooldownPeriod = alertCooldown + 1.0 // 2.5 seconds
            case "Traffic Light":
                cooldownPeriod = alertCooldown + 1.5 // 3.0 seconds
            case "Stop Sign":
                cooldownPeriod = alertCooldown + 1.5 // 3.0 seconds
            default:
                cooldownPeriod = alertCooldown + 2.0 // 3.5 seconds
            }
            
            return currentTime.timeIntervalSince(lastTime) > cooldownPeriod
        }
        return true
    }
    
    // Speak detection using text-to-speech
    private func speakDetection(_ text: String) {
        // Only speak if not currently speaking
        if !speechSynthesizer.isSpeaking {
            let utterance = AVSpeechUtterance(string: text)
            utterance.rate = 0.5 // Slower rate for clarity
            utterance.volume = 1.0 // Full volume
            utterance.pitchMultiplier = 1.1 // Slightly higher pitch
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            
            speechSynthesizer.speak(utterance)
        }
    }
    
    // Play alert sound - updated to use AVAudioPlayer instead of system sounds
    private func playSound(soundID: SystemSoundID) {
        // Add debug logging to identify which sound is playing
        let soundName: String
        var player: AVAudioPlayer?
        
        switch soundID {
        case stopSignSound:
            soundName = "Stop Sign Sound"
            player = stopSignPlayer
        case personSound:
            soundName = "Person Sound"
            player = personPlayer
        case vehicleSound:
            soundName = "Vehicle Sound"
            player = vehiclePlayer
        case bikeSound:
            soundName = "Bike Sound"
            player = bikePlayer
        case trafficLightSound:
            soundName = "Traffic Light Sound"
            player = trafficLightPlayer
        default:
            soundName = "Unknown Sound (\(soundID))"
            player = nil
        }
        
        print("🔊 Playing alert sound: \(soundName)")
        
        if let audioPlayer = player {
            // First try to play with AVAudioPlayer (works in silent mode)
            if audioPlayer.isPlaying {
                audioPlayer.stop()
            }
            audioPlayer.currentTime = 0
            audioPlayer.play()
            print("Playing sound using AVAudioPlayer")
        } else {
            // Fallback to system sound if audio player not available
            print("Falling back to system sound")
            AudioServicesPlaySystemSound(soundID)
        }
    }
    
    // Enable/disable processing
    public func toggleProcessing() {
        processingEnabled = !processingEnabled
        print("Object detection processing: \(processingEnabled ? "ENABLED" : "DISABLED")")
        
        // Force an update to clear any stale objects when disabling
        if !processingEnabled {
            detectedObjects = []
        }
    }
    
    // Reset object detection for new trip
    public func resetObjectDetection() {
        // Clear detected objects
        detectedObjects.removeAll()
        
        // Also reset the tracked objects in the detection manager if available
        if let objectDetectionManager = objectDetectionManager {
            objectDetectionManager.recentlyDetectedObjects.removeAll()
        }
        
        // Clear distances and other related data
        averageDistanceToObjects.removeAll()
        
        print("Object detection reset for new trip")
    }
    
    // Helper method to check if a rectangle could be a stop sign
    private func analyzeImageForStopSign(in pixelBuffer: CVPixelBuffer, rect: CGRect) -> Bool {
        // Convert to CIImage for color analysis
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Convert normalized rect to pixel coordinates
        let frameWidth = CVPixelBufferGetWidth(pixelBuffer)
        let frameHeight = CVPixelBufferGetHeight(pixelBuffer)
        
        let pixelRect = CGRect(
            x: rect.minX * CGFloat(frameWidth),
            y: rect.minY * CGFloat(frameHeight),
            width: rect.width * CGFloat(frameWidth),
            height: rect.height * CGFloat(frameHeight)
        )
        
        // Create a cropped image of just this region
        let croppedImage = ciImage.cropped(to: pixelRect)
        
        // Set up a CIAreaAverage filter to get average color
        let areaAverageFilter = CIFilter(name: "CIAreaAverage")
        areaAverageFilter?.setValue(croppedImage, forKey: kCIInputImageKey)
        areaAverageFilter?.setValue(CIVector(cgRect: CGRect(x: 0, y: 0, width: pixelRect.width, height: pixelRect.height)), forKey: "inputExtent")
        
        guard let outputImage = areaAverageFilter?.outputImage else {
            return false
        }
        
        // Create a bitmap to read the average color
        let context = CIContext(options: nil)
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        // Get color components
        let red = CGFloat(bitmap[0]) / 255.0
        let green = CGFloat(bitmap[1]) / 255.0
        let blue = CGFloat(bitmap[2]) / 255.0
        
        // Check if predominant color is reddish (stop signs are red)
        let isReddish = red > 0.5 && green < 0.4 && blue < 0.4
        
        // If the shape is square-ish and reddish, it's more likely to be a stop sign
        return isReddish
    }
    
    // Estimate distance to object based on its size in the frame
    private func estimateDistanceToObject(size: CGFloat, objectType: String) -> Float {
        // Simple distance estimation based on apparent size
        // This is a simplified approach; real apps would use depth sensing or other techniques
        
        // Baseline sizes at 1 meter distance (rough estimates)
        let baselineSize: CGFloat
        switch objectType {
        case "Stop Sign":
            baselineSize = 400 // Stop sign at 1m would be about 400px wide
        case "Traffic Light":
            baselineSize = 250 // Traffic light at 1m - reduced from 300px to detect at greater distances
        case "Person":
            baselineSize = 500 // Person at 1m would be about 500px tall
        case "Bike":
            baselineSize = 450 // Bike at 1m would be about 450px wide
        case "Car":
            baselineSize = 600 // Car at 1m would be about 600px wide
        default:
            baselineSize = 400 // Default assumption
        }
        
        // Calculate inverse relationship between size and distance with some adjustments
        var distance: CGFloat
        
        if objectType == "Traffic Light" {
            // Special calculation for traffic lights that are typically higher up
            // This applies a smaller distance penalty for small traffic lights
            distance = max(1.0, (baselineSize / size) * 0.8)
        } else {
            distance = max(1.0, baselineSize / size)
        }
        
        return Float(distance)
    }
    
    // Enhanced object detection method
    public func enhanceDetection(_ detectedObject: DetectedObject, in pixelBuffer: CVPixelBuffer) -> DetectedObject {
        var updatedObject = detectedObject
        
        // Analyze the image to confirm object type
        switch detectedObject.label {
        case "Stop Sign":
            let isActualStopSign = analyzeImageForStopSign(in: pixelBuffer, rect: detectedObject.boundingBox)
            
            // Update confidence based on color analysis
            if isActualStopSign {
                // It's more likely to be a stop sign if the color matches
                updatedObject = DetectedObject(
                    label: detectedObject.label,
                    confidence: min(1.0, detectedObject.confidence * 1.5), // Increase confidence
                    boundingBox: detectedObject.boundingBox
                )
                print("Confirmed stop sign detection with color analysis")
            } else {
                // Probably not a stop sign
                updatedObject = DetectedObject(
                    label: detectedObject.label,
                    confidence: detectedObject.confidence * 0.7, // Less aggressive decrease
                    boundingBox: detectedObject.boundingBox
                )
                print("Uncertain stop sign detection with color analysis")
            }
        
        case "Traffic Light":
            let isTrafficLight = analyzeImageForTrafficLight(in: pixelBuffer, rect: detectedObject.boundingBox)
            if isTrafficLight {
                updatedObject = DetectedObject(
                    label: detectedObject.label,
                    confidence: min(1.0, detectedObject.confidence * 1.4),
                    boundingBox: detectedObject.boundingBox
                )
            } else {
                updatedObject = DetectedObject(
                    label: detectedObject.label,
                    confidence: detectedObject.confidence * 0.7,
                    boundingBox: detectedObject.boundingBox
                )
            }
            
        case "Bike":
            // Bikes are harder to detect, so we'll be more lenient
            updatedObject = DetectedObject(
                label: detectedObject.label,
                confidence: min(1.0, detectedObject.confidence * 1.2),
                boundingBox: detectedObject.boundingBox
            )
            
        default:
            // For other objects, keep the same confidence
            break
        }
        
        return updatedObject
    }
    
    // Helper method to check if a rectangle could be a traffic light
    private func analyzeImageForTrafficLight(in pixelBuffer: CVPixelBuffer, rect: CGRect) -> Bool {
        // Convert to CIImage for color analysis
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Convert normalized rect to pixel coordinates
        let frameWidth = CVPixelBufferGetWidth(pixelBuffer)
        let frameHeight = CVPixelBufferGetHeight(pixelBuffer)
        
        let pixelRect = CGRect(
            x: rect.minX * CGFloat(frameWidth),
            y: rect.minY * CGFloat(frameHeight),
            width: rect.width * CGFloat(frameWidth),
            height: rect.height * CGFloat(frameHeight)
        )
        
        // Create a cropped image of just this region
        let croppedImage = ciImage.cropped(to: pixelRect)
        
        // Set up a CIAreaAverage filter to get average color
        let areaAverageFilter = CIFilter(name: "CIAreaAverage")
        areaAverageFilter?.setValue(croppedImage, forKey: kCIInputImageKey)
        areaAverageFilter?.setValue(CIVector(cgRect: CGRect(x: 0, y: 0, width: pixelRect.width, height: pixelRect.height)), forKey: "inputExtent")
        
        guard let outputImage = areaAverageFilter?.outputImage else {
            return false
        }
        
        // Create a bitmap to read the average color
        let context = CIContext(options: nil)
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        // Get color components
        let red = CGFloat(bitmap[0]) / 255.0
        let green = CGFloat(bitmap[1]) / 255.0
        let blue = CGFloat(bitmap[2]) / 255.0
        let brightness = (red + green + blue) / 3.0
        
        // Traffic lights have bright spots (red/yellow/green) and darker housing
        let hasBrightSpots = brightness > 0.5
        let hasContrastingColors = max(red, green, blue) - min(red, green, blue) > 0.2
        
        // Traffic lights typically have bright red/yellow/green on dark background
        return hasContrastingColors || hasBrightSpots
    }
}

// MARK: - SwiftUI Extensions

extension ModelIntegration {
    // Helper method to create a SwiftUI Image from a UIImage
    func getProcessedImage() -> Image? {
        guard let uiImage = self.lastProcessedImage else { return nil }
        return Image(uiImage: uiImage)
    }
    
    // Helper method to get the depth map visualization
    func getDepthMapImage() -> Image? {
        guard let uiImage = self.depthMapImage else { return nil }
        return Image(uiImage: uiImage)
    }
}
