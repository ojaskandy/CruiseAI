import SwiftUI
import MapKit
import CoreLocation

struct DriveMapView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var locationManager: LocationManager
    @Binding var isDriving: Bool
    @Binding var showingShareSheet: Bool
    @Binding var tripStartTime: Date?
    @Binding var tripEndTime: Date?
    @Binding var tripDistance: Double
    @Binding var tripTopSpeed: Double
    @Binding var tripAvgSpeed: Double
    @Binding var speedReadings: [Double]
    @Binding var locationHistory: [CLLocationCoordinate2D]
    
    // Map state
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var cameraPosition: MapCameraPosition = .userLocation(followsHeading: false, fallback: .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )))
    @State private var searchText = ""
    @State private var route: MKRoute?
    @State private var selectedDestination: SearchResultItem?
    @State private var showingSearchSheet = false
    @State private var showingDirections = false
    @State private var estimatedTime: TimeInterval?
    @State private var estimatedDistance: CLLocationDistance?
    @State private var isNavigating = false
    @StateObject private var navigationManager = NavigationManager()
    
    // Map presentation
    @State private var mapType: MKMapType = .standard
    
    var body: some View {
        ZStack {
            // Update region when location changes
            let _ = updateRegionIfNeeded()
            
            // Modern Map implementation
            Map(position: $cameraPosition,
                interactionModes: .all) {
                // User location
                if let location = locationManager.location?.coordinate {
                    UserAnnotation()
                }
                
                // Destination marker
                if let destination = selectedDestination?.mapItem {
                    Marker(destination.name ?? "Destination", coordinate: destination.placemark.coordinate)
                        .tint(appState.theme.accentColor)
                }
                
                // Show route polylines with arrows
                if let route = route {
                    // Main route polyline
                    MapPolyline(route.polyline)
                        .stroke(Color.blue, lineWidth: 6)
                    
                    // If navigating, show with arrows
                    if isNavigating {
                        ForEach(navigationManager.routePolylines) { segment in
                            if segment.isArrow {
                                // White arrow for turn points
                                MapPolyline(segment.polyline)
                                    .stroke(Color.white, lineWidth: CGFloat(segment.lineWidth))
                            } else {
                                // Blue route line
                                MapPolyline(segment.polyline)
                                    .stroke(Color.blue, lineWidth: CGFloat(segment.lineWidth))
                            }
                        }
                    }
                }
            }
            .mapStyle(mapType == .standard ? .standard : .imagery)
            .mapControls {
                MapCompass()
                MapPitchToggle()
                MapUserLocationButton()
            }
            .edgesIgnoringSafeArea(.top)
            
            // Search and controls overlay
            VStack(spacing: 0) {
                // Top bar with search and map type toggle
                GlassContainer(theme: appState.theme) {
                    HStack(spacing: 12) {
                        // Search button that looks like a text field
                        Button(action: {
                            showingSearchSheet = true
                            searchText = ""
                        }) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(appState.theme.accentColor)
                                Text(searchText.isEmpty ? "Search for a destination" : searchText)
                                    .foregroundColor(appState.theme.textColor.opacity(0.8))
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        
                        // Map type toggle with improved visual
                        Button(action: {
                            mapType = mapType == .standard ? .satellite : .standard
                        }) {
                            Image(systemName: mapType == .standard ? "map" : "map.fill")
                                .foregroundColor(appState.theme.accentColor)
                                .padding(8)
                                .background(appState.theme.gradientColors[1].opacity(0.3))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)
                }
                .padding()
                
                // Directions panel
                if showingDirections, let time = estimatedTime, let distance = estimatedDistance {
                    GlassContainer(theme: appState.theme) {
                        VStack(spacing: 12) {
                            // Route overview
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(formatTime(time))
                                        .font(.title2)
                                        .foregroundColor(appState.theme.textColor)
                                    Text(formatDistance(distance))
                                        .font(.subheadline)
                                        .foregroundColor(appState.theme.secondaryTextColor)
                                }
                                
                                Spacer()
                                
                                // GO button
                                Button(action: {
                                    startNavigation()
                                }) {
                                    Text("GO")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(appState.theme.accentColor)
                                        .clipShape(Capsule())
                                }
                            }
                            
                            Divider()
                                .background(appState.theme.secondaryTextColor)
                            
                            // Destination info
                            if let destination = selectedDestination?.mapItem {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(destination.name ?? "Destination")
                                            .font(.headline)
                                            .foregroundColor(appState.theme.textColor)
                                        if let address = destination.placemark.title {
                                            Text(address)
                                                .font(.caption)
                                                .foregroundColor(appState.theme.secondaryTextColor)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        // Clear route
                                        route = nil
                                        showingDirections = false
                                        selectedDestination = nil
                                        searchText = ""
                                        isNavigating = false
                                        navigationManager.stopNavigation()
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(appState.theme.secondaryTextColor)
                                            .imageScale(.large)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                    .transition(.move(edge: .top))
                }
                
                // Navigation banner when actively navigating
                if isNavigating {
                    EnhancedDirectionBannerView(navigationManager: navigationManager, theme: appState.theme)
                        .transition(.move(edge: .top))
                }
                
                Spacer()
                
                // Drive controls at bottom
                VStack(spacing: 15) {
                    // Show stop navigation button when navigating
                    if isNavigating {
                        GlassButton(
                            theme: appState.theme,
                            title: "Stop Navigation",
                            icon: "xmark.circle.fill"
                        ) {
                            isNavigating = false
                            navigationManager.stopNavigation()
                        }
                        .padding(.bottom, 10)
                    }
                    
                    // Start/Stop Drive button with glass effect
                    GlassButton(
                        theme: appState.theme,
                        title: isDriving ? "Stop Drive" : "Start Drive",
                        icon: isDriving ? "stop.circle.fill" : "play.circle.fill"
                    ) {
                        if isDriving {
                            isDriving = false
                            tripEndTime = Date()
                            locationManager.stopUpdatingLocation()
                            
                            if !speedReadings.isEmpty {
                                tripAvgSpeed = speedReadings.reduce(0, +) / Double(speedReadings.count)
                            }
                            
                            showingShareSheet = true
                        } else {
                            isDriving = true
                            tripStartTime = Date()
                            tripEndTime = nil
                            tripDistance = 0.0
                            tripTopSpeed = 0.0
                            speedReadings = []
                            locationHistory = []
                            locationManager.startUpdatingLocation()
                        }
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            // Set initial region to current location if available
            if let location = locationManager.location?.coordinate {
                region = MKCoordinateRegion(
                    center: location,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            }
            
            // Set up notifications for route updates
            setupNotifications()
        }
        .sheet(isPresented: $showingSearchSheet) {
            DestinationSearchSheet(
                searchText: $searchText,
                selectedDestination: $selectedDestination,
                showingDirections: $showingDirections,
                route: $route,
                estimatedTime: $estimatedTime,
                estimatedDistance: $estimatedDistance,
                userLocation: locationManager.location?.coordinate,
                appState: appState
            )
        }
        .onChange(of: route) { _, newRoute in
            if let newRoute = newRoute, let destination = selectedDestination?.mapItem {
                // When route changes, update navigation manager
                navigationManager.destination = destination
                navigationManager.route = newRoute
                navigationManager.routeSteps = newRoute.steps
                navigationManager.estimatedTimeRemaining = newRoute.expectedTravelTime
                navigationManager.estimatedDistanceRemaining = newRoute.distance
                navigationManager.arrivalTime = Date().addingTimeInterval(newRoute.expectedTravelTime)
            }
        }
    }
    
    private func setupNotifications() {
        // Listen for arrival at destination
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DestinationReached"),
            object: nil,
            queue: .main
        ) { _ in
            withAnimation {
                isNavigating = false
                // Show arrival alert
                showArrivalAlert()
            }
        }
    }
    
    private func startNavigation() {
        // Set camera to follow user with heading
        cameraPosition = .userLocation(followsHeading: true, fallback: .region(region))
        
        // Start navigation in manager
        if let destination = selectedDestination?.mapItem {
            // Ensure we have current location
            if let userLocation = locationManager.location?.coordinate {
                // Set current location in navigation manager if needed
                let location = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                navigationManager.locationManager(CLLocationManager(), didUpdateLocations: [location])
                
                // Calculate route in navigation manager
                navigationManager.calculateRoute(to: destination)
                
                withAnimation {
                    isNavigating = true
                    navigationManager.startNavigation()
                }
            }
        }
    }
    
    private func showArrivalAlert() {
        // In a real app, you'd show an alert here
        print("You have arrived at your destination!")
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) / 60 % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }
    
    private func formatDistance(_ meters: CLLocationDistance) -> String {
        let miles = meters / 1609.34
        if miles >= 10 {
            return String(format: "%.0f mi", miles)
        } else {
            return String(format: "%.1f mi", miles)
        }
    }
    
    private func updateRegionIfNeeded() {
        if let location = locationManager.location?.coordinate {
            region = MKCoordinateRegion(
                center: location,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        }
    }
}

// MARK: - Custom Direction Banner
struct EnhancedDirectionBannerView: View {
    @ObservedObject var navigationManager: NavigationManager
    let theme: AppTheme
    
    var body: some View {
        GlassContainer(theme: theme) {
            VStack(spacing: 12) {
                // Current direction instruction
                HStack(spacing: 16) {
                    // Turn icon
                    Image(systemName: navigationManager.nextTurnIcon)
                        .font(.system(size: 28))
                        .foregroundColor(theme.accentColor)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        // Next turn direction
                        Text(navigationManager.nextTurnDirection)
                            .font(.headline)
                            .foregroundColor(theme.textColor)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Distance to next turn
                        Text(formatDistance(navigationManager.nextTurnDistance))
                            .font(.subheadline)
                            .foregroundColor(theme.secondaryTextColor)
                    }
                }
                .padding(.horizontal, 8)
                
                Divider()
                    .background(theme.secondaryTextColor.opacity(0.3))
                
                // Trip overview
                HStack(spacing: 24) {
                    // ETA
                    VStack {
                        Text("ETA")
                            .font(.caption)
                            .foregroundColor(theme.secondaryTextColor)
                        
                        Text(formatTime(navigationManager.arrivalTime))
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(theme.textColor)
                    }
                    
                    Spacer()
                    
                    // Remaining time
                    VStack {
                        Text("Time")
                            .font(.caption)
                            .foregroundColor(theme.secondaryTextColor)
                        
                        Text(formatDuration(navigationManager.estimatedTimeRemaining))
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(theme.textColor)
                    }
                    
                    Spacer()
                    
                    // Remaining distance
                    VStack {
                        Text("Distance")
                            .font(.caption)
                            .foregroundColor(theme.secondaryTextColor)
                        
                        Text(formatDistance(navigationManager.estimatedDistanceRemaining))
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(theme.textColor)
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(.vertical, 12)
        }
        .padding(.horizontal)
    }
    
    // Format distance
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            let km = distance / 1000
            return String(format: "%.1f km", km)
        }
    }
    
    // Format time
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Format duration
    private func formatDuration(_ timeInterval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: timeInterval) ?? "Unknown"
    }
}
