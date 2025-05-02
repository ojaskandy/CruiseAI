import Foundation

// Trip store for storing trip data locally
public class TripStore: ObservableObject {
    @Published public var trips: [TripRecord] = []
    private let tripsKey = "savedTrips"
    
    public init() {
        loadTrips()
    }
    
    public func saveTrip(startTime: Date, endTime: Date, distance: Double, avgSpeed: Double, maxSpeed: Double) {
        let newTrip = TripRecord(
            id: UUID(),
            startTime: startTime,
            endTime: endTime,
            distance: distance,
            avgSpeed: avgSpeed,
            maxSpeed: maxSpeed
        )
        
        trips.append(newTrip)
        saveTrips()
    }
    
    private func saveTrips() {
        do {
            let data = try JSONEncoder().encode(trips)
            UserDefaults.standard.set(data, forKey: tripsKey)
            print("Saved \(trips.count) trips to local storage")
        } catch {
            print("Failed to save trips: \(error.localizedDescription)")
        }
    }
    
    // Made public so it can be called from HistoryView
    public func loadTrips() {
        guard let data = UserDefaults.standard.data(forKey: tripsKey) else {
            print("No saved trips found")
            return
        }
        
        do {
            trips = try JSONDecoder().decode([TripRecord].self, from: data)
            print("Loaded \(trips.count) trips from local storage")
        } catch {
            print("Failed to load trips: \(error.localizedDescription)")
        }
    }
    
    // Delete a specific trip
    public func deleteTrip(id: UUID) {
        trips.removeAll { $0.id == id }
        saveTrips()
    }
    
    // Clear all trips
    public func clearAllTrips() {
        trips.removeAll()
        saveTrips()
    }
}

// Trip record data model
public struct TripRecord: Identifiable, Codable {
    public var id: UUID
    public var startTime: Date
    public var endTime: Date
    public var distance: Double
    public var avgSpeed: Double
    public var maxSpeed: Double
    
    public var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    public init(id: UUID, startTime: Date, endTime: Date, distance: Double, avgSpeed: Double, maxSpeed: Double) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.distance = distance
        self.avgSpeed = avgSpeed
        self.maxSpeed = maxSpeed
    }
} 