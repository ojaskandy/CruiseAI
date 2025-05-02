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
import MapKit

public class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    
    // Published properties for UI updates
    @Published public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published public var location: CLLocation?
    @Published public var speed: Double = 0.0 // Speed in meters per second
    @Published public var speedKPH: Double = 0.0 // Speed in kilometers per hour
    @Published public var speedMPH: Double = 0.0 // Speed in miles per hour
    @Published public var isUpdatingLocation = false
    @Published public var heading: CLLocationDirection?
    @Published public var headingAccuracy: CLLocationDirectionAccuracy = 0.0
    
    // Accuracy settings - maximum possible accuracy for precise speed measurement
    private let desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyBestForNavigation
    private let distanceFilter: CLLocationDistance = 0.1 // Update every 0.1 meters for more frequent updates
    
    // Speed calculation
    private var speedFilter = SpeedFilter()
    private var kalmanFilter = KalmanFilter() // More sophisticated filtering for higher accuracy
    private var speedBuffer: [Double] = [] // Buffer for speed validation
    private let speedBufferSize = 5; // Number of speed readings to keep for validation
    private let maxSpeedChange = 10.0; // Maximum allowed speed change in m/s between updates
    private let minSpeedAccuracy: CLLocationAccuracy = 5.0 // Minimum required speed accuracy in m/s - increased threshold
    
    // Speed limit tracking
    @Published public var currentSpeedLimit: Double = 0.0 // in mph
    @Published public var isOverSpeedLimit: Bool = false
    
    // Trip statistics
    @Published public var totalDistance: Double = 0.0 // in meters
    @Published public var averageSpeed: Double = 0.0 // in meters per second
    @Published public var maxSpeed: Double = 0.0 // in meters per second
    private var tripStartTime: Date?
    private var lastLocation: CLLocation?
    private var speedReadings: [Double] = []
    private var speedSamplingTimer: Timer?
    private let speedSamplingInterval: TimeInterval = 0.5 // Sample speed every 0.5 seconds
    
    public override init() {
        super.init()
        
        // Configure location manager for maximum accuracy
        locationManager.delegate = self
        locationManager.desiredAccuracy = desiredAccuracy
        locationManager.distanceFilter = distanceFilter
        locationManager.activityType = .automotiveNavigation
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        
        // Enable heading updates for map navigation
        locationManager.headingFilter = 5 // Update every 5 degrees
        
        // Enable significant location changes for better background updates
        locationManager.startMonitoringSignificantLocationChanges()
        
        // Additional high-accuracy settings for iOS 14+
        if #available(iOS 14.0, *) {
            // Check if we have full accuracy authorization
            if locationManager.accuracyAuthorization != .fullAccuracy {
                print("Warning: Full location accuracy not authorized")
            }
        }
        
        // Check current authorization status
        authorizationStatus = locationManager.authorizationStatus
    }
    
    // Request location permissions - simplified to match camera permission approach
    public func requestPermission() {
        print("Requesting location permission...")
        locationManager.requestWhenInUseAuthorization()
    }
    
    // Start location updates
    public func startUpdatingLocation() {
        print("Attempting to start location updates. Current auth status: \(authorizationStatus)")
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            // Reset trip statistics
            totalDistance = 0.0
            averageSpeed = 0.0
            maxSpeed = 0.0
            tripStartTime = Date()
            lastLocation = nil
            speedReadings.removeAll()
            
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
            isUpdatingLocation = true
            print("Started updating location, heading, and reset trip statistics")
            
            // Force an initial speed update to make sure the speedometer shows something
            DispatchQueue.main.async {
                self.speed = 0.0
                self.speedKPH = 0.0
                self.speedMPH = 0.0
                print("Initial speed values set")
            }
            
            // Start speed sampling timer
            startSpeedSamplingTimer()
        } else {
            print("Cannot start location updates: not authorized")
            requestPermission()
        }
    }
    
    // Stop location updates
    public func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        isUpdatingLocation = false
        
        // Stop speed sampling timer
        stopSpeedSamplingTimer()
        
        // Calculate final trip statistics
        calculateFinalTripStatistics()
        print("Stopped updating location. Final trip statistics calculated")
    }
    
    // Toggle location updates
    public func toggleLocationUpdates() {
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
    
    // Update speed values with advanced filtering and validation
    private func updateSpeed(_ speedMPS: Double) {
        // Don't waste time if it's too low - just set to zero
        if speedMPS < 0.2 { // Below 0.2 m/s (~0.45 mph) just show zero
            DispatchQueue.main.async {
                self.speed = 0.0
                self.speedKPH = 0.0
                self.speedMPH = 0.0
            }
            return
        }
        
        // Add to speed buffer for smoothing
        speedBuffer.append(speedMPS)
        if speedBuffer.count > speedBufferSize {
            speedBuffer.removeFirst()
        }
        
        // Apply filters for optimal results
        
        // 1. Low-pass filter to remove high-frequency noise
        let lowPassFiltered = speedFilter.filter(speed: speedMPS)
        
        // 2. Kalman filter for statistical optimality
        let kalmanFiltered = kalmanFilter.filter(measurement: lowPassFiltered)
        
        // 3. Median filter (resistant to outliers) if we have enough samples
        var finalSpeed = kalmanFiltered
        if speedBuffer.count >= 3 {
            let medianFiltered = speedBuffer.sorted()
            finalSpeed = medianFiltered[speedBuffer.count / 2]
        }
        
        // Final sanity check - cap maximum speed to something reasonable
        finalSpeed = min(finalSpeed, 55.0) // Cap at ~125 mph
        
        // Update the published values on the main thread
        DispatchQueue.main.async {
            self.speed = finalSpeed
            self.speedKPH = self.metersPerSecondToKPH(finalSpeed)
            self.speedMPH = self.metersPerSecondToMPH(finalSpeed)
        }
    }
    
    // Check for speed limit at current location
    private func checkSpeedLimit(at location: CLLocation) {
        // Create a search request for the current location
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = "road"
        searchRequest.region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 50, longitudinalMeters: 50)
        
        // Perform the search
        let search = MKLocalSearch(request: searchRequest)
        search.start { [weak self] (response, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Error searching for road data: \(error.localizedDescription)")
                self.applyStaticSpeedLimit(35.0) // Fallback to default speed limit
                return
            }
            
            guard let mapItem = response?.mapItems.first else {
                print("No road data found")
                self.applyStaticSpeedLimit(35.0) // Fallback to default speed limit
                return
            }
            
            // Try to get speed limit from address dictionary
            if let addressDict = mapItem.placemark.addressDictionary,
               let speedLimitStr = addressDict["SpeedLimit"] as? String,
               let speedLimitMPH = Double(speedLimitStr) {
                DispatchQueue.main.async {
                    self.currentSpeedLimit = speedLimitMPH
                    self.isOverSpeedLimit = self.speedMPH > self.currentSpeedLimit
                    
                    if self.isOverSpeedLimit {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("SpeedLimitExceeded"),
                            object: nil,
                            userInfo: ["speed": self.speedMPH, "limit": self.currentSpeedLimit]
                        )
                    }
                }
            } else {
                // If no speed limit data is available, use a default value
                self.applyStaticSpeedLimit(35.0) // Default to 35 mph
            }
        }
    }
    
    // Apply a static speed limit if map data is unavailable
    private func applyStaticSpeedLimit(_ limit: Double) {
        // Only update if we don't already have a limit or it's significantly different
        if self.currentSpeedLimit == 0 || abs(limit - self.currentSpeedLimit) > 5.0 {
            DispatchQueue.main.async {
                self.currentSpeedLimit = limit
                print("Using static speed limit: \(self.currentSpeedLimit) mph")
                
                // Check if we're over the speed limit
                self.isOverSpeedLimit = self.speedMPH > self.currentSpeedLimit
                
                // Post notification for speed limit warning if we exceed the limit
                if self.isOverSpeedLimit {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SpeedLimitExceeded"),
                        object: nil,
                        userInfo: ["speed": self.speedMPH, "limit": self.currentSpeedLimit]
                    )
                }
            }
        }
    }
    
    // Start timer to sample speed at regular intervals
    private func startSpeedSamplingTimer() {
        // Stop any existing timer first
        stopSpeedSamplingTimer()
        
        // Create a new timer
        speedSamplingTimer = Timer.scheduledTimer(withTimeInterval: speedSamplingInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Only record speed if we're actually moving
            if self.speed > 0.1 {
                self.speedReadings.append(self.speed)
                print("Speed reading added: \(self.speed) m/s")
                
                // Update average speed on the fly
                if !self.speedReadings.isEmpty {
                    self.averageSpeed = self.speedReadings.reduce(0, +) / Double(self.speedReadings.count)
                    print("Updated average speed: \(self.averageSpeed) m/s")
                }
            }
        }
    }
    
    // Stop the speed sampling timer
    private func stopSpeedSamplingTimer() {
        speedSamplingTimer?.invalidate()
        speedSamplingTimer = nil
    }
    
    // Calculate final trip statistics
    private func calculateFinalTripStatistics() {
        guard let startTime = tripStartTime else { return }
        
        let tripDuration = Date().timeIntervalSince(startTime)
        if tripDuration > 0 {
            // Calculate average speed only if we have readings
            if !speedReadings.isEmpty {
                // Filter out zero readings for more accurate average
                let nonZeroSpeeds = speedReadings.filter { $0 > 0.1 }
                if !nonZeroSpeeds.isEmpty {
                    averageSpeed = nonZeroSpeeds.reduce(0, +) / Double(nonZeroSpeeds.count)
                    print("Final average speed calculated: \(averageSpeed) m/s from \(nonZeroSpeeds.count) readings")
                }
            }
            
            // Convert statistics to different units for easy access
            let avgSpeedKPH = metersPerSecondToKPH(averageSpeed)
            let avgSpeedMPH = metersPerSecondToMPH(averageSpeed)
            let maxSpeedKPH = metersPerSecondToKPH(maxSpeed)
            let maxSpeedMPH = metersPerSecondToMPH(maxSpeed)
            let distanceKM = totalDistance / 1000.0
            let distanceMiles = distanceKM * 0.621371
            
            // Create a formatted trip summary
            let summaryText = """
                🚗 My Trip Summary:
                ⏱ Duration: \(Int(tripDuration / 60)) minutes \(Int(tripDuration.truncatingRemainder(dividingBy: 60))) seconds
                📍 Distance: \(String(format: "%.2f", distanceKM)) km (\(String(format: "%.2f", distanceMiles)) miles)
                ⚡️ Average Speed: \(String(format: "%.1f", avgSpeedKPH)) km/h (\(String(format: "%.1f", avgSpeedMPH)) mph)
                🏃 Maximum Speed: \(String(format: "%.1f", maxSpeedKPH)) km/h (\(String(format: "%.1f", maxSpeedMPH)) mph)
                
                Tracked with CruiseAI 🚀
                """
            
            print(summaryText)
            
            // Create trip summary data for sharing
            let tripSummaryData: [String: Any] = [
                "duration": tripDuration,
                "distance": totalDistance,
                "averageSpeed": averageSpeed,
                "maxSpeed": maxSpeed,
                "summaryText": summaryText
            ]
            
            // Post trip summary notification with sharing data
            NotificationCenter.default.post(
                name: NSNotification.Name("TripSummary"),
                object: nil,
                userInfo: tripSummaryData
            )
        }
    }
    
    // Share trip summary
    public func shareTripSummary() {
        guard let startTime = tripStartTime else { return }
        
        let tripDuration = Date().timeIntervalSince(startTime)
        let avgSpeedMPH = metersPerSecondToMPH(averageSpeed)
        let maxSpeedMPH = metersPerSecondToMPH(maxSpeed)
        let distanceMiles = (totalDistance / 1000.0) * 0.621371
        
        let summaryText = """
        🚗 My Trip with CruiseAI:
        ⏱ Duration: \(Int(tripDuration / 60)) minutes \(Int(tripDuration.truncatingRemainder(dividingBy: 60))) seconds
        📍 Distance: \(String(format: "%.2f", distanceMiles)) miles
        ⚡️ Average Speed: \(String(format: "%.1f", avgSpeedMPH)) mph
        🏃 Maximum Speed: \(String(format: "%.1f", maxSpeedMPH)) mph
        
        Tracked with CruiseAI 🚀
        """
        
        // Create activity view controller for sharing
        let activityViewController = UIActivityViewController(
            activityItems: [summaryText],
            applicationActivities: nil
        )
        
        // Post notification for presenting share sheet
        NotificationCenter.default.post(
            name: NSNotification.Name("PresentShareSheet"),
            object: activityViewController
        )
    }
    
    // Add a reset method for the trip statistics
    public func resetTripStatistics() {
        totalDistance = 0.0
        averageSpeed = 0.0
        maxSpeed = 0.0
        tripStartTime = Date()
        lastLocation = nil
        speedReadings.removeAll()
        print("Trip statistics reset")
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    // Handle authorization status changes
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
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
    
    // Handle location updates with improved accuracy checks
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Apply strict filtering to avoid phantom movements and erratic speed readings
        guard location.horizontalAccuracy <= 10.0 else {
            print("Location accuracy too low: \(location.horizontalAccuracy)m - REJECTED")
            return
        }
        
        // Update the location and calculate distance
        if let lastLocation = self.lastLocation {
            let distance = location.distance(from: lastLocation)
            let timeDelta = location.timestamp.timeIntervalSince(lastLocation.timestamp)
            
            let impliedSpeed = timeDelta > 0 ? distance / timeDelta : 0
            
            if distance >= 1.0 && impliedSpeed <= 55.0 && timeDelta >= 0.1 {
                totalDistance += distance
                
                // Add the speed to readings regardless of filtering
                if impliedSpeed > 0 {
                    speedReadings.append(impliedSpeed)
                    
                    // Update max speed if this is the highest we've seen
                    if impliedSpeed > maxSpeed {
                        maxSpeed = impliedSpeed
                        print("New max speed: \(String(format: "%.2f", metersPerSecondToMPH(maxSpeed))) mph")
                    }
                }
                
                print("Added distance: \(String(format: "%.2f", distance))m, Total: \(String(format: "%.2f", totalDistance))m")
            } else if distance > 0 {
                print("Filtered out suspicious movement: \(String(format: "%.2f", distance))m, implied speed: \(String(format: "%.2f", impliedSpeed))m/s")
            }
        }
        
        self.lastLocation = location
        self.location = location
        
        // Speed validation and processing
        if location.speed >= 0 {
            let rawSpeedMPS = location.speed
            let speedIsAccurate = location.speedAccuracy <= 0.5
            let speedIsPlausible = rawSpeedMPS <= 55.0
            
            if speedIsPlausible {
                // Always record the speed for statistics
                speedReadings.append(rawSpeedMPS)
                
                // Update max speed if this is higher
                if rawSpeedMPS > maxSpeed {
                    maxSpeed = rawSpeedMPS
                    print("New max speed: \(String(format: "%.2f", metersPerSecondToMPH(maxSpeed))) mph")
                }
                
                if speedIsAccurate {
                    updateSpeed(rawSpeedMPS)
                    print("Speed updated: \(String(format: "%.2f", rawSpeedMPS)) m/s, Accuracy: \(String(format: "%.2f", location.speedAccuracy)) m/s")
                }
                
                checkSpeedLimit(at: location)
                NotificationCenter.default.post(name: NSNotification.Name("LocationUpdate"), object: location)
            }
        }
    }
    
    // Handle location errors
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
        
        // Add specific error handling for common location errors
        switch error {
        case let clError as CLError:
            switch clError.code {
            case .denied:
                print("Location access denied - prompt user to enable in settings")
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("LocationAccessDenied"), object: nil)
                }
            case .network:
                print("Network error - check connectivity")
                resetLocationService(after: 5.0)
            default:
                print("CLError: \(clError.code.rawValue)")
            }
        default:
            break
        }
    }
    
    // Reset location service after error
    private func resetLocationService(after seconds: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            if self.isUpdatingLocation {
                self.stopUpdatingLocation()
                self.startUpdatingLocation()
                print("Location service reset after error")
            }
        }
    }
    
    // Handle heading updates
    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Filter out low accuracy headings
        guard newHeading.headingAccuracy >= 0 && newHeading.headingAccuracy <= 45 else {
            print("Heading accuracy too low: \(newHeading.headingAccuracy) degrees - REJECTED")
            return
        }
        
        // Use true heading when available, fallback to magnetic heading
        let headingValue = newHeading.trueHeading > 0 ? newHeading.trueHeading : newHeading.magneticHeading
        
        DispatchQueue.main.async {
            self.heading = headingValue
            self.headingAccuracy = newHeading.headingAccuracy
            
            // Notify that heading was updated
            NotificationCenter.default.post(
                name: NSNotification.Name("HeadingUpdate"),
                object: newHeading
            )
        }
    }
}

