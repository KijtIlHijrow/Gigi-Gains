//
//  RoutineService.swift
//  Gigi Gains - Internal API Contract
//
//  Defines the interface for routine management including template operations,
//  routine creation from workout sessions, and reusable workout templates.
//
//  Created: 2025-09-28
//

import Foundation
import Combine
import CoreData

// MARK: - Supporting Types

/// Errors that can occur during routine operations
public enum RoutineServiceError: Error, LocalizedError {
    case routineNotFound(UUID)
    case exerciseNotFound(UUID)
    case duplicateRoutineName(String)
    case invalidRoutineData(reason: String)
    case routineInUse(sessionsCount: Int)
    case coreDataError(Error)
    case validationError(String)

    public var errorDescription: String? {
        switch self {
        case .routineNotFound(let id):
            return "Routine with ID \(id) not found"
        case .exerciseNotFound(let id):
            return "Exercise with ID \(id) not found in routine"
        case .duplicateRoutineName(let name):
            return "A routine with the name '\(name)' already exists"
        case .invalidRoutineData(let reason):
            return "Invalid routine data: \(reason)"
        case .routineInUse(let sessionsCount):
            return "Cannot delete routine: it is used by \(sessionsCount) workout session(s)"
        case .coreDataError(let error):
            return "Core Data error: \(error.localizedDescription)"
        case .validationError(let message):
            return "Validation error: \(message)"
        }
    }
}

/// Configuration for creating a new routine
public struct RoutineCreationConfig {
    public let name: String
    public let notes: String?
    public let estimatedDuration: TimeInterval?

    public init(name: String, notes: String? = nil, estimatedDuration: TimeInterval? = nil) {
        self.name = name
        self.notes = notes
        self.estimatedDuration = estimatedDuration
    }

    /// Validates the routine configuration
    public func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RoutineServiceError.validationError("Routine name cannot be empty")
        }
        if let duration = estimatedDuration, duration < 0 {
            throw RoutineServiceError.validationError("Estimated duration must be non-negative")
        }
    }
}

/// Data structure for adding an exercise to a routine template
public struct RoutineExerciseTemplate {
    public let exerciseId: UUID
    public let orderIndex: Int32?
    public let targetSets: Int32
    public let targetReps: [Int32]  // Array to support varied rep schemes like [5,5,5] or [10,8,6]
    public let targetWeight: Double?
    public let targetRPE: Double?
    public let restTime: TimeInterval
    public let superset: String?
    public let notes: String?

    public init(exerciseId: UUID, orderIndex: Int32? = nil, targetSets: Int32, targetReps: [Int32], targetWeight: Double? = nil, targetRPE: Double? = nil, restTime: TimeInterval = 120, superset: String? = nil, notes: String? = nil) {
        self.exerciseId = exerciseId
        self.orderIndex = orderIndex
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.targetRPE = targetRPE
        self.restTime = restTime
        self.superset = superset
        self.notes = notes
    }

    /// Validates the exercise template data
    public func validate() throws {
        guard targetSets > 0 else {
            throw RoutineServiceError.validationError("Target sets must be greater than 0")
        }
        guard !targetReps.isEmpty else {
            throw RoutineServiceError.validationError("Target reps array cannot be empty")
        }
        guard targetReps.allSatisfy({ $0 > 0 }) else {
            throw RoutineServiceError.validationError("All target reps must be greater than 0")
        }
        if let weight = targetWeight, weight < 0 {
            throw RoutineServiceError.validationError("Target weight must be non-negative")
        }
        if let rpe = targetRPE, !(1.0...10.0).contains(rpe) {
            throw RoutineServiceError.validationError("Target RPE must be between 1.0 and 10.0")
        }
        guard restTime >= 0 else {
            throw RoutineServiceError.validationError("Rest time must be non-negative")
        }
    }
}

/// Filter criteria for querying routines
public struct RoutineFilter {
    public let searchText: String?
    public let isArchived: Bool?
    public let lastUsedAfter: Date?
    public let lastUsedBefore: Date?
    public let containsExerciseId: UUID?
    public let estimatedDurationMin: TimeInterval?
    public let estimatedDurationMax: TimeInterval?

