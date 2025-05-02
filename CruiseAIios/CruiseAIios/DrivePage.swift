//
//  DrivePage.swift
//  CruiseAIios
//
//  Created by Cline on 4/5/25.
//

import SwiftUI
import AVFoundation
import UIKit
import Vision
import AudioToolbox
import MapKit
import CoreLocation

// MARK: - Extensions

// Add this extension to handle global navigation
extension View {
    func popToRootView() {
        let keyWindow = UIApplication.shared.connectedScenes
            .filter({$0.activationState == .foregroundActive})
            .compactMap({$0 as? UIWindowScene})
            .first?.windows
            .filter({$0.isKeyWindow}).first
        
        keyWindow?.rootViewController?.dismiss(animated: true, completion: nil)
    }
}

// ShareSheet for UIActivityViewController
struct DriveShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Design Constants

private struct DesignConstants {
    static let backgroundGradient = LinearGradient(
        colors: [Color(hex: "0A0A23"), Color(hex: "151538")],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let glassBackground = Color.black.opacity(0.2)
    static let glassBorder = Color.white.opacity(0.1)
    static let glassBlur: CGFloat = 10
    
    static let actionGradient = LinearGradient(
        colors: [Color(hex: "00C853"), Color(hex: "69F0AE")],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let warningGradient = LinearGradient(
        colors: [Color(hex: "FF3D00"), Color(hex: "FF9100")],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// Add TripStore for storing trip data locally
// Removing this whole class since it's already defined in TripStore.swift

public struct DrivePage: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var cameraManager = DrivePageCameraManager()
    @StateObject private var locationManager = LocationManager()
    @ObservedObject var appState: AppState
    
    // State variables
    @State private var showingExitAlert = false
    @State private var showingTripSummary = false
    @State private var mapTrackingMode: MKUserTrackingMode = .follow
    
    // Navigation state
    @State private var showingSearchSheet = false
    @State private var searchQuery = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedDestination: MKMapItem?
    @State private var route: MKRoute?
    @State private var showingDirections = false
    @State private var currentStepIndex = 0
    @State private var estimatedArrival: Date?
    @State private var remainingDistance: CLLocationDistance = 0
    @State private var remainingTime: TimeInterval = 0
    
    // Trip tracking
    @State private var showingShareSheet = false
    @State private var tripStartTime: Date?
    @State private var tripEndTime: Date?
    @State private var tripDistance: Double = 0.0
    @State private var tripTopSpeed: Double = 0.0
    @State private var tripAvgSpeed: Double = 0.0
    @State private var speedReadings: [Double] = []
    @State private var locationHistory: [CLLocationCoordinate2D] = []
    
    // Speed warning
    @State private var showingSpeedWarning = false
    @State private var speedWarningOpacity = 0.0
    
    // Camera view properties
    @State private var cameraViewOpacity = 1.0
    
    // Function to pop to root view (home page) - simplify this
    func navigateToHomePage() {
        presentationMode.wrappedValue.dismiss()
    }
    
    // Public initializer to ensure it's accessible from other modules
    public init(appState: AppState) {
        self.appState = appState
    }
    
    public var body: some View {
        ZStack {
            // Theme-based gradient background
            LinearGradient(
                gradient: Gradient(colors: appState.theme.gradientColors),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            .animation(.easeInOut(duration: 0.5), value: appState.theme.id)
            
            if !cameraManager.isAuthorized {
                // Modern camera permission view
                VStack(spacing: 20) {
                    Spacer()
                    
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.9))
                        .padding()
                        .background(
                            Color.white.opacity(0.15)
                                .overlay(
                                    Color.white.opacity(0.1)
                                        .blur(radius: DesignConstants.glassBlur)
                                )
                        )
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.2), radius: 15)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    
                    Text("Camera Access Required")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Please grant permission to access your camera for object detection and safety features.")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    // Camera access button
                    Button {
                        // Request camera permission using AVCaptureDevice API directly
                        AVCaptureDevice.requestAccess(for: .video) { granted in
                            DispatchQueue.main.async {
                                if granted {
                                    self.cameraManager.isAuthorized = true
                                    self.cameraManager.setupCaptureSession()
                                } else {
                                    // Show alert to direct user to settings if denied
                                    print("Camera permission denied. User should go to Settings.")
                                }
                            }
                        }
                    } label: {
                        Text("Allow Camera Access")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .padding()
                            .frame(maxWidth: 250)
                            .background(DesignConstants.actionGradient)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: Color.green.opacity(0.3), radius: 10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                    
                    Spacer()
                }
                .padding()
                .background(DesignConstants.backgroundGradient)
            } else {
                // Replace camera feed with map view
                MapView(locationManager: locationManager, 
                       route: route, 
                       onAnnotationTapped: { mapItem in
                           calculateRoute(to: mapItem)
                       })
                    .edgesIgnoringSafeArea(.all)
                
                // Map controls overlay
                MapControlsOverlay(trackingMode: $mapTrackingMode)
                    .edgesIgnoringSafeArea(.all)
                
                // Directions overlay when navigating
                if showingDirections, let route = route {
                    DirectionsOverlay(
                        route: route,
                        currentStepIndex: $currentStepIndex,
                        remainingDistance: remainingDistance,
                        remainingTime: remainingTime,
                        estimatedArrival: estimatedArrival,
                        onDismiss: {
                            withAnimation {
                                self.showingDirections = false
                                self.route = nil
                            }
                        }
                    )
                }
                
                // Search button overlay at top
                VStack {
                    HStack {
                        // Back button
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showingExitAlert = true
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        
                        // Search bar button
                        Button(action: {
                            showingSearchSheet = true
                        }) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.white)
                                
                                Text("Search for a destination")
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineLimit(1)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(20)
                        }
                        
                        Spacer()
                        
                        // Current speed limit if available
                        if locationManager.currentSpeedLimit > 0 {
                            SpeedLimitView(speedLimit: locationManager.currentSpeedLimit,
                                           isOverLimit: locationManager.isOverSpeedLimit)
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Bottom area with speedometer and controls
                    VStack(spacing: 15) {
                        // Enhanced speedometer
                        EnhancedSpeedometerView(
                            speed: locationManager.speedMPH,
                            maxSpeed: 120,
                            useMetric: false,
                            theme: appState.theme,
                            rawSpeedMetersPerSecond: locationManager.speed,
                            currentSpeedLimit: locationManager.currentSpeedLimit
                        )
                        .frame(height: 120)
                        
                        // Trip statistics display
                        TripStatisticsView(
                            distance: locationManager.totalDistance,
                            averageSpeed: locationManager.averageSpeed,
                            maxSpeed: locationManager.maxSpeed,
                            useMetric: false
                        )
                        
                        // Stop Drive button
                        Button(action: {
                            withAnimation {
                                stopDrive()
                            }
                        }) {
                            Text("Stop Drive")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(DesignConstants.warningGradient)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                        }
                        .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.black.opacity(0.7))
                }
                .edgesIgnoringSafeArea(.bottom)
                
                // Speed warning overlay
                if showingSpeedWarning {
                    SpeedWarningView(opacity: $speedWarningOpacity)
                }
                
                // Trip summary sheet
                if showingTripSummary {
                    // Remove this inline instance as we're using a sheet instead
                }
            }
        }
        .navigationBarTitle("Drive", displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading: Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showingExitAlert = true
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                    Text("Back")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Color.white.opacity(0.15)
                        .overlay(
                            Color.white.opacity(0.1)
                                .blur(radius: DesignConstants.glassBlur)
                        )
                )
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.2), radius: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
        )
        .alert(isPresented: $showingExitAlert) {
            Alert(
                title: Text("Drive in Progress"),
                message: Text("Are you sure you want to exit? Your current drive will be stopped."),
                primaryButton: .destructive(Text("Exit")) {
                    presentationMode.wrappedValue.dismiss()
                },
                secondaryButton: .cancel()
            )
        }
        .onAppear {
            // Initialize location services
            print("DrivePage appeared - starting location services")
            
            // Location setup
            locationManager.requestPermission()
            locationManager.resetTripStatistics()
            locationManager.startUpdatingLocation()
            
            // Set trip start time
            tripStartTime = Date()
            
            // Print debug info
            print("Location services initialized")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SpeedLimitExceeded"))) { _ in
            displaySpeedWarning()
        }
        .sheet(isPresented: $showingTripSummary, onDismiss: {
            // Dismiss the drive page to return to homepage when trip summary is closed
            presentationMode.wrappedValue.dismiss()
        }) {
            DriveTripSummaryView(
                isPresented: $showingTripSummary,
                startTime: tripStartTime ?? Date(),
                endTime: tripEndTime ?? Date(),
                distance: tripDistance,
                avgSpeed: tripAvgSpeed,
                maxSpeed: tripTopSpeed
            )
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showingSearchSheet) {
            NavigationView {
                SearchView(searchQuery: $searchQuery, searchResults: $searchResults, onSelectDestination: { mapItem in
                    selectedDestination = mapItem
                    showingSearchSheet = false
                    calculateRoute(to: mapItem)
                })
                .navigationTitle("Search Destination")
                .navigationBarItems(trailing: Button("Cancel") {
                    showingSearchSheet = false
                })
            }
            .preferredColorScheme(.dark)
        }
        .onReceive(locationManager.$location) { location in
            // Update navigation progress when we have an active route
            if showingDirections, let location = location, let route = route {
                updateNavigationProgress(userLocation: location, route: route)
            }
        }
    }
    
    private func calculateTripStatistics() {
        guard let startTime = tripStartTime else { return }
        
        // Calculate trip duration
        let duration = tripEndTime?.timeIntervalSince(startTime) ?? 0
        
        // Calculate average speed - only use non-zero readings to avoid skewing the average
        let validSpeedReadings = speedReadings.filter { $0 > 0.1 }
        if !validSpeedReadings.isEmpty {
            tripAvgSpeed = validSpeedReadings.reduce(0, +) / Double(validSpeedReadings.count)
        } else {
            tripAvgSpeed = 0
        }
        
        // Get top speed - filter out unrealistic values (> 50 m/s or ~112 mph)
        let filteredSpeedReadings = speedReadings.filter { $0 > 0.1 && $0 < 50.0 }
        tripTopSpeed = filteredSpeedReadings.max() ?? 0
        
        // Instead of trying to calculate from location history, use the total distance 
        // from the LocationManager which has better filtering
        tripDistance = locationManager.totalDistance
        
        print("Trip Statistics:")
        print("Duration: \(duration) seconds")
        print("Average Speed: \(tripAvgSpeed) m/s")
        print("Top Speed: \(tripTopSpeed) m/s")
        print("Total Distance: \(tripDistance) meters")
    }
    
    private func stopDrive() {
        // Stop camera and location tracking
        cameraManager.stopCaptureSession()
        locationManager.stopUpdatingLocation()
        
        // Record trip end time
        tripEndTime = Date()
        
        // Calculate trip statistics
        calculateTripStatistics()
        
        // Save trip to local storage
        if let startTime = tripStartTime, let endTime = tripEndTime {
            // Much lower minimum distance threshold (from 10m to 1m) to ensure all trips are saved
            // Most trips should be significantly longer, but this catches even very short ones
            if tripDistance > 1.0 {
                // Always save the trip to history regardless of distance
                appState.tripStore.saveTrip(
                    startTime: startTime,
                    endTime: endTime,
                    distance: tripDistance,
                    avgSpeed: tripAvgSpeed,
                    maxSpeed: tripTopSpeed
                )
                print("Trip saved to history with distance: \(tripDistance)m")
            } else if endTime.timeIntervalSince(startTime) > 10 {
                // If the trip lasted at least 10 seconds, save it even with minimal distance
                // This catches trips where GPS didn't register movement but the app was running
                appState.tripStore.saveTrip(
                    startTime: startTime,
                    endTime: endTime,
                    distance: max(1.0, tripDistance), // Ensure at least 1m distance is recorded
                    avgSpeed: tripAvgSpeed,
                    maxSpeed: tripTopSpeed
                )
                print("Trip saved to history based on duration: \(endTime.timeIntervalSince(startTime))s")
            } else {
                print("Trip not saved - too short distance (\(tripDistance)m) and duration (\(endTime.timeIntervalSince(startTime))s)")
            }
        } else {
            // If missing start or end time, create default values and still save the trip
            let actualStartTime = tripStartTime ?? Date().addingTimeInterval(-60) // Default to 1 minute ago
            let actualEndTime = tripEndTime ?? Date()
            
            appState.tripStore.saveTrip(
                startTime: actualStartTime,
                endTime: actualEndTime,
                distance: max(1.0, tripDistance),
                avgSpeed: tripAvgSpeed,
                maxSpeed: tripTopSpeed
            )
            print("Trip saved with default timing values")
        }
        
        // Show trip summary
        showingTripSummary = true
    }
    
    private func displaySpeedWarning() {
        guard !showingSpeedWarning else { return }
        
        showingSpeedWarning = true
        
        withAnimation(.easeIn(duration: 0.3)) {
            speedWarningOpacity = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                speedWarningOpacity = 0.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showingSpeedWarning = false
            }
        }
    }
    
    private func setupCaptureSession() {
        print("DrivePage: Setting up capture session")
        
        // Avoid setup if already running
        if cameraManager.captureSession?.isRunning == true {
            print("DrivePage: Capture session already running")
            return
        }
        
        // Get camera authorization first
        cameraManager.checkCameraPermission { authorized in
            if authorized {
                print("DrivePage: Camera permission granted, starting session")
                DispatchQueue.global(qos: .userInitiated).async {
                    self.cameraManager.setupCaptureSession()
                    
                    // Verify the session started
                    DispatchQueue.main.async {
                        if self.cameraManager.captureSession?.isRunning == true {
                            print("DrivePage: Capture session successfully started")
                            
                            // Enable object detection processing
                            self.cameraManager.modelIntegration.processingEnabled = true
                            print("DrivePage: Object detection enabled")
                        } else {
                            print("⚠️ DrivePage: Capture session failed to start")
                        }
                    }
                }
            } else {
                print("⚠️ DrivePage: Camera permission denied")
            }
        }
    }
    
    // Calculate a route to the destination
    private func calculateRoute(to destination: MKMapItem) {
        guard let userLocation = locationManager.location else {
            print("Cannot calculate route: user location unknown")
            return
        }
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation.coordinate))
        request.destination = destination
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            if let error = error {
                print("Error calculating route: \(error.localizedDescription)")
                return
            }
            
            guard let route = response?.routes.first else {
                print("No route found")
                return
            }
            
            // Store the route and initialize navigation
            self.route = route
            self.estimatedArrival = Date().addingTimeInterval(route.expectedTravelTime)
            self.remainingDistance = route.distance
            self.remainingTime = route.expectedTravelTime
            self.currentStepIndex = 0
            self.showingDirections = true
            
            // Log the calculated route
            print("Route calculated: \(route.steps.count) steps, \(Int(route.distance)) meters, \(Int(route.expectedTravelTime / 60)) minutes")
        }
    }
    
    // Update navigation progress based on user location
    private func updateNavigationProgress(userLocation: CLLocation, route: MKRoute) {
        // Skip if we don't have a valid route
        guard route.steps.count > currentStepIndex else { return }
        
        // Get current step and check if we've completed it
        let currentStep = route.steps[currentStepIndex]
        let currentStepEndCoordinate = currentStep.polyline.points()[currentStep.polyline.pointCount - 1].coordinate
        let distanceToStepEnd = userLocation.distance(from: CLLocation(latitude: currentStepEndCoordinate.latitude, longitude: currentStepEndCoordinate.longitude))
        
        // If within 20 meters of step end, advance to next step
        if distanceToStepEnd < 20.0 && currentStepIndex < route.steps.count - 1 {
            currentStepIndex += 1
            
            // Provide haptic feedback for step completion
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
        
        // Calculate remaining distance and time
        var remainingDistance: CLLocationDistance = 0
        for i in currentStepIndex..<route.steps.count {
            remainingDistance += route.steps[i].distance
        }
        
        // Calculate remaining time (proportional to remaining distance)
        let distanceRatio = remainingDistance / route.distance
        let remainingTime = route.expectedTravelTime * distanceRatio
        
        // Update navigation state
        self.remainingDistance = remainingDistance
        self.remainingTime = remainingTime
        self.estimatedArrival = Date().addingTimeInterval(remainingTime)
    }
}

