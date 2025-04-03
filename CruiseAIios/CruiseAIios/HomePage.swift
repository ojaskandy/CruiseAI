//
//  HomePage.swift
//  CruiseAIios
//
//  Created by Ojas Kandhare on 4/3/25.
//

import SwiftUI
import MapKit

// App theme options
enum AppTheme: String, CaseIterable, Identifiable {
    case blue = "Blue"
    case purple = "Purple"
    case green = "Green"
    case orange = "Orange"
    case red = "Red"
    
    var id: String { self.rawValue }
    
    var gradientColors: [Color] {
        switch self {
        case .blue:
            return [
                Color(red: 0.05, green: 0.1, blue: 0.3),
                Color(red: 0.1, green: 0.2, blue: 0.45),
                Color(red: 0.2, green: 0.4, blue: 0.6)
            ]
        case .purple:
            return [
                Color(red: 0.2, green: 0.05, blue: 0.3),
                Color(red: 0.4, green: 0.1, blue: 0.6),
                Color(red: 0.6, green: 0.2, blue: 0.8)
            ]
        case .green:
            return [
                Color(red: 0.05, green: 0.2, blue: 0.1),
                Color(red: 0.1, green: 0.4, blue: 0.2),
                Color(red: 0.2, green: 0.6, blue: 0.3)
            ]
        case .orange:
            return [
                Color(red: 0.3, green: 0.1, blue: 0.05),
                Color(red: 0.6, green: 0.2, blue: 0.1),
                Color(red: 0.8, green: 0.4, blue: 0.2)
            ]
        case .red:
            return [
                Color(red: 0.3, green: 0.05, blue: 0.05),
                Color(red: 0.5, green: 0.1, blue: 0.1),
                Color(red: 0.7, green: 0.2, blue: 0.2)
            ]
        }
    }
}

// App state to share between views
class AppState: ObservableObject {
    @Published var theme: AppTheme = .blue
}

struct HomePage: View {
    @State private var isAnimating = false
    @State private var showMonitorView = false
    @State private var showMapsPicker = false
    @State private var showHistoryView = false
    @State private var showProfileView = false
    @State private var currentTime = Date()
    @State private var selectedTab = 0
    
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
                
                // Content
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
                        Image(systemName: "car.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
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
                    
                    // Quick Actions Section
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Quick Actions")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.leading, 5)
                            .padding(.bottom, 5)
                        
                        // Grid of action buttons
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 20) {
                            // Start a Drive
                            QuickActionButton(
                                icon: "car.circle.fill",
                                title: "Start a Drive",
                                color: Color.green
                            ) {
                                showMonitorView = true
                            }
                            
                            // Maps
                            QuickActionButton(
                                icon: "map.fill",
                                title: "Maps",
                                color: Color.blue
                            ) {
                                showMapsPicker = true
                            }
                            
                            // History
                            QuickActionButton(
                                icon: "clock.fill",
                                title: "History",
                                color: Color.orange
                            ) {
                                showHistoryView = true
                            }
                            
                            // Profile
                            QuickActionButton(
                                icon: "person.fill",
                                title: "Profile",
                                color: Color.purple
                            ) {
                                showProfileView = true
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 15)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(20)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Expandable Info Sections
                    VStack(spacing: 15) {
                        // How It Works button
                        ExpandableInfoButton(
                            title: "How It Works",
                            icon: "info.circle.fill",
                            color: Color.blue,
                            content: {
                                VStack(alignment: .leading, spacing: 15) {
                                    InfoRow(icon: "1.circle.fill", title: "Start a Drive", description: "Tap 'Start a Drive' to begin recording your trip")
                                    InfoRow(icon: "2.circle.fill", title: "Allow Permissions", description: "Grant camera and location access when prompted")
                                    InfoRow(icon: "3.circle.fill", title: "Monitor Speed", description: "View your accurate speed with color indicators")
                                    InfoRow(icon: "4.circle.fill", title: "Get Warnings", description: "Receive alerts when exceeding speed limits")
                                    InfoRow(icon: "5.circle.fill", title: "Share Trip", description: "Share your trip details when finished")
                                }
                                .padding(.vertical, 10)
                            }
                        )
                        
                        // Coming Soon button with animation
                        ExpandableInfoButton(
                            title: "Coming Soon",
                            icon: "sparkles",
                            color: Color.purple,
                            isGlowing: true,
                            content: {
                                VStack(alignment: .leading, spacing: 15) {
                                    InfoRow(icon: "bolt.fill", title: "AI Voice Assistant", description: "Hands-free control with voice commands")
                                    InfoRow(icon: "car.2.fill", title: "Lane Detection", description: "Stay in your lane with visual guidance")
                                    InfoRow(icon: "cloud.fill", title: "Cloud Sync", description: "Access your driving data across devices")
                                    InfoRow(icon: "chart.bar.fill", title: "Advanced Analytics", description: "Get insights to improve your driving")
                                    InfoRow(icon: "person.2.fill", title: "Family Sharing", description: "Monitor family members' driving habits")
                                }
                                .padding(.vertical, 10)
                            }
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
                .padding(.vertical)
                
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
            }
            .navigationBarHidden(true)
            .onAppear {
                isAnimating = true
            }
            .onChange(of: selectedTab) { newTab in
                switch newTab {
                case 0: // Drive
                    showMonitorView = true
                case 1: // Maps
                    showMapsPicker = true
                case 2: // History
                    showHistoryView = true
                case 3: // Profile
                    showProfileView = true
                default:
                    break
                }
            }
            .fullScreenCover(isPresented: $showMonitorView) {
                CameraView(appState: appState)
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

// Quick Action Button component
struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .background(color.opacity(0.8))
            .cornerRadius(15)
            .shadow(color: color.opacity(0.4), radius: 5, x: 0, y: 3)
        }
    }
}

// Feature row component
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(Color.white.opacity(0.2))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
    }
}

