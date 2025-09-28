//
//  WorkoutService.swift
//  Gigi Gains - Internal API Contract
//
//  Defines the interface for workout session management including CRUD operations,
//  real-time session tracking, and exercise management within workout sessions.
//
//  Created: 2025-09-28
//

import Foundation
import Combine
import CoreData

// MARK: - Supporting Types

/// Represents the current state of a workout session
public enum WorkoutSessionState: String, CaseIterable {
    case draft      // Created but not started
    case inProgress // Started but not completed
    case completed  // Finished and saved
    case paused     // Temporarily paused
}

/// Errors that can occur during workout operations
public enum WorkoutServiceError: Error, LocalizedError {
    case sessionNotFound(UUID)
    case invalidSessionState(current: WorkoutSessionState, required: WorkoutSessionState)
    case exerciseNotFound(UUID)
    case setNotFound(UUID)
    case invalidSetData(reason: String)
    case concurrentModification
    case coreDataError(Error)
    case validationError(String)

    public var errorDescription: String? {
        switch self {
        case .sessionNotFound(let id):
            return "Workout session with ID \(id) not found"
        case .invalidSessionState(let current, let required):
            return "Invalid session state: \(current), required: \(required)"
        case .exerciseNotFound(let id):
            return "Exercise with ID \(id) not found in session"
        case .setNotFound(let id):
            return "Set with ID \(id) not found"
        case .invalidSetData(let reason):
            return "Invalid set data: \(reason)"
        case .concurrentModification:
            return "Session was modified by another process"
        case .coreDataError(let error):
            return "Core Data error: \(error.localizedDescription)"
        case .validationError(let message):
            return "Validation error: \(message)"
        }
    }
}

/// Configuration for creating a new workout session
public struct WorkoutSessionConfig {
    public let name: String?
    public let routineId: UUID?
    public let notes: String?
    public let startDate: Date

    public init(name: String? = nil, routineId: UUID? = nil, notes: String? = nil, startDate: Date = Date()) {
        self.name = name
        self.routineId = routineId
        self.notes = notes
        self.startDate = startDate
    }
}

/// Data structure for adding an exercise to a workout session
public struct AddExerciseRequest {
    public let exerciseId: UUID
    public let orderIndex: Int32?
    public let restTimerDuration: TimeInterval?
    public let superset: String?
    public let notes: String?

    public init(exerciseId: UUID, orderIndex: Int32? = nil, restTimerDuration: TimeInterval? = nil, superset: String? = nil, notes: String? = nil) {
        self.exerciseId = exerciseId
        self.orderIndex = orderIndex
        self.restTimerDuration = restTimerDuration
        self.superset = superset
        self.notes = notes
    }
}

/// Data structure for adding or updating a set within an exercise
public struct SetData {
    public let weight: Double
    public let reps: Int32
    public let rpe: Double
    public let notes: String?
    public let isCompleted: Bool

    public init(weight: Double, reps: Int32, rpe: Double, notes: String? = nil, isCompleted: Bool = true) {
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.notes = notes
        self.isCompleted = isCompleted
    }

    /// Validates the set data according to business rules
    public func validate() throws {
        guard weight >= 0 else {
            throw WorkoutServiceError.validationError("Weight must be non-negative")
        }
        guard reps >= 0 && reps <= 1000 else {
            throw WorkoutServiceError.validationError("Reps must be between 0 and 1000")
        }
        guard rpe >= 1.0 && rpe <= 10.0 else {
            throw WorkoutServiceError.validationError("RPE must be between 1.0 and 10.0")
        }
    }
}

/// Filter criteria for querying workout sessions
public struct WorkoutSessionFilter {
    public let startDate: Date?
    public let endDate: Date?
    public let state: WorkoutSessionState?
    public let exerciseId: UUID?
    public let routineId: UUID?
    public let isCompleted: Bool?

    public init(startDate: Date? = nil, endDate: Date? = nil, state: WorkoutSessionState? = nil, exerciseId: UUID? = nil, routineId: UUID? = nil, isCompleted: Bool? = nil) {
        self.startDate = startDate
        self.endDate = endDate
        self.state = state
        self.exerciseId = exerciseId
        self.routineId = routineId
        self.isCompleted = isCompleted
    }
}

// MARK: - Main Protocol