// Camera manager for DrivePage to handle permissions and camera setup
class DrivePageCameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var isAuthorized = false
    @Published var detectedObjects: [DetectedObject] = []
    @Published var detectionCount: Int = 0
    @Published var lastDetectedObjectTypes: Set<String> = []
    
    var captureSession: AVCaptureSession?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    let modelIntegration = ModelIntegration() // Model integration for object detection
    
    // Debug properties
    private var frameCounter: Int = 0
    private var lastFrameReportTime = Date()
    private let frameReportInterval: TimeInterval = 5.0 // Report FPS every 5 seconds
    
    override init() {
        super.init()
        print("DrivePageCameraManager initialized")
        
        // Register for notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleObjectsDetected),
            name: NSNotification.Name("ObjectsDetected"),
            object: nil
        )
        
        checkCameraPermission() // Check permission immediately
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleObjectsDetected(notification: Notification) {
        if let count = notification.userInfo?["count"] as? Int {
            DispatchQueue.main.async {
                self.detectionCount = count
            }
        }
    }
    
    func checkCameraPermission(completion: ((Bool) -> Void)? = nil) {
        print("Checking camera permission")
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            print("Camera permission already authorized")
            self.isAuthorized = true
            DispatchQueue.main.async {
                self.setupCaptureSession() // Setup capture session immediately when authorized
            }
            completion?(true)
        case .notDetermined:
            print("Camera permission not determined, requesting...")
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                print("Camera permission response: \(granted)")
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted {
                        self?.setupCaptureSession()
                    }
                    completion?(granted)
                }
            }
        default:
            print("Camera permission denied or restricted")
            self.isAuthorized = false
            completion?(false)
        }
    }
    
    func setupCaptureSession() {
        print("Setting up capture session")
        
        // Ensure we're on a background thread for AVCaptureSession configuration
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, self.isAuthorized else {
                print("Not authorized to setup capture session")
                return
            }
            
            // Check if we already have a running session
            if let existingSession = self.captureSession, existingSession.isRunning {
                print("Capture session already running, not creating a new one")
                return
            }
            
            // Create a new session
        let session = AVCaptureSession()
            session.beginConfiguration()
        session.sessionPreset = .high
        
            do {
                // Set up camera input
                guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                    print("Failed to get back camera")
            return
        }
                
                let input = try AVCaptureDeviceInput(device: camera)
        
        // Configure camera for better performance
                try camera.lockForConfiguration()
            
            // Enable auto-focus
                if camera.isFocusModeSupported(.continuousAutoFocus) {
                    camera.focusMode = .continuousAutoFocus
            }
            
            // Enable auto-exposure
                if camera.isExposureModeSupported(.continuousAutoExposure) {
                    camera.exposureMode = .continuousAutoExposure
                }
                
                camera.unlockForConfiguration()
                print("Camera configured for high performance")
            
            if session.canAddInput(input) {
                session.addInput(input)
                    print("Added camera input")
            } else {
                    print("ERROR: Could not add camera input")
            return
        }
        
                // Set up video output
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
                    self.videoDataOutput = videoOutput
                    print("Added video output")
        } else {
                    print("ERROR: Could not add video output")
            return
        }
        
                session.commitConfiguration()
                
                // Store session reference
        self.captureSession = session
                
                // Start running on main thread
                DispatchQueue.main.async {
                    session.startRunning()
                    print("Camera capture session started")
                    
                    // Reset object detection when starting new session
                    self.modelIntegration.resetObjectDetection()
                    
                    // Force refresh to update the camera view
                    self.objectWillChange.send()
                }
            } catch {
                print("Error setting up capture session: \(error.localizedDescription)")
            }
        }
    }
    
    func stopCaptureSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
            print("Camera capture session stopped")
        }
    }
    
    // Handle video frames
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Count frames for FPS debugging
        frameCounter += 1
        let now = Date()
        if now.timeIntervalSince(lastFrameReportTime) >= frameReportInterval {
            let fps = Double(frameCounter) / now.timeIntervalSince(lastFrameReportTime)
            print("Camera FPS: \(String(format: "%.1f", fps))")
            frameCounter = 0
            lastFrameReportTime = now
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { 
            print("Error: Could not get pixel buffer from sample buffer")
            return 
        }
        
        // Check if the buffer is completely black/covered
        if isBufferBlank(pixelBuffer) {
            // Camera is likely covered - don't process for detections
            print("Camera appears to be covered or in complete darkness - skipping detection")
            DispatchQueue.main.async {
                // Clear existing detections when camera is covered
                self.detectedObjects = []
                self.lastDetectedObjectTypes = []
            }
            return
        }
        
        // Process frame for object detection using ModelIntegration
        modelIntegration.processFrame(pixelBuffer)
        
        // Get detected objects from the model integration
        DispatchQueue.main.async {
            // Validate detections before displaying
            let validDetections = self.validateDetections(self.modelIntegration.detectedObjects)
            self.detectedObjects = validDetections
            
            if !self.detectedObjects.isEmpty {
                // Update set of detected object types
                let objectTypes = Set(self.detectedObjects.map { $0.label })
                self.lastDetectedObjectTypes = objectTypes
                
                // Log detected objects
                let objectLabels = self.detectedObjects.map { "\($0.label) (\(Int($0.confidence * 100))%)" }
                print("Detected objects: \(objectLabels.joined(separator: ", "))")
            }
        }
    }
    
    // Check if a pixel buffer is completely black/dark (camera covered)
    private func isBufferBlank(_ pixelBuffer: CVPixelBuffer) -> Bool {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        // Get dimensions
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        // Sample a few points in the image
        let sampleCount = 5
        var totalBrightness: Int = 0
        
        // Get base address
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return false
        }
        
        // Get bytes per row for stride calculations
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        // Sample points in a grid pattern - using CGFloat for division
        for x in stride(from: 0, to: width, by: max(1, width/sampleCount)) {
            for y in stride(from: 0, to: height, by: max(1, height/sampleCount)) {
                // Calculate offset
                let offset = y * bytesPerRow + x * 4 // Assuming 4 bytes per pixel (RGBA or similar)
                
                // Read pixel brightness (approximation, using first byte for simplicity)
                let pixelPtr = baseAddress.advanced(by: offset).assumingMemoryBound(to: UInt8.self)
                let brightness = Int(pixelPtr.pointee)
                totalBrightness += brightness
            }
        }
        
        // Calculate average brightness
        let totalSamples = sampleCount * sampleCount
        let avgBrightness = totalBrightness / totalSamples
        
        // Consider the image blank if average brightness is very low
        let isBlank = avgBrightness < 10 // Threshold for "too dark"
        
        return isBlank
    }
    
    // Validate detections to prevent false positives
    private func validateDetections(_ detections: [DetectedObject]) -> [DetectedObject] {
        // Filter out low-confidence detections or those with unrealistic proportions
        return detections.filter { detection in
            // Minimum confidence threshold
            guard detection.confidence > 0.5 else { return false }
            
            // Check for reasonable bounding box size
            let boxArea = detection.boundingBox.width * detection.boundingBox.height
            let isReasonableSize = boxArea > 0.001 && boxArea < 0.9 // Between 0.1% and 90% of frame
            
            // Check for reasonable aspect ratio
            let aspectRatio = detection.boundingBox.width / detection.boundingBox.height
            let hasReasonableRatio = aspectRatio > 0.2 && aspectRatio < 5.0
            
            return isReasonableSize && hasReasonableRatio
        }
    }
}

