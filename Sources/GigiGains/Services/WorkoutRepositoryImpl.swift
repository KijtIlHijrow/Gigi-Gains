import Foundation
import CoreData
import Combine

public class WorkoutRepositoryImpl: WorkoutRepository {

    // MARK: - Properties

    private let coreDataStack: CoreDataStack
    private let workoutSessionsChangedSubject = PassthroughSubject<Void, Never>()
    private let workoutExercisesChangedSubject = PassthroughSubject<Void, Never>()
    private let exerciseSetsChangedSubject = PassthroughSubject<Void, Never>()

    // MARK: - Publishers

    public var workoutSessionsChangedPublisher: AnyPublisher<Void, Never> {
        workoutSessionsChangedSubject.eraseToAnyPublisher()
    }

    public var workoutExercisesChangedPublisher: AnyPublisher<Void, Never> {
        workoutExercisesChangedSubject.eraseToAnyPublisher()
    }

    public var exerciseSetsChangedPublisher: AnyPublisher<Void, Never> {
        exerciseSetsChangedSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    public init(coreDataStack: CoreDataStack = CoreDataStack.shared) {
        self.coreDataStack = coreDataStack
    }

    // MARK: - Workout Session Operations

    public func createWorkoutSession(name: String?, routineId: UUID?, startDate: Date, notes: String?) async throws -> WorkoutSession {
        let context = coreDataStack.viewContext

        let session = WorkoutSession(context: context)
        session.name = name
        session.startDate = startDate
        session.notes = notes

        // Link to routine if provided
        if let routineId = routineId {
            let routineFetch: NSFetchRequest<Routine> = Routine.fetchRequest()
            routineFetch.predicate = NSPredicate(format: "id == %@", routineId as NSUUID)
            routineFetch.fetchLimit = 1

            if let routine = try context.fetch(routineFetch).first {
                session.routine = routine
            }
        }

        do {
            try context.save()
            workoutSessionsChangedSubject.send()
            return session
        } catch {
            throw WorkoutRepositoryError.saveContextFailed(error)
        }
    }

    public func fetchWorkoutSession(id: UUID) async throws -> WorkoutSession {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<WorkoutSession> = WorkoutSession.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as NSUUID)
        request.fetchLimit = 1

        do {
            let sessions = try context.fetch(request)
            guard let session = sessions.first else {
                throw WorkoutRepositoryError.objectNotFound(id)
            }
            return session
        } catch is WorkoutRepositoryError {
            throw error
        } catch {
            throw WorkoutRepositoryError.fetchRequestFailed(error)
        }
    }

    public func fetchWorkoutSessions(filter: WorkoutQueryFilter, sortBy: WorkoutSortOption, options: FetchOptions) async throws -> [WorkoutSession] {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<WorkoutSession> = WorkoutSession.fetchRequest()

        // Apply filter
        request.predicate = filter.predicate

        // Apply sorting
        request.sortDescriptors = sortBy.sortDescriptors

        // Apply options
        if let limit = options.limit {
            request.fetchLimit = limit
        }

        if let offset = options.offset {
            request.fetchOffset = offset
        }

        request.relationshipKeyPathsForPrefetching = options.prefetchRelationships
        request.returnsObjectsAsFaults = options.returnsObjectsAsFaults
        request.refreshesRefetchedObjects = options.refreshesRefetchedObjects

        do {
            return try context.fetch(request)
        } catch {
            throw WorkoutRepositoryError.fetchRequestFailed(error)
        }
    }

