//
//  DetectedObject.swift
//  CruiseAIios
//
//  Created by Ojas Kandhare on 4/7/25.
//

import Foundation
import SwiftUI

// Shared model for object detection results
public struct DetectedObject: Identifiable, Equatable, Hashable {
    public let id = UUID()
    public let label: String
    public let confidence: Float
    public let boundingBox: CGRect
    
    // Initialize with all properties
    public init(label: String, confidence: Float, boundingBox: CGRect) {
        self.label = label
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
    
    // Implement Equatable
    public static func == (lhs: DetectedObject, rhs: DetectedObject) -> Bool {
        return lhs.label == rhs.label &&
               lhs.confidence == rhs.confidence &&
               lhs.boundingBox == rhs.boundingBox
    }
    
    // Implement Hashable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(label)
        hasher.combine(confidence)
        hasher.combine(boundingBox.origin.x)
        hasher.combine(boundingBox.origin.y)
        hasher.combine(boundingBox.size.width)
        hasher.combine(boundingBox.size.height)
    }
}