// Camera view for live feed
struct DriveCameraView: UIViewRepresentable {
    @ObservedObject var cameraManager: DrivePageCameraManager
    var detectedObjects: [DetectedObject]
    
    func makeUIView(context: Context) -> UIView {
        print("DriveCameraView: makeUIView called")
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black
        
        // Set up the camera preview layer
        setupPreviewLayer(on: view)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Check if the preview layer exists and is correctly configured
        if uiView.layer.sublayers?.contains(where: { $0 is AVCaptureVideoPreviewLayer }) != true {
            print("DriveCameraView: No preview layer found, setting up")
            setupPreviewLayer(on: uiView)
        } else if let previewLayer = uiView.layer.sublayers?.first(where: { $0 is AVCaptureVideoPreviewLayer }) as? AVCaptureVideoPreviewLayer,
                  previewLayer.session != cameraManager.captureSession {
            // Remove old preview layer if session changed
            previewLayer.removeFromSuperlayer()
            setupPreviewLayer(on: uiView)
        }
        
        // Update the layer size to match the view's bounds
        if let previewLayer = uiView.layer.sublayers?.first(where: { $0 is AVCaptureVideoPreviewLayer }) as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
    
    private func setupPreviewLayer(on view: UIView) {
        // Remove any existing preview layers first
        view.layer.sublayers?.filter { $0 is AVCaptureVideoPreviewLayer }.forEach { $0.removeFromSuperlayer() }
        
        // Only set up if we have a valid, running capture session
        guard let captureSession = cameraManager.captureSession else {
            print("⚠️ DriveCameraView: No capture session available")
            return
        }
        
            let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
            previewLayer.frame = view.bounds
        
        // Set proper video orientation
        if let connection = previewLayer.connection {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }
        
        view.layer.addSublayer(previewLayer)
        print("DriveCameraView: Preview layer set up successfully")
    }
}

// Overlay showing bounding boxes for detected objects
struct DetectedObjectsOverlay: View {
    var detectedObjects: [DetectedObject]
    @State private var isPulsing = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(detectedObjects, id: \.id) { object in
                    let rect = boundingBoxToScreenRect(object.boundingBox, in: geometry.size)
                    
                    // Bounding box
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(color(for: object.label), lineWidth: 3)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.white, lineWidth: 1)
                                .frame(width: rect.width - 2, height: rect.height - 2)
                                .position(x: rect.midX, y: rect.midY)
                                .opacity(isPulsing ? 0.8 : 0.3)
                        )
                        .scaleEffect(isHighPriority(object.label) && isPulsing ? 1.05 : 1.0)
                    
