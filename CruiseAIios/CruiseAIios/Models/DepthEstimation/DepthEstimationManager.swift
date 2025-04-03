//
//  DepthEstimationManager.swift
//  CruiseAIios
//
//  Created by Ojas Kandhare on 4/2/25.
//

import Foundation
import Vision
import UIKit
import CoreML

class DepthEstimationManager {
    // MARK: - Properties
    
    private var model: MLModel?
    // Try different input sizes that might be compatible with the model
    private let inputSize = CGSize(width: 256, height: 256)
    
    // MARK: - Initialization
    
    init() {
        setupModel()
    }
    
    // MARK: - Setup
    
    private func setupModel() {
        do {
            // Try to find the model in the mlpackage subdirectory
            if let modelURL = Bundle.main.url(forResource: "DepthAnythingV2SmallF16P6", withExtension: "mlmodelc", subdirectory: "DepthAnythingV2SmallF16P6.mlpackage") {
                print("Found depth model at: \(modelURL.path)")
                self.model = try MLModel(contentsOf: modelURL)
                print("Successfully loaded DepthAnythingV2 model")
                return
            }
            
            // Try to find the model directly
            if let modelURL = Bundle.main.url(forResource: "DepthAnythingV2SmallF16P6", withExtension: "mlmodelc") {
                print("Found depth model at: \(modelURL.path)")
                self.model = try MLModel(contentsOf: modelURL)
                print("Successfully loaded DepthAnythingV2 model")
                return
            }
            
            // Try to find the uncompiled model
            if let modelURL = Bundle.main.url(forResource: "DepthAnythingV2SmallF16P6", withExtension: "mlmodel") {
                print("Found depth model at: \(modelURL.path)")
                self.model = try MLModel(contentsOf: modelURL)
                print("Successfully loaded DepthAnythingV2 model")
                return
            }
            
            print("Could not find DepthAnythingV2SmallF16P6 model in the bundle")
        } catch {
            print("Failed to load depth model: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Depth Estimation
    
    func estimateDepth(from pixelBuffer: CVPixelBuffer, completion: @escaping (DepthMap?) -> Void) {
        guard let model = model else {
            print("Depth model not available")
            completion(nil)
            return
        }
        
        // Resize and prepare the input image
        guard let resizedPixelBuffer = resizePixelBuffer(pixelBuffer, to: inputSize) else {
            print("Failed to resize pixel buffer")
            completion(nil)
            return
        }
        
        // Create input for the model
        do {
            let input = try MLFeatureValue(pixelBuffer: resizedPixelBuffer)
            let inputFeatures = try MLDictionaryFeatureProvider(dictionary: ["image": input])
            
            // Get prediction
            let outputFeatures = try model.prediction(from: inputFeatures)
            
            // Extract depth map from output
            guard let depthFeature = outputFeatures.featureValue(for: "depth"),
                  let depthMap = depthFeature.multiArrayValue else {
                print("Failed to get depth map from model output")
                completion(nil)
                return
            }
            
            // Get the actual dimensions from the MLMultiArray
            let shape = depthMap.shape
            let width = shape.count > 0 ? shape[0].intValue : 256
            let height = shape.count > 1 ? shape[1].intValue : 256
            
            print("Depth map dimensions: \(width) x \(height)")
            
            // Create our depth map structure
            let processedDepthMap = DepthMap(
                width: width,
                height: height,
                depthData: depthMap
            )
            
            completion(processedDepthMap)
        } catch {
            print("Failed to perform depth estimation: \(error.localizedDescription)")
            completion(nil)
        }
    }
    
    // MARK: - Utility Methods
    
    private func resizePixelBuffer(_ pixelBuffer: CVPixelBuffer, to size: CGSize) -> CVPixelBuffer? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let scale = CGAffineTransform(scaleX: size.width / CGFloat(CVPixelBufferGetWidth(pixelBuffer)),
                                     y: size.height / CGFloat(CVPixelBufferGetHeight(pixelBuffer)))
        let scaledImage = ciImage.transformed(by: scale)
        
        var newPixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(nil, Int(size.width), Int(size.height),
                                        kCVPixelFormatType_32BGRA,
                                        nil, &newPixelBuffer)
        
        guard status == kCVReturnSuccess, let newPixelBuffer = newPixelBuffer else {
            return nil
        }
        
        let context = CIContext()
        context.render(scaledImage, to: newPixelBuffer)
        
        return newPixelBuffer
    }
    
    func visualizeDepthMap(_ depthMap: DepthMap) -> UIImage? {
        // Create a grayscale image from the depth map
        // Brighter values represent closer objects
        
        let width = depthMap.width
        let height = depthMap.height
        
        // Create a bitmap context
        let bitsPerComponent = 8
        let bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(data: nil,
                                     width: width,
                                     height: height,
                                     bitsPerComponent: bitsPerComponent,
                                     bytesPerRow: bytesPerRow,
                                     space: colorSpace,
                                     bitmapInfo: bitmapInfo.rawValue) else {
            return nil
        }
        
        // Find min and max values for normalization
        var minValue: Float = Float.greatestFiniteMagnitude
        var maxValue: Float = -Float.greatestFiniteMagnitude
        
        for y in 0..<height {
            for x in 0..<width {
                let value = depthMap.depthAt(x: x, y: y)
                minValue = min(minValue, value)
                maxValue = max(maxValue, value)
            }
        }
        
        // Create pixel data
        guard let data = context.data else {
            return nil
        }
        
        let buffer = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        
        // Fill the pixel data
        for y in 0..<height {
            for x in 0..<width {
                let value = depthMap.depthAt(x: x, y: y)
                
                // Normalize value between 0 and 1
                let normalizedValue = (value - minValue) / (maxValue - minValue)
                
                // Convert to 0-255 range
                let pixelValue = UInt8(normalizedValue * 255)
                
                // Set RGB values (use a heat map coloring)
                let offset = (y * width + x) * 4
                
                // Simple grayscale visualization
                buffer[offset] = pixelValue     // R
                buffer[offset + 1] = pixelValue // G
                buffer[offset + 2] = pixelValue // B
                buffer[offset + 3] = 255        // A
            }
        }
        
        // Create image from context
        guard let cgImage = context.makeImage() else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Models

struct DepthMap {
    let width: Int
    let height: Int
    let depthData: MLMultiArray
    
    // Get depth value at specific coordinates
    func depthAt(x: Int, y: Int) -> Float {
        // The depth map is a 2D array with shape [height, width]
        // Access it using the appropriate index
        let index = y * width + x
        return depthData[index].floatValue
    }
    
    // Calculate average depth in a region
    func averageDepthInRegion(rect: CGRect) -> Float {
        // Convert normalized rect (0-1) to depth map coordinates
        let startX = Int(rect.minX * CGFloat(width))
        let startY = Int(rect.minY * CGFloat(height))
        let endX = min(Int(rect.maxX * CGFloat(width)), width)
        let endY = min(Int(rect.maxY * CGFloat(height)), height)
        
        var sum: Float = 0
        var count = 0
        
        for y in startY..<endY {
            for x in startX..<endX {
                if x >= 0 && x < width && y >= 0 && y < height {
                    sum += depthAt(x: x, y: y)
                    count += 1
                }
            }
        }
        
        return count > 0 ? sum / Float(count) : 0
    }
}
