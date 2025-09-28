//
//  WorkoutRepository.swift
//  Gigi Gains - Internal API Contract
//
//  Defines the interface for Core Data operations related to workout sessions,
//  including CRUD operations, querying, and relationship management.
//
//  Created: 2025-09-28
//

import Foundation
import Combine
import CoreData

// MARK: - Supporting Types

/// Errors that can occur during workout repository operations
public enum WorkoutRepositoryError: Error, LocalizedError {
    case objectNotFound(UUID)
    case saveContextFailed(Error)
    case fetchRequestFailed(Error)
    case batchUpdateFailed(Error)
    case batchDeleteFailed(Error)
    case relationshipConstraintViolation(String)
    case invalidObjectState(String)
    case contextMergeFailed(Error)
    case backgroundContextError(Error)

    public var errorDescription: String? {
        switch self {
        case .objectNotFound(let id):
            return "Object with ID \(id) not found"
        case .saveContextFailed(let error):
            return "Failed to save context: \(error.localizedDescription)"
        case .fetchRequestFailed(let error):
            return "Fetch request failed: \(error.localizedDescription)"
        case .batchUpdateFailed(let error):
            return "Batch update failed: \(error.localizedDescription)"
        case .batchDeleteFailed(let error):
            return "Batch delete failed: \(error.localizedDescription)"
        case .relationshipConstraintViolation(let details):
            return "Relationship constraint violation: \(details)"
        case .invalidObjectState(let details):
            return "Invalid object state: \(details)"
        case .contextMergeFailed(let error):
            return "Context merge failed: \(error.localizedDescription)"
        case .backgroundContextError(let error):
            return "Background context error: \(error.localizedDescription)"
        }
    }
}

/// Sort options for workout session queries
public enum WorkoutSortOption: String, CaseIterable {
    case startDateAscending = "startDate_asc"
    case startDateDescending = "startDate_desc"
    case durationAscending = "duration_asc"
    case durationDescending = "duration_desc"
    case totalVolumeAscending = "totalVolume_asc"
    case totalVolumeDescending = "totalVolume_desc"
    case nameAscending = "name_asc"
    case nameDescending = "name_desc"
    case createdAtAscending = "createdAt_asc"
    case createdAtDescending = "createdAt_desc"

    public var description: String {
        switch self {
        case .startDateAscending: return "Start Date (Oldest First)"
        case .startDateDescending: return "Start Date (Newest First)"
        case .durationAscending: return "Duration (Shortest First)"
        case .durationDescending: return "Duration (Longest First)"
        case .totalVolumeAscending: return "Volume (Lowest First)"
        case .totalVolumeDescending: return "Volume (Highest First)"
        case .nameAscending: return "Name (A-Z)"
        case .nameDescending: return "Name (Z-A)"
        case .createdAtAscending: return "Created (Oldest First)"
        case .createdAtDescending: return "Created (Newest First)"
        }
    }

    /// Core Data sort descriptors for this option
    public var sortDescriptors: [NSSortDescriptor] {
        switch self {
        case .startDateAscending:
            return [NSSortDescriptor(keyPath: \WorkoutSession.startDate, ascending: true)]
        case .startDateDescending:
            return [NSSortDescriptor(keyPath: \WorkoutSession.startDate, ascending: false)]
        case .durationAscending:
            return [NSSortDescriptor(keyPath: \WorkoutSession.duration, ascending: true)]
        case .durationDescending:
            return [NSSortDescriptor(keyPath: \WorkoutSession.duration, ascending: false)]
        case .totalVolumeAscending:
            return [NSSortDescriptor(keyPath: \WorkoutSession.totalVolume, ascending: true)]
        case .totalVolumeDescending:
            return [NSSortDescriptor(keyPath: \WorkoutSession.totalVolume, ascending: false)]
        case .nameAscending:
            return [NSSortDescriptor(keyPath: \WorkoutSession.name, ascending: true)]
        case .nameDescending:
            return [NSSortDescriptor(keyPath: \WorkoutSession.name, ascending: false)]
        case .createdAtAscending:
            return [NSSortDescriptor(keyPath: \WorkoutSession.createdAt, ascending: true)]
        case .createdAtDescending:
            return [NSSortDescriptor(keyPath: \WorkoutSession.createdAt, ascending: false)]
        }
    }
}