// MARK: - Speed Filters

// Simple low-pass filter to smooth out speed readings
public class SpeedFilter {
    private let alpha: Double = 0.3 // Filter coefficient (0-1), lower = more smoothing
    private var lastFilteredSpeed: Double = 0.0
    
    public func filter(speed: Double) -> Double {
        // Apply low-pass filter: output = α × input + (1 - α) × lastOutput
        lastFilteredSpeed = alpha * speed + (1 - alpha) * lastFilteredSpeed
        return lastFilteredSpeed
    }
    
    public func reset() {
        lastFilteredSpeed = 0.0
    }
}

// Kalman filter for more accurate speed measurements
// This is a simplified implementation of a Kalman filter specifically for speed
public class KalmanFilter {
    // State variables
    private var x: Double = 0.0 // Estimated speed
    private var p: Double = 1.0 // Estimation error covariance
    
    // Filter parameters - adjusted for better balance
    private let q: Double = 0.03 // Process noise covariance (lower = more smoothing)
    private let r: Double = 0.1 // Measurement noise covariance (higher = less trust in measurements)
    
    public func filter(measurement: Double) -> Double {
        // Prediction step
        // x = x (no state transition for constant speed model)
        p = p + q
        
        // Update step
        let k = p / (p + r) // Kalman gain
        x = x + k * (measurement - x) // Update estimate
        p = (1 - k) * p // Update error covariance
        
        return x
    }
    
    public func reset() {
        x = 0.0
        p = 1.0
    }
}
