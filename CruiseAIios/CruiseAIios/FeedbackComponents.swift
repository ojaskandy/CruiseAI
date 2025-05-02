//
//  FeedbackComponents.swift
//  CruiseAIios
//
//  Created by Ojas Kandhare on 4/3/25.
//

import SwiftUI

// Feedback button that appears on HomePage and ProfileView
struct FeedbackButton: View {
    @State private var isGlowing = false
    @State private var isPressed = false
    
    public var body: some View {
        Button(action: {
            // Open feedback form
            if let url = URL(string: "https://forms.gle/upoTt5ZRXGCgxvFq7") {
                UIApplication.shared.open(url)
            }
        }) {
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [Color.green.opacity(0.5), Color.green.opacity(0)]),
                            center: .center,
                            startRadius: 15,
                            endRadius: 35
                        )
                    )
                    .frame(width: 70, height: 70)
                    .opacity(isGlowing ? 0.8 : 0)
                    .scaleEffect(isGlowing ? 1.2 : 0.8)
                
                // Button background
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.green.opacity(0.8), Color.blue.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                
                // Arrow icon
                Image(systemName: "arrow.up")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            // Start glow animation
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isGlowing = true
            }
        }
        .onLongPressGesture(minimumDuration: 0.1, maximumDistance: 10, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.2)) {
                self.isPressed = pressing
            }
        }, perform: {})
    }
}

// Feedback popup that appears occasionally
public struct FeedbackPopup: View {
    @Binding var isShowing: Bool
    @State private var offset: CGFloat = 1000
    
    public init(isShowing: Binding<Bool>) {
        self._isShowing = isShowing
    }
    
    public var body: some View {
        ZStack {
            if isShowing {
                // Dimmed background
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        dismissPopup()
                    }
                
                // Popup content
                VStack(spacing: 20) {
                    // Close button
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            dismissPopup()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.trailing, 10)
                        .padding(.top, 10)
                    }
                    
                    // Logo
                    ZStack {
                        // Colorful gradient background for logo
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.95, green: 0.3, blue: 0.5),  // Pink
                                        Color(red: 1.0, green: 0.5, blue: 0.2),   // Orange
                                        Color(red: 0.3, green: 0.9, blue: 0.5)    // Green
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                        
                        // "C" letter for CruiseAI
                        Image(systemName: "c.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                    }
                    
                    // Title
                    Text("Make this better")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    // Message
                    Text("Your feedback helps us improve driving safety for everyone.")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    // Feedback button
                    Button(action: {
                        if let url = URL(string: "https://forms.gle/upoTt5ZRXGCgxvFq7") {
                            UIApplication.shared.open(url)
                        }
                        dismissPopup()
                    }) {
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 20))
                            
                            Text("Give Feedback")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 25)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.green.opacity(0.8), Color.blue.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(15)
                        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
                    }
                    
                    // Dismiss button
                    Button(action: {
                        dismissPopup()
                    }) {
                        Text("Maybe Later")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.bottom, 20)
                }
                .frame(width: 300)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.3), Color(red: 0.2, green: 0.2, blue: 0.4)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                .offset(y: offset)
            }
        }
        .animation(.spring(), value: offset)
        .animation(.easeInOut, value: isShowing)
        .onChange(of: isShowing) { oldValue, newValue in
            if newValue {
                // Show popup with animation
                withAnimation(.spring()) {
                    offset = 0
                }
            } else {
                // Hide popup with animation
                withAnimation(.spring()) {
                    offset = 1000
                }
            }
        }
    }
    
    private func dismissPopup() {
        withAnimation {
            isShowing = false
        }
    }
}

// Feedback manager to handle occasional prompts
public class FeedbackManager: ObservableObject {
    @Published public var showFeedbackPopup = false
    private var lastPromptDate: Date?
    private let minDaysBetweenPrompts = 3 // Show popup every 3 days at most
    
    // Check if we should show a feedback prompt
    public func checkForFeedbackPrompt() {
        // If popup is already showing, do nothing
        if showFeedbackPopup {
            return
        }
        
        // If we've never shown a prompt, or it's been at least minDaysBetweenPrompts days
        if lastPromptDate == nil || daysSinceLastPrompt() >= minDaysBetweenPrompts {
            // 20% chance to show the popup on any given check
            if Int.random(in: 1...5) == 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { // Delay by 5 seconds
                    self.showFeedbackPopup = true
                    self.lastPromptDate = Date()
                }
            }
        }
    }
    
    // Calculate days since last prompt
    private func daysSinceLastPrompt() -> Int {
        guard let lastDate = lastPromptDate else { return Int.max }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: lastDate, to: Date())
        return components.day ?? Int.max
    }
}

struct FeedbackComponents_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 50) {
                FeedbackButton()
                
                Text("Feedback Button")
                    .foregroundColor(.white)
            }
        }
    }
}
