//
//  HistoryView.swift
//  CruiseAIios
//
//  Created by Ojas Kandhare on 4/3/25.
//

import SwiftUI

// History View
struct HistoryView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var appState: AppState
    
    // Computed property to convert TripRecord to TripData for display
    private var trips: [TripData] {
        return appState.tripStore.trips.map { record -> TripData in
            // Format date
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            let dateString = dateFormatter.string(from: record.startTime)
            
            // Format duration
            let duration = record.duration
            let hours = Int(duration) / 3600
            let minutes = Int(duration) / 60 % 60
            let seconds = Int(duration) % 60
            let durationString: String
            if hours > 0 {
                durationString = "\(hours)h \(minutes)m"
            } else {
                durationString = "\(minutes)m \(seconds)s"
            }
            
            // Format distance (meters to miles)
            let distanceMiles = (record.distance / 1000.0) * 0.621371
            let distanceString = String(format: "%.1f mi", distanceMiles)
            
            // Format average speed (m/s to mph)
            let avgSpeedMph = record.avgSpeed * 2.23694
            let speedString = String(format: "%.1f mph", avgSpeedMph)
            
            return TripData(
                id: record.id,
                date: dateString,
                duration: durationString,
                distance: distanceString,
                avgSpeed: speedString,
                recordReference: record
            )
        }.sorted { $0.recordReference.startTime > $1.recordReference.startTime }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Theme-based gradient background
                LinearGradient(gradient: Gradient(colors: appState.theme.gradientColors), 
                               startPoint: .top, 
                               endPoint: .bottom)
                    .edgesIgnoringSafeArea(.all)
                    .animation(.easeInOut(duration: 0.5), value: appState.theme.id)
                
                if trips.isEmpty {
                    // No trips view
                    VStack(spacing: 25) {
                        Image(systemName: "car.circle")
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("No Trips Yet")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Your driving history will appear here after you complete your first trip with CruiseAI.")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                Image(systemName: "car.fill")
                                Text("Start Your First Drive")
                            }
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green.opacity(0.8))
                            .cornerRadius(15)
                            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
                        }
                        .padding(.top, 20)
                    }
                    .padding()
                } else {
                    // Trip list view
                    VStack {
                        List {
                            ForEach(trips) { trip in
                                NavigationLink(destination: TripDetailView(trip: trip.recordReference, appState: appState)) {
                                    TripRow(trip: trip)
                                }
                                .listRowBackground(Color.black.opacity(0.3))
                            }
                            .onDelete { indexSet in
                                // Delete the trips at the specified indices
                                for index in indexSet {
                                    let tripToDelete = trips[index]
                                    appState.tripStore.deleteTrip(id: tripToDelete.id)
                                }
                            }
                        }
                        .listStyle(InsetGroupedListStyle())
                        
                        // Add clear all button if there are trips
                        if !trips.isEmpty {
                            Button(action: {
                                // Show a confirmation dialog before clearing
                                alertTitle = "Clear All Trips"
                                alertMessage = "Are you sure you want to delete all trip history? This cannot be undone."
                                showingAlert = true
                            }) {
                                Text("Clear All History")
                                    .foregroundColor(.red)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.black.opacity(0.3))
                                    .cornerRadius(10)
                            }
                            .padding(.horizontal)
                            .padding(.bottom)
                        }
                    }
                }
            }
            .navigationBarTitle("Drive History", displayMode: .inline)
            .navigationBarItems(
                leading: Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.white)
                },
                trailing: trips.isEmpty ? nil : EditButton()
                    .foregroundColor(.white)
            )
        }
        .onAppear {
            // Reload trips when the view appears
            appState.tripStore.loadTrips()
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                primaryButton: .destructive(Text("Delete All")) {
                    appState.tripStore.clearAllTrips()
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    // Alert state
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
}

// Trip data model for display
struct TripData: Identifiable {
    let id: UUID
    let date: String
    let duration: String
    let distance: String
    let avgSpeed: String
    let recordReference: TripRecord  // Reference to the original record for detail view
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

// Trip detail view
struct TripDetailView: View {
    let trip: TripRecord
    @ObservedObject var appState: AppState
    @State private var showingShareSheet = false
    
    var body: some View {
        ZStack {
            // Theme-based gradient background
            LinearGradient(gradient: Gradient(colors: appState.theme.gradientColors), 
                           startPoint: .top, 
                           endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                // Header
                Text("Trip Summary")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                // Detail card
                VStack(spacing: 16) {
                    // Date and time
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Start Time")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Text(formatDate(trip.startTime))
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("End Time")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Text(formatDate(trip.endTime))
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    // Stats grid
                    VStack(spacing: 16) {
                        // Duration and Distance
                        HStack {
                            StatItem(
                                title: "Duration",
                                value: formatDuration(trip.duration),
                                icon: "clock.fill",
                                color: .blue
                            )
                            
                            Spacer()
                            
                            StatItem(
                                title: "Distance",
                                value: formatDistance(trip.distance),
                                icon: "map.fill",
                                color: .green
                            )
                        }
                        
                        // Average and Max Speed
                        HStack {
                            StatItem(
                                title: "Avg Speed",
                                value: formatSpeed(trip.avgSpeed),
                                icon: "speedometer",
                                color: .orange
                            )
                            
                            Spacer()
                            
                            StatItem(
                                title: "Max Speed",
                                value: formatSpeed(trip.maxSpeed),
                                icon: "bolt.fill",
                                color: .red
                            )
                        }
                    }
                }
                .padding(20)
                .background(Color.black.opacity(0.4))
                .cornerRadius(16)
                .padding(.horizontal)
                
                // Share button
                Button(action: {
                    showingShareSheet = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18))
                        Text("Share Trip Summary")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                Spacer()
            }
            .padding(.top, 20)
        }
        .navigationTitle("Trip Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShareSheet) {
            DriveShareSheet(activityItems: [createShareText()])
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) / 60 % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formatDistance(_ meters: Double) -> String {
        let miles = (meters / 1000.0) * 0.621371
        return String(format: "%.1f mi", miles)
    }
    
    private func formatSpeed(_ metersPerSecond: Double) -> String {
        let mph = metersPerSecond * 2.23694
        return String(format: "%.1f mph", mph)
    }
    
    private func createShareText() -> String {
        """
        🚗 My Trip with CruiseAI:
        📅 \(formatDate(trip.startTime))
        ⏱ Duration: \(formatDuration(trip.duration))
        📍 Distance: \(formatDistance(trip.distance))
        ⚡️ Average Speed: \(formatSpeed(trip.avgSpeed))
        🏃 Maximum Speed: \(formatSpeed(trip.maxSpeed))
        
        Tracked with CruiseAI 🚀
        """
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
        }
    }
}