/// Filter criteria for workout session queries
public struct WorkoutQueryFilter {
    public let startDateFrom: Date?
    public let startDateTo: Date?
    public let isCompleted: Bool?
    public let routineId: UUID?
    public let exerciseId: UUID?
    public let nameContains: String?
    public let notesContain: String?
    public let minimumDuration: TimeInterval?
    public let maximumDuration: TimeInterval?
    public let minimumVolume: Double?
    public let maximumVolume: Double?
    public let minimumSets: Int?
    public let maximumSets: Int?

    public init(startDateFrom: Date? = nil, startDateTo: Date? = nil, isCompleted: Bool? = nil, routineId: UUID? = nil, exerciseId: UUID? = nil, nameContains: String? = nil, notesContain: String? = nil, minimumDuration: TimeInterval? = nil, maximumDuration: TimeInterval? = nil, minimumVolume: Double? = nil, maximumVolume: Double? = nil, minimumSets: Int? = nil, maximumSets: Int? = nil) {
        self.startDateFrom = startDateFrom
        self.startDateTo = startDateTo
        self.isCompleted = isCompleted
        self.routineId = routineId
        self.exerciseId = exerciseId
        self.nameContains = nameContains
        self.notesContain = notesContain
        self.minimumDuration = minimumDuration
        self.maximumDuration = maximumDuration
        self.minimumVolume = minimumVolume
        self.maximumVolume = maximumVolume
        self.minimumSets = minimumSets
        self.maximumSets = maximumSets
    }

    /// Converts filter to NSPredicate for Core Data queries
    public var predicate: NSPredicate? {
        var predicates: [NSPredicate] = []

        if let startDateFrom = startDateFrom {
            predicates.append(NSPredicate(format: "startDate >= %@", startDateFrom as NSDate))
        }

        if let startDateTo = startDateTo {
            predicates.append(NSPredicate(format: "startDate <= %@", startDateTo as NSDate))
        }

        if let isCompleted = isCompleted {
            predicates.append(NSPredicate(format: "isCompleted == %@", NSNumber(value: isCompleted)))
        }

        if let routineId = routineId {
            predicates.append(NSPredicate(format: "routine.id == %@", routineId as NSUUID))
        }

        if let exerciseId = exerciseId {
            predicates.append(NSPredicate(format: "ANY exercises.exercise.id == %@", exerciseId as NSUUID))
        }

        if let nameContains = nameContains, !nameContains.isEmpty {
            predicates.append(NSPredicate(format: "name CONTAINS[cd] %@", nameContains))
        }

        if let notesContain = notesContain, !notesContain.isEmpty {
            predicates.append(NSPredicate(format: "notes CONTAINS[cd] %@", notesContain))
        }

        if let minimumDuration = minimumDuration {
            predicates.append(NSPredicate(format: "duration >= %f", minimumDuration))
        }

        if let maximumDuration = maximumDuration {
            predicates.append(NSPredicate(format: "duration <= %f", maximumDuration))
        }

        if let minimumVolume = minimumVolume {
            predicates.append(NSPredicate(format: "totalVolume >= %f", minimumVolume))
        }

        if let maximumVolume = maximumVolume {
            predicates.append(NSPredicate(format: "totalVolume <= %f", maximumVolume))
        }

        if let minimumSets = minimumSets {
            predicates.append(NSPredicate(format: "exercises.@sum.sets.@count >= %d", minimumSets))
        }

        if let maximumSets = maximumSets {
            predicates.append(NSPredicate(format: "exercises.@sum.sets.@count <= %d", maximumSets))
        }

        return predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}

/// Configuration for batch operations
public struct BatchOperationConfig {
    public let batchSize: Int
    public let includeSubentities: Bool
    public let resultType: NSBatchUpdateRequestResultType

    public init(batchSize: Int = 100, includeSubentities: Bool = true, resultType: NSBatchUpdateRequestResultType = .statusOnlyResultType) {
        self.batchSize = batchSize
        self.includeSubentities = includeSubentities
        self.resultType = resultType
    }
}

/// Options for fetch requests
public struct FetchOptions {
    public let limit: Int?
    public let offset: Int?
    public let prefetchRelationships: [String]
    public let returnsObjectsAsFaults: Bool
    public let refreshesRefetchedObjects: Bool

