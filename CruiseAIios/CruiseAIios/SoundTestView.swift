//
//  SoundTestView.swift
//  CruiseAIios
//
//  Created by Ojas Kandhare on 4/10/25.
//

import SwiftUI

struct SoundTestView: View {
    let objectTypes = ["person", "bicycle", "traffic light", "stop sign"]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Tap a button to test the instrumental sound for each object type")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                ForEach(objectTypes, id: \.self) { objectType in
                    Button(action: {
                        // Play the sound
                        SoundManager.shared.playSoundForObject(objectType)
                    }) {
                        HStack {
                            // Icon based on object type
                            Image(systemName: iconForObjectType(objectType))
                                .font(.title2)
                            
                            Text(objectType.capitalized)
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Sound Test")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // Helper to get system icons for each object type
    private func iconForObjectType(_ type: String) -> String {
        switch type.lowercased() {
        case "person":
            return "person.fill"
        case "bicycle":
            return "bicycle"
        case "traffic light":
            return "light.beacon.max.fill"
        case "stop sign":
            return "octagon.fill"
        default:
            return "questionmark.circle"
        }
    }
}

#Preview {
    SoundTestView()
} 