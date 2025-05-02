//
//  SpeedometerView.swift
//  CruiseAIios
//
//  Created by Ojas Kandhare on 4/7/25.
//

import SwiftUI

struct ModernSpeedometerView: View {
    let speed: Double
    let maxSpeed: Double
    let useMetric: Bool
    let theme: AppTheme
    @State private var animatedSpeed: Double = 0
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(
                    theme.accentColor.opacity(0.2),
                    lineWidth: 15
                )
            
            // Progress ring
            Circle()
                .trim(from: 0, to: min(animatedSpeed / maxSpeed, 1.0))
                .stroke(
                    theme.accentColor,
                    style: StrokeStyle(
                        lineWidth: 15,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6), value: animatedSpeed)
            
            // Speed text
            VStack(spacing: 5) {
                Text(String(format: "%.1f", speed))
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(useMetric ? "KPH" : "MPH")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Pulsing ring
            Circle()
                .stroke(theme.accentColor.opacity(0.5), lineWidth: 2)
                .scaleEffect(animatedSpeed > 0 ? 1.1 : 1.0)
                .opacity(animatedSpeed > 0 ? 0.0 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: false),
                    value: animatedSpeed
                )
        }
        .onAppear {
            // Initialize the animation with the current speed
            animatedSpeed = speed
        }
        .onChange(of: speed) { newSpeed in
            withAnimation {
                animatedSpeed = newSpeed
            }
        }
    }
}

struct CompactSpeedometerView: View {
    let speed: Double
    let maxSpeed: Double
    let useMetric: Bool
    let theme: AppTheme
    @State private var animatedSpeed: Double = 0
    
    var body: some View {
        GlassContainer(theme: theme, padding: 15) {
            HStack(spacing: 15) {
                // Mini speedometer ring
                ZStack {
                    Circle()
                        .stroke(
                            theme.accentColor.opacity(0.2),
                            lineWidth: 4
                        )
                        .frame(width: 40, height: 40)
                    
                    Circle()
                        .trim(from: 0, to: min(animatedSpeed / maxSpeed, 1.0))
                        .stroke(
                            theme.accentColor,
                            style: StrokeStyle(
                                lineWidth: 4,
                                lineCap: .round
                            )
                        )
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6), value: animatedSpeed)
                }
                
                // Speed text
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%.1f", speed))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(useMetric ? "KPH" : "MPH")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .onAppear {
            // Initialize the animation with the current speed
            animatedSpeed = speed
        }
        .onChange(of: speed) { newSpeed in
            withAnimation {
                animatedSpeed = newSpeed
            }
        }
    }
}

struct SpeedometerView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                ModernSpeedometerView(
                    speed: 65,
                    maxSpeed: 120,
                    useMetric: false,
                    theme: .midnight
                )
                .frame(width: 200, height: 200)
                
                CompactSpeedometerView(
                    speed: 65,
                    maxSpeed: 120,
                    useMetric: false,
                    theme: .midnight
                )
            }
        }
    }
}
