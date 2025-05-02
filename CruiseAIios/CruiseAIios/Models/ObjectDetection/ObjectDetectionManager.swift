//
//  ObjectDetectionManager.swift
//  CruiseAIios
//
//  Created by Ojas Kandhare on 4/2/25.
//

import Foundation
import Vision
import UIKit
import CoreML
import SwiftUI
import AudioToolbox
import UserNotifications

class ObjectDetectionManager {
    // MARK: - Properties
    
    private var visionModel: VNCoreMLModel?
    private let confidenceThreshold: Float = 0.3 // Threshold for detection confidence
    private var isBackgroundMode = false
    
    // Concurrent queue for frame processing
    private let processingQueue = DispatchQueue(label: "com.cruiseai.objectdetection", attributes: .concurrent)
    
    // Object tracking and alert management
    public struct TrackedObject: Hashable {
        let label: String
        let boundingBox: CGRect
        let timestamp: Date
        
        // Consider objects in similar positions as the same object
        static func ~= (lhs: TrackedObject, rhs: TrackedObject) -> Bool {
            guard lhs.label == rhs.label else { return false }
            
            // Calculate center points
            let lhsCenter = CGPoint(x: lhs.boundingBox.midX, y: lhs.boundingBox.midY)
            let rhsCenter = CGPoint(x: rhs.boundingBox.midX, y: rhs.boundingBox.midY)
            
            // Calculate distance between centers
            let distance = hypot(lhsCenter.x - rhsCenter.x, lhsCenter.y - rhsCenter.y)
            
            // If centers are close enough and time difference is small, consider it the same object
            return distance < 0.2 // 20% of frame size
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(label)
            hasher.combine(boundingBox.origin.x)
            hasher.combine(boundingBox.origin.y)
        }
        
        static func == (lhs: TrackedObject, rhs: TrackedObject) -> Bool {
            lhs ~= rhs
        }
    }
    
    // Recently detected objects and their cooldown times
    public var recentlyDetectedObjects: Set<TrackedObject> = []
    private let objectCooldownTime: TimeInterval = 10.0 // Time before same object type can trigger again
    private let locationCooldownTime: TimeInterval = 30.0 // Time before same location can trigger again
    private let stopSignCooldownTime: TimeInterval = 5.0 // Reduced cooldown time for stop signs
    
    // Target objects to detect
    private let targetObjects = [
        "person",
        "bicycle", 
        "motorcycle",
        "traffic light",
        "stop sign"
    ]
    
    // Object priorities (1 = highest)
    private let objectPriorities: [String: Int] = [
        "person": 1,        // Highest priority
        "bicycle": 2,
        "motorcycle": 2,
        "traffic light": 3,
        "stop sign": 1      // Also highest priority
    ]
    
    // Different confidence thresholds for different objects
    private let objectConfidenceThresholds: [String: Float] = [
        "person": 0.3,
        "bicycle": 0.3, 
        "motorcycle": 0.3,
        "traffic light": 0.3,
        "stop sign": 0.2  // Lower threshold for stop signs to detect them better
    ]
    
    // MARK: - Initialization
    
