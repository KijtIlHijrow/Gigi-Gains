import Foundation
import CoreData

@objc(Exercise)
public class Exercise: NSManagedObject, Identifiable {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Exercise> {
        return NSFetchRequest<Exercise>(entityName: "Exercise")
    }

    // MARK: - Computed Properties

    /// Parsed primary muscle groups from JSON string
    public var primaryMuscleGroupsArray: [String] {
        get {
            guard let jsonString = primaryMuscleGroups,
                  let data = jsonString.data(using: .utf8),
                  let array = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return array
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let jsonString = String(data: data, encoding: .utf8) {
                primaryMuscleGroups = jsonString
            }
        }
    }

    /// Parsed secondary muscle groups from JSON string
    public var secondaryMuscleGroupsArray: [String] {
        get {
            guard let jsonString = secondaryMuscleGroups,
                  let data = jsonString.data(using: .utf8),
                  let array = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return array
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let jsonString = String(data: data, encoding: .utf8) {
                secondaryMuscleGroups = jsonString
            }
        }
    }

    /// All muscle groups (primary + secondary)
    public var allMuscleGroups: [String] {
        return primaryMuscleGroupsArray + secondaryMuscleGroupsArray
    }

    /// Whether this exercise is a compound movement
    public var isCompound: Bool {
        return category.lowercased() == "compound" || primaryMuscleGroupsArray.count > 1
    }

    /// Recent workout history for this exercise
    public var recentWorkoutExercises: [WorkoutExercise] {
        guard let workoutExercisesSet = workoutExercises as? Set<WorkoutExercise> else { return [] }

        return workoutExercisesSet
            .filter { $0.session.isCompleted }
            .sorted { $0.session.startDate > $1.session.startDate }
            .prefix(10)
            .map { $0 }
    }

    /// Current personal records for this exercise
    public var currentPersonalRecords: [PersonalRecord] {
        guard let personalRecordsSet = personalRecords as? Set<PersonalRecord> else { return [] }

        // Group by record type and get the best for each
        let groupedRecords = Dictionary(grouping: personalRecordsSet) { $0.recordType }

        return groupedRecords.compactMap { (type, records) in
            // For most record types, we want the highest value
            return records.max { $0.value < $1.value }
        }
    }

    /// Best estimated 1RM from recent workout history
    public var bestEstimated1RM: Double {
        guard let workoutExercisesSet = workoutExercises as? Set<WorkoutExercise> else { return 0 }

        var bestOneRM: Double = 0

        for workoutExercise in workoutExercisesSet {
            guard let setsSet = workoutExercise.sets as? Set<ExerciseSet> else { continue }

            for exerciseSet in setsSet where exerciseSet.isCompleted {
                bestOneRM = max(bestOneRM, exerciseSet.estimatedOneRM)
            }
        }

        return bestOneRM
    }

    /// Total volume performed for this exercise across all workouts
    public var totalVolumeLifted: Double {
        guard let workoutExercisesSet = workoutExercises as? Set<WorkoutExercise> else { return 0 }

        return workoutExercisesSet.reduce(0) { total, workoutExercise in
            guard let setsSet = workoutExercise.sets as? Set<ExerciseSet> else { return total }

            let exerciseVolume = setsSet.reduce(0) { setTotal, exerciseSet in
                guard exerciseSet.isCompleted else { return setTotal }
                return setTotal + exerciseSet.volume
            }

            return total + exerciseVolume
        }
    }

    // MARK: - Validation

    /// Validates exercise data according to business rules
    public func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ExerciseValidationError.invalidName("Exercise name cannot be empty")
        }

        guard !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ExerciseValidationError.invalidCategory("Exercise category cannot be empty")
        }

        guard !equipment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ExerciseValidationError.invalidEquipment("Exercise equipment cannot be empty")
        }

        guard primaryMuscleGroupsArray.count > 0 else {
            throw ExerciseValidationError.invalidMuscleGroups("Exercise must have at least one primary muscle group")
        }

        guard defaultRestTime >= 0 else {
            throw ExerciseValidationError.invalidRestTime("Default rest time must be non-negative")
        }
    }

    // MARK: - Business Logic Methods

    /// Archives or unarchives the exercise
    public func setArchived(_ archived: Bool) throws {
        guard isCustom else {
            throw ExerciseValidationError.cannotModifyPredefined("Cannot archive predefined exercises")
        }

        isArchived = archived
        modifiedAt = Date()
    }

    /// Updates exercise properties (only for custom exercises)
    public func updateProperties(name: String? = nil,
                               category: String? = nil,
                               instructions: String? = nil,
                               defaultRestTime: Double? = nil) throws {
        guard isCustom else {
            throw ExerciseValidationError.cannotModifyPredefined("Cannot modify predefined exercises")
        }

        if let name = name {
            self.name = name
        }

        if let category = category {
            self.category = category
        }

        if let instructions = instructions {
            self.instructions = instructions
        }

        if let defaultRestTime = defaultRestTime {
            self.defaultRestTime = defaultRestTime
        }

        try validate()
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
        isCustom = false
        isArchived = false
        defaultRestTime = 120 // 2 minutes default

        // Initialize empty muscle groups if not set
        if primaryMuscleGroups == nil {
            primaryMuscleGroupsArray = []
        }
        if secondaryMuscleGroups == nil {
            secondaryMuscleGroupsArray = []
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
                print("Validation error for Exercise: \(error)")
            }
        }
    }
}

// MARK: - Validation Errors

public enum ExerciseValidationError: Error, LocalizedError {
    case invalidName(String)
    case invalidCategory(String)
    case invalidEquipment(String)
    case invalidMuscleGroups(String)
    case invalidRestTime(String)
    case cannotModifyPredefined(String)

    public var errorDescription: String? {
        switch self {
        case .invalidName(let message),
             .invalidCategory(let message),
             .invalidEquipment(let message),
             .invalidMuscleGroups(let message),
             .invalidRestTime(let message),
             .cannotModifyPredefined(let message):
            return message
        }
    }
}