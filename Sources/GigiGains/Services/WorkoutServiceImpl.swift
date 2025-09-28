//
//  WorkoutServiceImpl.swift
//  Gigi Gains
//
//  Implementation of WorkoutService protocol providing complete workout session
//  management including real-time tracking, exercise management, and statistics.
//
//  Created: 2025-09-28
//

import Foundation
import CoreData
import Combine

public class WorkoutServiceImpl: WorkoutService {

    // MARK: - Properties

    private let workoutRepository: WorkoutRepository
    private let exerciseRepository: ExerciseRepository

    private let currentSessionSubject = CurrentValueSubject<WorkoutSession?, Never>(nil)
    private let sessionsUpdateSubject = PassthroughSubject<[WorkoutSession], Never>()
    private let sessionStateSubject = CurrentValueSubject<WorkoutSessionState?, Never>(nil)

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Publishers

    public var currentSessionPublisher: AnyPublisher<WorkoutSession?, Never> {
        currentSessionSubject.eraseToAnyPublisher()
    }

    public var sessionsUpdatePublisher: AnyPublisher<[WorkoutSession], Never> {
        sessionsUpdateSubject.eraseToAnyPublisher()
    }

    public var sessionStatePublisher: AnyPublisher<WorkoutSessionState?, Never> {
        sessionStateSubject.eraseToAnyPublisher()
    }

    // MARK: - Computed Properties

    public var currentSession: WorkoutSession? {
        get async {
            return currentSessionSubject.value
        }
    }

    public var hasActiveSession: Bool {
        get async {
            guard let session = currentSessionSubject.value else { return false }
            let state = WorkoutSessionState(rawValue: session.state) ?? .draft
            return state == .inProgress || state == .paused
        }
    }

    // MARK: - Initialization

    public init(workoutRepository: WorkoutRepository, exerciseRepository: ExerciseRepository) {
        self.workoutRepository = workoutRepository
        self.exerciseRepository = exerciseRepository

        setupPublisherSubscriptions()

        // Load current active session on initialization
        Task {
            await loadCurrentActiveSession()
        }
    }

    // MARK: - Session Management

    public func createSession(config: WorkoutSessionConfig) async throws -> WorkoutSession {
        do {
            try validateSessionConfig(config)

            let session = try await workoutRepository.createWorkoutSession(
                name: config.name,
                routineId: config.routineId,
                startDate: config.startDate,
                notes: config.notes
            )

            // Update publishers
            await updateSessionsPublisher()

            return session
        } catch {
            throw mapRepositoryError(error)
        }
    }

    public func getSession(sessionId: UUID) async throws -> WorkoutSession {
        do {
            return try await workoutRepository.fetchWorkoutSession(id: sessionId)
        } catch {
            throw mapRepositoryError(error)
        }
    }

    public func getSessions(filter: WorkoutSessionFilter) async throws -> [WorkoutSession] {
        do {
            let workoutFilter = WorkoutQueryFilter(
                startDate: filter.startDate,
                endDate: filter.endDate,
                isCompleted: filter.isCompleted,
                routineId: filter.routineId
            )

            return try await workoutRepository.fetchWorkoutSessions(
                filter: workoutFilter,
                sortBy: .startDateDescending,
                options: FetchOptions()
            )
        } catch {
            throw mapRepositoryError(error)
        }
    }

    public func startSession(sessionId: UUID) async throws {
        do {
            let session = try await workoutRepository.fetchWorkoutSession(id: sessionId)

            guard let currentState = WorkoutSessionState(rawValue: session.state) else {
                throw WorkoutServiceError.invalidSessionState(current: .draft, required: .draft)
            }

            guard currentState == .draft else {
                throw WorkoutServiceError.invalidSessionState(current: currentState, required: .draft)
            }

            // Update session state
            try await workoutRepository.updateWorkoutSessionState(sessionId: sessionId, state: .inProgress)

            // Set as current session
            let updatedSession = try await workoutRepository.fetchWorkoutSession(id: sessionId)
            currentSessionSubject.send(updatedSession)
            sessionStateSubject.send(.inProgress)

            await updateSessionsPublisher()
        } catch {
            throw mapRepositoryError(error)
        }
    }

    public func pauseSession(sessionId: UUID) async throws {
        do {
            let session = try await workoutRepository.fetchWorkoutSession(id: sessionId)

            guard let currentState = WorkoutSessionState(rawValue: session.state) else {
                throw WorkoutServiceError.invalidSessionState(current: .draft, required: .inProgress)
            }

            guard currentState == .inProgress else {
                throw WorkoutServiceError.invalidSessionState(current: currentState, required: .inProgress)
            }

            try await workoutRepository.updateWorkoutSessionState(sessionId: sessionId, state: .paused)

            let updatedSession = try await workoutRepository.fetchWorkoutSession(id: sessionId)
            currentSessionSubject.send(updatedSession)
            sessionStateSubject.send(.paused)

            await updateSessionsPublisher()
        } catch {
            throw mapRepositoryError(error)
        }
    }

