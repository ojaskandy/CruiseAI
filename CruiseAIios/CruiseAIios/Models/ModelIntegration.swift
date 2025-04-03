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

class ModelIntegration: ObservableObject {
    // MARK: - Properties
    
    @Published var detectedObjects: [DetectedObject] = []
    @Published var depthMapImage: UIImage?
    @Published var isProcessing = false
    @Published var averageDistanceToObjects: [String: Float] = [:]
    @Published var lastProcessedImage: UIImage?
    @Published var processingEnabled = true
    
    private let objectDetectionManager = ObjectDetectionManager()
    private let depthEstimationManager = DepthEstimationManager()
    
    // Processing queue to avoid blocking the main thread
    private let processingQueue = DispatchQueue(label: "com.cruiseai.modelProcessing", qos: .userInitiated)
    
    // Frame processing rate control
    private var lastProcessingTime = Date()
    private let processingInterval: TimeInterval = 0.5 // Process frames every 0.5 seconds
    
    // MARK: - Initialization
    
    init() {
        print("ModelIntegration initialized")
    }
    
    // MARK: - Public Methods
    
    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        // All state changes must happen on the main thread
        DispatchQueue.main.async {
            // Skip processing if disabled or if we're already processing a frame
            guard self.processingEnabled, !self.isProcessing else { return }
            
            // Rate limit processing to avoid overwhelming the CPU/GPU
            let currentTime = Date()
            guard currentTime.timeIntervalSince(self.lastProcessingTime) >= self.processingInterval else { return }
            
            self.isProcessing = true
            self.lastProcessingTime = currentTime
            
            // Convert pixel buffer to UIImage for display (just for reference)
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext()
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
                self.isProcessing = false
                return
            }
            
            let uiImage = UIImage(cgImage: cgImage)
            self.lastProcessedImage = uiImage
            
            // Process on background queue
            self.processingQueue.async { [weak self] in
                guard let self = self else { return }
                
                print("Processing frame...")
                
                // Process object detection only (skip depth estimation for now)
                self.objectDetectionManager.detectObjects(in: pixelBuffer) { detectedObjects in
                    print("Object detection completed. Found \(detectedObjects.count) objects.")
                    
                    // Update UI on main thread
                    DispatchQueue.main.async {
                        // Check if we detected new objects
                        let hadObjectsBefore = !self.detectedObjects.isEmpty
                        let hasObjectsNow = !detectedObjects.isEmpty
                        
                        self.detectedObjects = detectedObjects
                        self.isProcessing = false
                        
                        // Play sound and vibration if objects are detected
                        if hasObjectsNow {
                            // Play different sounds based on detected object types
                            self.playObjectDetectionSounds(for: detectedObjects)
                            
                            // Also vibrate
                            AudioServicesPlaySystemSound(1352) // kSystemSoundID_Vibrate
                            
                            print("Played sound and vibration for detected objects")
                        }
                        
                        print("UI updated with detection results")
                    }
                }
            }
        }
    }
    
    // Play different sounds based on detected object types
    private func playObjectDetectionSounds(for objects: [DetectedObject]) {
        // Define sound IDs for different object types
        let personSoundID: SystemSoundID = 1013     // SMS sent sound
        let stopSignSoundID: SystemSoundID = 1016   // Alert sound
        let trafficLightSoundID: SystemSoundID = 1020 // New mail sound
        let transportationSoundID: SystemSoundID = 1008 // Low power sound
        
        // Track which sounds we've played to avoid duplicates
        var playedSounds = Set<SystemSoundID>()
        
        // Check for each object type and play the corresponding sound
        for object in objects {
            let label = object.label.lowercased()
            
            // Person detection
            if label == "person" && !playedSounds.contains(personSoundID) {
                AudioServicesPlaySystemSound(personSoundID)
                playedSounds.insert(personSoundID)
                print("Played person detection sound")
            }
            
            // Stop sign detection
            else if label == "stop sign" && !playedSounds.contains(stopSignSoundID) {
                AudioServicesPlaySystemSound(stopSignSoundID)
                playedSounds.insert(stopSignSoundID)
                print("Played stop sign detection sound")
            }
            
            // Traffic light detection
            else if label == "traffic light" && !playedSounds.contains(trafficLightSoundID) {
                AudioServicesPlaySystemSound(trafficLightSoundID)
                playedSounds.insert(trafficLightSoundID)
                print("Played traffic light detection sound")
            }
            
            // Transportation detection (car, truck, bus, motorcycle, bicycle)
            else if ["car", "truck", "bus", "motorcycle", "bicycle"].contains(label) && !playedSounds.contains(transportationSoundID) {
                AudioServicesPlaySystemSound(transportationSoundID)
                playedSounds.insert(transportationSoundID)
                print("Played transportation detection sound")
            }
        }
        
        // If no specific sounds were played, play a generic detection sound
        if playedSounds.isEmpty {
            AudioServicesPlaySystemSound(1005) // Generic ding sound
            print("Played generic detection sound")
        }
    }
    
    // Toggle processing on/off
    func toggleProcessing() {
        processingEnabled.toggle()
        print("Processing \(processingEnabled ? "enabled" : "disabled")")
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
