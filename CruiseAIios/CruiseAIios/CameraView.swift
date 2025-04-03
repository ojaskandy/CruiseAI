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

// A wrapper view that handles camera permission and refreshes when permission changes
struct CameraView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var modelIntegration = ModelIntegration()
    @StateObject private var locationManager = LocationManager()
    @ObservedObject var appState: AppState
    
    // State for drive button
    @State private var isDriving = false
    @State private var useMetricSystem = false // false = MPH, true = KPH
    @State private var showingExitAlert = false
    @State private var showingShareSheet = false
    @State private var showingSpeedWarning = false
    @State private var speedWarningOpacity: Double = 0.0
    @State private var speedWarningMessage: String = ""
    
    // Speech synthesizer for speed warnings
    let speechSynthesizer = AVSpeechSynthesizer()
    
    // Trip tracking
    @State private var tripStartTime: Date? = nil
    @State private var tripEndTime: Date? = nil
    @State private var tripDistance: Double = 0.0 // in meters
    @State private var tripTopSpeed: Double = 0.0 // in m/s
    @State private var tripAvgSpeed: Double = 0.0 // in m/s
    @State private var lastLocation: CLLocation? = nil
    @State private var speedReadings: [Double] = []
    
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
    
    var body: some View {
        ZStack {
            // Theme-based gradient background
            LinearGradient(
                gradient: Gradient(colors: appState.theme.gradientColors),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            .animation(.easeInOut(duration: 0.5), value: appState.theme)
            
            if cameraManager.isAuthorized {
                ZStack {
                    // Camera preview with model processing
                    CameraPreviewView(cameraManager: cameraManager, modelIntegration: modelIntegration)
                        .edgesIgnoringSafeArea(.all)
                
                    // Overlay with detection information
                    VStack {
                        HStack {
                            // Detection stats
                            VStack(alignment: .leading) {
                                Text("Objects: \(modelIntegration.detectedObjects.count)")
                                    .font(.headline)
                                    .padding(8)
                                    .background(Color.black.opacity(0.7))
                                    .foregroundColor(Color.white)
                                    .cornerRadius(8)
                                
                                Text("Processing...")
                                    .font(.caption)
                                    .padding(4)
                                    .background(Color.orange.opacity(0.6))
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                                    .opacity(modelIntegration.isProcessing ? 1.0 : 0.0)
                            }
                            .padding(.leading, 8)
                            
                            Spacer()
                            
                            // Speedometer (only shown when location is authorized)
                            if locationManager.authorizationStatus == .authorizedWhenInUse || 
                               locationManager.authorizationStatus == .authorizedAlways {
                                CompactSpeedometerView(locationManager: locationManager, useMetric: useMetricSystem)
                                    .onTapGesture {
                                        // Toggle between MPH and KPH
                                        useMetricSystem.toggle()
                                    }
                            }
                            
                            // Toggle processing button
                            Button {
                                modelIntegration.toggleProcessing()
                            } label: {
                                Text("Toggle")
                                    .font(.headline)
                                    .padding(8)
                                    .background(Color.black.opacity(0.6))
                                    .foregroundColor(.green)
                                    .cornerRadius(8)
                            }
                            .padding(.trailing, 8)
                        }
                        .padding(.top, 8)
                        
                        // Large speedometer in the center
                        Spacer()
                        
                        // Large speedometer display
                        ZStack {
                            // Background for speedometer
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.black.opacity(0.7))
                                .frame(width: 250, height: 150)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(speedColor, lineWidth: 4)
                                )
                            
                            if locationManager.authorizationStatus == .authorizedWhenInUse || 
                               locationManager.authorizationStatus == .authorizedAlways {
                                // When location permission is granted
                                VStack(spacing: 10) {
                                    // Speed value
                                    Text("\(Int(useMetricSystem ? locationManager.speedKPH : locationManager.speedMPH))")
                                        .font(.system(size: 70, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    
                                    // Speed unit
                                    Text(useMetricSystem ? "KILOMETERS PER HOUR" : "MILES PER HOUR")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    
                                    // Status indicator
                                    Text(isDriving ? "RECORDING" : "TAP TO TOGGLE UNITS")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(isDriving ? .red : .green)
                                        .padding(.top, 5)
                                }
                            } else {
                                // When location permission is not granted
                                VStack(spacing: 10) {
                                    Image(systemName: "location.slash.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.orange)
                                    
                                    Text("Location Access Required")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Button {
                                        locationManager.requestPermission()
                                    } label: {
                                        Text("Enable Location")
                                            .font(.subheadline)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 8)
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        .onTapGesture {
                            if locationManager.authorizationStatus == .authorizedWhenInUse || 
                               locationManager.authorizationStatus == .authorizedAlways {
                                // Toggle between MPH and KPH
                                useMetricSystem.toggle()
                                
                                // Provide haptic feedback
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                            }
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 12) {
                            // Start/Stop Drive button
                            Button {
                                toggleDriving()
                            } label: {
                                Text(isDriving ? "Stop Drive" : "Start Drive")
                                    .font(.headline)
                                    .padding()
                                    .frame(maxWidth: 200)
                                    .background(isDriving ? Color.red : Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                    .shadow(radius: 3)
                            }
                            
                            // Detection indicator (only shown when objects are detected)
                            if !modelIntegration.detectedObjects.isEmpty {
                                Text("OBJECTS DETECTED")
                                    .font(.title)
                                    .bold()
                                    .padding()
                                    .background(Color.red.opacity(0.8))
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            } else if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                // Location permission denied
                VStack {
                    Spacer()
                    Text("Camera access is required")
                        .font(.headline)
                    Text("Please grant permission in Settings")
                        .font(.subheadline)
                        .padding(.top, 4)
                    
                    Button {
                        cameraManager.checkPermission()
                    } label: {
                        Text("Check Camera Permission")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding(.top, 20)
                    
                    Text("Location access is required for speedometer")
                        .font(.headline)
                        .padding(.top, 20)
                    
                    Button {
                        locationManager.requestPermission()
                    } label: {
                        Text("Check Location Permission")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                }
                .padding()
            } else {
                // Camera permission denied
                VStack {
                    Spacer()
                    Text("Camera access is required")
                        .font(.headline)
                    Text("Please grant permission in Settings")
                        .font(.subheadline)
                        .padding(.top, 4)
                    
                    Button {
                        cameraManager.checkPermission()
                    } label: {
                        Text("Check Permission Again")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                }
                .padding()
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
                    presentationMode.wrappedValue.dismiss()
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showingShareSheet) {
            TripSummaryView(
                startTime: tripStartTime ?? Date(),
                endTime: tripEndTime ?? Date(),
                distance: tripDistance,
                topSpeed: tripTopSpeed,
                avgSpeed: tripAvgSpeed,
                useMetric: useMetricSystem,
                appState: appState
            )
        }
        .onAppear {
            cameraManager.checkPermission()
            locationManager.requestPermission()
            
            // Set up location updates observer
            NotificationCenter.default.addObserver(forName: NSNotification.Name("LocationUpdate"), object: nil, queue: .main) { [self] notification in
                if let location = notification.object as? CLLocation, isDriving {
                    updateTripMetrics(with: location)
                }
            }
            
            // Set up speed limit warning observer
            NotificationCenter.default.addObserver(forName: NSNotification.Name("SpeedLimitExceeded"), object: nil, queue: .main) { [self] notification in
                if let userInfo = notification.userInfo,
                   let speed = userInfo["speed"] as? Double,
                   let limit = userInfo["limit"] as? Double {
                    showSpeedWarning(speed: speed, limit: limit)
                }
            }
        }
        
        // Add speed warning overlay
        .overlay(
            ZStack {
                if showingSpeedWarning {
                    VStack {
                        Text("SPEED")
                            .font(.system(size: 60, weight: .heavy))
                            .foregroundColor(.red)
                        
                        Text(speedWarningMessage)
                            .font(.title)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(30)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(20)
                    .opacity(speedWarningOpacity)
                }
            }
        )
    }
}

// Camera manager to handle permissions and camera setup
class CameraManager: NSObject, ObservableObject {
    @Published var isAuthorized = false
    private var captureSession: AVCaptureSession?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    
    // Delegate to receive camera frames
    weak var frameDelegate: CameraFrameDelegate?
    
    override init() {
        super.init()
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
        var modelIntegration: ModelIntegration?
        
        func didReceiveFrame(_ pixelBuffer: CVPixelBuffer) {
            modelIntegration?.processFrame(pixelBuffer)
        }
    }
}

// MARK: - Trip Tracking Methods
extension CameraView {
    // Toggle driving state and handle trip tracking
    func toggleDriving() {
        isDriving.toggle()
        
        if isDriving {
            // Start a new trip
            tripStartTime = Date()
            tripEndTime = nil
            tripDistance = 0.0
            tripTopSpeed = 0.0
            speedReadings = []
            lastLocation = nil
            
            // Start location updates
            locationManager.startUpdatingLocation()
        } else {
            // End the trip
            tripEndTime = Date()
            locationManager.stopUpdatingLocation()
            
            // Calculate average speed
            if !speedReadings.isEmpty {
                tripAvgSpeed = speedReadings.reduce(0, +) / Double(speedReadings.count)
            }
            
            // Show share sheet
            showingShareSheet = true
        }
        
        // Play sound for feedback
        AudioServicesPlaySystemSound(1519) // Vibration
    }
    
    // Update trip metrics with new location data
    func updateTripMetrics(with location: CLLocation) {
        // Update distance
        if let lastLoc = lastLocation {
            let newDistance = location.distance(from: lastLoc)
            tripDistance += newDistance
        }
        
        // Update last location
        lastLocation = location
        
        // Update speed readings
        let currentSpeed = location.speed
        if currentSpeed > 0 {
            speedReadings.append(currentSpeed)
            
            // Update top speed
            if currentSpeed > tripTopSpeed {
                tripTopSpeed = currentSpeed
            }
        }
    }
    
    // Show speed warning when exceeding speed limit
    func showSpeedWarning(speed: Double, limit: Double) {
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
}

// Trip summary view with share functionality
struct TripSummaryView: View {
    let startTime: Date
    let endTime: Date
    let distance: Double // in meters
    let topSpeed: Double // in m/s
    let avgSpeed: Double // in m/s
    let useMetric: Bool
    @ObservedObject var appState: AppState
    
    @Environment(\.presentationMode) var presentationMode
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                Text("Trip Summary")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // Trip details
                VStack(spacing: 15) {
                    SummaryRow(title: "Start Time", value: formatDate(startTime))
                    SummaryRow(title: "End Time", value: formatDate(endTime))
                    SummaryRow(title: "Duration", value: formatDuration(endTime.timeIntervalSince(startTime)))
                    SummaryRow(title: "Distance", value: formatDistance(distance, useMetric: useMetric))
                    SummaryRow(title: "Top Speed", value: formatSpeed(topSpeed, useMetric: useMetric))
                    SummaryRow(title: "Average Speed", value: formatSpeed(avgSpeed, useMetric: useMetric))
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
                
                // Share button
                Button {
                    showingShareSheet = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Trip Details")
                    }
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: appState.theme.gradientColors),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)
                .animation(.easeInOut(duration: 0.5), value: appState.theme)
            )
            .foregroundColor(.white)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: [tripSummaryText])
            }
        }
    }
    
    // Format date to string
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Format duration to string
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let seconds = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    // Format distance to string
    private func formatDistance(_ meters: Double, useMetric: Bool) -> String {
        if useMetric {
            if meters >= 1000 {
                return String(format: "%.2f km", meters / 1000)
            } else {
                return String(format: "%.0f m", meters)
            }
        } else {
            let miles = meters / 1609.34
            return String(format: "%.2f mi", miles)
        }
    }
    
    // Format speed to string
    private func formatSpeed(_ metersPerSecond: Double, useMetric: Bool) -> String {
        if useMetric {
            let kph = metersPerSecond * 3.6
            return String(format: "%.1f km/h", kph)
        } else {
            let mph = metersPerSecond * 2.23694
            return String(format: "%.1f mph", mph)
        }
    }
    
    // Generate text summary for sharing
    private var tripSummaryText: String {
        """
        CruiseAI Trip Summary
        
        Date: \(formatDate(startTime))
        Duration: \(formatDuration(endTime.timeIntervalSince(startTime)))
        Distance: \(formatDistance(distance, useMetric: useMetric))
        Top Speed: \(formatSpeed(topSpeed, useMetric: useMetric))
        Average Speed: \(formatSpeed(avgSpeed, useMetric: useMetric))
        
        Shared from CruiseAI
        """
    }
}

// Summary row component
struct SummaryRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            Text(value)
                .font(.body)
                .foregroundColor(.white)
        }
        .padding(.horizontal)
    }
}

// Share sheet using UIActivityViewController
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Preview provider
struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Preview not available")
    }
}