/// Service protocol for managing workout sessions, exercises, and sets
///
/// This protocol defines the complete interface for workout session management in the Gigi Gains app.
/// It supports creating, modifying, and tracking workout sessions with real-time updates via Combine publishers.
/// All operations are designed to work offline-first with automatic CloudKit synchronization.
///
/// Key responsibilities:
/// - Workout session lifecycle management (create, start, pause, complete)
/// - Exercise management within sessions (add, remove, reorder)
/// - Set tracking with real-time updates
/// - Progress calculation and statistics
/// - Data validation and error handling
/// - Reactive updates via Combine publishers
///
/// ## Usage Example:
/// ```swift
/// let service: WorkoutService = WorkoutServiceImpl()
///
/// // Create and start a new workout session
/// let config = WorkoutSessionConfig(name: "Push Day")
/// let session = try await service.createSession(config: config)
/// try await service.startSession(sessionId: session.id)
///
/// // Add exercises and log sets
/// let request = AddExerciseRequest(exerciseId: benchPressId)
/// let workoutExercise = try await service.addExercise(sessionId: session.id, request: request)
///
/// let setData = SetData(weight: 100.0, reps: 8, rpe: 7.5)
/// try await service.addSet(sessionId: session.id, exerciseId: workoutExercise.id, setData: setData)
///
/// // Complete the session
/// try await service.completeSession(sessionId: session.id)
/// ```
public protocol WorkoutService: AnyObject {

    // MARK: - Publishers for Reactive Updates

    /// Publishes updates to the current active workout session
    /// Emits nil when no session is active, or the session data when active
    var currentSessionPublisher: AnyPublisher<WorkoutSession?, Never> { get }

    /// Publishes real-time updates to all workout sessions
    /// Useful for updating history views and session lists
    var sessionsUpdatePublisher: AnyPublisher<[WorkoutSession], Never> { get }

    /// Publishes the current session state changes
    /// Useful for updating UI based on session state transitions
    var sessionStatePublisher: AnyPublisher<WorkoutSessionState?, Never> { get }

    // MARK: - Session Management

    /// Creates a new workout session
    /// - Parameter config: Configuration for the new session
    /// - Returns: The created workout session
    /// - Throws: `WorkoutServiceError.coreDataError` if creation fails
    /// - Throws: `WorkoutServiceError.validationError` if config is invalid
    func createSession(config: WorkoutSessionConfig) async throws -> WorkoutSession

    /// Retrieves a workout session by ID
    /// - Parameter sessionId: The unique identifier of the session
    /// - Returns: The workout session if found
    /// - Throws: `WorkoutServiceError.sessionNotFound` if session doesn't exist
    func getSession(sessionId: UUID) async throws -> WorkoutSession

    /// Retrieves all workout sessions matching the filter criteria
    /// - Parameter filter: Filter criteria for querying sessions
    /// - Returns: Array of matching workout sessions, sorted by start date (most recent first)
    /// - Throws: `WorkoutServiceError.coreDataError` if query fails
    func getSessions(filter: WorkoutSessionFilter) async throws -> [WorkoutSession]

    /// Starts an existing workout session
    /// - Parameter sessionId: The ID of the session to start
    /// - Throws: `WorkoutServiceError.sessionNotFound` if session doesn't exist
    /// - Throws: `WorkoutServiceError.invalidSessionState` if session is not in draft state
    func startSession(sessionId: UUID) async throws

    /// Pauses the current active workout session
    /// - Parameter sessionId: The ID of the session to pause
    /// - Throws: `WorkoutServiceError.sessionNotFound` if session doesn't exist
    /// - Throws: `WorkoutServiceError.invalidSessionState` if session is not in progress
    func pauseSession(sessionId: UUID) async throws

    /// Resumes a paused workout session
    /// - Parameter sessionId: The ID of the session to resume
    /// - Throws: `WorkoutServiceError.sessionNotFound` if session doesn't exist
    /// - Throws: `WorkoutServiceError.invalidSessionState` if session is not paused
    func resumeSession(sessionId: UUID) async throws

    /// Completes a workout session and calculates final statistics
    /// - Parameter sessionId: The ID of the session to complete
    /// - Throws: `WorkoutServiceError.sessionNotFound` if session doesn't exist
    /// - Throws: `WorkoutServiceError.invalidSessionState` if session is not in progress or paused
    func completeSession(sessionId: UUID) async throws

