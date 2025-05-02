//
//  ThemeSelector.swift
//  CruiseAIios
//
//  Created by Ojas Kandhare on 4/7/25.
//

import SwiftUI

struct ThemeSelector: View {
    @ObservedObject var appState: AppState
    @State private var selectedTheme: AppTheme
    @State private var isAnimating = false
    
    init(appState: AppState) {
        self.appState = appState
        _selectedTheme = State(initialValue: appState.theme)
    }
    
    var body: some View {
        GlassContainer(theme: appState.theme) {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Image(systemName: "paintbrush.fill")
                        .font(.system(size: 24))
                        .foregroundColor(appState.theme.accentColor)
                    
                    Text("Theme")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                // Theme grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 15) {
                    ForEach(AppTheme.allCases) { theme in
                        ThemePreview(
                            theme: theme,
                            isSelected: selectedTheme == theme,
                            action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedTheme = theme
                                    appState.theme = theme
                                    appState.saveUserData()
                                }
                                
                                // Haptic feedback
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                            }
                        )
                    }
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }
}

// Theme preview card
struct ThemePreview: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Theme preview
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: theme.gradientColors,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? theme.accentColor : .clear,
                                lineWidth: 2
                            )
                    )
                    .shadow(
                        color: theme.accentColor.opacity(0.3),
                        radius: isSelected ? 8 : 0
                    )
                
                // Theme name
                Text(theme.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial.opacity(0.5))
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSelected)
        }
    }
}

// Preview provider
struct ThemeSelector_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            ThemeSelector(appState: AppState())
        }
    }
}
