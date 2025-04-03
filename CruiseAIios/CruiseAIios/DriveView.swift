//
//  DriveView.swift
//  CruiseAIios
//
//  Created by Ojas Kandhare on 4/2/25.
//

import SwiftUI
import AVFoundation

struct DriveView: View {
    @State private var isDriving = false
    @State private var driveStartTime: Date?
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @ObservedObject var appState: AppState
    
    var body: some View {
        ZStack {
            // Camera view with object detection and depth estimation
            CameraView(appState: appState)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                // Drive information at the top
                if isDriving {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Drive in progress")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Duration: \(formattedElapsedTime)")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        .padding(10)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        
                        Spacer()
                    }
                    .padding(.top, 50)
                    .padding(.horizontal, 20)
                }
                
                Spacer()
                
                // Drive button at the bottom
                Button(action: {
                    toggleDrive()
                }) {
                    Text(isDriving ? "Stop Drive" : "Start Drive")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(isDriving ? Color.red : Color.green)
                        .cornerRadius(10)
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 30)
            }
        }
    }
    
    // Toggle drive state
    private func toggleDrive() {
        isDriving.toggle()
        
        if isDriving {
            // Start the drive
            driveStartTime = Date()
            startTimer()
        } else {
            // Stop the drive
            stopTimer()
            elapsedTime = 0
        }
    }
    
    // Start the timer to track drive duration
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let startTime = driveStartTime {
                elapsedTime = Date().timeIntervalSince(startTime)
            }
        }
    }
    
    // Stop the timer
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // Format the elapsed time as mm:ss
    private var formattedElapsedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct DriveView_Previews: PreviewProvider {
    static var previews: some View {
        DriveView(appState: AppState())
    }
}