    public init(limit: Int? = nil, offset: Int? = nil, prefetchRelationships: [String] = [], returnsObjectsAsFaults: Bool = false, refreshesRefetchedObjects: Bool = false) {
        self.limit = limit
        self.offset = offset
        self.prefetchRelationships = prefetchRelationships
        self.returnsObjectsAsFaults = returnsObjectsAsFaults
        self.refreshesRefetchedObjects = refreshesRefetchedObjects
    }
}

// MARK: - Main Protocol

/// Repository protocol for Core Data operations on workout-related entities
///
/// This protocol defines the data access layer for workout sessions and their related entities
/// in the Gigi Gains app. It provides a clean abstraction over Core Data operations, including
/// CRUD operations, complex queries, batch operations, and relationship management. All operations
/// are designed to work efficiently with CloudKit synchronization.
///
/// Key responsibilities:
/// - Workout session CRUD operations
/// - Complex querying with filtering and sorting
/// - Batch operations for performance
/// - Relationship management between workout entities
/// - Background context operations
/// - Data validation and integrity checks
/// - Performance optimization for large datasets
///
/// ## Usage Example:
/// ```swift
/// let repository: WorkoutRepository = WorkoutRepositoryImpl()
///
/// // Create a new workout session
/// let session = try await repository.createWorkoutSession(
///     name: "Push Day",
///     routineId: routineId
/// )
///
/// // Query workout sessions with filtering
/// let filter = WorkoutQueryFilter(
///     startDateFrom: Calendar.current.date(byAdding: .day, value: -30, to: Date()),
///     isCompleted: true
/// )
/// let recentWorkouts = try await repository.fetchWorkoutSessions(
///     filter: filter,
///     sortBy: .startDateDescending,
///     options: FetchOptions(limit: 10)
/// )
/// ```
public protocol WorkoutRepository: AnyObject {

    // MARK: - Publishers for Reactive Updates

    /// Publishes changes to workout sessions
    /// Emits when workout sessions are created, updated, or deleted
    var workoutSessionsChangedPublisher: AnyPublisher<Void, Never> { get }

    /// Publishes changes to workout exercises
    /// Emits when exercises are added, removed, or modified within sessions
    var workoutExercisesChangedPublisher: AnyPublisher<Void, Never> { get }

    /// Publishes changes to exercise sets
    /// Emits when sets are added, updated, or removed
    var exerciseSetsChangedPublisher: AnyPublisher<Void, Never> { get }

    // MARK: - Workout Session Operations

    /// Creates a new workout session
    /// - Parameters:
    ///   - name: Optional name for the workout session
    ///   - routineId: Optional ID of the routine this session is based on
    ///   - startDate: Start date/time for the session (defaults to now)
    ///   - notes: Optional notes for the session
    /// - Returns: The created WorkoutSession object
    /// - Throws: `WorkoutRepositoryError.saveContextFailed` if save fails
    func createWorkoutSession(name: String?, routineId: UUID?, startDate: Date, notes: String?) async throws -> WorkoutSession

    /// Fetches a workout session by ID
    /// - Parameter id: The unique identifier of the workout session
    /// - Returns: The WorkoutSession object if found
    /// - Throws: `WorkoutRepositoryError.objectNotFound` if session doesn't exist
    /// - Throws: `WorkoutRepositoryError.fetchRequestFailed` if fetch fails
    func fetchWorkoutSession(id: UUID) async throws -> WorkoutSession

    /// Fetches workout sessions with filtering and sorting
    /// - Parameters:
    ///   - filter: Filter criteria for the query
    ///   - sortBy: Sort option for the results
    ///   - options: Fetch options including limits and prefetching
    /// - Returns: Array of WorkoutSession objects matching the criteria
    /// - Throws: `WorkoutRepositoryError.fetchRequestFailed` if query fails
    func fetchWorkoutSessions(filter: WorkoutQueryFilter, sortBy: WorkoutSortOption, options: FetchOptions) async throws -> [WorkoutSession]