    /// Updates the metadata of a workout session
    /// - Parameters:
    ///   - sessionId: The ID of the session to update
    ///   - name: New name for the session (optional)
    ///   - notes: New notes for the session (optional)
    /// - Throws: `WorkoutServiceError.sessionNotFound` if session doesn't exist
    /// - Throws: `WorkoutServiceError.invalidSessionState` if session is completed
    func updateSession(sessionId: UUID, name: String?, notes: String?) async throws

    /// Deletes a workout session and all associated data
    /// - Parameter sessionId: The ID of the session to delete
    /// - Throws: `WorkoutServiceError.sessionNotFound` if session doesn't exist
    /// - Note: This operation cascades to delete all exercises and sets
    func deleteSession(sessionId: UUID) async throws

    // MARK: - Exercise Management Within Sessions

    /// Adds an exercise to a workout session
    /// - Parameters:
    ///   - sessionId: The ID of the session to add the exercise to
    ///   - request: Details of the exercise to add
    /// - Returns: The created WorkoutExercise instance
    /// - Throws: `WorkoutServiceError.sessionNotFound` if session doesn't exist
    /// - Throws: `WorkoutServiceError.invalidSessionState` if session is completed
    func addExercise(sessionId: UUID, request: AddExerciseRequest) async throws -> WorkoutExercise

    /// Removes an exercise from a workout session
    /// - Parameters:
    ///   - sessionId: The ID of the session
    ///   - exerciseId: The ID of the WorkoutExercise to remove
    /// - Throws: `WorkoutServiceError.sessionNotFound` if session doesn't exist
    /// - Throws: `WorkoutServiceError.exerciseNotFound` if exercise doesn't exist in session
    /// - Throws: `WorkoutServiceError.invalidSessionState` if session is completed
    func removeExercise(sessionId: UUID, exerciseId: UUID) async throws

    /// Reorders exercises within a workout session
    /// - Parameters:
    ///   - sessionId: The ID of the session
    ///   - exerciseOrdering: Array of exercise IDs in the desired order
    /// - Throws: `WorkoutServiceError.sessionNotFound` if session doesn't exist
    /// - Throws: `WorkoutServiceError.exerciseNotFound` if any exercise ID is invalid
    /// - Throws: `WorkoutServiceError.invalidSessionState` if session is completed
    func reorderExercises(sessionId: UUID, exerciseOrdering: [UUID]) async throws

    /// Updates exercise-specific settings within a session
    /// - Parameters:
    ///   - sessionId: The ID of the session
    ///   - exerciseId: The ID of the WorkoutExercise to update
    ///   - restTimerDuration: New rest timer duration (optional)
    ///   - superset: New superset identifier (optional)
    ///   - notes: New notes (optional)
    /// - Throws: `WorkoutServiceError.sessionNotFound` if session doesn't exist
    /// - Throws: `WorkoutServiceError.exerciseNotFound` if exercise doesn't exist in session
    func updateExercise(sessionId: UUID, exerciseId: UUID, restTimerDuration: TimeInterval?, superset: String?, notes: String?) async throws

    // MARK: - Set Management

    /// Adds a new set to an exercise within a workout session
    /// - Parameters:
    ///   - sessionId: The ID of the session
    ///   - exerciseId: The ID of the WorkoutExercise
    ///   - setData: The data for the new set
    /// - Returns: The created ExerciseSet instance
    /// - Throws: `WorkoutServiceError.sessionNotFound` if session doesn't exist
    /// - Throws: `WorkoutServiceError.exerciseNotFound` if exercise doesn't exist in session
    /// - Throws: `WorkoutServiceError.validationError` if set data is invalid
    /// - Throws: `WorkoutServiceError.invalidSessionState` if session is completed
    func addSet(sessionId: UUID, exerciseId: UUID, setData: SetData) async throws -> ExerciseSet

