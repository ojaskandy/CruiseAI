//
//  AppState.swift
//  CruiseAIios
//
//  Created by Ojas Kandhare on 4/3/25.
//

import SwiftUI

// Modern app state with enhanced theme support
public class AppState: ObservableObject {
    @Published public var theme: AppTheme = .midnight
    @Published public var userName: String = ""
    @Published public var userEmail: String = ""
    @Published public var hasCompletedSetup: Bool = false
    
    // Feedback manager for handling occasional prompts
    @Published public var feedbackManager = FeedbackManager()
    
    // Trip store for handling and persisting trip history
    @Published internal var tripStore = TripStore()
    
    // User defaults keys
    private let userNameKey = "userName"
    private let userEmailKey = "userEmail"
    private let hasCompletedSetupKey = "hasCompletedSetup"
    private let themeKey = "theme"
    
    public init() {
        // Load saved user data
        if let name = UserDefaults.standard.string(forKey: userNameKey) {
            userName = name
        }
        
        if let email = UserDefaults.standard.string(forKey: userEmailKey) {
            userEmail = email
        }
        
        hasCompletedSetup = UserDefaults.standard.bool(forKey: hasCompletedSetupKey)
        
        if let savedTheme = UserDefaults.standard.string(forKey: themeKey),
           let appTheme = AppTheme(rawValue: savedTheme) {
            theme = appTheme
        }
        
        // Load trip history
        tripStore.loadTrips()
    }
    
    // Save user data when properties change
    public func saveUserData() {
        UserDefaults.standard.set(userName, forKey: userNameKey)
        UserDefaults.standard.set(userEmail, forKey: userEmailKey)
        UserDefaults.standard.set(hasCompletedSetup, forKey: hasCompletedSetupKey)
        UserDefaults.standard.set(theme.rawValue, forKey: themeKey)
    }
}