                    // Label above the box
                    VStack(spacing: 2) {
                        Text(object.label)
                            .font(.system(size: 16, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(color(for: object.label).opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        
                        Text("\(Int(object.confidence * 100))%")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                    .position(x: rect.midX, y: max(rect.minY - 30, 30))
                    .shadow(color: Color.black.opacity(0.5), radius: 3)
                }
            }
            .onChange(of: detectedObjects.count) { newCount in
                if newCount > 0 && isHighPriorityObjectDetected() {
                    // Provide haptic feedback for high priority objects
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
            }
            .onAppear {
                // Start pulsing animation
                withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
    }
    
    private func isHighPriorityObjectDetected() -> Bool {
        for object in detectedObjects {
            if isHighPriority(object.label) {
                return true
            }
        }
        return false
    }
    
    private func isHighPriority(_ label: String) -> Bool {
        let lowercaseLabel = label.lowercased()
        return lowercaseLabel == "person" || lowercaseLabel == "stop sign"
    }
    
    private func boundingBoxToScreenRect(_ boundingBox: CGRect, in size: CGSize) -> CGRect {
        // Convert normalized coordinates to screen coordinates
        let x = boundingBox.minX * size.width
        let y = boundingBox.minY * size.height
        let width = boundingBox.width * size.width
        let height = boundingBox.height * size.height
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    private func color(for label: String) -> Color {
        switch label.lowercased() {
        case "person":
            return .red
        case "stop sign":
            return .red
        case "traffic light":
            return .yellow
        case "bicycle", "motorcycle":
            return .green
        case "car":
            return .orange
        default:
            return .blue
        }
    }
}

// Detection indicator view
struct DetectionIndicator: View {
    var objectType: String
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 4) {
            // Icon
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
            
            // Label
            Text(displayName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(backgroundColor.opacity(isAnimating ? 0.8 : 0.6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: backgroundColor.opacity(0.5), radius: 5)
        .scaleEffect(isAnimating ? 1.1 : 1.0)
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
    
    private var iconName: String {
        switch objectType.lowercased() {
        case "person":
            return "person.fill"
        case "car":
            return "car.fill"
        case "stop sign":
            return "octagon.fill"
        case "traffic light":
            return "light.beacon.fill"
        default:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var displayName: String {
        switch objectType.lowercased() {
        case "stop sign":
            return "STOP"
        case "traffic light":
            return "LIGHT"
        default:
            return objectType.uppercased()
        }
    }
    
    private var backgroundColor: Color {
        switch objectType.lowercased() {
        case "person":
            return Color.red
        case "car", "motorcycle", "bicycle":
            return Color.orange
        case "stop sign":
            return Color.red
        case "traffic light":
            return Color.yellow
        default:
            return Color.blue
        }
    }
}

// Enhanced speedometer with more detailed information
struct EnhancedSpeedometerView: View {
    var speed: Double
    var maxSpeed: Double
    var useMetric: Bool
    var theme: AppTheme
    var rawSpeedMetersPerSecond: Double
    var currentSpeedLimit: Double
    
    private var speedUnit: String {
        useMetric ? "km/h" : "mph"
    }
    
    private var speedPercentage: Double {
        min(speed / maxSpeed, 1.0)
    }
    
    private var speedColor: Color {
        if currentSpeedLimit > 0 && speed > currentSpeedLimit {
            return .red
        } else if speed > maxSpeed * 0.7 {
            return .orange
            } else {
            return theme.accentColor
        }
    }
    
    var body: some View {
        VStack(spacing: 5) {
            Text("CURRENT SPEED")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.gray)
            
            // Large speed display
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(Int(speed))")
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundColor(speedColor)
                    .contentTransition(.numericText())
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(speedUnit)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                    
                    // Raw data for debugging
                    Text("(\(String(format: "%.2f", rawSpeedMetersPerSecond)) m/s)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                        .opacity(0.7)
                }
            }
            
            // Speed gauge
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    // Speed indicator
                    Rectangle()
                        .fill(speedColor)
                        .frame(width: geometry.size.width * speedPercentage, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
            
            // Speed limit indicator if available
            if currentSpeedLimit > 0 {
                HStack {
                    Spacer()
                    Text("Speed Limit: \(Int(currentSpeedLimit)) \(speedUnit)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(speed > currentSpeedLimit ? .red : .gray)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.5))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

// Trip statistics view
struct TripStatisticsView: View {
    var distance: Double // in meters
    var averageSpeed: Double // in m/s
    var maxSpeed: Double // in m/s
    var useMetric: Bool
    
    private var distanceFormatted: String {
        let distanceKm = distance / 1000.0
        let distanceMiles = distanceKm * 0.621371
        let value = useMetric ? distanceKm : distanceMiles
        let unit = useMetric ? "km" : "mi"
        return String(format: "%.2f %@", value, unit)
    }
    
    private var avgSpeedFormatted: String {
        let avgSpeedKmh = averageSpeed * 3.6
        let avgSpeedMph = averageSpeed * 2.23694
        let value = useMetric ? avgSpeedKmh : avgSpeedMph
        let unit = useMetric ? "km/h" : "mph"
        return String(format: "%.1f %@", value, unit)
    }
    
    private var maxSpeedFormatted: String {
        let maxSpeedKmh = maxSpeed * 3.6
        let maxSpeedMph = maxSpeed * 2.23694
        let value = useMetric ? maxSpeedKmh : maxSpeedMph
        let unit = useMetric ? "km/h" : "mph"
        return String(format: "%.1f %@", value, unit)
    }
    
    var body: some View {
        HStack(spacing: 20) {
            StatisticItem(title: "Distance", value: distanceFormatted, icon: "map")
            StatisticItem(title: "Avg Speed", value: avgSpeedFormatted, icon: "speedometer")
            StatisticItem(title: "Max Speed", value: maxSpeedFormatted, icon: "bolt.fill")
        }
        .padding(.horizontal)
    }
}

struct StatisticItem: View {
    var title: String
    var value: String
    var icon: String
    
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white)
            
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.3))
        .cornerRadius(10)
    }
}

// Speed warning view
struct SpeedWarningView: View {
    @Binding var opacity: Double
    
    var body: some View {
        VStack {
            Text("SLOW DOWN")
                .font(.system(size: 32, weight: .black))
                .foregroundColor(.white)
                .padding()
                .background(Color.red)
                .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.red.opacity(0.3))
        .opacity(opacity)
        .edgesIgnoringSafeArea(.all)
    }
}

// Speed limit view
struct SpeedLimitView: View {
    var speedLimit: Double
    var isOverLimit: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.red, lineWidth: 3)
                .background(Circle().fill(Color.white))
                .frame(width: 50, height: 50)
            
            Text("\(Int(speedLimit))")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(isOverLimit ? .red : .black)
        }
        .overlay(
            isOverLimit ? 
                Circle()
                    .stroke(Color.red, lineWidth: 3)
                    .scaleEffect(1.1)
                    .opacity(0.5)
                : nil
        )
    }
}

// Trip summary view
struct DriveTripSummaryView: View {
    @Binding var isPresented: Bool
    var startTime: Date
    var endTime: Date
    var distance: Double
    var avgSpeed: Double
    var maxSpeed: Double
    @State private var showingShareSheet = false
    @Environment(\.presentationMode) var presentationMode
    
    private var tripDuration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    private var distanceInMiles: Double {
        (distance / 1000.0) * 0.621371
    }
    
    private var distanceInKm: Double {
        distance / 1000.0
    }
    
    private var avgSpeedInMPH: Double {
        avgSpeed * 2.23694
    }
    
    private var avgSpeedInKPH: Double {
        avgSpeed * 3.6
    }
    
    private var maxSpeedInMPH: Double {
        maxSpeed * 2.23694
    }
    
    private var maxSpeedInKPH: Double {
        maxSpeed * 3.6
    }
    
    private var shareText: String {
        """
        🚗 My Trip Summary:
        ⏱ Duration: \(formatDuration(tripDuration))
        📍 Distance: \(String(format: "%.2f", distanceInMiles)) miles (\(String(format: "%.2f", distanceInKm)) km)
        ⚡️ Average Speed: \(String(format: "%.1f", avgSpeedInMPH)) mph (\(String(format: "%.1f", avgSpeedInKPH)) km/h)
        🏃 Maximum Speed: \(String(format: "%.1f", maxSpeedInMPH)) mph (\(String(format: "%.1f", maxSpeedInKPH)) km/h)
        
        Tracked with CruiseAI 🚀
        """
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                Text("Trip Summary")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                VStack(spacing: 15) {
                    SummaryRow(title: "Duration", 
                              value: formatDuration(tripDuration),
                              icon: "clock.fill")
                    
                    SummaryRow(title: "Distance", 
                              value: String(format: "%.2f miles (%.2f km)", distanceInMiles, distanceInKm),
                              icon: "map.fill")
                    
                    SummaryRow(title: "Average Speed", 
                              value: String(format: "%.1f mph (%.1f km/h)", avgSpeedInMPH, avgSpeedInKPH),
                              icon: "speedometer")
                    
                    SummaryRow(title: "Maximum Speed", 
                              value: String(format: "%.1f mph (%.1f km/h)", maxSpeedInMPH, maxSpeedInKPH),
                              icon: "bolt.fill")
                }
                .padding()
                .background(Color.black.opacity(0.6))
                .cornerRadius(16)
                
                // Share button
                Button(action: {
                    showingShareSheet = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18))
                        Text("Share")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .cornerRadius(12)
                }
                .padding(.top, 10)
                
                // Done button
                Button(action: {
                    // Close the trip summary
                    isPresented = false
                    
                    // Add a slight delay to ensure the sheet is dismissed first
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        // Dismiss the drive page to get back to the homepage
                        presentationMode.wrappedValue.dismiss()
                        
                        // For older iOS versions, also try the direct UIKit approach
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = windowScene.windows.first,
                           let rootVC = window.rootViewController {
                            
                            // Dismiss any presented view controllers
                            var currentVC = rootVC
                            while let presentedVC = currentVC.presentedViewController {
                                currentVC = presentedVC
                            }
                            
                            // If we're more than one level deep, dismiss to get back to root
                            if currentVC != rootVC {
                                rootVC.dismiss(animated: true)
                            }
                        }
                    }
                }) {
                    Text("Close")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.top, 5)
            }
            .padding(30)
            .background(Color.black.opacity(0.85))
            .cornerRadius(20)
            .shadow(radius: 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .edgesIgnoringSafeArea(.all)
            .transition(.opacity)
            .sheet(isPresented: $showingShareSheet) {
                // Use our renamed ShareSheet
                DriveShareSheet(activityItems: [shareText])
            }
            .navigationBarHidden(true)
        }
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        let seconds = Int(interval.truncatingRemainder(dividingBy: 60))
        return "\(minutes)m \(seconds)s"
    }
}

struct SummaryRow: View {
    var title: String
    var value: String
    var icon: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.white)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                
                Text(value)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding(.vertical, 5)
    }
}

// Preview provider
struct DrivePage_Previews: PreviewProvider {
    static var previews: some View {
        DrivePage(appState: AppState())
    }
}

// MapView for navigation
struct MapView: UIViewRepresentable {
    var locationManager: LocationManager
    var route: MKRoute?
    var onAnnotationTapped: ((MKMapItem) -> Void)?
    @State private var userTrackingMode: MKUserTrackingMode = .follow
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = userTrackingMode
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.showsTraffic = true
        
