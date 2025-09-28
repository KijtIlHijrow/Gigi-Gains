import Foundation
import CoreData

@objc(WeeklyVolume)
public class WeeklyVolume: NSManagedObject, Identifiable {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<WeeklyVolume> {
        return NSFetchRequest<WeeklyVolume>(entityName: "WeeklyVolume")
    }

    // MARK: - Computed Properties

    /// Parsed muscle group volumes from JSON string
    public var muscleGroupVolumesDict: [String: Double] {
        get {
            guard let jsonString = muscleGroupVolumes,
                  let data = jsonString.data(using: .utf8),
                  let dict = try? JSONDecoder().decode([String: Double].self, from: data) else {
                return [:]
            }
            return dict
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let jsonString = String(data: data, encoding: .utf8) {
                muscleGroupVolumes = jsonString
            }
        }
    }

    /// Average sets per workout for this week
    public var averageSetsPerWorkout: Double {
        guard totalWorkouts > 0 else { return 0 }
        return Double(totalSets) / Double(totalWorkouts)
    }

    /// Average workout duration in minutes
    public var averageWorkoutDuration: Double {
        guard totalWorkouts > 0 else { return 0 }
        return totalDuration / Double(totalWorkouts)
    }

    /// Average volume per workout
    public var averageVolumePerWorkout: Double {
        guard totalWorkouts > 0 else { return 0 }
        return totalVolume / Double(totalWorkouts)
    }

    /// Week end date
    public var weekEndDate: Date {
        return Calendar.current.date(byAdding: .day, value: 6, to: weekStartDate) ?? weekStartDate
    }