    public func resumeSession(sessionId: UUID) async throws {
        do {
            let session = try await workoutRepository.fetchWorkoutSession(id: sessionId)

            guard let currentState = WorkoutSessionState(rawValue: session.state) else {
                throw WorkoutServiceError.invalidSessionState(current: .draft, required: .paused)
            }

            guard currentState == .paused else {
                throw WorkoutServiceError.invalidSessionState(current: currentState, required: .paused)
            }

            try await workoutRepository.updateWorkoutSessionState(sessionId: sessionId, state: .inProgress)

            let updatedSession = try await workoutRepository.fetchWorkoutSession(id: sessionId)
            currentSessionSubject.send(updatedSession)
            sessionStateSubject.send(.inProgress)

            await updateSessionsPublisher()
        } catch {
            throw mapRepositoryError(error)
        }
    }

    public func completeSession(sessionId: UUID) async throws {
        do {
            let session = try await workoutRepository.fetchWorkoutSession(id: sessionId)

            guard let currentState = WorkoutSessionState(rawValue: session.state) else {
                throw WorkoutServiceError.invalidSessionState(current: .draft, required: .inProgress)
            }

            guard currentState == .inProgress || currentState == .paused else {
                throw WorkoutServiceError.invalidSessionState(current: currentState, required: .inProgress)
            }

            // Calculate final statistics
            try await calculateAndUpdateSessionStatistics(sessionId: sessionId)

            // Update session state to completed
            try await workoutRepository.updateWorkoutSessionState(sessionId: sessionId, state: .completed)

            // Clear current session if this was the active one
            if currentSessionSubject.value?.id == sessionId {
                currentSessionSubject.send(nil)
                sessionStateSubject.send(nil)
            }

            await updateSessionsPublisher()
        } catch {
            throw mapRepositoryError(error)
        }
    }

    public func updateSession(sessionId: UUID, name: String?, notes: String?) async throws {
        do {
            let session = try await workoutRepository.fetchWorkoutSession(id: sessionId)

            guard let currentState = WorkoutSessionState(rawValue: session.state) else {
                throw WorkoutServiceError.invalidSessionState(current: .draft, required: .draft)
            }

            guard currentState != .completed else {
                throw WorkoutServiceError.invalidSessionState(current: currentState, required: .inProgress)
            }

            try await workoutRepository.updateWorkoutSession(
                sessionId: sessionId,
                name: name,
                notes: notes
            )

            // Update current session if this is the active one
            if currentSessionSubject.value?.id == sessionId {
                let updatedSession = try await workoutRepository.fetchWorkoutSession(id: sessionId)
                currentSessionSubject.send(updatedSession)
            }

            await updateSessionsPublisher()
        } catch {
            throw mapRepositoryError(error)
        }
    }

    public func deleteSession(sessionId: UUID) async throws {
        do {
            // Clear current session if this is the active one
            if currentSessionSubject.value?.id == sessionId {
                currentSessionSubject.send(nil)
                sessionStateSubject.send(nil)
            }

            try await workoutRepository.deleteWorkoutSession(sessionId: sessionId)
            await updateSessionsPublisher()
        } catch {
            throw mapRepositoryError(error)
        }
    }

    // MARK: - Exercise Management Within Sessions

    public func addExercise(sessionId: UUID, request: AddExerciseRequest) async throws -> WorkoutExercise {
        do {
            let session = try await workoutRepository.fetchWorkoutSession(id: sessionId)

            guard let currentState = WorkoutSessionState(rawValue: session.state) else {
                throw WorkoutServiceError.invalidSessionState(current: .draft, required: .draft)
            }

            guard currentState != .completed else {
                throw WorkoutServiceError.invalidSessionState(current: currentState, required: .inProgress)
            }

            // Verify exercise exists
            let _ = try await exerciseRepository.fetchExercise(id: request.exerciseId)

            let workoutExercise = try await workoutRepository.addExercise(
                sessionId: sessionId,
                exerciseId: request.exerciseId,
                orderIndex: request.orderIndex,
                restTimerDuration: request.restTimerDuration,
                superset: request.superset,
                notes: request.notes
            )

            // Update current session if this is the active one
            if currentSessionSubject.value?.id == sessionId {
                let updatedSession = try await workoutRepository.fetchWorkoutSession(id: sessionId)
                currentSessionSubject.send(updatedSession)
            }

            await updateSessionsPublisher()
            return workoutExercise
        } catch {
            throw mapRepositoryError(error)
        }
    }