        // Configure map appearance
        mapView.mapType = .standard
        
        // Add a long press gesture recognizer to drop pins
        let longPressGesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.addPinAtLocation(_:)))
        mapView.addGestureRecognizer(longPressGesture)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update the user tracking mode
        if mapView.userTrackingMode != userTrackingMode {
            mapView.setUserTrackingMode(userTrackingMode, animated: true)
        }
        
        // Update the user's location on the map
        if let location = locationManager.location {
            // Only update the map if we haven't set the initial region yet or if tracking is off
            if !context.coordinator.hasSetInitialRegion || mapView.userTrackingMode == .none {
                let region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                )
                mapView.setRegion(region, animated: true)
                context.coordinator.hasSetInitialRegion = true
            }
            
            // Update the user heading if available
            if let heading = locationManager.heading {
                mapView.camera.heading = heading
            }
        }
        
        // Update route overlay if changed
        if context.coordinator.currentRoute != route {
            // Remove existing overlays
            mapView.removeOverlays(mapView.overlays)
            
            // Add new route overlay if it exists
            if let route = route {
                mapView.addOverlay(route.polyline)
                
                // Add destination annotation if not already on map
                let destinationCoordinate = route.steps.last?.polyline.coordinate ?? route.polyline.coordinate
                
                // Remove any existing annotations except user location
                mapView.annotations.forEach { annotation in
                    if !annotation.isKind(of: MKUserLocation.self) {
                        mapView.removeAnnotation(annotation)
                    }
                }
                
                // Add destination annotation
                let annotation = MKPointAnnotation()
                annotation.coordinate = destinationCoordinate
                annotation.title = "Destination"
                mapView.addAnnotation(annotation)
                
                // Zoom to show the whole route with padding
                let padding: CGFloat = 50
                mapView.setVisibleMapRect(route.polyline.boundingMapRect, edgePadding: UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding), animated: true)
                
                context.coordinator.currentRoute = route
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        var hasSetInitialRegion = false
        var currentRoute: MKRoute?
        
        init(_ parent: MapView) {
            self.parent = parent
        }
        
        @objc func addPinAtLocation(_ gestureRecognizer: UILongPressGestureRecognizer) {
            if gestureRecognizer.state == .began {
                let mapView = gestureRecognizer.view as! MKMapView
                let point = gestureRecognizer.location(in: mapView)
                let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
                
                // Reverse geocode to get address information
                let geocoder = CLGeocoder()
                geocoder.reverseGeocodeLocation(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) { placemarks, error in
                    guard error == nil, let placemark = placemarks?.first else {
                        // If reverse geocoding fails, still create a basic pin
                        let simpleItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                        simpleItem.name = "Dropped Pin"
                        
                        DispatchQueue.main.async {
                            self.parent.onAnnotationTapped?(simpleItem)
                        }
                        return
                    }
                    
                    // Create a map item with the geocoded information
                    let mapItem = MKMapItem(placemark: MKPlacemark(placemark: placemark))
                    if mapItem.name == nil {
                        mapItem.name = "Dropped Pin"
                    }
                    
                    DispatchQueue.main.async {
                        self.parent.onAnnotationTapped?(mapItem)
                    }
                }
            }
        }
        
        // MARK: - MKMapViewDelegate
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.blue
                renderer.lineWidth = 5
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Don't modify the user location annotation
            if annotation is MKUserLocation {
                return nil
            }
            
            // Create custom annotation view for destinations
            let identifier = "destination"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
                
                // Add a button to get directions
                let directionsButton = UIButton(type: .detailDisclosure)
                directionsButton.setImage(UIImage(systemName: "car.fill"), for: .normal)
                annotationView?.rightCalloutAccessoryView = directionsButton
            } else {
                annotationView?.annotation = annotation
            }
            
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            guard let coordinate = view.annotation?.coordinate else { return }
            
            // Create a map item for this annotation
            let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            mapItem.name = view.annotation?.title ?? "Destination"
            
            // Pass the map item to the tap handler
            parent.onAnnotationTapped?(mapItem)
        }
    }
}

