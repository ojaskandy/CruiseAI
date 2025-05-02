//
//  CameraView.swift
//  CruiseAIios
//
//  Created by Ojas Kandhare on 4/2/25.
//

import SwiftUI
import AVFoundation
import AudioToolbox
import CoreLocation
import UIKit
import MapKit
import UserNotifications

// Map annotation for trip summary
struct TripMapAnnotation: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String
}

// A wrapper view that handles camera permission and refreshes when permission changes
public struct MainCameraView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var modelIntegration = ModelIntegration()
    @StateObject private var locationManager = LocationManager()
    @ObservedObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    
    // Public initializer to ensure it's accessible from other modules
    public init(appState: AppState) {
        self.appState = appState
    }
    
    // State for drive button
    @State private var isDriving = false
    @State private var isLoading = false // Loading state for drive initialization
    @State private var loadingProgress: CGFloat = 0.0 // Progress for the car animation
    @State private var loadingMessage = "Getting ready to start drive..." // Current loading message
    @State private var useMetricSystem = false // false = MPH, true = KPH
    @State private var showingExitAlert = false
    @State private var showingShareSheet = false
    @State private var showingSpeedWarning = false
    @State private var speedWarningOpacity: Double = 0.0
    @State private var speedWarningMessage: String = ""
    @State private var isAnimating = false
    @State private var showingMapView = false // Track when to show the map view
    
    // Speech synthesizer for speed warnings
    let speechSynthesizer = AVSpeechSynthesizer()
    
    // Speed warning throttling
    @State private var lastSpeedWarningTime: Date? = nil
    @State private var lastSpeedWarningRoad: String? = nil
    private let speedWarningInterval: TimeInterval = 30.0 // 30 seconds between warnings
    
    // Trip tracking
    @State private var tripStartTime: Date? = nil
    @State private var tripEndTime: Date? = nil
    @State private var tripDistance: Double = 0.0 // in meters
    @State private var tripTopSpeed: Double = 0.0 // in m/s
    @State private var tripAvgSpeed: Double = 0.0 // in m/s
    @State private var lastLocation: CLLocation? = nil
    @State private var speedReadings: [Double] = []
    @State private var startLocation: CLLocationCoordinate2D? = nil
    @State private var endLocation: CLLocationCoordinate2D? = nil
    @State private var locationHistory: [CLLocationCoordinate2D] = []
    
    // Color based on speed
    private var speedColor: Color {
        let currentSpeed = useMetricSystem ? locationManager.speedKPH : locationManager.speedMPH
        
        if currentSpeed < 30 {
            return .green
        } else if currentSpeed < 60 {
            return .yellow
        } else if currentSpeed < 90 {
            return .orange
        } else {
            return .red
        }
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
            .animation(.easeInOut(duration: 0.5), value: appState.theme)
            
            // Loading screen overlay
            if isLoading {
                LoadingView(
                    progress: $loadingProgress,
                    message: $loadingMessage,
                    gradientColors: appState.theme.gradientColors
                )
                .frame(width: UIScreen.main.bounds.width * 0.9)
                
            // Map view
            } else if showingMapView {
                DriveMapView(
                    appState: appState,
                    locationManager: locationManager,
                    isDriving: $isDriving,
                    showingShareSheet: $showingShareSheet,
                    tripStartTime: $tripStartTime,
                    tripEndTime: $tripEndTime,
                    tripDistance: $tripDistance,
                    tripTopSpeed: $tripTopSpeed,
                    tripAvgSpeed: $tripAvgSpeed,
                    speedReadings: $speedReadings,
                    locationHistory: $locationHistory
                )
            
            // Main camera view
            } else if cameraManager.isAuthorized {
                ZStack {
                    // Camera preview with model processing and detection overlay
                    ZStack {
                        CameraPreviewView(cameraManager: cameraManager, modelIntegration: modelIntegration)
                            .edgesIgnoringSafeArea(.all)
                        
                        // Modern detection overlay
                        DetectionOverlayView(
                            objects: modelIntegration.detectedObjects.map { object in
                                DetectedObject(
                                    label: object.label,
                                    confidence: object.confidence,
                                    boundingBox: object.boundingBox
                                )
                            },
                            theme: appState.theme,
                            screenSize: UIScreen.main.bounds.size
                        )
                        
                        // Top bar with controls
                        VStack {
                            HStack {
                                // Speedometer (only shown when location is authorized)
                                if locationManager.authorizationStatus == .authorizedWhenInUse ||
                                   locationManager.authorizationStatus == .authorizedAlways {
                                    CompactSpeedometerView(
                                        speed: useMetricSystem ? locationManager.speedKPH : locationManager.speedMPH,
                                        maxSpeed: useMetricSystem ? 200 : 120,
                                        useMetric: useMetricSystem,
                                        theme: appState.theme
                                    )
                                    .onTapGesture {
                                        useMetricSystem.toggle()
                                    }
                                }
                                
                                Spacer()
                                
                                // Toggle processing button
                                GlassButton(
                                    theme: appState.theme,
                                    title: "Toggle",
                                    icon: "cpu"
                                ) {
                                    modelIntegration.toggleProcessing()
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                            
                            Spacer()
                            
                            // Modern speedometer in the center
                            if locationManager.authorizationStatus == .authorizedWhenInUse ||
                               locationManager.authorizationStatus == .authorizedAlways {
                                ModernSpeedometerView(
                                    speed: useMetricSystem ? locationManager.speedKPH : locationManager.speedMPH,
                                    maxSpeed: useMetricSystem ? 200 : 120,
                                    useMetric: useMetricSystem,
                                    theme: appState.theme
                                )
                                .frame(width: 250, height: 250)
                                .padding(.bottom, 20)
                            } else {
                                // Location permission required view
                                GlassContainer(theme: appState.theme) {
                                    VStack(spacing: 15) {
                                        Image(systemName: "location.slash.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(appState.theme.accentColor)
                                        
                                        Text("Location Access Required")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        GlassButton(
                                            theme: appState.theme,
                                            title: "Enable Location",
                                            icon: "location.fill"
                                        ) {
                                            locationManager.requestPermission()
                                        }
                                    }
                                    .padding()
                                }
                                .frame(width: 250)
                                .padding(.bottom, 20)
                            }
                        }
                        .onTapGesture {
                            // Toggle between MPH and KPH if authorized
                            if locationManager.authorizationStatus == .authorizedWhenInUse ||
                               locationManager.authorizationStatus == .authorizedAlways {
                                useMetricSystem.toggle()
                                // Provide haptic feedback
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                            }
                        }
                        
                        // Modern object detection display
                        if !modelIntegration.detectedObjects.isEmpty {
                            GlassContainer(theme: appState.theme, padding: 15) {
                                VStack(spacing: 12) {
                                    HStack {
                                        Image(systemName: "cube.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(appState.theme.accentColor)
                                        
                                        Text("Detected Objects")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                        
                                        Spacer()
                                        
                                        Text("\(modelIntegration.detectedObjects.count)")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(appState.theme.accentColor)
                                    }
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 10) {
                                            ForEach(modelIntegration.detectedObjects.prefix(5), id: \.self) { object in
                                                GlassContainer(theme: appState.theme, padding: 8) {
                                                    HStack(spacing: 6) {
                                                        Image(systemName: "viewfinder")
                                                            .font(.system(size: 14))
                                                            .foregroundColor(appState.theme.accentColor)
                                                        
                                                        Text(object.label)
                                                            .font(.system(size: 14, weight: .medium))
                                                            .foregroundColor(.white)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 20)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 15) {
                            // Start/Stop Drive button with glass effect
                            GlassButton(
                                theme: appState.theme,
                                title: isDriving ? "Stop Drive" : "Start Drive",
                                icon: isDriving ? "stop.circle.fill" : "play.circle.fill"
                            ) {
                                let isDrivingCopy = isDriving
                                
                                if !isDrivingCopy {
                                    // Show loading screen before starting drive
                                    isLoading = true
                                    loadingProgress = 0.0
                                    loadingMessage = "Getting ready to start drive..."
                                    
                                    // Simulate loading with a sequence of steps
                                    let totalLoadingTime: TimeInterval = 5.0
                                    
                                    // Loading sequence
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        self.updateProgress(progress: 0.2, message: "Loading models...")
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        self.updateProgress(progress: 0.4, message: "Calibrating sensors...")
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                        self.updateProgress(progress: 0.6, message: "Ensuring accuracy...")
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                                        self.updateProgress(progress: 0.8, message: "Almost ready...")
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + totalLoadingTime) {
                                        self.updateProgress(progress: 1.0, message: "Drive starting now!")
                                        
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            self.isLoading = false
                                            self.showingMapView = true
                                            self.isDriving = true
                                            self.tripStartTime = Date()
                                            self.tripEndTime = nil
                                            self.tripDistance = 0.0
                                            self.tripTopSpeed = 0.0
                                            self.speedReadings = []
                                            self.lastLocation = nil
                                            self.locationManager.startUpdatingLocation()
                                            
                                            // Request notification permission if needed
                                            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
                                                if granted {
                                                    print("Notification permission granted")
                                                } else if let error = error {
                                                    print("Notification permission error: \(error)")
                                                }
                                            }
                                            
                                            AudioServicesPlaySystemSound(1519)
                                        }
                                    }
                                } else {
                                    isDriving = false
                                    tripEndTime = Date()
                                    locationManager.stopUpdatingLocation()
                                    BackgroundManager.shared.endBackgroundSession()
                                    
                                    if !speedReadings.isEmpty {
                                        tripAvgSpeed = speedReadings.reduce(0, +) / Double(speedReadings.count)
                                    }
                                    
                                    showingShareSheet = true
                                    AudioServicesPlaySystemSound(1519)
                                }
                            }
                            
                            // Detection indicator with glass effect
                            if !modelIntegration.detectedObjects.isEmpty {
                                GlassContainer(theme: appState.theme, padding: 12) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(appState.theme.accentColor)
                                        
                                        Text("OBJECTS DETECTED")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(maxWidth: 300)
                            }
                        }
                        .padding(.bottom, 30)
                    }
                    
                }
                
            } else if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                // Modern permission denied view
                VStack(spacing: 30) {
                    Spacer()
                    
                    // Camera permission section
                    GlassContainer(theme: appState.theme) {
                        VStack(spacing: 15) {
                            Image(systemName: "camera.slash.fill")
                                .font(.system(size: 40))
                                .foregroundColor(appState.theme.accentColor)
                            
                            Text("Camera Access Required")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Please grant permission in Settings")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                            
                            GlassButton(
                                theme: appState.theme,
                                title: "Check Camera Permission",
                                icon: "camera.fill"
                            ) {
                                cameraManager.checkPermission()
                            }
                        }
                        .padding()
                    }
                    
                    // Location permission section
                    GlassContainer(theme: appState.theme) {
                        VStack(spacing: 15) {
                            Image(systemName: "location.slash.fill")
                                .font(.system(size: 40))
                                .foregroundColor(appState.theme.accentColor)
                            
                            Text("Location Access Required")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Location access is needed for speedometer functionality")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                            
                            GlassButton(
                                theme: appState.theme,
                                title: "Check Location Permission",
                                icon: "location.fill"
                            ) {
                                locationManager.requestPermission()
                            }
                        }
                        .padding()
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                
            } else {
                // Modern camera permission denied view
                VStack {
                    Spacer()
                    
                    GlassContainer(theme: appState.theme) {
                        VStack(spacing: 15) {
                            Image(systemName: "camera.slash.fill")
                                .font(.system(size: 40))
                                .foregroundColor(appState.theme.accentColor)
                            
                            Text("Camera Access Required")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Please grant permission in Settings to use CruiseAI's driving features")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                            
                            GlassButton(
                                theme: appState.theme,
                                title: "Check Permission Again",
                                icon: "camera.fill"
                            ) {
                                cameraManager.checkPermission()
                            }
                        }
                        .padding()
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
        .navigationBarTitle("Drive Monitor", displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading: Button(action: {
                if isDriving {
                    showingExitAlert = true
                } else {
                    presentationMode.wrappedValue.dismiss()
                }
            }) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .foregroundColor(.white)
            }
        )
        .alert(isPresented: $showingExitAlert) {
            Alert(
                title: Text("Drive in Progress"),
                message: Text("Are you sure you want to exit? Your current drive will be stopped."),
                primaryButton: .destructive(Text("Exit")) {
                    locationManager.stopUpdatingLocation()
                    BackgroundManager.shared.endBackgroundSession()
                    presentationMode.wrappedValue.dismiss()
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showingShareSheet) {
            TripSummaryView(
                tripStartTime: tripStartTime ?? Date(),
                tripDuration: tripEndTime?.timeIntervalSince(tripStartTime ?? Date()) ?? 0,
                tripDistance: tripDistance,
                avgSpeed: tripAvgSpeed,
                maxSpeed: tripTopSpeed,
                isPresented: $showingShareSheet
            )
            .preferredColorScheme(.dark)
        }
        .onAppear {
            cameraManager.checkPermission()
            locationManager.requestPermission()
            
            // Set up location updates observer
            NotificationCenter.default.addObserver(forName: NSNotification.Name("LocationUpdate"), object: nil, queue: .main) { notification in
                if let location = notification.object as? CLLocation, self.isDriving {
                    self.updateTripMetrics(location: location)
                }
            }
            
            // Set up speed limit warning observer
            NotificationCenter.default.addObserver(forName: NSNotification.Name("SpeedLimitExceeded"), object: nil, queue: .main) { notification in
                if let userInfo = notification.userInfo,
                   let speed = userInfo["speed"] as? Double,
                   let limit = userInfo["limit"] as? Double {
                    self.showSpeedWarning(speed: speed, limit: limit)
                }
            }
        }
        .onAppear {
            isAnimating = true
        }
        // Add modern speed warning overlay
        .overlay(
            ZStack {
                if showingSpeedWarning {
                    GlassContainer(theme: appState.theme, padding: 30) {
                        VStack(spacing: 15) {
                            // Warning icon with pulsing animation
                            Image(systemName: "speedometer")
                                .font(.system(size: 48))
                                .foregroundColor(appState.theme.accentColor)
                                .scaleEffect(isAnimating ? 1.1 : 1.0)
                                .animation(
                                    Animation.easeInOut(duration: 1.0)
                                        .repeatForever(autoreverses: true),
                                    value: isAnimating
                                )
                            
                            Text("SPEED WARNING")
                                .font(.system(size: 28, weight: .heavy))
                                .foregroundColor(.white)
                            
                            Text(speedWarningMessage)
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.9)
                    .opacity(speedWarningOpacity)
                }
            }
        )
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .background:
                if isDriving {
                    // Configure for background operation
                    cameraManager.configureForBackground()
                    modelIntegration.objectDetectionManager?.configureForBackground()
                    BackgroundManager.shared.startBackgroundSession()
                }
            case .active:
                if isDriving {
                    // Restore normal operation
                    cameraManager.restoreNormalOperation()
                    modelIntegration.objectDetectionManager?.restoreNormalOperation()
                }
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
    
    // Update trip metrics with new location data
    func updateTripMetrics(location: CLLocation) {
        // Store the start location if this is the first update
        if startLocation == nil {
            startLocation = location.coordinate
            print("Set start location: \(location.coordinate)")
        }
        
        // Always update the end location
        endLocation = location.coordinate
        
        // Add to location history
        locationHistory.append(location.coordinate)
        
        // Update distance - only if we've moved more than the minimum threshold
        if let lastLoc = lastLocation {
            let newDistance = location.distance(from: lastLoc)
            
            // Improved filtering for GPS jitter
            if newDistance > 10.0 &&
               location.horizontalAccuracy < 20.0 &&
               location.speed > 0.5 {
                
                tripDistance += newDistance
                lastLocation = location
                
                print("Added distance: \(newDistance)m, Total: \(tripDistance)m")
            } else {
                print("Filtered out location update: distance=\(newDistance)m, accuracy=\(location.horizontalAccuracy)m, speed=\(location.speed)m/s")
            }
        } else {
            // First location update
            lastLocation = location
            print("Set initial location: \(location.coordinate)")
        }
        
        // Update speed readings
        let currentSpeed = location.speed
        if currentSpeed > 0 {
            speedReadings.append(currentSpeed)
            
            // Update top speed
            if currentSpeed > tripTopSpeed {
                tripTopSpeed = currentSpeed
                print("New top speed: \(tripTopSpeed) m/s")
            }
        }
    }
    
    // Update loading progress with animation
    private func updateProgress(progress: CGFloat, message: String) {
        DispatchQueue.main.async {
            withAnimation {
                self.loadingProgress = progress
                self.loadingMessage = message
            }
        }
    }
    
    // Show speed warning when exceeding speed limit
    func showSpeedWarning(speed: Double, limit: Double) {
        // Get current road name (simplified - in a real app, you might use reverse geocoding)
        let currentRoad = "Road-\(Int(limit))" // Use speed limit as a proxy for road identity
        
        // Check if we should show a warning based on time and road
        let shouldShowWarning = shouldShowSpeedWarning(forRoad: currentRoad)
        if !shouldShowWarning {
            print("Suppressing speed warning: last warning was less than 30 seconds ago on the same road")
            return
        }
        
        // Update last warning time and road
        lastSpeedWarningTime = Date()
        lastSpeedWarningRoad = currentRoad
        
        // Create warning message
        let speedInt = Int(speed)
        let limitInt = Int(limit)
        speedWarningMessage = "You are driving \(speedInt) mph in a \(limitInt) mph zone"
        
        // Show warning
        withAnimation(.easeIn(duration: 0.3)) {
            showingSpeedWarning = true
            speedWarningOpacity = 1.0
        }
        
        // Speak warning
        let utterance = AVSpeechUtterance(string: "Speed limit \(limitInt). You are driving \(speedInt) miles per hour.")
        utterance.rate = 0.5
        utterance.volume = 1.0
        utterance.pitchMultiplier = 1.2
        speechSynthesizer.speak(utterance)
        
        // Play warning sound
        AudioServicesPlaySystemSound(1521) // Strong vibration
        
        // Hide warning after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                self.speedWarningOpacity = 0.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showingSpeedWarning = false
            }
        }
    }
    
    // Helper method to determine if we should show a speed warning
    private func shouldShowSpeedWarning(forRoad currentRoad: String) -> Bool {
        // If this is a different road than the last warning, always show
        if lastSpeedWarningRoad != currentRoad {
            print("New road detected: showing speed warning")
            return true
        }
        
        // If we've never shown a warning before, show it
        guard let lastWarningTime = lastSpeedWarningTime else {
            print("First speed warning: showing")
            return true
        }
        
        // Check if enough time has passed since the last warning
        let timeSinceLastWarning = Date().timeIntervalSince(lastWarningTime)
        let shouldShow = timeSinceLastWarning >= speedWarningInterval
        
        if shouldShow {
            print("Time since last warning: \(timeSinceLastWarning) seconds - showing warning")
        } else {
            print("Time since last warning: \(timeSinceLastWarning) seconds - suppressing warning")
        }
        
        return shouldShow
    }
}

// Camera manager to handle permissions and camera setup
class CameraManager: NSObject, ObservableObject {
    @Published var isAuthorized = false
    private var captureSession: AVCaptureSession?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var playerLayer: AVPlayerLayer?
    private var player: AVPlayer?
    
    // Delegate to receive camera frames
    weak var frameDelegate: CameraFrameDelegate?
    
    // Background state
    private var isBackgroundMode = false
    
    override init() {
        super.init()
        print("CameraManager initialized")
        checkPermission()
    }
    
    func checkPermission() {
        print("Checking camera permission...")
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            print("Camera permission already granted")
            self.isAuthorized = true
            self.setupCaptureSession()
        case .notDetermined:
            print("Requesting camera permission...")
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                print("Camera permission response: \(granted)")
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted {
                        self?.setupCaptureSession()
                    } else {
                        print("Camera permission denied by user")
                    }
                }
            }
        case .denied:
            print("Camera permission denied")
            self.isAuthorized = false
        case .restricted:
            print("Camera permission restricted")
            self.isAuthorized = false
        @unknown default:
            print("Unknown camera permission status")
            self.isAuthorized = false
        }
    }
    
    func setupCaptureSession() {
        print("Setting up capture session...")
        
        let session = AVCaptureSession()
        session.sessionPreset = .high
        
        // Get the back camera
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Could not find back camera")
            return
        }
        
        // Create input from camera
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            
            if session.canAddInput(input) {
                session.addInput(input)
                print("Added camera input to session")
            } else {
                print("Could not add camera input to session")
                return
            }
        } catch {
            print("Error creating camera input: \(error.localizedDescription)")
            return
        }
        
        // Set up video data output for frame processing
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            print("Added video output to session")
        } else {
            print("Could not add video output to session")
            return
        }
        
        self.captureSession = session
        self.videoDataOutput = videoOutput
        
        // Set up PiP support
        setupPictureInPicture()
        
        // Start the capture session on a background thread
        print("Starting capture session...")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
            print("Capture session started")
        }
    }
    
    func getCaptureSession() -> AVCaptureSession? {
        return captureSession
    }
    
    // MARK: - Background Support
    
    func configureForBackground() {
        isBackgroundMode = true
        
        // Start PiP if available
        startPictureInPicture()
        
        // Note: We're no longer reducing quality or frame rate
        print("Configured for background operation at full quality")
    }
    
    func restoreNormalOperation() {
        isBackgroundMode = false
        
        // Stop PiP
        stopPictureInPicture()
        
        print("Restored normal operation")
    }
    
    // MARK: - Picture in Picture Support
    
    private func setupPictureInPicture() {
        // Create a blank video source for PiP
        let videoURL = Bundle.main.url(forResource: "blank", withExtension: "mp4") ?? URL(fileURLWithPath: "")
        player = AVPlayer(url: videoURL)
        playerLayer = AVPlayerLayer(player: player)
        
        if let playerLayer = playerLayer {
            BackgroundManager.shared.setupPictureInPicture(with: playerLayer)
        }
    }
    
    private func startPictureInPicture() {
        BackgroundManager.shared.startPictureInPicture()
    }
    
    private func stopPictureInPicture() {
        BackgroundManager.shared.stopPictureInPicture()
    }
}

// Protocol for receiving camera frames
protocol CameraFrameDelegate: AnyObject {
    func didReceiveFrame(_ pixelBuffer: CVPixelBuffer)
}

// Extension to handle camera frame capture
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Pass the frame to the delegate for processing
        frameDelegate?.didReceiveFrame(pixelBuffer)
    }
}

