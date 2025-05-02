//
//  BoundingBoxView.swift
//  CruiseAIios
//
//  Created by Ojas Kandhare on 4/7/25.
//

import SwiftUI
import Foundation

struct BoundingBoxView: View {
    let object: DetectedObject
    let theme: AppTheme
    @State private var isAnimating = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Bounding box
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.accentColor, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.accentColor.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            theme.accentColor.opacity(0.5),
                            lineWidth: 1
                        )
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .opacity(isAnimating ? 0.0 : 1.0)
                )
            
            // Label with confidence
            HStack(spacing: 4) {
                Text(object.label)
                    .font(.system(size: 12, weight: .semibold))
                Text(String(format: "%.0f%%", object.confidence * 100))
                    .font(.system(size: 10, weight: .medium))
                    .opacity(0.8)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(theme.accentColor.opacity(0.3), lineWidth: 1)
                    )
            )
            .offset(x: 0, y: -25)
        }
        .frame(width: object.boundingBox.width, height: object.boundingBox.height)
        .position(
            x: object.boundingBox.midX,
            y: object.boundingBox.midY
        )
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: false)
            ) {
                isAnimating = true
            }
        }
    }
}

struct DetectionOverlayView: View {
    let objects: [DetectedObject]
    let theme: AppTheme
    let screenSize: CGSize
    
    var body: some View {
        ZStack {
            // Stats overlay at the top
            VStack {
                GlassContainer(theme: theme, padding: 10) {
                    HStack(spacing: 15) {
                        // Object count
                        HStack(spacing: 8) {
                            Image(systemName: "cube.fill")
                                .foregroundColor(theme.accentColor)
                            Text("\(objects.count)")
                                .foregroundColor(.white)
                                .font(.system(size: 14, weight: .semibold))
                            Text("Objects")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.system(size: 12))
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.3))
                        
                        // Processing indicator
                        HStack(spacing: 8) {
                            Image(systemName: "cpu.fill")
                                .foregroundColor(theme.accentColor)
                            Text("Processing")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.system(size: 12))
                        }
                    }
                }
                .frame(maxWidth: screenSize.width * 0.8)
                
                Spacer()
            }
            .padding(.top, 10)
            
            // Bounding boxes
            ForEach(objects) { object in
                BoundingBoxView(object: object, theme: theme)
            }
        }
    }
}

// Preview provider
struct BoundingBoxView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            DetectionOverlayView(
                objects: [
                    DetectedObject(
                        label: "Car",
                        confidence: 0.95,
                        boundingBox: CGRect(x: 100, y: 100, width: 200, height: 150)
                    ),
                    DetectedObject(
                        label: "Person",
                        confidence: 0.88,
                        boundingBox: CGRect(x: 350, y: 200, width: 100, height: 200)
                    )
                ],
                theme: .midnight,
                screenSize: CGSize(width: 600, height: 800)
            )
        }
    }
}
