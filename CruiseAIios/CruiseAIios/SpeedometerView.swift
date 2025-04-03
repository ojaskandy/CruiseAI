//
//  SpeedometerView.swift
//  CruiseAIios
//
//  Created by Ojas Kandhare on 4/3/25.
//

import SwiftUI

struct SpeedometerView: View {
    @ObservedObject var locationManager: LocationManager
    var useMetric: Bool = false // Whether to show KPH (true) or MPH (false)
    
    // Speed thresholds for color changes (in the displayed unit)
    private let lowSpeedThreshold: Double = 30.0
    private let mediumSpeedThreshold: Double = 60.0
    private let highSpeedThreshold: Double = 90.0
    
    // Maximum speed for the gauge (in the displayed unit)
    private let maxSpeed: Double = 120.0
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                .frame(width: 150, height: 150)
            
            // Speed progress
            Circle()
                .trim(from: 0, to: CGFloat(min(currentSpeed / maxSpeed, 1.0)))
                .stroke(speedColor, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                .frame(width: 150, height: 150)
                .rotationEffect(.degrees(-90))
                .animation(.easeOut, value: currentSpeed)
            
            // Speed text
            VStack {
                Text("\(Int(currentSpeed))")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(useMetric ? "km/h" : "mph")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding()
        .background(Color.black.opacity(0.6))
        .cornerRadius(20)
    }
    
    // Current speed in the selected unit
    private var currentSpeed: Double {
        useMetric ? locationManager.speedKPH : locationManager.speedMPH
    }
    
    // Color based on speed
    private var speedColor: Color {
        if currentSpeed < lowSpeedThreshold {
            return .green
        } else if currentSpeed < mediumSpeedThreshold {
            return .yellow
        } else if currentSpeed < highSpeedThreshold {
            return .orange
        } else {
            return .red
        }
    }
}

// A compact version of the speedometer for smaller displays
struct CompactSpeedometerView: View {
    @ObservedObject var locationManager: LocationManager
    var useMetric: Bool = false
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "speedometer")
                .font(.system(size: 20))
                .foregroundColor(.white)
            
            Text("\(Int(useMetric ? locationManager.speedKPH : locationManager.speedMPH))")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text(useMetric ? "km/h" : "mph")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(10)
    }
}

// Preview provider
struct SpeedometerView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                SpeedometerView(locationManager: LocationManager(), useMetric: false)
                CompactSpeedometerView(locationManager: LocationManager(), useMetric: true)
            }
        }
    }
}