    public func removeExercise(sessionId: UUID, exerciseId: UUID) async throws {
        do {
            let session = try await workoutRepository.fetchWorkoutSession(id: sessionId)

            guard let currentState = WorkoutSessionState(rawValue: session.state) else {
                throw WorkoutServiceError.invalidSessionState(current: .draft, required: .draft)
            }

            guard currentState != .completed else {
                throw WorkoutServiceError.invalidSessionState(current: currentState, required: .inProgress)
            }

            try await workoutRepository.removeExercise(sessionId: sessionId, exerciseId: exerciseId)

            // Update current session if this is the active one
            if currentSessionSubject.value?.id == sessionId {
                let updatedSession = try await workoutRepository.fetchWorkoutSession(id: sessionId)
                currentSessionSubject.send(updatedSession)
            }

            await updateSessionsPublisher()
        } catch {
            throw mapRepositoryError(error)
        }
    }

    public func reorderExercises(sessionId: UUID, exerciseOrdering: [UUID]) async throws {
        do {
            let session = try await workoutRepository.fetchWorkoutSession(id: sessionId)

            guard let currentState = WorkoutSessionState(rawValue: session.state) else {
                throw WorkoutServiceError.invalidSessionState(current: .draft, required: .draft)
            }

            guard currentState != .completed else {
                throw WorkoutServiceError.invalidSessionState(current: currentState, required: .inProgress)
            }

            try await workoutRepository.reorderExercises(sessionId: sessionId, exerciseOrder: exerciseOrdering)

            // Update current session if this is the active one
            if currentSessionSubject.value?.id == sessionId {
                let updatedSession = try await workoutRepository.fetchWorkoutSession(id: sessionId)
                currentSessionSubject.send(updatedSession)
            }

            await updateSessionsPublisher()
        } catch {
            throw mapRepositoryError(error)
        }
    }

    public func updateExercise(sessionId: UUID, exerciseId: UUID, restTimerDuration: TimeInterval?, superset: String?, notes: String?) async throws {
        do {
            let session = try await workoutRepository.fetchWorkoutSession(id: sessionId)

            guard let currentState = WorkoutSessionState(rawValue: session.state) else {
                throw WorkoutServiceError.invalidSessionState(current: .draft, required: .draft)
            }

            guard currentState != .completed else {
                throw WorkoutServiceError.invalidSessionState(current: currentState, required: .inProgress)
            }

            try await workoutRepository.updateExercise(
                sessionId: sessionId,
                exerciseId: exerciseId,
                restTimerDuration: restTimerDuration,
                superset: superset,
                notes: notes
            )

            // Update current session if this is the active one
            if currentSessionSubject.value?.id == sessionId {
                let updatedSession = try await workoutRepository.fetchWorkoutSession(id: sessionId)
                currentSessionSubject.send(updatedSession)
            }

            await updateSessionsPublisher()
        } catch {
            throw mapRepositoryError(error)
        }
    }

    // MARK: - Set Management

    public func addSet(sessionId: UUID, exerciseId: UUID, setData: SetData) async throws -> ExerciseSet {
        do {
            try setData.validate()

            let session = try await workoutRepository.fetchWorkoutSession(id: sessionId)

            guard let currentState = WorkoutSessionState(rawValue: session.state) else {
                throw WorkoutServiceError.invalidSessionState(current: .draft, required: .draft)
            }

            guard currentState != .completed else {
                throw WorkoutServiceError.invalidSessionState(current: currentState, required: .inProgress)
            }

            let exerciseSet = try await workoutRepository.addSet(
                sessionId: sessionId,
                exerciseId: exerciseId,
                weight: setData.weight,
                reps: setData.reps,
                rpe: setData.rpe,
                notes: setData.notes,
                isCompleted: setData.isCompleted
            )

            // Record exercise usage
            if setData.isCompleted {
                // Get the actual exercise ID from the workout exercise
                let workoutExercise = try await workoutRepository.fetchWorkoutExercise(
                    sessionId: sessionId,
                    exerciseId: exerciseId
                )
                if let actualExerciseId = workoutExercise.exercise?.id {
                    try await exerciseRepository.recordExerciseUsage(exerciseId: actualExerciseId)
                }
            }

            // Update current session if this is the active one
            if currentSessionSubject.value?.id == sessionId {
                let updatedSession = try await workoutRepository.fetchWorkoutSession(id: sessionId)
                currentSessionSubject.send(updatedSession)
            }

            await updateSessionsPublisher()
            return exerciseSet
        } catch let error as WorkoutServiceError {
            throw error
        } catch {
            throw mapRepositoryError(error)
        }
    }