    public init(searchText: String? = nil, isArchived: Bool? = nil, lastUsedAfter: Date? = nil, lastUsedBefore: Date? = nil, containsExerciseId: UUID? = nil, estimatedDurationMin: TimeInterval? = nil, estimatedDurationMax: TimeInterval? = nil) {
        self.searchText = searchText
        self.isArchived = isArchived
        self.lastUsedAfter = lastUsedAfter
        self.lastUsedBefore = lastUsedBefore
        self.containsExerciseId = containsExerciseId
        self.estimatedDurationMin = estimatedDurationMin
        self.estimatedDurationMax = estimatedDurationMax
    }
}

/// Sort options for routine queries
public enum RoutineSortOption: CaseIterable {
    case nameAscending
    case nameDescending
    case lastUsedRecent
    case lastUsedOldest
    case useCountMost
    case useCountLeast
    case createdRecent
    case createdOldest
    case estimatedDurationShortest
    case estimatedDurationLongest

    public var description: String {
        switch self {
        case .nameAscending: return "Name (A-Z)"
        case .nameDescending: return "Name (Z-A)"
        case .lastUsedRecent: return "Recently Used"
        case .lastUsedOldest: return "Least Recently Used"
        case .useCountMost: return "Most Used"
        case .useCountLeast: return "Least Used"
        case .createdRecent: return "Recently Created"
        case .createdOldest: return "Oldest"
        case .estimatedDurationShortest: return "Shortest Duration"
        case .estimatedDurationLongest: return "Longest Duration"
        }
    }
}

/// Statistics for a routine showing usage patterns
public struct RoutineStatistics {
    /// Total number of times this routine has been used
    public let useCount: Int32

    /// Date when the routine was last used
    public let lastUsed: Date?

    /// Average duration of workouts created from this routine
    public let averageDuration: TimeInterval?

    /// Average total volume achieved when using this routine
    public let averageVolume: Double?

    /// Total number of exercises in the routine
    public let exerciseCount: Int

    /// Estimated duration based on rest times and target sets
    public let estimatedDuration: TimeInterval

    /// Most frequently achieved RPE when using this routine
    public let averageRPE: Double?

    /// Number of personal records achieved using this routine
    public let personalRecordsAchieved: Int

    public init(useCount: Int32, lastUsed: Date?, averageDuration: TimeInterval?, averageVolume: Double?, exerciseCount: Int, estimatedDuration: TimeInterval, averageRPE: Double?, personalRecordsAchieved: Int) {
        self.useCount = useCount
        self.lastUsed = lastUsed
        self.averageDuration = averageDuration
        self.averageVolume = averageVolume
        self.exerciseCount = exerciseCount
        self.estimatedDuration = estimatedDuration
        self.averageRPE = averageRPE
        self.personalRecordsAchieved = personalRecordsAchieved
    }
}

// MARK: - Main Protocol

/// Service protocol for managing workout routines and templates
///
/// This protocol defines the complete interface for routine management in the Gigi Gains app.
/// It supports creating, modifying, and using workout routine templates with real-time updates
/// via Combine publishers. All operations work offline-first with automatic CloudKit synchronization.
///
/// Key responsibilities:
/// - Routine template creation and management
/// - Exercise template configuration within routines
/// - Routine usage tracking and statistics
/// - Creating workout sessions from routine templates
/// - Routine discovery and search
/// - Routine archiving and organization
///
/// ## Usage Example:
/// ```swift
/// let service: RoutineService = RoutineServiceImpl()
///
/// // Create a new routine
/// let config = RoutineCreationConfig(name: "Push Day", estimatedDuration: 3600)
/// let routine = try await service.createRoutine(config: config)
///
/// // Add exercises to the routine
/// let template = RoutineExerciseTemplate(
///     exerciseId: benchPressId,
///     targetSets: 3,
///     targetReps: [8, 8, 8],
///     restTime: 180
/// )
/// try await service.addExerciseToRoutine(routineId: routine.id, template: template)
///
/// // Use the routine to create a workout session
/// let session = try await service.createWorkoutFromRoutine(routineId: routine.id)
/// ```
public protocol RoutineService: AnyObject {

    // MARK: - Publishers for Reactive Updates

    /// Publishes updates to all routines
    /// Emits the complete list of routines whenever any routine is modified
    var routinesUpdatePublisher: AnyPublisher<[Routine], Never> { get }

    /// Publishes updates to routine statistics
    /// Useful for updating routine list views with usage statistics
    var routineStatisticsUpdatePublisher: AnyPublisher<[UUID: RoutineStatistics], Never> { get }

    // MARK: - Routine Management