// Add map control buttons overlay
struct MapControlsOverlay: View {
    @Binding var trackingMode: MKUserTrackingMode
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                VStack(spacing: 10) {
                    // Tracking mode button
                    Button(action: {
                        // Cycle through tracking modes
                        switch trackingMode {
                        case .none:
                            trackingMode = .follow
                        case .follow:
                            trackingMode = .followWithHeading
                        case .followWithHeading:
                            trackingMode = .none
                        @unknown default:
                            trackingMode = .follow
                        }
                    }) {
                        Image(systemName: trackingModeIcon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    
                    // Map type toggle (standard/satellite)
                    Button(action: {
                        // This would typically change the map type, but we'll keep it simple
                        // and use standard map for this implementation
                    }) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding(.trailing, 16)
                .padding(.top, 60)
            }
            
            Spacer()
        }
    }
    
    private var trackingModeIcon: String {
        switch trackingMode {
        case .none:
            return "location"
        case .follow:
            return "location.fill"
        case .followWithHeading:
            return "location.north.line.fill"
        @unknown default:
            return "location"
        }
    }
}

// Search view for entering destinations
struct SearchView: View {
    @Binding var searchQuery: String
    @Binding var searchResults: [MKMapItem]
    var onSelectDestination: (MKMapItem) -> Void
    
