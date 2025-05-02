//
//  HomePage.swift
//  CruiseAIios
//
//  Created by Ojas Kandhare on 4/3/25.
//

import SwiftUI
import MapKit

struct HomePage: View {
    @State private var isAnimating = false
    @State private var showMapsPicker = false
    @State private var showHistoryView = false
    @State private var showProfileView = false
    @State private var currentTime = Date()
    @State private var selectedTab = 0
    @State private var showLoadingDrive = false
    @State private var showSafetyAlert = false // For drive safety popup
    @State private var showSetupInstructions = false // For setup instructions popup
    @State private var showSoundTest = false
    
    // App state for sharing theme
    @ObservedObject var appState: AppState
    
    // Timer for updating the current time
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Gradient background with theme colors
                LinearGradient(gradient: Gradient(colors: appState.theme.gradientColors), 
                               startPoint: .topLeading, 
                               endPoint: .bottomTrailing)
                    .edgesIgnoringSafeArea(.all)
                    .animation(.easeInOut(duration: 0.5), value: appState.theme)
                
                // Content in ScrollView for scrollability
                ScrollView {
                    VStack(spacing: 20) {
                        // Header with time and logo
                        HStack {
                            // Current time
                            Text(timeString)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .onReceive(timer) { _ in
                                    currentTime = Date()
                                }
                            
                            Spacer()
                            
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
                                    .frame(width: 50, height: 50)
                                
                                // "C" letter for CruiseAI
                                Image(systemName: "c.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white)
                            }
                            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
                            .scaleEffect(isAnimating ? 1.1 : 1.0)
                            .animation(
                                Animation.easeInOut(duration: 1.5)
                                    .repeatForever(autoreverses: true),
                                value: isAnimating
                            )
                        }
                        .padding(.horizontal, 25)
                        .padding(.top, 20)
                        
                        // Title
                        Text("CruiseAI")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 10)
                        
                // Quick Actions Section with glass effect
                GlassContainer(theme: appState.theme) {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Quick Actions")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.leading, 5)
                            .padding(.bottom, 5)
                        
                        // Setup button with glow effect
                        Button(action: {
                            showSetupInstructions = true
                        }) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.yellow)
                                
                                Text("Setup")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Image(systemName: "sparkles")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.yellow)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 30)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(LinearGradient(
                                        gradient: Gradient(colors: [
                                            appState.theme.accentColor.opacity(0.8),
                                            appState.theme.accentColor
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                    )
                                    .shadow(color: appState.theme.accentColor.opacity(0.7), radius: isAnimating ? 10 : 5, x: 0, y: 0)
                            )
                            .scaleEffect(isAnimating ? 1.02 : 1.0)
                            .animation(
                                Animation.easeInOut(duration: 1.5)
                                    .repeatForever(autoreverses: true),
                                value: isAnimating
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 15)
                        
                        // Grid of action buttons
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 20) {
                            // Start a Drive
                            GlassCard(theme: appState.theme, padding: 15) {
                                Button(action: { 
                                    // Show safety popup first
                                    showSafetyAlert = true
                                }) {
                                    VStack(spacing: 12) {
                                        Image(systemName: "car.circle.fill")
                                            .font(.system(size: 36))
                                            .foregroundColor(appState.theme.accentColor)
                                        
                                        Text("Start a Drive")
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                    .frame(height: 120)
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            
                            // Maps
                            GlassCard(theme: appState.theme, padding: 15) {
                                Button(action: { showMapsPicker = true }) {
                                    VStack(spacing: 12) {
                                        Image(systemName: "map.fill")
                                            .font(.system(size: 36))
                                            .foregroundColor(appState.theme.accentColor)
                                        
                                        Text("Maps")
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                    .frame(height: 120)
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            
                            // History
                            GlassCard(theme: appState.theme, padding: 15) {
                                Button(action: { showHistoryView = true }) {
                                    VStack(spacing: 12) {
                                        Image(systemName: "clock.fill")
                                            .font(.system(size: 36))
                                            .foregroundColor(appState.theme.accentColor)
                                        
                                        Text("History")
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                    .frame(height: 120)
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            
                            // Profile
                            GlassCard(theme: appState.theme, padding: 15) {
                                Button(action: { showProfileView = true }) {
                                    VStack(spacing: 12) {
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 36))
                                            .foregroundColor(appState.theme.accentColor)
                                        
                                        Text("Profile")
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                    .frame(height: 120)
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                        
                        // Info Sections with glass effect
                        VStack(spacing: 15) {
                            // How It Works section
                            GlassCard(theme: appState.theme) {
                                VStack(alignment: .leading, spacing: 15) {
                                    HStack {
                                        Image(systemName: "info.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(appState.theme.accentColor)
                                        
                                        Text("How It Works")
                                            .font(.system(size: 20, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.bottom, 5)
                                    
                                    VStack(alignment: .leading, spacing: 15) {
                                        InfoRow(icon: "camera.fill", title: "Object Detection", description: "Uses your phone's camera to detect vehicles, pedestrians, and road signs in real time", theme: appState.theme)
                                        InfoRow(icon: "rectangle.dashed", title: "Visual Feedback", description: "Displays bounding boxes directly on the live camera feed", theme: appState.theme)
                                        InfoRow(icon: "arrow.left.and.right", title: "Depth Estimation", description: "Estimates relative depth to understand object proximity", theme: appState.theme)
                                        InfoRow(icon: "speedometer", title: "Speed Tracking", description: "Tracks your current speed using GPS and shows it on-screen", theme: appState.theme)
                                        InfoRow(icon: "hand.raised.fill", title: "Simple & Safe", description: "Designed for safety and simplicity—no extra hardware needed", theme: appState.theme)
                                    }
                                }
                            }
                            
                            // Coming Soon section with pulsing effect
                            GlassCard(theme: appState.theme) {
                                VStack(alignment: .leading, spacing: 15) {
                                    HStack {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 24))
                                            .foregroundColor(appState.theme.accentColor)
                                            .opacity(isAnimating ? 1.0 : 0.5)
                                            .animation(
                                                Animation.easeInOut(duration: 1.5)
                                                    .repeatForever(autoreverses: true),
                                                value: isAnimating
                                            )
                                        
                                        Text("Coming Soon")
                                            .font(.system(size: 20, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.bottom, 5)
                                    
                                    VStack(alignment: .leading, spacing: 15) {
                                        InfoRow(icon: "exclamationmark.triangle.fill", title: "Lane Drift Detection", description: "Visual and audio alerts when drifting from your lane", theme: appState.theme)
                                        InfoRow(icon: "car.2.fill", title: "Collision Warning", description: "Advanced warning system based on depth + motion", theme: appState.theme)
                                        InfoRow(icon: "exclamationmark.octagon.fill", title: "Traffic Violation Detection", description: "Red light and stop sign violation detection", theme: appState.theme)
                                        InfoRow(icon: "chart.bar.fill", title: "Driver Analytics", description: "Smart trip summaries and driver score analytics", theme: appState.theme)
                                        InfoRow(icon: "message.fill", title: "Guardian Alerts", description: "Seamless SMS alerts for parents or guardians", theme: appState.theme)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Add some padding at the bottom to ensure content doesn't get hidden behind the tab bar
                        Spacer(minLength: 100)
                    }
                    .padding(.vertical)
                }
                
                // Feedback button (positioned at the bottom right)
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        FeedbackButton()
                            .padding(.trailing, 20)
                            .padding(.bottom, 80) // Position above the tab bar
                    }
                }
                
                // Floating tab bar at the bottom
                VStack {
                    Spacer()
                    
                    FloatingTabBar(
                        selectedTab: $selectedTab,
                        tabs: [
                            (icon: "car.fill", title: "Drive"),
                            (icon: "map.fill", title: "Maps"),
                            (icon: "clock.fill", title: "History"),
                            (icon: "person.fill", title: "Profile")
                        ]
                    )
                    .padding(.bottom, 20)
                }
                
                // Feedback popup
                FeedbackPopup(isShowing: $appState.feedbackManager.showFeedbackPopup)
                
                // Safety alert popup
                if showSafetyAlert {
                    ZStack {
                        // Dimmed background
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)
                            .onTapGesture {
                                // Don't dismiss on outside tap
                            }
                        
                        // Glass popup
                        GlassContainer(theme: appState.theme, padding: 20) {
                            VStack(spacing: 15) {
                                // Title
                                HStack {
                                    Image(systemName: "exclamationmark.shield.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(appState.theme.accentColor)
                                    
                                    Text("Drive Safely")
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    // Close button
                                    Button(action: {
                                        showSafetyAlert = false
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                }
                                
                                Divider()
                                    .background(Color.white.opacity(0.3))
                                    .padding(.vertical, 5)
                                
                                // Content
                                VStack(alignment: .leading, spacing: 12) {
                                    InfoRow(icon: "bell.fill", title: "Enable Sound", description: "Sounds will play even when your device is in silent mode", theme: appState.theme, isImportant: true)
                                    
                                    InfoRow(icon: "hand.raised.fill", title: "Drive Safely", description: "Keep your eyes on the road and use a mount for your device", theme: appState.theme)
                                    
                                    InfoRow(icon: "exclamationmark.triangle.fill", title: "Be Aware", description: "This app is for assistance only - always obey traffic laws", theme: appState.theme)
                                }
                                
                                // Buttons
                                HStack(spacing: 15) {
                                    // Cancel button
                                    Button(action: {
                                        showSafetyAlert = false
                                    }) {
                                        Text("Cancel")
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            .foregroundColor(.white.opacity(0.9))
                                            .padding(.vertical, 12)
                                            .frame(maxWidth: .infinity)
                                            .background(Color.white.opacity(0.2))
                                            .cornerRadius(12)
                                    }
                                    
                                    // Start button
                                    Button(action: {
                                        showSafetyAlert = false
                                        showLoadingDrive = true
                                    }) {
                                        Text("Start Drive")
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            .foregroundColor(.white)
                                            .padding(.vertical, 12)
                                            .frame(maxWidth: .infinity)
                                            .background(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [appState.theme.accentColor, appState.theme.accentColor.opacity(0.7)]),
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .cornerRadius(12)
                                    }
                                }
                                .padding(.top, 10)
                            }
                            .padding()
                        }
                        .frame(width: UIScreen.main.bounds.width - 60)
                    }
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: showSafetyAlert)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                isAnimating = true
            }
            .onChange(of: selectedTab) { _, newTab in
                switch newTab {
                case 0: // Drive
                    break // Navigation is handled by NavigationLink
                case 1: // Maps
                    showMapsPicker = true
                case 2: // History
                    showHistoryView = true
                case 3: // Profile
                    showProfileView = true
                default:
                    return
                }
            }
            .actionSheet(isPresented: $showMapsPicker) {
                ActionSheet(
                    title: Text("Open Maps"),
                    message: Text("Choose your preferred maps application"),
                    buttons: [
                        .default(Text("Apple Maps")) {
                            openAppleMaps()
                        },
                        .default(Text("Google Maps")) {
                            openGoogleMaps()
                        },
                        .cancel()
                    ]
                )
            }
            .sheet(isPresented: $showHistoryView) {
                HistoryView(appState: appState)
            }
            .sheet(isPresented: $showProfileView) {
                ProfileView(appState: appState)
            }
            // Setup Instructions Sheet
            .sheet(isPresented: $showSetupInstructions) {
                SetupInstructionsView(isPresented: $showSetupInstructions)
            }
            .sheet(isPresented: $showSoundTest) {
                SoundTestView()
            }
        }
        .fullScreenCover(isPresented: $showLoadingDrive) {
            // Show loading view first, then transition to drive page
            LoadingDriveView(appState: appState)
        }
    }
    
    // Formatted time string
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: currentTime)
    }
    
    // Open Apple Maps
    private func openAppleMaps() {
        if let url = URL(string: "maps://") {
            UIApplication.shared.open(url)
        }
    }
    
    // Open Google Maps
    private func openGoogleMaps() {
        if let url = URL(string: "comgooglemaps://") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                // If Google Maps is not installed, open in App Store
                if let appStoreURL = URL(string: "https://apps.apple.com/app/google-maps/id585027354") {
                    UIApplication.shared.open(appStoreURL)
                }
            }
        }
    }
}

// Info Row component with glass effect
struct InfoRow: View {
    let icon: String
    let title: String
    let description: String
    let theme: AppTheme
    var isImportant: Bool = false
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(isImportant ? .red : theme.accentColor)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                        .opacity(theme.glassOpacity)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                if isImportant {
                    Text("**SOUNDS WILL PLAY** even when your device is in silent mode")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                } else {
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            Spacer()
        }
    }
}

// Floating Tab Bar
struct FloatingTabBar: View {
    @Binding var selectedTab: Int
    let tabs: [(icon: String, title: String)]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button {
                    withAnimation(.spring()) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tabs[index].icon)
                            .font(.system(size: 24))
                            .foregroundColor(selectedTab == index ? .white : .white.opacity(0.6))
                        
                        Text(tabs[index].title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(selectedTab == index ? .white : .white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selectedTab == index ? Color.white.opacity(0.2) : Color.clear)
                    .cornerRadius(10)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(red: 0.1, green: 0.1, blue: 0.2).opacity(0.9))
        .cornerRadius(25)
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 20)
    }
}

struct HomePage_Previews: PreviewProvider {
    static var previews: some View {
        HomePage(appState: AppState())
    }
}

// Setup Instructions View
struct SetupInstructionsView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    // Header
                    VStack(alignment: .center, spacing: 10) {
                        Image(systemName: "car.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                Circle()
                                    .fill(LinearGradient(
                                        gradient: Gradient(colors: [.blue, .purple]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                            )
                            .shadow(color: .blue.opacity(0.5), radius: 10)
                        
                        Text("How to Set Up CruiseAI")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.top, 10)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    
                    // Step 1
                    SetupStep(
                        number: 1,
                        title: "Mount Your Phone",
                        description: "Attach phone to car phone mount and ensure cameras can see through windshield (contact ojaskandy@gmail.com if you need a phone mount)",
                        icon: "iphone.gen3"
                    )
                    
                    // Step 2
                    SetupStep(
                        number: 2,
                        title: "Start Drive",
                        description: "Click start a drive. Wait for it to load and start driving when you see the drive page on your screen. (Drive safe. Click stop drive if the app is buggy and report the issue later)",
                        icon: "car.fill"
                    )
                    
                    // Step 3
                    SetupStep(
                        number: 3,
                        title: "End & Share",
                        description: "Click stop drive when you've reached your destination. Share your trip details by clicking \"share\" with a friend to let them know you've arrived or with a loved one to let them know you had a successful drive",
                        icon: "square.and.arrow.up"
                    )
                    
                    // Close button
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("Got it!")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .shadow(color: Color.blue.opacity(0.3), radius: 10)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, 25)
                .background(
                    Color.black
                        .edgesIgnoringSafeArea(.all)
                )
            }
            .navigationBarTitle("Setup Guide", displayMode: .inline)
            .navigationBarItems(trailing: Button(action: {
                isPresented = false
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            })
        }
        .preferredColorScheme(.dark)
    }
}

struct SetupStep: View {
    var number: Int
    var title: String
    var description: String
    var icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 16) {
                // Step number
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    
                    Text("\(number)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Title
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue.opacity(0.7), .purple.opacity(0.7)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }
            
            // Description
            Text(description)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 56)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue.opacity(0.5), .purple.opacity(0.5)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}
