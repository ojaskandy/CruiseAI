import SwiftUI
import MapKit

// MARK: - Helper structs for storage
// Define this at the top level to avoid duplicate definitions
struct StoredLocation: Codable {
    let name: String
    let latitude: Double
    let longitude: Double
    let address: String
}

struct SearchResultItem: Identifiable {
    let id = UUID()
    let mapItem: MKMapItem
}

struct DestinationSearchSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var searchText: String
    @Binding var selectedDestination: SearchResultItem?
    @Binding var showingDirections: Bool
    @Binding var route: MKRoute?
    @Binding var estimatedTime: TimeInterval?
    @Binding var estimatedDistance: CLLocationDistance?
    let userLocation: CLLocationCoordinate2D?
    let appState: AppState
    
    @State private var searchResults: [SearchResultItem] = []
    @State private var recentSearches: [SearchResultItem] = []
    @State private var isSearching = false
    @State private var region: MKCoordinateRegion
    @State private var searchDebounceTimer: Timer? = nil
    @State private var searchCompleter = MKLocalSearchCompleter()
    @State private var searchCompletions: [MKLocalSearchCompletion] = []
    @State private var showNoResultsMessage = false
    
    init(searchText: Binding<String>, 
         selectedDestination: Binding<SearchResultItem?>,
         showingDirections: Binding<Bool>,
         route: Binding<MKRoute?>,
         estimatedTime: Binding<TimeInterval?>,
         estimatedDistance: Binding<CLLocationDistance?>,
         userLocation: CLLocationCoordinate2D?,
         appState: AppState) {
        self._searchText = searchText
        self._selectedDestination = selectedDestination
        self._showingDirections = showingDirections
        self._route = route
        self._estimatedTime = estimatedTime
        self._estimatedDistance = estimatedDistance
        self.userLocation = userLocation
        self.appState = appState
        
        // Initialize region with user location or default to San Francisco
        let center = userLocation ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        self._region = State(initialValue: MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar with improved styling
                GlassContainer(theme: appState.theme) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(appState.theme.accentColor)
                        
                        TextField("Enter any address or place", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .foregroundColor(appState.theme.textColor)
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.never)
                            .onChange(of: searchText) { _ in
                                searchDebounceTimer?.invalidate()
                                searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                                    if searchText.isEmpty {
                                        searchResults = []
                                        searchCompletions = []
                                        showNoResultsMessage = false
                                    } else {
                                        updateSearchCompletions()
                                    }
                                }
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                searchResults = []
                                searchCompletions = []
                                showNoResultsMessage = false
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(appState.theme.secondaryTextColor)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 16) {
                        if isSearching {
                            VStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .padding()
                                Text("Searching...")
                                    .foregroundColor(appState.theme.secondaryTextColor)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        } else if !searchCompletions.isEmpty {
                            // Autocomplete suggestions
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(searchCompletions, id: \.self) { completion in
                                    Button(action: {
                                        searchText = completion.title
                                        searchForCompletion(completion)
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(completion.title)
                                                    .foregroundColor(appState.theme.textColor)
                                                    .font(.system(size: 16, weight: .medium))
                                                
                                                if !completion.subtitle.isEmpty {
                                                    Text(completion.subtitle)
                                                        .foregroundColor(appState.theme.secondaryTextColor)
                                                        .font(.system(size: 14))
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "arrow.right.circle")
                                                .foregroundColor(appState.theme.accentColor)
                                        }
                                        .padding(.vertical, 10)
                                        .padding(.horizontal)
                                    }
                                    
                                    Divider()
                                        .background(appState.theme.secondaryTextColor.opacity(0.3))
                                        .padding(.horizontal)
                                }
                            }
                            .background(appState.theme.gradientColors[0])
                        } else if !searchResults.isEmpty {
                            // Search results
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(searchResults) { result in
                                    SearchResultRow(result: result, theme: appState.theme) {
                                        selectDestination(result)
                                    }
                                    
                                    Divider()
                                        .background(appState.theme.secondaryTextColor.opacity(0.3))
                                        .padding(.horizontal)
                                }
                            }
                            .background(appState.theme.gradientColors[0])
                        } else if showNoResultsMessage {
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 40))
                                    .foregroundColor(appState.theme.secondaryTextColor.opacity(0.7))
                                
                                Text("No results found")
                                    .font(.headline)
                                    .foregroundColor(appState.theme.textColor)
                                
                                Text("Try a different search term or be more specific")
                                    .font(.subheadline)
                                    .foregroundColor(appState.theme.secondaryTextColor)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else if searchText.isEmpty {
                            // Quick actions when no search
                            QuickActionsView(theme: appState.theme)
                            
                            if !recentSearches.isEmpty {
                                // Recent searches
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text("Recent Searches")
                                            .font(.headline)
                                            .foregroundColor(appState.theme.textColor)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            recentSearches = []
                                        }) {
                                            Text("Clear")
                                                .font(.subheadline)
                                                .foregroundColor(appState.theme.accentColor)
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.top)
                                    
                                    ForEach(recentSearches.prefix(5)) { result in
                                        SearchResultRow(result: result, theme: appState.theme, showingIcon: true) {
                                            selectDestination(result)
                                        }
                                        
                                        Divider()
                                            .background(appState.theme.secondaryTextColor.opacity(0.3))
                                            .padding(.horizontal)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarTitle("Search", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(appState.theme.accentColor)
            )
            .onAppear {
                setupSearchCompleter()
                loadRecentSearches()
            }
        }
    }
    
    private func setupSearchCompleter() {
        searchCompleter.delegate = CompleterDelegate(for: self)
        searchCompleter.pointOfInterestFilter = .includingAll
        searchCompleter.resultTypes = .pointOfInterest
        
        if let userLocation = userLocation {
            let region = MKCoordinateRegion(
                center: userLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
            searchCompleter.region = region
        }
    }
    
    private func updateSearchCompletions() {
        if !searchText.isEmpty {
            searchCompleter.queryFragment = searchText
        }
    }
    
    private func searchForCompletion(_ completion: MKLocalSearchCompletion) {
        isSearching = true
        showNoResultsMessage = false
        
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, error in
            DispatchQueue.main.async {
                isSearching = false
                
                if let error = error {
                    print("Search error: \(error.localizedDescription)")
                    showNoResultsMessage = true
                    return
                }
                
                if let response = response, !response.mapItems.isEmpty {
                    searchResults = response.mapItems.map { SearchResultItem(mapItem: $0) }
                    
                    // If there's only one result, automatically select it
                    if searchResults.count == 1 {
                        selectDestination(searchResults[0])
                    }
                } else {
                    showNoResultsMessage = true
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        showNoResultsMessage = false
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.resultTypes = [.pointOfInterest, .address]
        
        if let location = userLocation {
            request.region = MKCoordinateRegion(
                center: location,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                isSearching = false
                
                if let error = error {
                    print("Search error: \(error.localizedDescription)")
                    showNoResultsMessage = true
                    return
                }
                
                if let response = response, !response.mapItems.isEmpty {
                    searchResults = response.mapItems.map { SearchResultItem(mapItem: $0) }
                } else {
                    showNoResultsMessage = true
                }
            }
        }
    }
    
    private func selectDestination(_ item: SearchResultItem) {
        // Add to recent searches if not already present
        if !recentSearches.contains(where: { $0.mapItem.name == item.mapItem.name }) {
            recentSearches.insert(item, at: 0)
            if recentSearches.count > 10 {
                recentSearches.removeLast()
            }
            saveRecentSearches()
        }
        
        selectedDestination = item
        calculateRoute(to: item.mapItem)
        showingDirections = true
        presentationMode.wrappedValue.dismiss()
    }
    
    private func calculateRoute(to destination: MKMapItem) {
        guard let userLocation = userLocation else { return }
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation))
        request.destination = destination
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            if let error = error {
                print("Route calculation error: \(error.localizedDescription)")
                return
            }
            
            if let route = response?.routes.first {
                self.route = route
                self.estimatedTime = route.expectedTravelTime
                self.estimatedDistance = route.distance
            }
        }
    }
    
    private func saveRecentSearches() {
        do {
            let locationsToSave = recentSearches.map { item -> StoredLocation in
                return StoredLocation(
                    name: item.mapItem.name ?? "",
                    latitude: item.mapItem.placemark.coordinate.latitude,
                    longitude: item.mapItem.placemark.coordinate.longitude,
                    address: item.mapItem.placemark.title ?? ""
                )
            }
            
            let searchData = try JSONEncoder().encode(locationsToSave)
            UserDefaults.standard.set(searchData, forKey: "recentSearches")
        } catch {
            print("Failed to save recent searches: \(error)")
        }
    }
    
    private func loadRecentSearches() {
        guard let data = UserDefaults.standard.data(forKey: "recentSearches") else { return }
        
        do {
            let savedSearches = try JSONDecoder().decode([StoredLocation].self, from: data)
            
            recentSearches = savedSearches.compactMap { searchItem in
                let coordinate = CLLocationCoordinate2D(latitude: searchItem.latitude, longitude: searchItem.longitude)
                let placemark = MKPlacemark(coordinate: coordinate)
                let mapItem = MKMapItem(placemark: placemark)
                mapItem.name = searchItem.name
                
                return SearchResultItem(mapItem: mapItem)
            }
        } catch {
            print("Failed to load recent searches: \(error)")
        }
    }
    
    // Add a method to update completions from the delegate
    func updateCompletions(_ completions: [MKLocalSearchCompletion]) {
        searchCompletions = completions
    }
}