    @State private var isSearching = false
    
    var body: some View {
        VStack {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Enter destination", text: $searchQuery, onCommit: {
                    performSearch()
                })
                .foregroundColor(.white)
                
                if !searchQuery.isEmpty {
                    Button(action: {
                        searchQuery = ""
                        searchResults = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray5).opacity(0.6))
            .cornerRadius(10)
            .padding(.horizontal)
            .onChange(of: searchQuery) { _ in
                if searchQuery.count > 2 {
                    performSearch()
                }
            }
            
            if isSearching {
                ProgressView()
                    .padding()
            } else {
                // Results list
                List {
                    ForEach(searchResults, id: \.self) { item in
                        Button(action: {
                            onSelectDestination(item)
                        }) {
                            VStack(alignment: .leading) {
                                Text(item.name ?? "Unnamed Location")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text(formatAddress(item.placemark))
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .background(Color.black.opacity(0.9))
    }
    
    private func performSearch() {
        guard !searchQuery.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchQuery
        request.resultTypes = [.address, .pointOfInterest]
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            isSearching = false
            
            guard let response = response, error == nil else {
                print("Search error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            searchResults = response.mapItems
        }
    }
    
    private func formatAddress(_ placemark: MKPlacemark) -> String {
        let components = [
            placemark.thoroughfare,
            placemark.locality,
            placemark.administrativeArea,
            placemark.postalCode
        ]
        
        return components.compactMap { $0 }.joined(separator: ", ")
    }
}

// Directions overlay for turn-by-turn navigation
struct DirectionsOverlay: View {
    var route: MKRoute
    @Binding var currentStepIndex: Int
    var remainingDistance: CLLocationDistance
    var remainingTime: TimeInterval
    var estimatedArrival: Date?
    var onDismiss: () -> Void
    
    private var currentStep: MKRoute.Step {
        if route.steps.count > currentStepIndex {
            return route.steps[currentStepIndex]
        } else {
            // Return the last step if we're somehow out of bounds
            return route.steps.last ?? MKRoute.Step()
        }
    }
    
    private var nextStep: MKRoute.Step? {
        if route.steps.count > currentStepIndex + 1 {
            return route.steps[currentStepIndex + 1]
        }
        return nil
    }
    
    var body: some View {
        VStack {
            // Direction banner
            VStack(alignment: .leading, spacing: 2) {
                // Current maneuver
                HStack {
                    Image(systemName: directionIcon(for: currentStep))
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.blue)
                        .cornerRadius(25)
                    
                    VStack(alignment: .leading) {
                        Text(currentStep.instructions)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(2)
                        
                        if let nextStep = nextStep {
                            HStack {
                                Text("Then")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                Image(systemName: directionIcon(for: nextStep))
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                
                                Text(nextStep.instructions)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Distance to next maneuver
                    Text(formatDistance(currentStep.distance))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding()
                
                // ETA and summary info
                HStack {
                    VStack(alignment: .leading) {
                        if let arrival = estimatedArrival {
                            Text("Arrive at \(formatTime(arrival))")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        
                        Text("\(formatDistance(remainingDistance)) · \(formatDuration(remainingTime)) remaining")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // End navigation button
                    Button(action: onDismiss) {
                        Text("End")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red)
                            .cornerRadius(16)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            .background(Color.black.opacity(0.8))
            .cornerRadius(16)
            .padding()
            
            Spacer()
        }
    }
    
    private func directionIcon(for step: MKRoute.Step) -> String {
        if step.instructions.contains("right") {
            return "arrow.turn.up.right"
        } else if step.instructions.contains("left") {
            return "arrow.turn.up.left"
        } else if step.instructions.contains("Continue") {
            return "arrow.up"
        } else if step.instructions.contains("Arrive") {
            return "mappin.circle.fill"
        } else if step.instructions.contains("U-turn") {
            return "arrow.uturn.right"
        } else {
            return "arrow.up"
        }
    }
    
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            return String(format: "%.1f km", distance / 1000)
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours) hr \(remainingMinutes) min"
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
