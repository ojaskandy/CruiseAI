//
//  CruiseAIiosApp.swift
//  CruiseAIios
//
//  Created by Ojas Kandhare on 4/2/25.
//

import SwiftUI

@main
struct CruiseAIiosApp: App {
    // Initialize SoundManager at app startup
    init() {
        // Pre-cache sounds for faster response
        SoundManager.shared.precacheSounds()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
