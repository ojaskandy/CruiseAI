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

class ObjectDetectionManager {
    // MARK: - Properties
    
    private var visionModel: VNCoreMLModel?
    private let confidenceThreshold: Float = 0.3 // Lower threshold to detect more objects
    
    // COCO class names for YOLOv3
    private let cocoClassNames = [
        "person", "bicycle", "car", "motorcycle", "airplane", "bus", "train", "truck", "boat",
        "traffic light", "fire hydrant", "stop sign", "parking meter", "bench", "bird", "cat",
        "dog", "horse", "sheep", "cow", "elephant", "bear", "zebra", "giraffe", "backpack",
        "umbrella", "handbag", "tie", "suitcase", "frisbee", "skis", "snowboard", "sports ball",
        "kite", "baseball bat", "baseball glove", "skateboard", "surfboard", "tennis racket", "bottle",
        "wine glass", "cup", "fork", "knife", "spoon", "bowl", "banana", "apple", "sandwich",
        "orange", "broccoli", "carrot", "hot dog", "pizza", "donut", "cake", "chair", "couch",
        "potted plant", "bed", "dining table", "toilet", "tv", "laptop", "mouse", "remote",
        "keyboard", "cell phone", "microwave", "oven", "toaster", "sink", "refrigerator", "book",
        "clock", "vase", "scissors", "teddy bear", "hair drier", "toothbrush"
    ]
    
    // MARK: - Initialization
    
    init() {
        setupModel()
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
    
    // MARK: - Object Detection
    
    func detectObjects(in image: CVPixelBuffer, completion: @escaping ([DetectedObject]) -> Void) {
        guard let visionModel = visionModel else {
            print("Vision model not available")
            completion([])
            return
        }
        
        let request = VNCoreMLRequest(model: visionModel) { [weak self] request, error in
            guard let self = self, error == nil else {
                print("Vision request failed: \(error?.localizedDescription ?? "Unknown error")")
                completion([])
                return
            }
            
            guard let results = request.results as? [VNRecognizedObjectObservation] else {
                print("Unexpected result type from VNCoreMLRequest")
                completion([])
                return
            }
            
            // Log all results before filtering
            print("Raw detection results:")
            for (index, observation) in results.enumerated() {
                let labels = observation.labels.map { "\($0.identifier) (\(Int($0.confidence * 100))%)" }.joined(separator: ", ")
                print("  Object \(index): \(labels) - Confidence: \(observation.confidence)")
            }
            
            // Filter results by confidence threshold
            let filteredResults = results.filter { $0.confidence >= self.confidenceThreshold }
            
            // Convert Vision results to our DetectedObject model
            let detectedObjects = filteredResults.map { observation -> DetectedObject in
                let boundingBox = observation.boundingBox
                let confidence = Float(observation.confidence)
                
                // Get the most confident label
                let label = observation.labels.first?.identifier ?? "Unknown"
                
                // Log the detected object
                print("Detected \(label) with confidence \(confidence) at \(boundingBox)")
                
                return DetectedObject(
                    label: label,
                    confidence: confidence,
                    boundingBox: boundingBox
                )
            }
            
            print("Detected \(detectedObjects.count) objects after filtering")
            completion(detectedObjects)
        }
        
        // Configure the request to use the available GPU
        request.usesCPUOnly = false
        
        // Perform the request
        do {
            try VNImageRequestHandler(cvPixelBuffer: image, options: [:]).perform([request])
        } catch {
            print("Failed to perform detection: \(error.localizedDescription)")
            completion([])
        }
    }
}

// MARK: - Models

struct DetectedObject: Equatable {
    let label: String
    let confidence: Float
    let boundingBox: CGRect
    
    // Implement Equatable
    static func == (lhs: DetectedObject, rhs: DetectedObject) -> Bool {
        return lhs.label == rhs.label &&
               lhs.confidence == rhs.confidence &&
               lhs.boundingBox == rhs.boundingBox
    }
}