    /// Creates a new workout routine template
    /// - Parameter config: Configuration for the new routine
    /// - Returns: The created routine
    /// - Throws: `RoutineServiceError.duplicateRoutineName` if name already exists
    /// - Throws: `RoutineServiceError.validationError` if config is invalid
    /// - Throws: `RoutineServiceError.coreDataError` if creation fails
    func createRoutine(config: RoutineCreationConfig) async throws -> Routine

    /// Creates a routine from an existing workout session
    /// - Parameters:
    ///   - sessionId: The ID of the workout session to use as a template
    ///   - name: Name for the new routine
    ///   - notes: Optional notes for the routine
    /// - Returns: The created routine with exercises copied from the session
    /// - Throws: `RoutineServiceError.coreDataError` if session is not found or creation fails
    /// - Throws: `RoutineServiceError.duplicateRoutineName` if name already exists
    func createRoutineFromSession(sessionId: UUID, name: String, notes: String?) async throws -> Routine

    /// Retrieves a routine by ID
    /// - Parameter routineId: The unique identifier of the routine
    /// - Returns: The routine if found
    /// - Throws: `RoutineServiceError.routineNotFound` if routine doesn't exist
    func getRoutine(routineId: UUID) async throws -> Routine

    /// Retrieves all routines matching the filter criteria
    /// - Parameters:
    ///   - filter: Filter criteria for querying routines
    ///   - sortBy: Sort option for the results
    /// - Returns: Array of matching routines, sorted according to the specified option
    /// - Throws: `RoutineServiceError.coreDataError` if query fails
    func getRoutines(filter: RoutineFilter, sortBy: RoutineSortOption) async throws -> [Routine]

    /// Updates routine metadata
    /// - Parameters:
    ///   - routineId: The ID of the routine to update
    ///   - name: New name for the routine (optional)
    ///   - notes: New notes for the routine (optional)
    ///   - estimatedDuration: New estimated duration (optional)
    /// - Throws: `RoutineServiceError.routineNotFound` if routine doesn't exist
    /// - Throws: `RoutineServiceError.duplicateRoutineName` if new name conflicts
    /// - Throws: `RoutineServiceError.validationError` if new data is invalid
    func updateRoutine(routineId: UUID, name: String?, notes: String?, estimatedDuration: TimeInterval?) async throws

    /// Archives or unarchives a routine
    /// - Parameters:
    ///   - routineId: The ID of the routine to archive/unarchive
    ///   - isArchived: Whether the routine should be archived
    /// - Throws: `RoutineServiceError.routineNotFound` if routine doesn't exist
    func archiveRoutine(routineId: UUID, isArchived: Bool) async throws

    /// Deletes a routine and all associated template data
    /// - Parameter routineId: The ID of the routine to delete
    /// - Throws: `RoutineServiceError.routineNotFound` if routine doesn't exist
    /// - Throws: `RoutineServiceError.routineInUse` if routine is referenced by workout sessions
    /// - Note: This operation cascades to delete all routine exercises
    func deleteRoutine(routineId: UUID) async throws

    /// Duplicates an existing routine with a new name
    /// - Parameters:
    ///   - routineId: The ID of the routine to duplicate
    ///   - newName: Name for the duplicated routine
    /// - Returns: The newly created routine
    /// - Throws: `RoutineServiceError.routineNotFound` if source routine doesn't exist
    /// - Throws: `RoutineServiceError.duplicateRoutineName` if new name conflicts
    func duplicateRoutine(routineId: UUID, newName: String) async throws -> Routine

    // MARK: - Exercise Template Management

    /// Adds an exercise template to a routine
    /// - Parameters:
    ///   - routineId: The ID of the routine to add the exercise to
    ///   - template: The exercise template configuration
    /// - Returns: The created RoutineExercise instance
    /// - Throws: `RoutineServiceError.routineNotFound` if routine doesn't exist
    /// - Throws: `RoutineServiceError.validationError` if template data is invalid
    func addExerciseToRoutine(routineId: UUID, template: RoutineExerciseTemplate) async throws -> RoutineExercise

    /// Updates an exercise template within a routine
    /// - Parameters:
    ///   - routineId: The ID of the routine
    ///   - exerciseId: The ID of the RoutineExercise to update
    ///   - template: The updated exercise template configuration
    /// - Throws: `RoutineServiceError.routineNotFound` if routine doesn't exist
    /// - Throws: `RoutineServiceError.exerciseNotFound` if exercise doesn't exist in routine
    /// - Throws: `RoutineServiceError.validationError` if template data is invalid
    func updateExerciseInRoutine(routineId: UUID, exerciseId: UUID, template: RoutineExerciseTemplate) async throws