    public func fetchAllWorkoutSessions() async throws -> [WorkoutSession] {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<WorkoutSession> = WorkoutSession.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WorkoutSession.startDate, ascending: false)]

        do {
            return try context.fetch(request)
        } catch {
            throw WorkoutRepositoryError.fetchRequestFailed(error)
        }
    }

    public func updateWorkoutSession(_ session: WorkoutSession, name: String?, notes: String?, endDate: Date?, isCompleted: Bool?) async throws {
        let context = coreDataStack.viewContext

        if let name = name {
            session.name = name
        }

        if let notes = notes {
            session.notes = notes
        }

        if let endDate = endDate {
            session.endDate = endDate
        }

        if let isCompleted = isCompleted {
            session.isCompleted = isCompleted
        }

        // Update calculated fields
        session.updateCalculatedFields()

        do {
            try context.save()
            workoutSessionsChangedSubject.send()
        } catch {
            throw WorkoutRepositoryError.saveContextFailed(error)
        }
    }

    public func deleteWorkoutSession(_ session: WorkoutSession) async throws {
        let context = coreDataStack.viewContext
        context.delete(session)

        do {
            try context.save()
            workoutSessionsChangedSubject.send()
        } catch {
            throw WorkoutRepositoryError.saveContextFailed(error)
        }
    }

    public func deleteWorkoutSessions(ids sessionIds: [UUID], config: BatchOperationConfig) async throws -> Int {
        let context = coreDataStack.viewContext

        let batchDelete = NSBatchDeleteRequest(fetchRequest: {
            let request: NSFetchRequest<NSFetchRequestResult> = WorkoutSession.fetchRequest()
            request.predicate = NSPredicate(format: "id IN %@", sessionIds.map { $0 as NSUUID })
            return request
        }())

        batchDelete.resultType = .resultTypeCount

        do {
            let result = try context.execute(batchDelete) as? NSBatchDeleteResult
            let deletedCount = result?.result as? Int ?? 0

            workoutSessionsChangedSubject.send()
            return deletedCount
        } catch {
            throw WorkoutRepositoryError.batchDeleteFailed(error)
        }
    }

    public func completeWorkoutSession(_ session: WorkoutSession, endDate: Date) async throws {
        session.complete()
        session.endDate = endDate

        let context = coreDataStack.viewContext
        do {
            try context.save()
            workoutSessionsChangedSubject.send()
        } catch {
            throw WorkoutRepositoryError.saveContextFailed(error)
        }
    }

    // MARK: - Workout Exercise Operations

    public func addExerciseToWorkoutSession(_ session: WorkoutSession, exerciseId: UUID, orderIndex: Int32, restTimerDuration: Double?, superset: String?, notes: String?) async throws -> WorkoutExercise {
        let context = coreDataStack.viewContext

        // Fetch the exercise
        let exerciseFetch: NSFetchRequest<Exercise> = Exercise.fetchRequest()
        exerciseFetch.predicate = NSPredicate(format: "id == %@", exerciseId as NSUUID)
        exerciseFetch.fetchLimit = 1

        guard let exercise = try context.fetch(exerciseFetch).first else {
            throw WorkoutRepositoryError.relationshipConstraintViolation("Exercise with ID \(exerciseId) not found")
        }

        let workoutExercise = WorkoutExercise(context: context)
        workoutExercise.exercise = exercise
        workoutExercise.session = session
        workoutExercise.orderIndex = orderIndex
        workoutExercise.restTimerDuration = restTimerDuration ?? exercise.defaultRestTime
        workoutExercise.superset = superset
        workoutExercise.notes = notes

        session.addExercise(workoutExercise)

        do {
            try context.save()
            workoutExercisesChangedSubject.send()
            return workoutExercise
        } catch {
            throw WorkoutRepositoryError.saveContextFailed(error)
        }
    }

    public func removeExerciseFromWorkoutSession(_ session: WorkoutSession, workoutExercise: WorkoutExercise) async throws {
        let context = coreDataStack.viewContext
        session.removeExercise(workoutExercise)
        context.delete(workoutExercise)

        do {
            try context.save()
            workoutExercisesChangedSubject.send()
        } catch {
            throw WorkoutRepositoryError.saveContextFailed(error)
        }
    }

    public func updateWorkoutExercise(_ workoutExercise: WorkoutExercise, orderIndex: Int32?, restTimerDuration: Double?, superset: String?, notes: String?, isCompleted: Bool?) async throws {
        if let orderIndex = orderIndex {
            workoutExercise.orderIndex = orderIndex
        }

        if let restTimerDuration = restTimerDuration {
            workoutExercise.restTimerDuration = restTimerDuration
        }

        if let superset = superset {
            workoutExercise.superset = superset
        }

        if let notes = notes {
            workoutExercise.notes = notes
        }

        if let isCompleted = isCompleted {
            workoutExercise.isCompleted = isCompleted
        }

        let context = coreDataStack.viewContext
        do {
            try context.save()
            workoutExercisesChangedSubject.send()
        } catch {
            throw WorkoutRepositoryError.saveContextFailed(error)
        }
    }

    public func reorderExercisesInWorkoutSession(_ session: WorkoutSession, exerciseOrdering: [UUID]) async throws {
        let exercises = session.orderedExercises
        let exerciseDict = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })

        for (index, exerciseId) in exerciseOrdering.enumerated() {
            if let exercise = exerciseDict[exerciseId] {
                exercise.orderIndex = Int32(index)
            }
        }

        let context = coreDataStack.viewContext
        do {
            try context.save()
            workoutExercisesChangedSubject.send()
        } catch {
            throw WorkoutRepositoryError.saveContextFailed(error)
        }
    }

    // MARK: - Exercise Set Operations

    public func addSetToWorkoutExercise(_ workoutExercise: WorkoutExercise, setNumber: Int32, weight: Double, reps: Int32, rpe: Double, notes: String?, isCompleted: Bool) async throws -> ExerciseSet {
        let context = coreDataStack.viewContext

        let exerciseSet = ExerciseSet(context: context)
        exerciseSet.setNumber = setNumber
        exerciseSet.weight = weight
        exerciseSet.reps = reps
        exerciseSet.rpe = rpe
        exerciseSet.notes = notes
        exerciseSet.isCompleted = isCompleted

        // Validate the set data
        do {
            try exerciseSet.validate()
        } catch {
            throw WorkoutRepositoryError.invalidObjectState("Invalid set data: \(error.localizedDescription)")
        }

        workoutExercise.addSet(exerciseSet)

        do {
            try context.save()
            exerciseSetsChangedSubject.send()
            return exerciseSet
        } catch {
            throw WorkoutRepositoryError.saveContextFailed(error)
        }
    }

    public func updateExerciseSet(_ exerciseSet: ExerciseSet, weight: Double?, reps: Int32?, rpe: Double?, notes: String?, isCompleted: Bool?) async throws {
        if let weight = weight {
            exerciseSet.weight = weight
        }

        if let reps = reps {
            exerciseSet.reps = reps
        }

        if let rpe = rpe {
            exerciseSet.rpe = rpe
        }

        if let notes = notes {
            exerciseSet.notes = notes
        }

        if let isCompleted = isCompleted {
            exerciseSet.isCompleted = isCompleted
            if isCompleted {
                exerciseSet.complete()
            }
        }

        // Validate the updated set data
        do {
            try exerciseSet.validate()
        } catch {
            throw WorkoutRepositoryError.invalidObjectState("Invalid set data: \(error.localizedDescription)")
        }

        let context = coreDataStack.viewContext
        do {
            try context.save()
            exerciseSetsChangedSubject.send()
        } catch {
            throw WorkoutRepositoryError.saveContextFailed(error)
        }
    }

    public func removeSetFromWorkoutExercise(_ workoutExercise: WorkoutExercise, exerciseSet: ExerciseSet) async throws {
        let context = coreDataStack.viewContext
        workoutExercise.removeSet(exerciseSet)
        context.delete(exerciseSet)

        do {
            try context.save()
            exerciseSetsChangedSubject.send()
        } catch {
            throw WorkoutRepositoryError.saveContextFailed(error)
        }
    }

    public func duplicateLastSet(_ workoutExercise: WorkoutExercise) async throws -> ExerciseSet? {
        guard let lastSet = workoutExercise.getLastSet() else {
            return nil
        }

        return try await addSetToWorkoutExercise(
            workoutExercise,
            setNumber: Int32(workoutExercise.totalSetsCount + 1),
            weight: lastSet.weight,
            reps: lastSet.reps,
            rpe: lastSet.rpe,
            notes: lastSet.notes,
            isCompleted: false
        )
    }

    // MARK: - Advanced Queries

    public func fetchWorkoutSessionsContainingExercise(exerciseId: UUID, limit: Int?, sortBy: WorkoutSortOption) async throws -> [WorkoutSession] {
        let filter = WorkoutQueryFilter(exerciseId: exerciseId)
        let options = FetchOptions(limit: limit, prefetchRelationships: ["exercises", "exercises.exercise"])
        return try await fetchWorkoutSessions(filter: filter, sortBy: sortBy, options: options)
    }

    public func fetchWorkoutSessionsFromRoutine(routineId: UUID, limit: Int?, sortBy: WorkoutSortOption) async throws -> [WorkoutSession] {
        let filter = WorkoutQueryFilter(routineId: routineId)
        let options = FetchOptions(limit: limit, prefetchRelationships: ["routine"])
        return try await fetchWorkoutSessions(filter: filter, sortBy: sortBy, options: options)
    }

    public func fetchIncompleteWorkoutSessions() async throws -> [WorkoutSession] {
        let filter = WorkoutQueryFilter(isCompleted: false)
        let options = FetchOptions(prefetchRelationships: ["exercises"])
        return try await fetchWorkoutSessions(filter: filter, sortBy: .startDateDescending, options: options)
    }

    public func fetchRecentWorkoutSessions(days: Int, limit: Int?) async throws -> [WorkoutSession] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let filter = WorkoutQueryFilter(startDateFrom: cutoffDate)
        let options = FetchOptions(limit: limit)
        return try await fetchWorkoutSessions(filter: filter, sortBy: .startDateDescending, options: options)
    }

    public func countWorkoutSessions(filter: WorkoutQueryFilter) async throws -> Int {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<WorkoutSession> = WorkoutSession.fetchRequest()
        request.predicate = filter.predicate
        request.resultType = .countResultType

        do {
            return try context.count(for: request)
        } catch {
            throw WorkoutRepositoryError.fetchRequestFailed(error)
        }
    }

    public func fetchSetsForExercise(exerciseId: UUID, dateRange: (start: Date, end: Date)?, limit: Int?) async throws -> [ExerciseSet] {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<ExerciseSet> = ExerciseSet.fetchRequest()

        var predicates: [NSPredicate] = [
            NSPredicate(format: "workoutExercise.exercise.id == %@", exerciseId as NSUUID)
        ]

        if let dateRange = dateRange {
            predicates.append(NSPredicate(format: "workoutExercise.session.startDate >= %@ AND workoutExercise.session.startDate <= %@", dateRange.start as NSDate, dateRange.end as NSDate))
        }

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ExerciseSet.createdAt, ascending: false)]

        if let limit = limit {
            request.fetchLimit = limit
        }

        do {
            return try context.fetch(request)
        } catch {
            throw WorkoutRepositoryError.fetchRequestFailed(error)
        }
    }

    // MARK: - Background Operations

    public func performBackgroundOperation(_ operation: @escaping (NSManagedObjectContext) throws -> Void) async throws {
        let backgroundContext = coreDataStack.newBackgroundContext()

        do {
            try await backgroundContext.perform {
                try operation(backgroundContext)
            }
        } catch {
            throw WorkoutRepositoryError.backgroundContextError(error)
        }
    }

    public func saveBackgroundContext(_ context: NSManagedObjectContext) async throws {
        do {
            try await context.perform {
                if context.hasChanges {
                    try context.save()
                }
            }
        } catch {
            throw WorkoutRepositoryError.saveContextFailed(error)
        }
    }

    public func mergeChangesFromContextDidSave(notification: Notification) async throws {
        let context = coreDataStack.viewContext
        do {
            await context.perform {
                context.mergeChanges(fromContextDidSave: notification)
            }
        } catch {
            throw WorkoutRepositoryError.contextMergeFailed(error)
        }
    }

    // MARK: - Data Validation and Integrity

    public func validateWorkoutSession(_ session: WorkoutSession) async -> [String] {
        var errors: [String] = []

        if session.startDate > Date() {
            errors.append("Start date cannot be in the future")
        }

        if let endDate = session.endDate, endDate < session.startDate {
            errors.append("End date cannot be before start date")
        }

        if session.isCompleted && session.endDate == nil {
            errors.append("Completed session must have an end date")
        }

        if session.duration < 0 {
            errors.append("Duration cannot be negative")
        }

        if session.totalVolume < 0 {
            errors.append("Total volume cannot be negative")
        }

        if session.averageRPE < 0 || session.averageRPE > 10 {
            errors.append("Average RPE must be between 0 and 10")
        }

        return errors
    }

    public func validateExerciseSet(_ exerciseSet: ExerciseSet) async -> [String] {
        var errors: [String] = []

        do {
            try exerciseSet.validate()
        } catch {
            errors.append(error.localizedDescription)
        }

        return errors
    }

    public func findOrphanedWorkoutExercises() async throws -> [WorkoutExercise] {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<WorkoutExercise> = WorkoutExercise.fetchRequest()
        request.predicate = NSPredicate(format: "exercise == nil")

        do {
            return try context.fetch(request)
        } catch {
            throw WorkoutRepositoryError.fetchRequestFailed(error)
        }
    }

    public func cleanupOrphanedData() async throws -> Int {
        let orphanedExercises = try await findOrphanedWorkoutExercises()

        let context = coreDataStack.viewContext
        for orphanedExercise in orphanedExercises {
            context.delete(orphanedExercise)
        }

        do {
            try context.save()
            return orphanedExercises.count
        } catch {
            throw WorkoutRepositoryError.saveContextFailed(error)
        }
    }

    // MARK: - Performance and Statistics

    public func getDatabaseStatistics() async throws -> [String: Any] {
        let context = coreDataStack.viewContext

        let sessionCount = try await countWorkoutSessions(filter: WorkoutQueryFilter())
        let completedSessionCount = try await countWorkoutSessions(filter: WorkoutQueryFilter(isCompleted: true))

        let exerciseSetRequest: NSFetchRequest<ExerciseSet> = ExerciseSet.fetchRequest()
        exerciseSetRequest.resultType = .countResultType
        let totalSets = try context.count(for: exerciseSetRequest)

        return [
            "totalSessions": sessionCount,
            "completedSessions": completedSessionCount,
            "totalSets": totalSets,
            "averageSetsPerSession": sessionCount > 0 ? Double(totalSets) / Double(sessionCount) : 0
        ]
    }

    public func optimizeStore() async throws {
        // This would involve Core Data optimization operations
        // For now, we'll just refresh the objects
        let context = coreDataStack.viewContext
        await context.perform {
            context.refreshAllObjects()
        }
    }

    public func estimateMemoryUsage() async -> Int64 {
        let context = coreDataStack.viewContext
        return await context.perform {
            let registeredObjects = context.registeredObjects
            return Int64(registeredObjects.count * 1024) // Rough estimate: 1KB per object
        }
    }

    public func refreshObjects(olderThan: Date) async {
        let context = coreDataStack.viewContext
        await context.perform {
            for object in context.registeredObjects {
                if let managedObject = object as? NSManagedObject,
                   let modifiedAt = managedObject.value(forKey: "modifiedAt") as? Date,
                   modifiedAt < olderThan {
                    context.refresh(managedObject, mergeChanges: false)
                }
            }
        }
    }
}