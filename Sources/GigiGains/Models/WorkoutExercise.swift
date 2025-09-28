import Foundation
import CoreData

@objc(WorkoutExercise)
public class WorkoutExercise: NSManagedObject, Identifiable {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<WorkoutExercise> {
        return NSFetchRequest<WorkoutExercise>(entityName: "WorkoutExercise")
    }

    // MARK: - Computed Properties

    /// Total volume for this exercise (sum of all set volumes)
    public var totalVolume: Double {
        guard let setsSet = sets as? Set<ExerciseSet> else { return 0 }
        return setsSet.reduce(0) { $0 + $1.volume }
    }

    /// Number of completed sets
    public var completedSetsCount: Int {
        guard let setsSet = sets as? Set<ExerciseSet> else { return 0 }
        return setsSet.filter { $0.isCompleted }.count
    }

    /// Number of total sets
    public var totalSetsCount: Int {
        return sets?.count ?? 0
    }

    /// Average RPE across completed sets
    public var averageRPE: Double {
        guard let setsSet = sets as? Set<ExerciseSet> else { return 0 }
        let completedSets = setsSet.filter { $0.isCompleted }
        guard !completedSets.isEmpty else { return 0 }

        let totalRPE = completedSets.reduce(0) { $0 + $1.rpe }
        return totalRPE / Double(completedSets.count)
    }

    /// Best set by estimated 1RM
    public var bestSet: ExerciseSet? {
        guard let setsSet = sets as? Set<ExerciseSet> else { return nil }
        return setsSet.filter { $0.isCompleted }.max { $0.estimatedOneRM < $1.estimatedOneRM }
    }

    /// Sets ordered by set number
    public var orderedSets: [ExerciseSet] {
        guard let setsSet = sets as? Set<ExerciseSet> else { return [] }
        return setsSet.sorted { $0.setNumber < $1.setNumber }
    }

    /// Whether all sets are completed
    public var allSetsCompleted: Bool {
        guard let setsSet = sets as? Set<ExerciseSet>, !setsSet.isEmpty else { return false }
        return setsSet.allSatisfy { $0.isCompleted }
    }

    // MARK: - Business Logic Methods

    /// Adds a set to this exercise
    public func addSet(_ set: ExerciseSet) {
        // Set the set number automatically
        set.setNumber = Int32(totalSetsCount + 1)
        set.workoutExercise = self
        addToSets(set)
        updateCompletionStatus()
    }

    /// Removes a set from this exercise
    public func removeSet(_ set: ExerciseSet) {
        removeFromSets(set)
        renumberSets()
        updateCompletionStatus()
    }

    /// Updates the completion status based on sets
    public func updateCompletionStatus() {
        isCompleted = allSetsCompleted && totalSetsCount > 0
        modifiedAt = Date()
    }

    /// Renumbers sets after removal
    private func renumberSets() {
        let sortedSets = orderedSets
        for (index, set) in sortedSets.enumerated() {
            set.setNumber = Int32(index + 1)
        }
    }

    /// Gets the last completed set (for duplication)
    public func getLastSet() -> ExerciseSet? {
        return orderedSets.last
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
        restTimerDuration = 120 // 2 minutes default
        isCompleted = false
    }

    public override func willSave() {
        super.willSave()

        if isUpdated && !isDeleted {
            modifiedAt = Date()
        }
    }
}