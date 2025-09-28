import Foundation
import CoreData

@objc(ExerciseSet)
public class ExerciseSet: NSManagedObject, Identifiable {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ExerciseSet> {
        return NSFetchRequest<ExerciseSet>(entityName: "ExerciseSet")
    }

    // MARK: - Computed Properties

    /// Calculated estimated 1RM using modified Epley formula with RPE adjustment
    public var calculatedEstimatedOneRM: Double {
        guard weight > 0, reps > 0 else { return 0 }

        // Modified Epley formula with RPE adjustment
        // RIR (Reps in Reserve) = 10 - RPE
        let repsInReserve = rpe > 0 ? (10 - rpe) : 0
        let totalReps = Double(reps) + repsInReserve

        // Epley formula: 1RM = weight × (1 + reps/30)
        return weight * (1 + totalReps / 30)
    }

    /// Volume for this set (weight × reps)
    public var volume: Double {
        return weight * Double(reps)
    }

    /// Whether this set represents a potential personal record
    public var isPotentialPersonalRecord: Bool {
        guard isCompleted else { return false }

        // This would need to be calculated against historical data
        // For now, we'll consider any set with high RPE (9+) as potential PR
        return rpe >= 9.0
    }

    /// Intensity percentage based on RPE (approximate)
    public var intensityPercentage: Double {
        // Rough approximation: RPE 6 ≈ 60%, RPE 10 ≈ 100%
        return max(0, min(100, (rpe - 1) * 11.11))
    }

    // MARK: - Validation

    /// Validates set data according to business rules
    public func validate() throws {
        guard weight >= 0 else {
            throw ValidationError.invalidWeight("Weight must be non-negative")
        }

        guard reps >= 0 && reps <= 1000 else {
            throw ValidationError.invalidReps("Reps must be between 0 and 1000")
        }

        guard rpe >= 1.0 && rpe <= 10.0 else {
            throw ValidationError.invalidRPE("RPE must be between 1.0 and 10.0")
        }

        guard setNumber >= 1 else {
            throw ValidationError.invalidSetNumber("Set number must be at least 1")
        }
    }

    // MARK: - Business Logic Methods

    /// Marks the set as completed and calculates derived values
    public func complete() {
        isCompleted = true
        estimatedOneRM = calculatedEstimatedOneRM
        modifiedAt = Date()
    }

    /// Updates the estimated 1RM calculation
    public func updateEstimatedOneRM() {
        estimatedOneRM = calculatedEstimatedOneRM
        modifiedAt = Date()
    }

    // MARK: - Core Data Overrides

    public override func awakeFromInsert() {
        super.awakeFromInsert()

        let now = Date()
        if id == nil { id = UUID() }
        if createdAt == nil { createdAt = now }
        modifiedAt = now

        // Set default values
        weight = 0
        reps = 0
        rpe = 7.0 // Default RPE
        setNumber = 1
        isCompleted = false
        restDuration = 0
        estimatedOneRM = 0
    }

    public override func willSave() {
        super.willSave()

        if isUpdated && !isDeleted {
            modifiedAt = Date()

            // Update calculated fields
            estimatedOneRM = calculatedEstimatedOneRM

            // Validate data before saving
            do {
                try validate()
            } catch {
                // In a production app, you might want to handle this differently
                print("Validation error for ExerciseSet: \(error)")
            }
        }
    }
}

// MARK: - Validation Errors

public enum ValidationError: Error, LocalizedError {
    case invalidWeight(String)
    case invalidReps(String)
    case invalidRPE(String)
    case invalidSetNumber(String)

    public var errorDescription: String? {
        switch self {
        case .invalidWeight(let message),
             .invalidReps(let message),
             .invalidRPE(let message),
             .invalidSetNumber(let message):
            return message
        }
    }
}