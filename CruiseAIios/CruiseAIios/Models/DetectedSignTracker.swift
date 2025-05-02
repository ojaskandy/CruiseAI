//
//  DetectedSignTracker.swift
//  CruiseAIios
//
//  Created by Cline on 4/7/25.
//

import Foundation
import CoreGraphics

struct DetectedSignKey: Hashable {
    let label: String
    let locationKey: String
    
    // Create a location key based on bounding box coordinates
    // Round to nearest 0.1 to allow for small detection fluctuations
    static func makeLocationKey(from boundingBox: CGRect) -> String {
        let x = round(boundingBox.midX * 10) / 10
        let y = round(boundingBox.midY * 10) / 10
        return "\(x),\(y)"
    }
}

struct DetectedSignInfo {
    let lastBeepTime: Date
    let boundingBox: CGRect
    
    // Check if this is effectively the same location
    func isSameLocation(as boundingBox: CGRect, tolerance: CGFloat = 0.1) -> Bool {
        let dx = abs(self.boundingBox.midX - boundingBox.midX)
        let dy = abs(self.boundingBox.midY - boundingBox.midY)
        return dx <= tolerance && dy <= tolerance
    }
    
    // Check if enough time has passed since last beep
    func shouldBeepAgain(throttleInterval: TimeInterval = 30) -> Bool {
        return Date().timeIntervalSince(lastBeepTime) > throttleInterval
    }
}

class DetectedSignTracker {
    private var trackedSigns: [DetectedSignKey: DetectedSignInfo] = [:]
    private let throttleInterval: TimeInterval = 30 // 30 seconds between beeps
    private let locationTolerance: CGFloat = 0.1 // 10% of screen width/height
    
    // Check if we should beep for this sign
    func shouldBeep(label: String, boundingBox: CGRect) -> Bool {
        let key = DetectedSignKey(
            label: label,
            locationKey: DetectedSignKey.makeLocationKey(from: boundingBox)
        )
        
        // If we've never seen this sign or location, definitely beep
        guard let info = trackedSigns[key] else {
            trackedSigns[key] = DetectedSignInfo(lastBeepTime: Date(), boundingBox: boundingBox)
            return true
        }
        
        // If it's the same sign in roughly the same location
        if info.isSameLocation(as: boundingBox, tolerance: locationTolerance) {
            // Only beep if enough time has passed
            if info.shouldBeepAgain(throttleInterval: throttleInterval) {
                trackedSigns[key] = DetectedSignInfo(lastBeepTime: Date(), boundingBox: boundingBox)
                return true
            }
            return false
        }
        
        // New location for this sign type, beep and track it
        trackedSigns[key] = DetectedSignInfo(lastBeepTime: Date(), boundingBox: boundingBox)
        return true
    }
    
    // Clear old tracked signs (call periodically or when starting a new drive)
    func clearOldTrackedSigns() {
        let now = Date()
        trackedSigns = trackedSigns.filter { _, info in
            now.timeIntervalSince(info.lastBeepTime) <= throttleInterval * 2
        }
    }
}