    public func updateSet(sessionId: UUID, exerciseId: UUID, setId: UUID, setData: SetData) async throws {
        do {
            try setData.validate()

            let session = try await workoutRepository.fetchWorkoutSession(id: sessionId)

            guard let currentState = WorkoutSessionState(rawValue: session.state) else {
                throw WorkoutServiceError.invalidSessionState(current: .draft, required: .draft)
            }

            guard currentState != .completed else {
                throw WorkoutServiceError.invalidSessionState(current: currentState, required: .inProgress)
            }

            try await workoutRepository.updateSet(
                sessionId: sessionId,
                exerciseId: exerciseId,
                setId: setId,
                weight: setData.weight,
                reps: setData.reps,
                rpe: setData.rpe,
                notes: setData.notes,
                isCompleted: setData.isCompleted
            )

            // Update current session if this is the active one
            if currentSessionSubject.value?.id == sessionId {
                let updatedSession = try await workoutRepository.fetchWorkoutSession(id: sessionId)
                currentSessionSubject.send(updatedSession)
            }

            await updateSessionsPublisher()
        } catch let error as WorkoutServiceError {
            throw error
        } catch {
            throw mapRepositoryError(error)
        }
    }

    public func removeSet(sessionId: UUID, exerciseId: UUID, setId: UUID) async throws {
        do {
            let session = try await workoutRepository.fetchWorkoutSession(id: sessionId)

            guard let currentState = WorkoutSessionState(rawValue: session.state) else {
                throw WorkoutServiceError.invalidSessionState(current: .draft, required: .draft)
            }

            guard currentState != .completed else {
                throw WorkoutServiceError.invalidSessionState(current: currentState, required: .inProgress)
            }

            try await workoutRepository.removeSet(
                sessionId: sessionId,
                exerciseId: exerciseId,
                setId: setId
            )

            // Update current session if this is the active one
            if currentSessionSubject.value?.id == sessionId {
                let updatedSession = try await workoutRepository.fetchWorkoutSession(id: sessionId)
                currentSessionSubject.send(updatedSession)
            }

            await updateSessionsPublisher()
        } catch {
            throw mapRepositoryError(error)
        }
    }

    public func duplicateLastSet(sessionId: UUID, exerciseId: UUID) async throws -> ExerciseSet {
        do {
            let session = try await workoutRepository.fetchWorkoutSession(id: sessionId)

            guard let currentState = WorkoutSessionState(rawValue: session.state) else {
                throw WorkoutServiceError.invalidSessionState(current: .draft, required: .draft)
            }

            guard currentState != .completed else {
                throw WorkoutServiceError.invalidSessionState(current: currentState, required: .inProgress)
            }

            // Get the last set for this exercise
            let workoutExercise = try await workoutRepository.fetchWorkoutExercise(
                sessionId: sessionId,
                exerciseId: exerciseId
            )

            let sets = workoutExercise.orderedSets

            let setData: SetData
            if let lastSet = sets.last {
                // Duplicate the last set
                setData = SetData(
                    weight: lastSet.weight,
                    reps: lastSet.reps,
                    rpe: lastSet.rpe,
                    notes: lastSet.notes,
                    isCompleted: false // Start as incomplete for user to update
                )
            } else {
                // No previous sets, create default set
                setData = SetData(
                    weight: 20.0, // Default starting weight
                    reps: 8,      // Default reps
                    rpe: 7.0,     // Default RPE
                    notes: nil,
                    isCompleted: false
                )
            }

            return try await addSet(sessionId: sessionId, exerciseId: exerciseId, setData: setData)
        } catch {
            throw mapRepositoryError(error)
        }
    }

    // MARK: - Session Statistics and Analytics

