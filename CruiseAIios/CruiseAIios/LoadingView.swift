import SwiftUI

struct LoadingView: View {
    @Binding var progress: CGFloat
    @Binding var message: String
    let gradientColors: [Color]
    @State private var isAnimating = false
    private let theme = AppTheme.midnight
    
    var body: some View {
        GlassContainer(theme: theme, padding: 30) {
            VStack(spacing: 30) {
                // CruiseAI logo with pulsing effect
                Text("CruiseAI")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: theme.accentColor.opacity(0.5), radius: 10, x: 0, y: 0)
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                    .padding(.bottom, 20)
                
                // Loading message
                Text(message)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                // Progress bar with car animation
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .frame(height: 12)
                    
                    // Progress bar
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.accentColor)
                        .frame(width: UIScreen.main.bounds.width * 0.7 * progress, height: 12)
                    
                    // Car icon with glow
                    Image(systemName: "car.fill")
                        .font(.system(size: 30))
                        .foregroundColor(theme.accentColor)
                        .shadow(color: theme.accentColor.opacity(0.8), radius: 8, x: 0, y: 0)
                        .offset(x: UIScreen.main.bounds.width * 0.7 * progress - 15, y: -20)
                }
                .frame(width: UIScreen.main.bounds.width * 0.7)
                .padding(.vertical, 30)
                
                // Safety message with glass effect
                GlassContainer(theme: theme, padding: 15) {
                    HStack(spacing: 10) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 24))
                            .foregroundColor(theme.accentColor)
                        
                        Text("DRIVE SAFE")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(.white)
                    }
                }
                .padding(.top, 20)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
} 