// History View
struct HistoryView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var appState: AppState
    
    // Sample trip data
    let trips = [
        TripData(date: "Apr 2, 2025", duration: "45 min", distance: "15.2 mi", avgSpeed: "32 mph"),
        TripData(date: "Apr 1, 2025", duration: "28 min", distance: "8.7 mi", avgSpeed: "28 mph"),
        TripData(date: "Mar 30, 2025", duration: "1h 12m", distance: "42.5 mi", avgSpeed: "35 mph"),
        TripData(date: "Mar 28, 2025", duration: "22 min", distance: "5.3 mi", avgSpeed: "24 mph"),
        TripData(date: "Mar 25, 2025", duration: "33 min", distance: "12.1 mi", avgSpeed: "30 mph")
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Theme-based gradient background
                LinearGradient(gradient: Gradient(colors: appState.theme.gradientColors), 
                               startPoint: .top, 
                               endPoint: .bottom)
                    .edgesIgnoringSafeArea(.all)
                    .animation(.easeInOut(duration: 0.5), value: appState.theme)
                
                VStack {
                    List {
                        ForEach(trips) { trip in
                            TripRow(trip: trip)
                                .listRowBackground(Color.white.opacity(0.1))
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationBarTitle("Drive History", displayMode: .inline)
            .navigationBarItems(
                leading: Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back to Home")
                    }
                    .foregroundColor(.white)
                },
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .foregroundColor(.white)
        }
    }
}

// Trip data model
struct TripData: Identifiable {
    let id = UUID()
    let date: String
    let duration: String
    let distance: String
    let avgSpeed: String
}

// Trip row component
struct TripRow: View {
    let trip: TripData
    
    var body: some View {
        HStack {
            Image(systemName: "car.fill")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.3))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.date)
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack(spacing: 12) {
                    Label(trip.duration, systemImage: "clock")
                        .font(.subheadline)
                    
                    Label(trip.distance, systemImage: "map")
                        .font(.subheadline)
                    
                    Label(trip.avgSpeed, systemImage: "speedometer")
                        .font(.subheadline)
                }
                .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.vertical, 8)
    }
}