    public func getSessionStatistics(sessionId: UUID) async throws -> WorkoutSessionStatistics {
        do {
            let session = try await workoutRepository.fetchWorkoutSession(id: sessionId)

            var totalVolume: Double = 0
            var totalRPE: Double = 0
            var totalSets: Int = 0
            var rpeCount: Int = 0
            var volumeByMuscleGroup: [String: Double] = [:]

            // Calculate statistics from workout exercises and sets
            if let exercises = session.exercises?.allObjects as? [WorkoutExercise] {
                for workoutExercise in exercises {
                    if let sets = workoutExercise.sets?.allObjects as? [ExerciseSet] {
                        for set in sets where set.isCompleted {
                            let setVolume = set.volume
                            totalVolume += setVolume
                            totalSets += 1

                            if set.rpe > 0 {
                                totalRPE += set.rpe
                                rpeCount += 1
                            }

                            // Add to muscle group volume
                            if let exercise = workoutExercise.exercise {
                                for muscleGroup in exercise.primaryMuscleGroupsArray {
                                    volumeByMuscleGroup[muscleGroup, default: 0] += setVolume
                                }
                            }
                        }
                    }
                }
            }

            let averageRPE = rpeCount > 0 ? totalRPE / Double(rpeCount) : 0
            let duration = session.endDate?.timeIntervalSince(session.startDate) ?? 0
            let exerciseCount = session.exercises?.count ?? 0

            return WorkoutSessionStatistics(
                totalVolume: totalVolume,
                averageRPE: averageRPE,
                totalSets: totalSets,
                totalExercises: exerciseCount,
                duration: duration,
                personalRecordsCount: 0, // Would need ProgressTrackingService to calculate
                volumeByMuscleGroup: volumeByMuscleGroup,
                estimatedCalories: nil // Would need HealthKit integration
            )
        } catch {
            throw mapRepositoryError(error)
        }
    }

    // MARK: - Private Helper Methods

    private func setupPublisherSubscriptions() {
        // Subscribe to repository changes
        workoutRepository.workoutSessionsChangedPublisher
            .sink { [weak self] in
                Task { @MainActor in
                    await self?.updateSessionsPublisher()
                }
            }
            .store(in: &cancellables)
    }

    private func loadCurrentActiveSession() async {
        do {
            let filter = WorkoutQueryFilter(isCompleted: false)
            let sessions = try await workoutRepository.fetchWorkoutSessions(
                filter: filter,
                sortBy: .startDateDescending,
                options: FetchOptions(limit: 1)
            )

            if let activeSession = sessions.first {
                let state = WorkoutSessionState(rawValue: activeSession.state) ?? .draft
                if state == .inProgress || state == .paused {
                    currentSessionSubject.send(activeSession)
                    sessionStateSubject.send(state)
                }
            }
        } catch {
            // Silently handle errors during initialization
            print("Failed to load current active session: \(error)")
        }
    }

    private func updateSessionsPublisher() async {
        do {
            let sessions = try await workoutRepository.fetchWorkoutSessions(
                filter: WorkoutQueryFilter(),
                sortBy: .startDateDescending,
                options: FetchOptions()
            )
            sessionsUpdateSubject.send(sessions)
        } catch {
            // Silently handle errors
            print("Failed to update sessions publisher: \(error)")
        }
    }

    private func calculateAndUpdateSessionStatistics(sessionId: UUID) async throws {
        // Calculate final session statistics
        let statistics = try await getSessionStatistics(sessionId: sessionId)

        // Update session with calculated values
        try await workoutRepository.updateWorkoutSessionStatistics(
            sessionId: sessionId,
            totalVolume: statistics.totalVolume,
            totalSets: Int32(statistics.totalSets),
            averageRPE: statistics.averageRPE,
            duration: statistics.duration
        )
    }

    private func validateSessionConfig(_ config: WorkoutSessionConfig) throws {
        if let name = config.name, name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw WorkoutServiceError.validationError("Session name cannot be empty")
        }
    }

    private func mapRepositoryError(_ error: Error) -> WorkoutServiceError {
        if let repoError = error as? WorkoutRepositoryError {
            switch repoError {
            case .objectNotFound:
                return .sessionNotFound(UUID()) // Would need more context for specific ID
            case .saveContextFailed(let underlyingError):
                return .coreDataError(underlyingError)
            case .fetchRequestFailed(let underlyingError):
                return .coreDataError(underlyingError)
            default:
                return .coreDataError(error)
            }
        } else if let exerciseRepoError = error as? ExerciseRepositoryError {
            switch exerciseRepoError {
            case .objectNotFound(let id):
                return .exerciseNotFound(id)
            default:
                return .coreDataError(error)
            }
        } else {
            return .coreDataError(error)
        }
    }
}

// MARK: - WorkoutSessionState Extension

extension WorkoutSessionState {
    var rawValue: String {
        switch self {
        case .draft: return "draft"
        case .inProgress: return "inProgress"
        case .completed: return "completed"
        case .paused: return "paused"
        }
    }

    init?(rawValue: String) {
        switch rawValue {
        case "draft": self = .draft
        case "inProgress": self = .inProgress
        case "completed": self = .completed
        case "paused": self = .paused
        default: return nil
        }
    }
}