    /// Removes an exercise template from a routine
    /// - Parameters:
    ///   - routineId: The ID of the routine
    ///   - exerciseId: The ID of the RoutineExercise to remove
    /// - Throws: `RoutineServiceError.routineNotFound` if routine doesn't exist
    /// - Throws: `RoutineServiceError.exerciseNotFound` if exercise doesn't exist in routine
    func removeExerciseFromRoutine(routineId: UUID, exerciseId: UUID) async throws

    /// Reorders exercise templates within a routine
    /// - Parameters:
    ///   - routineId: The ID of the routine
    ///   - exerciseOrdering: Array of RoutineExercise IDs in the desired order
    /// - Throws: `RoutineServiceError.routineNotFound` if routine doesn't exist
    /// - Throws: `RoutineServiceError.exerciseNotFound` if any exercise ID is invalid
    func reorderExercisesInRoutine(routineId: UUID, exerciseOrdering: [UUID]) async throws

    // MARK: - Routine Usage

    /// Creates a new workout session from a routine template
    /// - Parameters:
    ///   - routineId: The ID of the routine to use as a template
    ///   - sessionName: Optional custom name for the workout session
    ///   - sessionNotes: Optional notes for the workout session
    /// - Returns: The created WorkoutSession with exercises pre-populated from the routine
    /// - Throws: `RoutineServiceError.routineNotFound` if routine doesn't exist
    /// - Note: This operation updates the routine's usage statistics
    func createWorkoutFromRoutine(routineId: UUID, sessionName: String?, sessionNotes: String?) async throws -> WorkoutSession

    /// Updates the last used date and increments use count for a routine
    /// - Parameter routineId: The ID of the routine that was used
    /// - Throws: `RoutineServiceError.routineNotFound` if routine doesn't exist
    /// - Note: This is typically called when a workout session based on this routine is completed
    func markRoutineAsUsed(routineId: UUID) async throws

    // MARK: - Routine Analytics and Statistics

    /// Gets detailed statistics for a specific routine
    /// - Parameter routineId: The ID of the routine
    /// - Returns: Detailed statistics about the routine's usage and performance
    /// - Throws: `RoutineServiceError.routineNotFound` if routine doesn't exist
    func getRoutineStatistics(routineId: UUID) async throws -> RoutineStatistics

    /// Gets usage statistics for all routines
    /// - Returns: Dictionary mapping routine IDs to their statistics
    func getAllRoutineStatistics() async throws -> [UUID: RoutineStatistics]

    /// Gets the most frequently used routines
    /// - Parameter limit: Maximum number of routines to return
    /// - Returns: Array of routines sorted by use count (most used first)
    func getMostUsedRoutines(limit: Int) async throws -> [Routine]

    /// Gets recently used routines
    /// - Parameter limit: Maximum number of routines to return
    /// - Returns: Array of routines sorted by last used date (most recent first)
    func getRecentlyUsedRoutines(limit: Int) async throws -> [Routine]

    /// Searches routines by name and content
    /// - Parameter searchText: Text to search for in routine names, notes, and exercise names
    /// - Returns: Array of matching routines sorted by relevance
    func searchRoutines(searchText: String) async throws -> [Routine]

    // MARK: - Routine Validation

    /// Validates that a routine is properly configured and ready to use
    /// - Parameter routineId: The ID of the routine to validate
    /// - Returns: Array of validation issues, empty if routine is valid
    /// - Throws: `RoutineServiceError.routineNotFound` if routine doesn't exist
    func validateRoutine(routineId: UUID) async throws -> [String]

    /// Estimates the duration of a workout session based on the routine template
    /// - Parameter routineId: The ID of the routine
    /// - Returns: Estimated duration in seconds based on rest times and target sets
    /// - Throws: `RoutineServiceError.routineNotFound` if routine doesn't exist
    func estimateRoutineDuration(routineId: UUID) async throws -> TimeInterval
}

// MARK: - Test Helper Protocol

/// Protocol for test implementations and mocking
/// Enables dependency injection and unit testing of components that depend on RoutineService
public protocol MockableRoutineService: RoutineService {
    /// Allows tests to inject mock routines
    func setMockRoutines(_ routines: [Routine])

    /// Allows tests to simulate errors
    func setMockError(_ error: RoutineServiceError?)

    /// Allows tests to control routine statistics
    func setMockStatistics(_ statistics: [UUID: RoutineStatistics])
}