//
//  GlassComponents.swift
//  CruiseAIios
//
//  Created by Ojas Kandhare on 4/7/25.
//

import SwiftUI

// Instead of using @_exported import, directly import the necessary components
// Remove: @_exported import struct CruiseAIios.GlassContainer

// Modern glass button with icon and text
struct GlassButton: View {
    let theme: AppTheme
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
            
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(theme.accentColor.opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: theme.accentColor.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(GlassButtonStyle())
    }
}

// Glass card for stats and info display
struct GlassCard<Content: View>: View {
    let theme: AppTheme
    let padding: CGFloat
    let content: Content
    
    init(theme: AppTheme, padding: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.theme = theme
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(theme.accentColor.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(color: theme.accentColor.opacity(0.1), radius: 6, x: 0, y: 3)
    }
}

// Custom button style for glass buttons
struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