    /// Fetches all workout sessions (use with caution for large datasets)
    /// - Returns: Array of all WorkoutSession objects
    /// - Throws: `WorkoutRepositoryError.fetchRequestFailed` if query fails
    func fetchAllWorkoutSessions() async throws -> [WorkoutSession]

    /// Updates an existing workout session
    /// - Parameters:
    ///   - session: The WorkoutSession object to update
    ///   - name: New name for the session (nil to keep current)
    ///   - notes: New notes for the session (nil to keep current)
    ///   - endDate: End date for the session (nil to keep current)
    ///   - isCompleted: Whether the session is completed (nil to keep current)
    /// - Throws: `WorkoutRepositoryError.saveContextFailed` if save fails
    func updateWorkoutSession(_ session: WorkoutSession, name: String?, notes: String?, endDate: Date?, isCompleted: Bool?) async throws

    /// Deletes a workout session and all related data
    /// - Parameter session: The WorkoutSession object to delete
    /// - Throws: `WorkoutRepositoryError.saveContextFailed` if deletion fails
    /// - Note: This cascades to delete all related exercises and sets
    func deleteWorkoutSession(_ session: WorkoutSession) async throws

    /// Deletes workout sessions by ID in batch
    /// - Parameters:
    ///   - sessionIds: Array of session IDs to delete
    ///   - config: Batch operation configuration
    /// - Returns: Number of sessions successfully deleted
    /// - Throws: `WorkoutRepositoryError.batchDeleteFailed` if batch operation fails
    func deleteWorkoutSessions(ids sessionIds: [UUID], config: BatchOperationConfig) async throws -> Int

    /// Marks a workout session as completed
    /// - Parameters:
    ///   - session: The WorkoutSession to complete
    ///   - endDate: End date/time for the session (defaults to now)
    /// - Throws: `WorkoutRepositoryError.saveContextFailed` if save fails
    func completeWorkoutSession(_ session: WorkoutSession, endDate: Date) async throws

    // MARK: - Workout Exercise Operations

    /// Adds an exercise to a workout session
    /// - Parameters:
    ///   - session: The WorkoutSession to add the exercise to
    ///   - exerciseId: ID of the Exercise from the library
    ///   - orderIndex: Position of the exercise in the workout
    ///   - restTimerDuration: Rest time for this exercise
    ///   - superset: Optional superset identifier
    ///   - notes: Optional notes for this exercise in the session
    /// - Returns: The created WorkoutExercise object
    /// - Throws: `WorkoutRepositoryError.saveContextFailed` if save fails
    /// - Throws: `WorkoutRepositoryError.relationshipConstraintViolation` if exercise doesn't exist
    func addExerciseToWorkoutSession(_ session: WorkoutSession, exerciseId: UUID, orderIndex: Int32, restTimerDuration: Double?, superset: String?, notes: String?) async throws -> WorkoutExercise

    /// Removes an exercise from a workout session
    /// - Parameters:
    ///   - session: The WorkoutSession to remove the exercise from
    ///   - workoutExercise: The WorkoutExercise to remove
    /// - Throws: `WorkoutRepositoryError.saveContextFailed` if save fails
    func removeExerciseFromWorkoutSession(_ session: WorkoutSession, workoutExercise: WorkoutExercise) async throws

    /// Updates a workout exercise
    /// - Parameters:
    ///   - workoutExercise: The WorkoutExercise to update
    ///   - orderIndex: New order index (nil to keep current)
    ///   - restTimerDuration: New rest timer duration (nil to keep current)
    ///   - superset: New superset identifier (nil to keep current)
    ///   - notes: New notes (nil to keep current)
    ///   - isCompleted: Whether the exercise is completed (nil to keep current)
    /// - Throws: `WorkoutRepositoryError.saveContextFailed` if save fails
    func updateWorkoutExercise(_ workoutExercise: WorkoutExercise, orderIndex: Int32?, restTimerDuration: Double?, superset: String?, notes: String?, isCompleted: Bool?) async throws

    /// Reorders exercises within a workout session
    /// - Parameters:
    ///   - session: The WorkoutSession containing the exercises
    ///   - exerciseOrdering: Array of WorkoutExercise IDs in the desired order
    /// - Throws: `WorkoutRepositoryError.saveContextFailed` if save fails
    func reorderExercisesInWorkoutSession(_ session: WorkoutSession, exerciseOrdering: [UUID]) async throws

