import SwiftUI
import UIKit

struct TripShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct TripSummaryView: View {
    let tripStartTime: Date
    let tripDuration: TimeInterval
    let tripDistance: Double
    let avgSpeed: Double
    let maxSpeed: Double
    @Binding var isPresented: Bool
    @State private var showingShareSheet = false
    
    // Format numbers for display
    private var formattedDistance: String {
        // Convert meters to miles
        let miles = tripDistance * 0.000621371
        return String(format: "%.1f miles", miles)
    }
    
    private var formattedAvgSpeed: String {
        // Convert m/s to mph
        let mph = avgSpeed * 2.23694
        return String(format: "%.1f mph", mph)
    }
    
    private var formattedMaxSpeed: String {
        // Convert m/s to mph
        let mph = maxSpeed * 2.23694
        return String(format: "%.1f mph", mph)
    }
    
    private var formattedDuration: String {
        let hours = Int(tripDuration) / 3600
        let minutes = Int(tripDuration) / 60 % 60
        let seconds = Int(tripDuration) % 60
        
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
    
    private var shareText: String {
        """
        🚗 Just finished my drive with CruiseAI!
        
        📍 Trip Summary:
        ⏰ Started: \(tripStartTime.formatted(date: .abbreviated, time: .shortened))
        ⌛️ Duration: \(formattedDuration)
        📏 Distance: \(formattedDistance)
        🏃‍♂️ Avg Speed: \(formattedAvgSpeed)
        🏃‍♂️ Max Speed: \(formattedMaxSpeed)
        
        #CruiseAI #DriveSafe
        """
    }
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
            
            // Summary card
            VStack(spacing: 20) {
                // Header
                Text("Trip Summary")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                // Stats
                VStack(spacing: 15) {
                    StatRow(icon: "clock.fill", label: "Started", value: tripStartTime.formatted(date: .abbreviated, time: .shortened))
                    StatRow(icon: "timer", label: "Duration", value: formattedDuration)
                    StatRow(icon: "map", label: "Distance", value: formattedDistance)
                    StatRow(icon: "speedometer", label: "Avg Speed", value: formattedAvgSpeed)
                    StatRow(icon: "gauge.with.dots.needle.bottom", label: "Max Speed", value: formattedMaxSpeed)
                }
                .padding(.vertical)
                
                // Share button
                Button(action: {
                    showingShareSheet = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Trip")
                    }
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                
                // Done button
                Button(action: {
                    isPresented = false
                }) {
                    Text("Done")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .cornerRadius(12)
                }
            }
            .padding(24)
            .background(Color(UIColor.systemBackground).opacity(0.95))
            .cornerRadius(20)
            .shadow(radius: 10)
            .padding(24)
        }
        .sheet(isPresented: $showingShareSheet) {
            TripShareSheet(activityItems: [shareText])
        }
    }
}

// Helper view for stat rows
struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            Text(label)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.primary)
                .fontWeight(.semibold)
        }
    }
} 