//
//  LocationManager.swift
//  CruiseAIios
//
//  Created by Ojas Kandhare on 4/3/25.
//

import Foundation
import CoreLocation
import Combine
import UIKit

class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    
    // Published properties for UI updates
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var location: CLLocation?
    @Published var speed: Double = 0.0 // Speed in meters per second
    @Published var speedKPH: Double = 0.0 // Speed in kilometers per hour
    @Published var speedMPH: Double = 0.0 // Speed in miles per hour
    @Published var isUpdatingLocation = false
    
    // Accuracy settings - maximum possible accuracy for precise speed measurement
    private let desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyBestForNavigation
    private let distanceFilter: CLLocationDistance = 0.5 // Update every 0.5 meters for more frequent updates
    
    // Speed calculation
    private var speedFilter = SpeedFilter()
    private var kalmanFilter = KalmanFilter() // More sophisticated filtering for higher accuracy
    
    // Speed limit tracking
    @Published var currentSpeedLimit: Double = 0.0 // in mph
    @Published var isOverSpeedLimit: Bool = false
    
    override init() {
        super.init()
        
        // Configure location manager
        locationManager.delegate = self
        locationManager.desiredAccuracy = desiredAccuracy
        locationManager.distanceFilter = distanceFilter
        locationManager.activityType = .automotiveNavigation
        
        // Check current authorization status
        authorizationStatus = locationManager.authorizationStatus
    }
    
    // Request location permissions - simplified to match camera permission approach
    func requestPermission() {
        print("Requesting location permission...")
        locationManager.requestWhenInUseAuthorization()
    }
    
    // Start location updates
    func startUpdatingLocation() {
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
            isUpdatingLocation = true
            print("Started updating location")
        } else {
            print("Cannot start location updates: not authorized")
            requestPermission()
        }
    }
    
    // Stop location updates
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        isUpdatingLocation = false
        print("Stopped updating location")
    }
    
    // Toggle location updates
    func toggleLocationUpdates() {
        if isUpdatingLocation {
            stopUpdatingLocation()
        } else {
            startUpdatingLocation()
        }
    }
    
    // Convert meters per second to kilometers per hour
    private func metersPerSecondToKPH(_ mps: Double) -> Double {
        return mps * 3.6
    }
    
    // Convert meters per second to miles per hour
    private func metersPerSecondToMPH(_ mps: Double) -> Double {
        return mps * 2.23694
    }
    
    // Update speed values with advanced filtering for maximum accuracy
    private func updateSpeed(_ speedMPS: Double) {
        // Apply both filters for optimal results
        // 1. Low-pass filter to remove high-frequency noise
        let lowPassFiltered = speedFilter.filter(speed: speedMPS)
        
        // 2. Kalman filter for statistical optimality
        let kalmanFiltered = kalmanFilter.filter(measurement: lowPassFiltered)
        
        // Use the Kalman filtered value for best accuracy
        let finalSpeed = kalmanFiltered
        
        DispatchQueue.main.async {
            self.speed = finalSpeed
            self.speedKPH = self.metersPerSecondToKPH(finalSpeed)
            self.speedMPH = self.metersPerSecondToMPH(finalSpeed)
            
            // Check if over speed limit
            if self.currentSpeedLimit > 0 && self.speedMPH > self.currentSpeedLimit {
                self.isOverSpeedLimit = true
                
                // Post notification for speed warning
                NotificationCenter.default.post(
                    name: NSNotification.Name("SpeedLimitExceeded"),
                    object: nil,
                    userInfo: ["speed": self.speedMPH, "limit": self.currentSpeedLimit]
                )
            } else {
                self.isOverSpeedLimit = false
            }
        }
    }
    
    // Get speed limit for current location
    func checkSpeedLimit(at location: CLLocation) {
        // In a real implementation, this would query a maps API
        // For now, we'll use a placeholder implementation
        
        // TODO: Implement actual speed limit lookup using MKMapItem or a maps API
        // This is a placeholder that sets random speed limits for demonstration
        let randomSpeedLimits = [25.0, 35.0, 45.0, 55.0, 65.0, 70.0]
        let randomIndex = Int.random(in: 0..<randomSpeedLimits.count)
        
        DispatchQueue.main.async {
            self.currentSpeedLimit = randomSpeedLimits[randomIndex]
            print("Speed limit set to: \(self.currentSpeedLimit) mph")
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    // Handle authorization status changes
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("Location permission granted")
            // Start updating location if we were trying to do so
            if isUpdatingLocation {
                startUpdatingLocation()
            }
        case .denied, .restricted:
            print("Location permission denied")
            isUpdatingLocation = false
        case .notDetermined:
            print("Location permission not determined")
        @unknown default:
            print("Unknown authorization status")
        }
    }
    
    // Handle location updates
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Update the location
        self.location = location
        
        // Get the speed from the location
        let speedMPS = max(0, location.speed) // Ensure non-negative speed
        updateSpeed(speedMPS)
        
        // Check speed limit at current location
        checkSpeedLimit(at: location)
        
        // Post notification for trip tracking
        NotificationCenter.default.post(name: NSNotification.Name("LocationUpdate"), object: location)
        
        // Print debug info
        print("Location update: \(location.coordinate), Speed: \(speedMPS) m/s, \(speedKPH) km/h, \(speedMPH) mph)")
        if currentSpeedLimit > 0 {
            print("Speed limit: \(currentSpeedLimit) mph, Over limit: \(isOverSpeedLimit)")
        }
    }
    
    // Handle location errors
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
}

// MARK: - Speed Filters

// Simple low-pass filter to smooth out speed readings
class SpeedFilter {
    private let alpha: Double = 0.3 // Filter coefficient (0-1), lower = more smoothing
    private var lastFilteredSpeed: Double = 0.0
    
    func filter(speed: Double) -> Double {
        // Apply low-pass filter: output = α × input + (1 - α) × lastOutput
        lastFilteredSpeed = alpha * speed + (1 - alpha) * lastFilteredSpeed
        return lastFilteredSpeed
    }
    
    func reset() {
        lastFilteredSpeed = 0.0
    }
}

// Kalman filter for more accurate speed measurements
// This is a simplified implementation of a Kalman filter specifically for speed
class KalmanFilter {
    // State variables
    private var x: Double = 0.0 // Estimated speed
    private var p: Double = 1.0 // Estimation error covariance
    
    // Filter parameters
    private let q: Double = 0.01 // Process noise covariance
    private let r: Double = 0.1  // Measurement noise covariance
    
    func filter(measurement: Double) -> Double {
        // Prediction step
        // x = x (no state transition for constant speed model)
        p = p + q
        
        // Update step
        let k = p / (p + r) // Kalman gain
        x = x + k * (measurement - x) // Update estimate
        p = (1 - k) * p // Update error covariance
        
        return x
    }
    
    func reset() {
        x = 0.0
        p = 1.0
    }
}