// MARK: - Completer delegate to handle search completions
class CompleterDelegate: NSObject, MKLocalSearchCompleterDelegate {
    private var parent: DestinationSearchSheet?
    
    init(for parent: DestinationSearchSheet) {
        self.parent = parent
        super.init()
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // Use the public method instead of accessing the property directly
        parent?.updateCompletions(completer.results)
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search completer error: \(error.localizedDescription)")
    }
}

// MARK: - Supporting Views

struct SearchResultRow: View {
    let result: SearchResultItem
    let theme: AppTheme
    let showingIcon: Bool
    let action: () -> Void
    
    init(result: SearchResultItem, theme: AppTheme, showingIcon: Bool = false, action: @escaping () -> Void) {
        self.result = result
        self.theme = theme
        self.showingIcon = showingIcon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if showingIcon {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(theme.secondaryTextColor)
                } else {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(theme.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.mapItem.name ?? "Unknown location")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.textColor)
                    
                    if let address = result.mapItem.placemark.title {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(theme.secondaryTextColor)
                    }
                }
                
                Spacer()
                
                Image(systemName: "arrow.right.circle")
                    .foregroundColor(theme.accentColor)
                    .font(.system(size: 18))
            }
            .padding(.vertical, 12)
            .padding(.horizontal)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct QuickActionsView: View {
    let theme: AppTheme
    @Environment(\.presentationMode) var presentationMode
    @State private var isDriving = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(theme.textColor)
                .padding(.horizontal)
            
            HStack(spacing: 16) {
                QuickActionButton(
                    icon: "play.circle.fill",
                    title: "Start Drive",
                    theme: theme,
                    action: {
                        isDriving = true
                        presentationMode.wrappedValue.dismiss()
                    }
                )
                
                QuickActionButton(
                    icon: "briefcase.fill",
                    title: "Work",
                    theme: theme,
                    action: {}
                )
                
                QuickActionButton(
                    icon: "star.fill",
                    title: "Favorites",
                    theme: theme,
                    action: {}
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let theme: AppTheme
    let action: () -> Void
    @State private var isLoading = false
    @State private var rotation: Double = 0
    
    var body: some View {
        Button(action: {
            withAnimation {
                isLoading = true
            }
            // Start rotation animation
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            // Delay to show animation before action
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                action()
                isLoading = false
                rotation = 0
            }
        }) {
            VStack(spacing: 8) {
                ZStack {
                    if isLoading {
                        // Outer rotating ring
                        Circle()
                            .trim(from: 0, to: 0.8)
                            .stroke(theme.accentColor, lineWidth: 2)
                            .frame(width: 30, height: 30)
                            .rotationEffect(.degrees(rotation))
                        
                        // Inner rotating ring
                        Circle()
                            .trim(from: 0.2, to: 0.6)
                            .stroke(theme.accentColor.opacity(0.5), lineWidth: 2)
                            .frame(width: 20, height: 20)
                            .rotationEffect(.degrees(-rotation))
                    } else {
                        Image(systemName: icon)
                            .font(.title2)
                    }
                }
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(theme.accentColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(theme.gradientColors[1].opacity(0.3))
            .cornerRadius(12)
        }
    }
}