// UIViewRepresentable for the camera preview with model integration
struct CameraPreviewView: UIViewRepresentable {
    let cameraManager: CameraManager
    let modelIntegration: ModelIntegration
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black
        
        // Set up the coordinator as the frame delegate
        context.coordinator.modelIntegration = modelIntegration
        cameraManager.frameDelegate = context.coordinator
        
        // Set up the preview layer
        if let captureSession = cameraManager.getCaptureSession() {
            let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.frame = view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.name = "previewLayer"
            view.layer.addSublayer(previewLayer)
        }
        
        // Add a debug label
        let debugLabel = UILabel(frame: CGRect(x: 10, y: 50, width: view.bounds.width - 20, height: 30))
        debugLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        debugLabel.textColor = .white
        debugLabel.textAlignment = .center
        debugLabel.font = UIFont.systemFont(ofSize: 14)
        debugLabel.tag = 200
        debugLabel.text = "Objects: 0"
        view.addSubview(debugLabel)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // All UI updates must happen on the main thread
        DispatchQueue.main.async {
            // Update the preview layer if needed
            if let previewLayer = uiView.layer.sublayers?.first(where: { $0.name == "previewLayer" }) as? AVCaptureVideoPreviewLayer,
               let captureSession = self.cameraManager.getCaptureSession() {
                previewLayer.session = captureSession
            }
            
            // Update the debug label
            if let debugLabel = uiView.viewWithTag(200) as? UILabel {
                let count = self.modelIntegration.detectedObjects.count
                debugLabel.text = "Objects: \(count)"
                debugLabel.textColor = UIColor.white
                
                // Make sure the debug label is on top
                uiView.bringSubviewToFront(debugLabel)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    // Simple coordinator class
    class Coordinator: NSObject, CameraFrameDelegate {
        // Use a weak reference to avoid retain cycles
        weak var modelIntegration: ModelIntegration?
        
        func didReceiveFrame(_ pixelBuffer: CVPixelBuffer) {
            // Ensure we're on the main thread when accessing modelIntegration
            DispatchQueue.main.async { [weak self] in
                self?.modelIntegration?.processFrame(pixelBuffer)
            }
        }
    }
}

// MARK: - Trip Summary View

// Using TripSummaryView from TripSummaryView.swift

// Preview Provider
struct MainCameraView_Previews: PreviewProvider {
    static var previews: some View {
        MainCameraView(appState: AppState())
    }
}
