//  GlassContainer.swift
//  CruiseAIios
//
//  Created by Ojas Kandhare on 4/7/25.
//

import SwiftUI

// Reusable glass effect container
struct GlassContainer<Content: View>: View {
    let theme: AppTheme
    let content: Content
    var padding: CGFloat = 20
    var cornerRadius: CGFloat = 20
    
    init(theme: AppTheme, padding: CGFloat = 20, cornerRadius: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.theme = theme
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .opacity(theme.glassOpacity)
                    .blur(radius: theme.glassBlur)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(theme.glassBorderColor, lineWidth: theme.glassBorderWidth)
                    )
            )
            .shadow(
                color: theme.shadowColor,
                radius: theme.shadowRadius,
                x: theme.shadowX,
                y: theme.shadowY
            )
    }
}

// Preview provider
struct GlassContainer_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: AppTheme.midnight.gradientColors),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            GlassContainer(theme: .midnight) {
                Text("Glass Container")
                    .foregroundColor(.white)
                    .font(.title)
            }
            .padding()
        }
    }
}