    // MARK: - Exercise Set Operations

    /// Adds a set to a workout exercise
    /// - Parameters:
    ///   - workoutExercise: The WorkoutExercise to add the set to
    ///   - setNumber: Position of the set within the exercise
    ///   - weight: Weight used for the set
    ///   - reps: Number of repetitions performed
    ///   - rpe: Rate of Perceived Exertion (1-10)
    ///   - notes: Optional notes for the set
    ///   - isCompleted: Whether the set was completed
    /// - Returns: The created ExerciseSet object
    /// - Throws: `WorkoutRepositoryError.saveContextFailed` if save fails
    func addSetToWorkoutExercise(_ workoutExercise: WorkoutExercise, setNumber: Int32, weight: Double, reps: Int32, rpe: Double, notes: String?, isCompleted: Bool) async throws -> ExerciseSet

    /// Updates an exercise set
    /// - Parameters:
    ///   - exerciseSet: The ExerciseSet to update
    ///   - weight: New weight (nil to keep current)
    ///   - reps: New rep count (nil to keep current)
    ///   - rpe: New RPE (nil to keep current)
    ///   - notes: New notes (nil to keep current)
    ///   - isCompleted: Whether the set is completed (nil to keep current)
    /// - Throws: `WorkoutRepositoryError.saveContextFailed` if save fails
    func updateExerciseSet(_ exerciseSet: ExerciseSet, weight: Double?, reps: Int32?, rpe: Double?, notes: String?, isCompleted: Bool?) async throws

    /// Removes a set from a workout exercise
    /// - Parameters:
    ///   - workoutExercise: The WorkoutExercise containing the set
    ///   - exerciseSet: The ExerciseSet to remove
    /// - Throws: `WorkoutRepositoryError.saveContextFailed` if save fails
    func removeSetFromWorkoutExercise(_ workoutExercise: WorkoutExercise, exerciseSet: ExerciseSet) async throws

    /// Duplicates the last set of a workout exercise
    /// - Parameter workoutExercise: The WorkoutExercise to duplicate the last set from
    /// - Returns: The duplicated ExerciseSet object, or nil if no sets exist
    /// - Throws: `WorkoutRepositoryError.saveContextFailed` if save fails
    func duplicateLastSet(_ workoutExercise: WorkoutExercise) async throws -> ExerciseSet?

    // MARK: - Advanced Queries

    /// Fetches workout sessions containing a specific exercise
    /// - Parameters:
    ///   - exerciseId: ID of the exercise to search for
    ///   - limit: Maximum number of sessions to return
    ///   - sortBy: Sort option for the results
    /// - Returns: Array of WorkoutSession objects containing the exercise
    /// - Throws: `WorkoutRepositoryError.fetchRequestFailed` if query fails
    func fetchWorkoutSessionsContainingExercise(exerciseId: UUID, limit: Int?, sortBy: WorkoutSortOption) async throws -> [WorkoutSession]

    /// Fetches workout sessions from a specific routine
    /// - Parameters:
    ///   - routineId: ID of the routine
    ///   - limit: Maximum number of sessions to return
    ///   - sortBy: Sort option for the results
    /// - Returns: Array of WorkoutSession objects based on the routine
    /// - Throws: `WorkoutRepositoryError.fetchRequestFailed` if query fails
    func fetchWorkoutSessionsFromRoutine(routineId: UUID, limit: Int?, sortBy: WorkoutSortOption) async throws -> [WorkoutSession]

    /// Fetches incomplete workout sessions
    /// - Returns: Array of WorkoutSession objects that are not completed
    /// - Throws: `WorkoutRepositoryError.fetchRequestFailed` if query fails
    func fetchIncompleteWorkoutSessions() async throws -> [WorkoutSession]

    /// Fetches recent workout sessions
    /// - Parameters:
    ///   - days: Number of days to look back
    ///   - limit: Maximum number of sessions to return
    /// - Returns: Array of recent WorkoutSession objects
    /// - Throws: `WorkoutRepositoryError.fetchRequestFailed` if query fails
    func fetchRecentWorkoutSessions(days: Int, limit: Int?) async throws -> [WorkoutSession]