    /// Updates an existing set
    /// - Parameters:
    ///   - sessionId: The ID of the session
    ///   - exerciseId: The ID of the WorkoutExercise
    ///   - setId: The ID of the set to update
    ///   - setData: The new data for the set
    /// - Throws: `WorkoutServiceError.sessionNotFound` if session doesn't exist
    /// - Throws: `WorkoutServiceError.exerciseNotFound` if exercise doesn't exist in session
    /// - Throws: `WorkoutServiceError.setNotFound` if set doesn't exist
    /// - Throws: `WorkoutServiceError.validationError` if set data is invalid
    /// - Throws: `WorkoutServiceError.invalidSessionState` if session is completed
    func updateSet(sessionId: UUID, exerciseId: UUID, setId: UUID, setData: SetData) async throws

    /// Removes a set from an exercise
    /// - Parameters:
    ///   - sessionId: The ID of the session
    ///   - exerciseId: The ID of the WorkoutExercise
    ///   - setId: The ID of the set to remove
    /// - Throws: `WorkoutServiceError.sessionNotFound` if session doesn't exist
    /// - Throws: `WorkoutServiceError.exerciseNotFound` if exercise doesn't exist in session
    /// - Throws: `WorkoutServiceError.setNotFound` if set doesn't exist
    /// - Throws: `WorkoutServiceError.invalidSessionState` if session is completed
    func removeSet(sessionId: UUID, exerciseId: UUID, setId: UUID) async throws

    /// Duplicates the last set of an exercise with the same parameters
    /// - Parameters:
    ///   - sessionId: The ID of the session
    ///   - exerciseId: The ID of the WorkoutExercise
    /// - Returns: The created ExerciseSet instance with duplicated data
    /// - Throws: `WorkoutServiceError.sessionNotFound` if session doesn't exist
    /// - Throws: `WorkoutServiceError.exerciseNotFound` if exercise doesn't exist in session
    /// - Throws: `WorkoutServiceError.invalidSessionState` if session is completed
    /// - Note: If no sets exist for the exercise, creates a set with default values
    func duplicateLastSet(sessionId: UUID, exerciseId: UUID) async throws -> ExerciseSet

    // MARK: - Session Statistics and Analytics

    /// Calculates current session statistics
    /// - Parameter sessionId: The ID of the session
    /// - Returns: Computed statistics for the session
    /// - Throws: `WorkoutServiceError.sessionNotFound` if session doesn't exist
    func getSessionStatistics(sessionId: UUID) async throws -> WorkoutSessionStatistics

    /// Gets the current active workout session, if any
    /// - Returns: The current active session, or nil if no session is active
    var currentSession: WorkoutSession? { get async }

    /// Checks if there is an active workout session
    /// - Returns: True if a session is currently in progress or paused
    var hasActiveSession: Bool { get async }
}

// MARK: - Supporting Statistics Type

/// Statistics calculated for a workout session
public struct WorkoutSessionStatistics {
    /// Total volume (weight × reps) for the session
    public let totalVolume: Double

    /// Average RPE across all completed sets
    public let averageRPE: Double

    /// Total number of sets completed
    public let totalSets: Int

    /// Total number of exercises in the session
    public let totalExercises: Int

    /// Duration of the session in seconds
    public let duration: TimeInterval

    /// Number of personal records achieved in this session
    public let personalRecordsCount: Int

    /// Breakdown of volume by muscle group
    public let volumeByMuscleGroup: [String: Double]

    /// Estimated calories burned (optional, if HealthKit integration is available)
    public let estimatedCalories: Double?

    public init(totalVolume: Double, averageRPE: Double, totalSets: Int, totalExercises: Int, duration: TimeInterval, personalRecordsCount: Int, volumeByMuscleGroup: [String: Double], estimatedCalories: Double? = nil) {
        self.totalVolume = totalVolume
        self.averageRPE = averageRPE
        self.totalSets = totalSets
        self.totalExercises = totalExercises
        self.duration = duration
        self.personalRecordsCount = personalRecordsCount
        self.volumeByMuscleGroup = volumeByMuscleGroup
        self.estimatedCalories = estimatedCalories
    }
}

// MARK: - Test Helper Protocol

/// Protocol for test implementations and mocking
/// Enables dependency injection and unit testing of components that depend on WorkoutService
public protocol MockableWorkoutService: WorkoutService {
    /// Allows tests to inject mock sessions
    func setMockSessions(_ sessions: [WorkoutSession])

    /// Allows tests to simulate errors
    func setMockError(_ error: WorkoutServiceError?)

    /// Allows tests to control the current session
    func setMockCurrentSession(_ session: WorkoutSession?)
}