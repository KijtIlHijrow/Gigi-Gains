import Foundation
import CoreData

@objc(RoutineExercise)
public class RoutineExercise: NSManagedObject, Identifiable {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<RoutineExercise> {
        return NSFetchRequest<RoutineExercise>(entityName: "RoutineExercise")
    }

    // MARK: - Computed Properties

    /// Parsed target reps from JSON string
    public var targetRepsArray: [Int32] {
        get {
            guard let jsonString = targetReps,
                  let data = jsonString.data(using: .utf8),
                  let array = try? JSONDecoder().decode([Int32].self, from: data) else {
                return [targetSets > 0 ? 8 : 0] // Default to 8 reps if no specific scheme
            }
            return array
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let jsonString = String(data: data, encoding: .utf8) {
                targetReps = jsonString
            }
        }
    }

    /// Estimated time for this exercise in seconds
    public var estimatedDuration: TimeInterval {
        // Estimate: 30 seconds per set + rest time between sets
        let setTime = Double(targetSets) * 30.0
        let totalRestTime = Double(targetSets - 1) * restTime
        return setTime + totalRestTime
    }

    /// Whether this exercise has varied rep schemes (e.g., pyramid sets)
    public var hasVariedRepScheme: Bool {
        let repsArray = targetRepsArray
        guard repsArray.count > 1 else { return false }
        return !repsArray.allSatisfy { $0 == repsArray.first }
    }

    /// Average target reps across all sets
    public var averageTargetReps: Double {
        let repsArray = targetRepsArray
        guard !repsArray.isEmpty else { return 0 }
        return Double(repsArray.reduce(0, +)) / Double(repsArray.count)
    }

    /// Total target volume if target weight is set
    public var estimatedVolume: Double? {
        guard let weight = targetWeight else { return nil }
        let totalReps = targetRepsArray.reduce(0, +)
        return weight * Double(totalReps)
    }

    // MARK: - Validation

    /// Validates routine exercise data according to business rules
    public func validate() throws {
        guard targetSets > 0 else {
            throw RoutineExerciseValidationError.invalidTargetSets("Target sets must be greater than 0")
        }

        let repsArray = targetRepsArray
        guard !repsArray.isEmpty else {
            throw RoutineExerciseValidationError.invalidTargetReps("Target reps array cannot be empty")
        }

        guard repsArray.allSatisfy({ $0 > 0 }) else {
            throw RoutineExerciseValidationError.invalidTargetReps("All target reps must be greater than 0")
        }

        if let weight = targetWeight, weight < 0 {
            throw RoutineExerciseValidationError.invalidTargetWeight("Target weight must be non-negative")
        }

        if let rpe = targetRPE, !(1.0...10.0).contains(rpe) {
            throw RoutineExerciseValidationError.invalidTargetRPE("Target RPE must be between 1.0 and 10.0")
        }

        guard restTime >= 0 else {
            throw RoutineExerciseValidationError.invalidRestTime("Rest time must be non-negative")
        }
    }

    // MARK: - Business Logic Methods

    /// Updates the target rep scheme
    public func updateTargetReps(_ reps: [Int32]) throws {
        guard !reps.isEmpty else {
            throw RoutineExerciseValidationError.invalidTargetReps("Target reps cannot be empty")
        }

        guard reps.allSatisfy({ $0 > 0 }) else {
            throw RoutineExerciseValidationError.invalidTargetReps("All reps must be positive")
        }

        targetRepsArray = reps
        modifiedAt = Date()
    }

    /// Updates exercise properties
    public func updateProperties(targetSets: Int32? = nil,
                               targetReps: [Int32]? = nil,
                               targetWeight: Double? = nil,
                               targetRPE: Double? = nil,
                               restTime: TimeInterval? = nil,
                               superset: String? = nil,
                               notes: String? = nil) throws {
        if let targetSets = targetSets {
            self.targetSets = targetSets
        }

        if let targetReps = targetReps {
            try updateTargetReps(targetReps)
        }

        if let targetWeight = targetWeight {
            self.targetWeight = targetWeight
        }

        if let targetRPE = targetRPE {
            self.targetRPE = targetRPE
        }

        if let restTime = restTime {
            self.restTime = restTime
        }

        if let superset = superset {
            self.superset = superset
        }

        if let notes = notes {
            self.notes = notes
        }

        try validate()
        modifiedAt = Date()
    }

    /// Creates a rep scheme string for display (e.g., "3x8" or "10,8,6")
    public var repSchemeDescription: String {
        let repsArray = targetRepsArray

        if !hasVariedRepScheme && repsArray.count > 0 {
            // Simple scheme like "3x8"
            return "\(targetSets)x\(repsArray[0])"
        } else {
            // Complex scheme like "10,8,6"
            return repsArray.map { String($0) }.joined(separator: ",")
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
        orderIndex = 0
        targetSets = 3
        restTime = 120 // 2 minutes default

        // Set default target reps (3 sets of 8 reps)
        if targetReps == nil {
            targetRepsArray = [8, 8, 8]
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
                print("Validation error for RoutineExercise: \(error)")
            }
        }
    }
}

// MARK: - Validation Errors

public enum RoutineExerciseValidationError: Error, LocalizedError {
    case invalidTargetSets(String)
    case invalidTargetReps(String)
    case invalidTargetWeight(String)
    case invalidTargetRPE(String)
    case invalidRestTime(String)

    public var errorDescription: String? {
        switch self {
        case .invalidTargetSets(let message),
             .invalidTargetReps(let message),
             .invalidTargetWeight(let message),
             .invalidTargetRPE(let message),
             .invalidRestTime(let message):
            return message
        }
    }
}