//
//  MapComponents.swift
//  CruiseAIios
//
//  Created by Cline on 4/6/25.
//

import SwiftUI
import MapKit
import Combine

// MARK: - Navigation Manager

class NavigationManager: NSObject, ObservableObject {
    @Published var destination: MKMapItem?
    @Published var route: MKRoute?
    @Published var routeSteps: [MKRoute.Step] = []
    @Published var currentStepIndex: Int = 0
    @Published var isNavigating: Bool = false
    @Published var estimatedTimeRemaining: TimeInterval = 0
    @Published var estimatedDistanceRemaining: CLLocationDistance = 0
    @Published var arrivalTime: Date = Date()
    @Published var nextTurnDirection: String = ""
    @Published var nextTurnDistance: CLLocationDistance = 0
    @Published var nextTurnIcon: String = "arrow.right"
    @Published var routePolylines: [RouteSegment] = []
    
    private var locationManager: CLLocationManager?
    private var currentLocation: CLLocation?
    private var cancellables = Set<AnyCancellable>()
    
    var hasValidLocation: Bool {
        return currentLocation != nil
    }
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager?.distanceFilter = 10 // Update every 10 meters
        
        // Request authorization if needed
        if locationManager?.authorizationStatus == .notDetermined {
            locationManager?.requestWhenInUseAuthorization()
        }
    }
    
    // Calculate route to destination
    func calculateRoute(to destination: MKMapItem, transportType: MKDirectionsTransportType = .automobile) {
        guard let location = currentLocation else {
            print("Current location not available")
            return
        }
        
        self.destination = destination;
        
        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation();
        request.destination = destination;
        request.transportType = transportType;
        
        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            guard let self = self, let response = response, let route = response.routes.first else {
                print("Failed to calculate route: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            self.route = route;
            self.routeSteps = route.steps;
            self.currentStepIndex = 0;
            self.estimatedTimeRemaining = route.expectedTravelTime;
            self.estimatedDistanceRemaining = route.distance;
            self.arrivalTime = Date().addingTimeInterval(route.expectedTravelTime);
            
            // Generate route polylines with arrows
            self.generateRouteSegments(from: route)
            
            // Set initial turn direction and distance
            self.updateNextTurnInfo()
            
            // Notify that route is calculated
            NotificationCenter.default.post(name: NSNotification.Name("RouteCalculated"), object: route)
        }
    }
    
    // Generate route segments with direction arrows
    private func generateRouteSegments(from route: MKRoute) {
        var segments: [RouteSegment] = []
        
        // Main route polyline (blue line)
        let mainSegment = RouteSegment(
            polyline: route.polyline,
            color: .systemBlue,
            lineWidth: 5,
            lineDashPattern: nil,
            isArrow: false
        )
        segments.append(mainSegment)
        
        // Add arrow segments at turn points
        for i in 0..<routeSteps.count {
            if i > 0 {
                // Get coordinates at the start of each step to place arrows
                let stepPolyline = routeSteps[i].polyline
                
                // Skip if polyline is too short
                if stepPolyline.pointCount < 2 {
                    continue
                }
                
                // Get the turn point coordinates
                let turnPoint = stepPolyline.points()[0]
                let coordinate = turnPoint.coordinate
                
                // Create a small arrow polyline
                let arrow = createArrowPolyline(at: coordinate, heading: getHeadingForStep(i))
                
                // Add arrow segment
                let arrowSegment = RouteSegment(
                    polyline: arrow,
                    color: .white,
                    lineWidth: 3,
                    lineDashPattern: nil,
                    isArrow: true
                )
                segments.append(arrowSegment)
            }
        }
        
        self.routePolylines = segments
    }
    
    // Create an arrow polyline at a specific coordinate
    private func createArrowPolyline(at coordinate: CLLocationCoordinate2D, heading: CLLocationDirection) -> MKPolyline {
        // Arrow size
        let arrowLength = 0.0003 // in coordinate degrees
        
        // Calculate arrow points based on heading
        let radianHeading = heading * .pi / 180
        
        // Arrow head point
        let headX = coordinate.longitude
        let headY = coordinate.latitude
        
        // Arrow tail point
        let tailX = headX - arrowLength * sin(radianHeading)
        let tailY = headY - arrowLength * cos(radianHeading)
        
        // Left wing point
        let leftWingAngle = radianHeading + 2.5
        let leftWingX = headX - (arrowLength * 0.7) * sin(leftWingAngle)
        let leftWingY = headY - (arrowLength * 0.7) * cos(leftWingAngle)
        
        // Right wing point
        let rightWingAngle = radianHeading - 2.5
        let rightWingX = headX - (arrowLength * 0.7) * sin(rightWingAngle)
        let rightWingY = headY - (arrowLength * 0.7) * cos(rightWingAngle)
        
        // Create polyline with these points
        var coords = [
            CLLocationCoordinate2D(latitude: headY, longitude: headX),
            CLLocationCoordinate2D(latitude: leftWingY, longitude: leftWingX),
            CLLocationCoordinate2D(latitude: tailY, longitude: tailX),
            CLLocationCoordinate2D(latitude: rightWingY, longitude: rightWingX),
            CLLocationCoordinate2D(latitude: headY, longitude: headX)
        ]
        
        return MKPolyline(coordinates: &coords, count: coords.count)
    }
    
    // Get heading for a step
    private func getHeadingForStep(_ stepIndex: Int) -> CLLocationDirection {
        guard stepIndex < routeSteps.count else { return 0 }
        
        let step = routeSteps[stepIndex]
        let polyline = step.polyline
        
        // Need at least two points to calculate heading
        guard polyline.pointCount >= 2 else { return 0 }
        
        // Get first two points of the step
        let point1 = polyline.points()[0]
        let point2 = polyline.points()[1]
        
        // Calculate heading
        let bearingRadians = calculateBearing(
            fromLatitude: point1.coordinate.latitude, fromLongitude: point1.coordinate.longitude,
            toLatitude: point2.coordinate.latitude, toLongitude: point2.coordinate.longitude
        )
        // Convert to degrees
        return CLLocationDirection((bearingRadians * 180.0 / .pi + 360.0).truncatingRemainder(dividingBy: 360.0))
    }
    
    // Helper function to calculate bearing between coordinates
    private func calculateBearing(
        fromLatitude: CLLocationDegrees, fromLongitude: CLLocationDegrees,
        toLatitude: CLLocationDegrees, toLongitude: CLLocationDegrees) -> Double {
        
        let lat1 = fromLatitude * .pi / 180.0
        let lon1 = fromLongitude * .pi / 180.0
        let lat2 = toLatitude * .pi / 180.0
        let lon2 = toLongitude * .pi / 180.0
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        
        return atan2(y, x)
    }
    
    // Update next turn information
    private func updateNextTurnInfo() {
        guard currentStepIndex < routeSteps.count - 1 else {
            // Last step, show destination info
            nextTurnDirection = "Arrive at destination"
            nextTurnDistance = 0
            nextTurnIcon = "mappin.circle.fill"
            return
        }
        
        let nextStep = routeSteps[currentStepIndex + 1]
        nextTurnDirection = nextStep.instructions
        nextTurnDistance = nextStep.distance
        
        // Set appropriate turn icon based on instructions
        if nextTurnDirection.lowercased().contains("right") {
            nextTurnIcon = "arrow.turn.up.right"
        } else if nextTurnDirection.lowercased().contains("left") {
            nextTurnIcon = "arrow.turn.up.left"
        } else if nextTurnDirection.lowercased().contains("continue") || 
                  nextTurnDirection.lowercased().contains("head") ||
                  nextTurnDirection.lowercased().contains("straight") {
            nextTurnIcon = "arrow.up"
        } else if nextTurnDirection.lowercased().contains("u-turn") {
            nextTurnIcon = "arrow.uturn.left"
        } else if nextTurnDirection.lowercased().contains("destination") ||
                  nextTurnDirection.lowercased().contains("arrive") {
            nextTurnIcon = "mappin.circle.fill"
        } else {
            // Default
            nextTurnIcon = "arrow.right"
        }
    }
    
    // Start navigation
    func startNavigation() {
        guard route != nil else {
            print("No route available")
            return
        }
        
        isNavigating = true;
        locationManager?.startUpdatingLocation();
        
        // Notify that navigation started
        NotificationCenter.default.post(name: NSNotification.Name("NavigationStarted"), object: nil)
    }
    
    // Stop navigation
    func stopNavigation() {
        isNavigating = false
        locationManager?.stopUpdatingLocation()
        
        // Notify that navigation stopped
        NotificationCenter.default.post(name: NSNotification.Name("NavigationStopped"), object: nil)
    }
    
    // Get current navigation step
    func getCurrentStep() -> MKRoute.Step? {
        guard !routeSteps.isEmpty, currentStepIndex < routeSteps.count else {
            return nil
        }
        
        return routeSteps[currentStepIndex]
    }
    
    // Update navigation progress based on user location
    private func updateNavigationProgress() {
        guard isNavigating, let location = currentLocation, let route = route else {
            return
        }
        
        // Check if we've reached the destination
        if let destinationLocation = destination?.placemark.location {
            let distanceToDestination = location.distance(from: destinationLocation)
            if distanceToDestination < 50 { // Within 50 meters of destination
                // Arrived at destination
                stopNavigation()
                NotificationCenter.default.post(name: NSNotification.Name("DestinationReached"), object: nil)
                return
            }
        }
        
        // Update current step
        if let currentStep = getCurrentStep() {
            // Check if we've completed the current step
            let stepEndLocation = CLLocation(latitude: currentStep.polyline.points()[currentStep.polyline.pointCount - 1].coordinate.latitude,
                                            longitude: currentStep.polyline.points()[currentStep.polyline.pointCount - 1].coordinate.longitude)
            
            let distanceToStepEnd = location.distance(from: stepEndLocation)
            if distanceToStepEnd < 20 { // Within 20 meters of step end
                // Move to next step
                currentStepIndex += 1
                
                // Update next turn information
                updateNextTurnInfo()
                
                // Announce next step
                if let nextStep = getCurrentStep() {
                    NotificationCenter.default.post(name: NSNotification.Name("NewNavigationStep"), object: nextStep)
                }
            }
        }
        
        // Update remaining time and distance
        let remainingSteps = Array(route.steps.dropFirst(currentStepIndex))
        
        // Calculate remaining distance
        estimatedDistanceRemaining = remainingSteps.reduce(into: CLLocationDistance(0)) { result, step in
            result += step.distance
        }
        
        // Calculate remaining time based on the proportion of distance remaining
        let totalDistance = route.distance
        let remainingProportion = estimatedDistanceRemaining / totalDistance
        estimatedTimeRemaining = route.expectedTravelTime * remainingProportion
        arrivalTime = Date().addingTimeInterval(estimatedTimeRemaining)
        
        // Update next turn distance
        if currentStepIndex < routeSteps.count - 1 {
            let currentLocation = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            let nextStepStartLocation = CLLocation(
                latitude: routeSteps[currentStepIndex + 1].polyline.points()[0].coordinate.latitude,
                longitude: routeSteps[currentStepIndex + 1].polyline.points()[0].coordinate.longitude
            )
            nextTurnDistance = currentLocation.distance(from: nextStepStartLocation)
        }
    }
}