    /// Week string for display (e.g., "Mar 1 - Mar 7, 2024")
    public var weekDisplayString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        let endDate = weekEndDate
        if Calendar.current.isDate(weekStartDate, equalTo: endDate, toGranularity: .month) {
            // Same month
            let startFormatter = DateFormatter()
            startFormatter.dateFormat = "MMM d"
            let endFormatter = DateFormatter()
            endFormatter.dateFormat = "d, yyyy"

            return "\(startFormatter.string(from: weekStartDate)) - \(endFormatter.string(from: endDate))"
        } else {
            // Different months
            let startFormatter = DateFormatter()
            startFormatter.dateFormat = "MMM d"
            let endFormatter = DateFormatter()
            endFormatter.dateFormat = "MMM d, yyyy"

            return "\(startFormatter.string(from: weekStartDate)) - \(endFormatter.string(from: endDate))"
        }
    }

    /// Top muscle groups by volume
    public var topMuscleGroups: [(muscleGroup: String, volume: Double)] {
        return muscleGroupVolumesDict
            .map { (muscleGroup: $0.key, volume: $0.value) }
            .sorted { $0.volume > $1.volume }
            .prefix(5)
            .map { $0 }
    }

    /// Training frequency (workouts per week)
    public var trainingFrequency: Int {
        return Int(totalWorkouts)
    }

    // MARK: - Business Logic Methods

    /// Updates muscle group volume
    public func updateMuscleGroupVolume(muscleGroup: String, volume: Double) {
        var currentVolumes = muscleGroupVolumesDict
        currentVolumes[muscleGroup] = volume
        muscleGroupVolumesDict = currentVolumes
        modifiedAt = Date()
    }

    /// Adds volume for a muscle group
    public func addMuscleGroupVolume(muscleGroup: String, volume: Double) {
        var currentVolumes = muscleGroupVolumesDict
        currentVolumes[muscleGroup, default: 0] += volume
        muscleGroupVolumesDict = currentVolumes
        modifiedAt = Date()
    }

    /// Updates all metrics from workout data
    public func updateMetrics(totalVolume: Double,
                            totalSets: Int32,
                            totalWorkouts: Int32,
                            averageRPE: Double,
                            totalDuration: Double,
                            muscleGroupVolumes: [String: Double]) {
        self.totalVolume = totalVolume
        self.totalSets = totalSets
        self.totalWorkouts = totalWorkouts
        self.averageRPE = averageRPE
        self.totalDuration = totalDuration
        self.muscleGroupVolumesDict = muscleGroupVolumes
        self.modifiedAt = Date()
    }

    /// Creates a weekly volume record for a specific week
    public static func createForWeek(startingMonday: Date, context: NSManagedObjectContext) -> WeeklyVolume {
        let weeklyVolume = WeeklyVolume(context: context)
        weeklyVolume.weekStartDate = startingMonday
        weeklyVolume.totalVolume = 0
        weeklyVolume.totalSets = 0
        weeklyVolume.totalWorkouts = 0
        weeklyVolume.averageRPE = 0
        weeklyVolume.totalDuration = 0
        weeklyVolume.muscleGroupVolumesDict = [:]
        return weeklyVolume
    }

    /// Gets the Monday of the week for a given date
    public static func mondayOfWeek(for date: Date) -> Date {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)

        // In Calendar, Sunday = 1, Monday = 2, etc.
        // We want to find Monday of the current week
        let daysFromMonday = (weekday == 1) ? -6 : -(weekday - 2)

        return calendar.date(byAdding: .day, value: daysFromMonday, to: date) ?? date
    }

    // MARK: - Validation

    /// Validates weekly volume data according to business rules
    public func validate() throws {
        guard totalVolume >= 0 else {
            throw WeeklyVolumeValidationError.invalidTotalVolume("Total volume must be non-negative")
        }

        guard totalSets >= 0 else {
            throw WeeklyVolumeValidationError.invalidTotalSets("Total sets must be non-negative")
        }

        guard totalWorkouts >= 0 else {
            throw WeeklyVolumeValidationError.invalidTotalWorkouts("Total workouts must be non-negative")
        }

        guard averageRPE >= 0 && averageRPE <= 10 else {
            throw WeeklyVolumeValidationError.invalidAverageRPE("Average RPE must be between 0 and 10")
        }

        guard totalDuration >= 0 else {
            throw WeeklyVolumeValidationError.invalidTotalDuration("Total duration must be non-negative")
        }

        // Validate that weekStartDate is actually a Monday
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: weekStartDate)
        guard weekday == 2 else { // Monday = 2 in Calendar
            throw WeeklyVolumeValidationError.invalidWeekStartDate("Week start date must be a Monday")
        }
    }

    // MARK: - Core Data Overrides

    public override func awakeFromInsert() {
        super.awakeFromInsert()

        let now = Date()
        if id == nil { id = UUID() }
        if createdAt == nil { createdAt = now }
        modifiedAt = now

        // Set default values
        totalVolume = 0
        totalSets = 0
        totalWorkouts = 0
        averageRPE = 0
        totalDuration = 0

        // Initialize empty muscle group volumes
        if muscleGroupVolumes == nil {
            muscleGroupVolumesDict = [:]
        }

        // Default to current week's Monday if not set
        if weekStartDate == Date(timeIntervalSince1970: 0) { // Default Core Data date
            weekStartDate = WeeklyVolume.mondayOfWeek(for: now)
        }
    }

    public override func willSave() {
        super.willSave()

        if isUpdated && !isDeleted {
            modifiedAt = Date()

            // Validate data before saving
            do {
                try validate()
            } catch {
                print("Validation error for WeeklyVolume: \(error)")
            }
        }
    }
}

// MARK: - Validation Errors

public enum WeeklyVolumeValidationError: Error, LocalizedError {
    case invalidTotalVolume(String)
    case invalidTotalSets(String)
    case invalidTotalWorkouts(String)
    case invalidAverageRPE(String)
    case invalidTotalDuration(String)
    case invalidWeekStartDate(String)

    public var errorDescription: String? {
        switch self {
        case .invalidTotalVolume(let message),
             .invalidTotalSets(let message),
             .invalidTotalWorkouts(let message),
             .invalidAverageRPE(let message),
             .invalidTotalDuration(let message),
             .invalidWeekStartDate(let message):
            return message
        }
    }
}