    init() {
        setupModel()
        setupBackgroundObserver()
        
        // Start cleanup timer for tracked objects
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.cleanupOldTrackedObjects()
        }
    }
    
    // MARK: - Setup
    
    private func setupModel() {
        print("Setting up object detection model...")
        
        // List all files in the bundle to find the model
        if let bundleURL = Bundle.main.resourceURL {
            let fileManager = FileManager.default
            if let files = try? fileManager.contentsOfDirectory(at: bundleURL, includingPropertiesForKeys: nil) {
                print("Bundle contents:")
                for file in files {
                    print("- \(file.lastPathComponent)")
                }
            }
        }
        
        do {
            // Try to find the model file
            if let modelURL = Bundle.main.url(forResource: "YOLOv3TinyFP16", withExtension: "mlmodel") {
                print("Found model at: \(modelURL.path)")
                
                // Get model description - removed because it's causing a compilation error
                // MLModelDescription doesn't have a contentsOf initializer
                print("Found YOLOv3TinyFP16.mlmodel")
                
                // Load the model
                let model = try MLModel(contentsOf: modelURL)
                self.visionModel = try VNCoreMLModel(for: model)
                print("Successfully loaded YOLOv3 model")
                return
            } else {
                print("Could not find YOLOv3TinyFP16.mlmodel in the bundle")
            }
            
            // Try to find the compiled model
            if let compiledModelURL = Bundle.main.url(forResource: "YOLOv3TinyFP16", withExtension: "mlmodelc") {
                print("Found compiled model at: \(compiledModelURL.path)")
                let model = try MLModel(contentsOf: compiledModelURL)
                self.visionModel = try VNCoreMLModel(for: model)
                print("Successfully loaded YOLOv3 model from compiled model")
                return
            } else {
                print("Could not find YOLOv3TinyFP16.mlmodelc in the bundle")
            }
            
            // Try to find the model in a subdirectory
            if let modelURL = Bundle.main.url(forResource: "YOLOv3TinyFP16", withExtension: "mlmodel", subdirectory: "Models/ObjectDetection") {
                print("Found model in subdirectory: \(modelURL.path)")
                let model = try MLModel(contentsOf: modelURL)
                self.visionModel = try VNCoreMLModel(for: model)
                print("Successfully loaded YOLOv3 model from subdirectory")
                return
            }
            
            print("Could not find YOLOv3TinyFP16 model in any location")
        } catch {
            print("Failed to load YOLOv3 model: \(error.localizedDescription)")
        }
    }
    
    private func setupBackgroundObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBackgroundProcessingTick),
            name: .backgroundProcessingTick,
            object: nil
        )
    }
    
    // MARK: - Background Support
    
    func configureForBackground() {
        isBackgroundMode = true
        print("Object detection configured for background operation at full capacity")
    }
    
    func restoreNormalOperation() {
        isBackgroundMode = false
        print("Object detection restored to normal operation")
    }
    
    @objc private func handleBackgroundProcessingTick() {
        // When in background mode, this method will be called by the BackgroundManager's timer
        if isBackgroundMode {
            // The frame processing is already handled by detectObjects
            // We don't need additional logic here since the camera is still sending frames
            // and detectObjects is processing them at full speed
            print("Background tick - continuing normal frame processing")
        }
    }
    
    // MARK: - Object Detection
    
    func detectObjects(in image: CVPixelBuffer, completion: @escaping ([DetectedObject]) -> Void) {
        guard let visionModel = visionModel else {
            print("No vision model available")
            completion([])
            return
        }
        
        processingQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            let request = VNCoreMLRequest(model: visionModel) { request, error in
                if let error = error {
                    print("Vision request failed: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                guard let results = request.results as? [VNRecognizedObjectObservation] else {
                    print("Invalid results type")
                    completion([])
                    return
                }
                
                // Filter and process detected objects with object-specific thresholds
                let detectedObjects = results
                    .compactMap { observation -> DetectedObject? in
                        guard let label = observation.labels.first?.identifier,
                              self.targetObjects.contains(label.lowercased()) else {
                            return nil
                        }
                        
                        // Get the object-specific threshold or use default
                        let threshold = self.objectConfidenceThresholds[label.lowercased()] ?? self.confidenceThreshold
                        
                        // Filter based on object-specific threshold
                        guard observation.confidence >= threshold else {
                            return nil
                        }
                        
                        // Improved debugging for stop sign detection
                        if label.lowercased() == "stop sign" {
                            print("STOP SIGN DETECTED! Confidence: \(observation.confidence), Threshold: \(threshold)")
                        }
                        
                        return DetectedObject(
                            label: label,
                            confidence: Float(observation.confidence),
                            boundingBox: observation.boundingBox
                        )
                    }
                
                // Process detections on main queue
                DispatchQueue.main.async {
                    self.processNewDetections(detectedObjects)
                    completion(detectedObjects)
                }
            }
            
            request.imageCropAndScaleOption = .scaleFill
            
            let handler = VNImageRequestHandler(cvPixelBuffer: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("Failed to perform vision request: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }
    
    // MARK: - Detection Processing
    
    private func processNewDetections(_ detections: [DetectedObject]) {
        let currentTime = Date()
        var newAlerts: [(String, Int)] = [] // Store label and priority
        
        // Process each detected object
        for detection in detections {
            let label = detection.label.lowercased()
            
            // Create a tracked object for cooldown checking
            let trackedObject = TrackedObject(
                label: label,
                boundingBox: detection.boundingBox,
                timestamp: currentTime
            )
            
            // Special handling for stop signs - reduce cooldown time
            let cooldownTime = label == "stop sign" ? stopSignCooldownTime : objectCooldownTime
            
            // Check if this object or location is in cooldown
            var shouldAlert = true
            
            // Loop through recently detected objects to check for cooldown
            for existingObject in recentlyDetectedObjects {
                // Don't alert if it's the same object type in cooldown period
                if existingObject.label == label && 
                   currentTime.timeIntervalSince(existingObject.timestamp) < cooldownTime {
                    shouldAlert = false
                    break
                }
                
                // Don't alert if it's a different object but same location in cooldown period
                // Except for stop signs which should always alert regardless of location cooldown
                if existingObject.label != label && 
                   existingObject ~= trackedObject && 
                   currentTime.timeIntervalSince(existingObject.timestamp) < locationCooldownTime &&
                   label != "stop sign" {
                    shouldAlert = false
                    break
                }
            }
            
            // For stop signs, always log detection attempt
            if label == "stop sign" {
                print("Stop sign processing: shouldAlert=\(shouldAlert), confidence=\(detection.confidence)")
            }
            
            // If we should alert, add to the new alerts and track this object
            if shouldAlert {
                if let priority = objectPriorities[label] {
                    newAlerts.append((label, priority))
                    recentlyDetectedObjects.insert(trackedObject)
                    
                    // Notify for object detection - for bounding box display only
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ObjectDetected"),
                        object: nil,
                        userInfo: [
                            "label": label,
                            "confidence": detection.confidence,
                            "boundingBox": NSValue(cgRect: detection.boundingBox)
                        ]
                    )
                    
                    // Extra logging for stop signs
                    if label == "stop sign" {
                        print("🛑 STOP SIGN ALERT TRIGGERED! 🛑")
                    }
                }
            }
        }
        
        // If we have alerts, sort by priority and play the highest priority one
        if !newAlerts.isEmpty {
            // Sort alerts by priority (lower number = higher priority)
            newAlerts.sort { (alert1, alert2) -> Bool in
                return alert1.1 < alert2.1
            }
            
            // Get the highest priority alert
            let (label, _) = newAlerts[0]
            
            // Play the instrumental sound using SoundManager
            SoundManager.shared.playSoundForObject(label)
            
            // Log the alert
            print("🔊 Playing instrumental sound for \(label.uppercased())")
        }
    }
    
    private func cleanupOldTrackedObjects() {
        let currentTime = Date()
        recentlyDetectedObjects = recentlyDetectedObjects.filter { object in
            currentTime.timeIntervalSince(object.timestamp) < locationCooldownTime
        }
    }
    
    // MARK: - Notifications
    
    private func sendObjectDetectionNotification(object: DetectedObject) {
        let content = UNMutableNotificationContent()
        content.title = "Object Detected"
        content.body = "\(object.label) detected with \(Int(object.confidence * 100))% confidence"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending notification: \(error)")
            }
        }
    }
}

// MARK: - Models
// Using shared DetectedObject model from Models/DetectedObject.swift