// Route segment struct for visualizing routes
struct RouteSegment: Identifiable {
    let id = UUID()
    let polyline: MKPolyline
    let color: UIColor
    let lineWidth: CGFloat
    let lineDashPattern: [NSNumber]?
    let isArrow: Bool
}

// MARK: - CLLocationManagerDelegate

extension NavigationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        currentLocation = location
        
        if isNavigating {
            updateNavigationProgress()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager?.startUpdatingLocation()
        default:
            locationManager?.stopUpdatingLocation()
            isNavigating = false
        }
    }
}

// MARK: - Navigation View Components

// Direction banner view
struct DirectionBannerView: View {
    @ObservedObject var navigationManager: NavigationManager
    
    var body: some View {
        if let currentStep = navigationManager.getCurrentStep() {
            VStack(spacing: 8) {
                // Direction instruction
                Text(currentStep.instructions)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Distance to next turn
                Text(formatDistance(currentStep.distance))
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                // Progress to destination
                HStack {
                    // ETA
                    VStack(alignment: .leading) {
                        Text("ETA")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(formatTime(navigationManager.arrivalTime))
                            .font(.subheadline)
                            .bold()
                    }
                    
                    Spacer()
                    
                    // Remaining time
                    VStack(alignment: .trailing) {
                        Text("Time")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(formatDuration(navigationManager.estimatedTimeRemaining))
                            .font(.subheadline)
                            .bold()
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
            .padding(.horizontal)
        } else {
            Text("Calculating route...")
                .font(.headline)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
                .padding(.horizontal)
        }
    }
    
    // Format distance
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        return formatter.string(fromDistance: distance)
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

// Route overview view
struct RouteOverviewView: View {
    @ObservedObject var navigationManager: NavigationManager
    var onStartNavigation: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Destination info
            if let destination = navigationManager.destination {
                VStack(alignment: .leading, spacing: 4) {
                    Text(destination.name ?? "Destination")
                        .font(.headline)
                    
                    // MKPlacemark is a subclass of CLPlacemark, so we can use it directly
                    let placemark = destination.placemark
                    Text(formatAddress(placemark))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }
            
            // Route info
            if let route = navigationManager.route {
                HStack(spacing: 24) {
                    // ETA
                    VStack {
                        Text("ETA")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(formatTime(navigationManager.arrivalTime))
                            .font(.headline)
                    }
                    
                    // Time
                    VStack {
                        Text("Time")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(formatDuration(route.expectedTravelTime))
                            .font(.headline)
                    }
                    
                    // Distance
                    VStack {
                        Text("Distance")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(formatDistance(route.distance))
                            .font(.headline)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            // Action buttons
            HStack(spacing: 16) {
                // Cancel button
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
                
                // Start button
                Button(action: onStartNavigation) {
                    Text("Start")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
        .cornerRadius(12, corners: [.topLeft, .topRight])
        .shadow(radius: 5)
    }
    
    // Format address
    private func formatAddress(_ placemark: CLPlacemark) -> String {
        var addressComponents: [String] = []
        
        if let thoroughfare = placemark.thoroughfare {
            addressComponents.append(thoroughfare)
        }
        
        if let locality = placemark.locality {
            addressComponents.append(locality)
        }
        
        if let administrativeArea = placemark.administrativeArea {
            addressComponents.append(administrativeArea)
        }
        
        return addressComponents.joined(separator: ", ")
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
    
    // Format distance
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        return formatter.string(fromDistance: distance)
    }
}

// MARK: - Helper Extensions

// RoundedCorner shape for custom corner radius
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// Extension to apply rounded corners to specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}
