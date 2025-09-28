import Foundation
import CoreData

@objc(Routine)
public class Routine: NSManagedObject, Identifiable {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Routine> {
        return NSFetchRequest<Routine>(entityName: "Routine")
    }

    // MARK: - Computed Properties

    /// Exercises ordered by index
    public var orderedExercises: [RoutineExercise] {
        guard let exercisesSet = exercises as? Set<RoutineExercise> else { return [] }
        return exercisesSet.sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Total number of exercises in the routine
    public var exerciseCount: Int {
        return exercises?.count ?? 0
    }

    /// Calculated estimated duration based on exercises and rest times
    public var calculatedEstimatedDuration: TimeInterval {
        guard let exercisesSet = exercises as? Set<RoutineExercise> else { return 0 }

        var totalDuration: TimeInterval = 0

        for routineExercise in exercisesSet {
            // Estimate time per set (assume 30 seconds per set + rest time)
            let setsTime = Double(routineExercise.targetSets) * 30.0
            let restTime = Double(routineExercise.targetSets - 1) * routineExercise.restTime
            totalDuration += setsTime + restTime
        }

        return totalDuration
    }

    /// Whether the routine has been used recently (within last 30 days)
    public var isRecentlyUsed: Bool {
        guard let lastUsed = lastUsed else { return false }
        return lastUsed.timeIntervalSinceNow > -30 * 24 * 60 * 60 // 30 days
    }

    /// Usage frequency category
    public var usageFrequency: UsageFrequency {
        switch useCount {
        case 0:
            return .never
        case 1...5:
            return .rarely
        case 6...15:
            return .sometimes
        case 16...30:
            return .often
        default:
            return .frequently
        }
    }

    // MARK: - Validation

    /// Validates routine data according to business rules
    public func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RoutineValidationError.invalidName("Routine name cannot be empty")
        }

        guard estimatedDuration >= 0 else {
            throw RoutineValidationError.invalidDuration("Estimated duration must be non-negative")
        }
    }

    // MARK: - Business Logic Methods

    /// Adds an exercise to the routine
    public func addExercise(_ routineExercise: RoutineExercise) {
        // Set the order index automatically
        routineExercise.orderIndex = Int32(exerciseCount)
        routineExercise.routine = self
        addToExercises(routineExercise)
        updateEstimatedDuration()
    }

    /// Removes an exercise from the routine
    public func removeExercise(_ routineExercise: RoutineExercise) {
        removeFromExercises(routineExercise)
        renumberExercises()
        updateEstimatedDuration()
    }

    /// Reorders exercises in the routine
    public func reorderExercises(_ orderedExerciseIds: [UUID]) {
        let exerciseDict = Dictionary(uniqueKeysWithValues: orderedExercises.map { ($0.id, $0) })

        for (index, exerciseId) in orderedExerciseIds.enumerated() {
            if let exercise = exerciseDict[exerciseId] {
                exercise.orderIndex = Int32(index)
            }
        }

        modifiedAt = Date()
    }

    /// Updates the estimated duration based on exercises
    public func updateEstimatedDuration() {
        estimatedDuration = calculatedEstimatedDuration
        modifiedAt = Date()
    }

    /// Marks the routine as used
    public func markAsUsed() {
        lastUsed = Date()
        useCount += 1
        modifiedAt = Date()
    }

    /// Archives or unarchives the routine
    public func setArchived(_ archived: Bool) {
        isArchived = archived
        modifiedAt = Date()
    }

    /// Updates routine properties
    public func updateProperties(name: String? = nil,
                               notes: String? = nil,
                               estimatedDuration: TimeInterval? = nil) throws {
        if let name = name {
            self.name = name
        }

        if let notes = notes {
            self.notes = notes
        }

        if let estimatedDuration = estimatedDuration {
            self.estimatedDuration = estimatedDuration
        }

        try validate()
        modifiedAt = Date()
    }

    /// Renumbers exercises after removal
    private func renumberExercises() {
        let sortedExercises = orderedExercises
        for (index, exercise) in sortedExercises.enumerated() {
            exercise.orderIndex = Int32(index)
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
        isArchived = false
        useCount = 0
        estimatedDuration = 0
    }

    public override func willSave() {
        super.willSave()

        if isUpdated && !isDeleted {
            modifiedAt = Date()

            // Validate data before saving
            do {
                try validate()
            } catch {
                print("Validation error for Routine: \(error)")
            }
        }
    }
}

// MARK: - Supporting Types

public enum UsageFrequency: String, CaseIterable {
    case never = "Never"
    case rarely = "Rarely"
    case sometimes = "Sometimes"
    case often = "Often"
    case frequently = "Frequently"
}

// MARK: - Validation Errors

public enum RoutineValidationError: Error, LocalizedError {
    case invalidName(String)
    case invalidDuration(String)

    public var errorDescription: String? {
        switch self {
        case .invalidName(let message),
             .invalidDuration(let message):
            return message
        }
    }
}