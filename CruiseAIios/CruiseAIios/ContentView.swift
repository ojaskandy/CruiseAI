//
//  ContentView.swift
//  CruiseAIios
//
//  Created by Ojas Kandhare on 4/2/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()
    @State private var showSetup = false
    
    var body: some View {
        // Main content
        HomePage(appState: appState)
            .onAppear {
                // Check if setup is needed
                if !appState.hasCompletedSetup {
                    showSetup = true
                }
                
                // Check for feedback prompts
                appState.feedbackManager.checkForFeedbackPrompt()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                // Check for feedback prompts when app becomes active
                appState.feedbackManager.checkForFeedbackPrompt()
            }
            .fullScreenCover(isPresented: $showSetup) {
                // Setup view
                SetupView(appState: appState, isPresented: $showSetup)
                    .onDisappear {
                        // Save user data when setup is completed
                        appState.saveUserData()
                    }
            }
    }
}

#Preview {
    ContentView()
}
