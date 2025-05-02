//
//  CameraPermissionPage.swift
//  CruiseAIios
//
//  Created by Claude on 4/5/25.
//

import SwiftUI
import AVFoundation

struct CameraPermissionPage: View {
    @StateObject private var cameraManager = CameraPermissionManager()
    @State private var isDriving = false
    @State private var buttonColor: Color = .green
    
    var body: some View {
        ZStack {
            // Camera view as background
            if cameraManager.isAuthorized {
                CameraPermissionPreviewView(session: cameraManager.session)
                    .edgesIgnoringSafeArea(.all)
            } else {
                Color.black
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    Text("Camera Access Required")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding()
                    
                    Text("CruiseAI needs access to your camera to function properly.")
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button(action: {
                        cameraManager.requestPermission()
                    }) {
                        Text("Allow Camera Access")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding()
                }
            }
            
            // Drive controls overlay
            VStack {
                Spacer()
                
                // Drive button
                Button(action: {
                    toggleDrive()
                }) {
                    Text(isDriving ? "Stop Drive" : "Start Drive")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 200)
                        .background(buttonColor)
                        .cornerRadius(10)
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            // Check camera permission when view appears
            cameraManager.checkPermission()
        }
    }
    
    private func toggleDrive() {
        isDriving.toggle()
        
        if isDriving {
            // Start drive
            buttonColor = .red
            // Additional logic for starting a drive would go here
            print("Drive started")
        } else {
            // Stop drive
            buttonColor = .green
            // Additional logic for stopping a drive would go here
            print("Drive stopped")
        }
    }
}

// Camera manager to handle permissions and setup
class CameraPermissionManager: NSObject, ObservableObject {
    @Published var isAuthorized = false
    let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    
    override init() {
        super.init()
        setupSession()
    }
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.isAuthorized = true
            self.startSession()
        case .notDetermined:
            requestPermission()
        case .denied, .restricted:
            self.isAuthorized = false
        @unknown default:
            self.isAuthorized = false
        }
    }
    
    func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if granted {
                    self?.startSession()
                }
            }
        }
    }
    
    private func setupSession() {
        session.beginConfiguration()
        
        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoInput) else {
            print("Failed to set up video input")
            session.commitConfiguration()
            return
        }
        
        session.addInput(videoInput)
        
        // Add video output
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        }
        
        session.commitConfiguration()
    }
    
    func startSession() {
        if !session.isRunning && isAuthorized {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }
    }
    
    func stopSession() {
        if session.isRunning {
            session.stopRunning()
        }
    }
}

// UIViewRepresentable to display the camera feed
struct CameraPermissionPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
}

struct CameraPermissionPage_Previews: PreviewProvider {
    static var previews: some View {
        CameraPermissionPage()
    }
}
