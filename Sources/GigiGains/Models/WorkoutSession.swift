import Foundation
import CoreData

@objc(WorkoutSession)
public class WorkoutSession: NSManagedObject, Identifiable {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<WorkoutSession> {
        return NSFetchRequest<WorkoutSession>(entityName: "WorkoutSession")
    }

    // MARK: - Computed Properties

    /// Calculated total volume (weight × reps) for the session
    public var calculatedTotalVolume: Double {
        guard let exercisesSet = exercises as? Set<WorkoutExercise> else { return 0 }

        return exercisesSet.reduce(0) { total, workoutExercise in
            guard let setsSet = workoutExercise.sets as? Set<ExerciseSet> else { return total }

            let exerciseVolume = setsSet.reduce(0) { setTotal, exerciseSet in
                return setTotal + (exerciseSet.weight * Double(exerciseSet.reps))
            }

            return total + exerciseVolume
        }
    }

    /// Calculated average RPE across all completed sets
    public var calculatedAverageRPE: Double {
        guard let exercisesSet = exercises as? Set<WorkoutExercise> else { return 0 }

        var totalRPE: Double = 0
        var setCount: Int = 0

        for workoutExercise in exercisesSet {
            guard let setsSet = workoutExercise.sets as? Set<ExerciseSet> else { continue }

            for exerciseSet in setsSet where exerciseSet.isCompleted {
                totalRPE += exerciseSet.rpe
                setCount += 1
            }
        }

        return setCount > 0 ? totalRPE / Double(setCount) : 0
    }

    /// Calculated duration based on start and end dates
    public var calculatedDuration: TimeInterval {
        guard let endDate = endDate else {
            // If workout is in progress, calculate duration to now
            return Date().timeIntervalSince(startDate)
        }
        return endDate.timeIntervalSince(startDate)
    }

    /// Total number of completed sets in the session
    public var totalCompletedSets: Int {
        guard let exercisesSet = exercises as? Set<WorkoutExercise> else { return 0 }

        return exercisesSet.reduce(0) { total, workoutExercise in
            guard let setsSet = workoutExercise.sets as? Set<ExerciseSet> else { return total }
            return total + setsSet.filter { $0.isCompleted }.count
        }
    }

    /// Total number of exercises in the session
    public var totalExercises: Int {
        return exercises?.count ?? 0
    }

    /// Whether the session is currently in progress
    public var isInProgress: Bool {
        return !isCompleted && endDate == nil && startDate <= Date()
    }

    /// Whether the session is in draft state (not started)
    public var isDraft: Bool {
        return !isCompleted && endDate == nil && startDate > Date()
    }

    // MARK: - Business Logic Methods

    /// Updates the session's calculated fields
    public func updateCalculatedFields() {
        totalVolume = calculatedTotalVolume
        averageRPE = calculatedAverageRPE
        duration = calculatedDuration
        modifiedAt = Date()
    }

    /// Marks the session as completed
    public func complete() {
        guard !isCompleted else { return }

        endDate = Date()
        isCompleted = true
        updateCalculatedFields()
    }

    /// Starts the session
    public func start() {
        guard isDraft else { return }

        startDate = Date()
        updateCalculatedFields()
    }

    /// Adds an exercise to the session
    public func addExercise(_ exercise: WorkoutExercise) {
        addToExercises(exercise)
        exercise.session = self
        updateCalculatedFields()
    }

    /// Removes an exercise from the session
    public func removeExercise(_ exercise: WorkoutExercise) {
        removeFromExercises(exercise)
        updateCalculatedFields()
    }

    /// Gets exercises sorted by order index
    public var orderedExercises: [WorkoutExercise] {
        guard let exercisesSet = exercises as? Set<WorkoutExercise> else { return [] }
        return exercisesSet.sorted { $0.orderIndex < $1.orderIndex }
    }

    // MARK: - Core Data Overrides

    public override func awakeFromInsert() {
        super.awakeFromInsert()

        let now = Date()
        if id == nil { id = UUID() }
        if createdAt == nil { createdAt = now }
        modifiedAt = now
        startDate = now

        // Set default values
        duration = 0
        totalVolume = 0
        averageRPE = 0
        isCompleted = false
    }

    public override func willSave() {
        super.willSave()

        if isUpdated && !isDeleted {
            modifiedAt = Date()

            // Update calculated fields whenever the session is saved
            if !isCompleted {
                updateCalculatedFields()
            }
        }
    }
}