    /// Counts workout sessions matching filter criteria
    /// - Parameter filter: Filter criteria for the count
    /// - Returns: Number of workout sessions matching the filter
    /// - Throws: `WorkoutRepositoryError.fetchRequestFailed` if query fails
    func countWorkoutSessions(filter: WorkoutQueryFilter) async throws -> Int

    /// Fetches sets for a specific exercise across all workout sessions
    /// - Parameters:
    ///   - exerciseId: ID of the exercise
    ///   - dateRange: Optional date range to filter by
    ///   - limit: Maximum number of sets to return
    /// - Returns: Array of ExerciseSet objects for the exercise
    /// - Throws: `WorkoutRepositoryError.fetchRequestFailed` if query fails
    func fetchSetsForExercise(exerciseId: UUID, dateRange: (start: Date, end: Date)?, limit: Int?) async throws -> [ExerciseSet]

    // MARK: - Background Operations

    /// Performs operations in a background context
    /// - Parameter operation: Closure containing operations to perform
    /// - Throws: `WorkoutRepositoryError.backgroundContextError` if operation fails
    func performBackgroundOperation(_ operation: @escaping (NSManagedObjectContext) throws -> Void) async throws

    /// Saves changes in a background context
    /// - Parameter context: The background context to save
    /// - Throws: `WorkoutRepositoryError.saveContextFailed` if save fails
    func saveBackgroundContext(_ context: NSManagedObjectContext) async throws

    /// Merges changes from background context to view context
    /// - Parameter notification: Core Data context save notification
    /// - Throws: `WorkoutRepositoryError.contextMergeFailed` if merge fails
    func mergeChangesFromContextDidSave(notification: Notification) async throws

    // MARK: - Data Validation and Integrity

    /// Validates a workout session object
    /// - Parameter session: The WorkoutSession to validate
    /// - Returns: Array of validation errors, empty if valid
    func validateWorkoutSession(_ session: WorkoutSession) async -> [String]

    /// Validates an exercise set object
    /// - Parameter exerciseSet: The ExerciseSet to validate
    /// - Returns: Array of validation errors, empty if valid
    func validateExerciseSet(_ exerciseSet: ExerciseSet) async -> [String]

    /// Checks for orphaned workout exercises (exercises with invalid exercise references)
    /// - Returns: Array of WorkoutExercise objects that have invalid references
    func findOrphanedWorkoutExercises() async throws -> [WorkoutExercise]

    /// Cleans up orphaned data and fixes relationships
    /// - Returns: Number of orphaned objects that were cleaned up
    /// - Throws: `WorkoutRepositoryError.saveContextFailed` if cleanup fails
    func cleanupOrphanedData() async throws -> Int

    // MARK: - Performance and Statistics

    /// Gets database statistics for workout data
    /// - Returns: Dictionary containing various database statistics
    func getDatabaseStatistics() async throws -> [String: Any]

    /// Optimizes the Core Data store
    /// - Note: This may take some time for large datasets
    func optimizeStore() async throws

    /// Estimates memory usage of loaded workout objects
    /// - Returns: Estimated memory usage in bytes
    func estimateMemoryUsage() async -> Int64

    /// Refreshes objects to free memory
    /// - Parameter olderThan: Refresh objects not accessed since this date
    func refreshObjects(olderThan: Date) async
}

// MARK: - Test Helper Protocol

/// Protocol for test implementations and mocking
/// Enables dependency injection and unit testing of components that depend on WorkoutRepository
public protocol MockableWorkoutRepository: WorkoutRepository {
    /// Allows tests to inject mock workout sessions
    func setMockWorkoutSessions(_ sessions: [WorkoutSession])

    /// Allows tests to simulate errors
    func setMockError(_ error: WorkoutRepositoryError?)

    /// Allows tests to control save operations
    func setShouldFailSave(_ shouldFail: Bool)

    /// Allows tests to control fetch operations
    func setShouldFailFetch(_ shouldFail: Bool)

    /// Allows tests to verify method calls
    var lastFetchFilter: WorkoutQueryFilter? { get }
    var lastSortOption: WorkoutSortOption? { get }
    var saveCallCount: Int { get }
}