// Profile View
struct ProfileView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var appState: AppState
    
    // Sample user stats
    let totalDrives = 42
    let totalDistance = 687.5 // miles
    let totalDuration = 1245 // minutes
    let avgSpeed = 33.2 // mph
    let topSpeed = 78.5 // mph
    
    var body: some View {
        NavigationView {
            ZStack {
                // Theme-based gradient background
                LinearGradient(gradient: Gradient(colors: appState.theme.gradientColors), 
                               startPoint: .top, 
                               endPoint: .bottom)
                    .edgesIgnoringSafeArea(.all)
                    .animation(.easeInOut(duration: 0.5), value: appState.theme)
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Profile header
                        VStack(spacing: 15) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.white)
                            
                            Text("Driver Profile")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 20)
                        
                        // Stats overview
                        VStack(spacing: 5) {
                            Text("Driving Statistics")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading)
                            
                            // Stats grid
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 15) {
                                StatCard(title: "Total Drives", value: "\(totalDrives)", icon: "number.circle.fill")
                                StatCard(title: "Total Distance", value: "\(totalDistance) mi", icon: "map.fill")
                                StatCard(title: "Drive Time", value: formatMinutes(totalDuration), icon: "clock.fill")
                                StatCard(title: "Avg Speed", value: "\(avgSpeed) mph", icon: "speedometer")
                                StatCard(title: "Top Speed", value: "\(topSpeed) mph", icon: "flame.fill")
                                StatCard(title: "Fuel Saved", value: "12.3 gal", icon: "leaf.fill")
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                        
                        // Theme selector
                        VStack(spacing: 10) {
                            Text("App Theme")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading)
                            
                            // Theme options
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 15) {
                                    ForEach(AppTheme.allCases) { theme in
                                        ThemeButton(
                                            theme: theme,
                                            isSelected: appState.theme == theme,
                                            action: {
                                                withAnimation {
                                                    appState.theme = theme
                                                }
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .padding(.vertical, 10)
                        }
                        .padding(.vertical)
                        
                        // Recent routes
                        VStack(spacing: 10) {
                            Text("Recent Routes")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading)
                            
                            VStack(spacing: 15) {
                                RouteCard(from: "Home", to: "Work", date: "Today", distance: "8.7 mi")
                                RouteCard(from: "Work", to: "Gym", date: "Yesterday", distance: "3.2 mi")
                                RouteCard(from: "Gym", to: "Home", date: "Yesterday", distance: "5.5 mi")
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitle("Profile", displayMode: .inline)
            .navigationBarItems(
                leading: Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back to Home")
                    }
                    .foregroundColor(.white)
                },
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .foregroundColor(.white)
        }
    }
    
    // Format minutes to hours and minutes
    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)h \(mins)m"
    }
}

// Stat card component
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(.white)
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.1))
        .cornerRadius(15)
    }
}

// Route card component
struct RouteCard: View {
    let from: String
    let to: String
    let date: String
    let distance: String
    
    var body: some View {
        HStack {
            VStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 2, height: 30)
                
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
            }
            .padding(.horizontal, 5)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(from)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Text(to)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 8) {
                Text(date)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                
                Text(distance)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(15)
    }
}

// Expandable Info Button component
struct ExpandableInfoButton<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let isGlowing: Bool
    let content: () -> Content
    
    @State private var isExpanded = false
    @State private var glowOpacity = 0.5
    
    init(title: String, icon: String, color: Color, isGlowing: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.isGlowing = isGlowing
        self.content = content
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Button header
            Button {
                withAnimation(.spring()) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .shadow(color: isGlowing ? color : Color.clear, radius: 5, x: 0, y: 0)
                        .opacity(isGlowing ? glowOpacity : 1.0)
                        .animation(
                            isGlowing ? Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true) : nil,
                            value: glowOpacity
                        )
                        .onAppear {
                            if isGlowing {
                                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                    glowOpacity = 1.0
                                }
                            }
                        }
                    
                    Text(title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.system(size: 16))
                }
                .padding()
                .background(color.opacity(0.7))
                .cornerRadius(isExpanded ? 15 : 15)
            }
            
            // Expandable content
            if isExpanded {
                VStack {
                    content()
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
                .background(Color.white.opacity(0.1))
                .cornerRadius(15)
            }
        }
        .background(Color.white.opacity(0.1))
        .cornerRadius(15)
    }
}

// Info Row component
struct InfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.2))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
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

// Theme button component
struct ThemeButton: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                // Theme color preview
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: theme.gradientColors),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: isSelected ? 3 : 0)
                    )
                    .shadow(color: isSelected ? Color.white.opacity(0.6) : Color.black.opacity(0.2), 
                            radius: isSelected ? 8 : 4, 
                            x: 0, 
                            y: 0)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
                
                // Theme name
                Text(theme.rawValue)
                    .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                    .foregroundColor(.white)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0.1, maximumDistance: 10, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.2)) {
                self.isPressed = pressing
            }
        }, perform: {
            action()
        })
    }
}

struct HomePage_Previews: PreviewProvider {
    static var previews: some View {
        HomePage(appState: AppState())
    }
}
