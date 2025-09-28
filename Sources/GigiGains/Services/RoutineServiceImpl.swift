//
//  RoutineServiceImpl.swift
//  Gigi Gains
//
//  Implementation of RoutineService protocol providing complete routine template
//  management including creation, modification, and workout session generation.
//
//  Created: 2025-09-28
//

import Foundation
import CoreData
import Combine

public class RoutineServiceImpl: RoutineService {

    // MARK: - Properties

    private let workoutRepository: WorkoutRepository
    private let exerciseRepository: ExerciseRepository
    private let coreDataStack: CoreDataStack

    private let routinesUpdateSubject = PassthroughSubject<[Routine], Never>()
    private let routineStatisticsUpdateSubject = PassthroughSubject<[UUID: RoutineStatistics], Never>()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Publishers

    public var routinesUpdatePublisher: AnyPublisher<[Routine], Never> {
        routinesUpdateSubject.eraseToAnyPublisher()
    }

    public var routineStatisticsUpdatePublisher: AnyPublisher<[UUID: RoutineStatistics], Never> {
        routineStatisticsUpdateSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    public init(workoutRepository: WorkoutRepository, exerciseRepository: ExerciseRepository, coreDataStack: CoreDataStack) {
        self.workoutRepository = workoutRepository
        self.exerciseRepository = exerciseRepository
        self.coreDataStack = coreDataStack

        setupPublisherSubscriptions()
    }

    // MARK: - Routine Management

    public func createRoutine(config: RoutineCreationConfig) async throws -> Routine {
        let context = coreDataStack.viewContext

        return try await context.perform {
            do {
                try config.validate()

                // Check for duplicate name
                if try self.isRoutineNameTaken(config.name, context: context) {
                    throw RoutineServiceError.duplicateRoutineName(config.name)
                }

                // Create new routine
                let routine = Routine(context: context)
                routine.name = config.name
                routine.notes = config.notes
                routine.estimatedDuration = config.estimatedDuration ?? 0

                try routine.validate()
                try context.save()

                Task { @MainActor in
                    await self.updateRoutinesPublisher()
                }

                return routine
            } catch let error as RoutineServiceError {
                context.rollback()
                throw error
            } catch {
                context.rollback()
                throw RoutineServiceError.coreDataError(error)
            }
        }
    }

    public func createRoutineFromSession(sessionId: UUID, name: String, notes: String?) async throws -> Routine {
        let context = coreDataStack.viewContext

        return try await context.perform {
            do {
                // Check for duplicate name
                if try self.isRoutineNameTaken(name, context: context) {
                    throw RoutineServiceError.duplicateRoutineName(name)
                }

                // Fetch the workout session
                let session = try await self.workoutRepository.fetchWorkoutSession(id: sessionId)

                // Create new routine
                let routine = Routine(context: context)
                routine.name = name
                routine.notes = notes
                routine.estimatedDuration = 0

                // Copy exercises from session
                if let workoutExercises = session.exercises?.allObjects as? [WorkoutExercise] {
                    let sortedExercises = workoutExercises.sorted { $0.orderIndex < $1.orderIndex }

                    for workoutExercise in sortedExercises {
                        guard let exercise = workoutExercise.exercise else { continue }

                        let routineExercise = RoutineExercise(context: context)
                        routineExercise.routine = routine
                        routineExercise.exercise = exercise
                        routineExercise.orderIndex = workoutExercise.orderIndex

                        // Calculate target values from completed sets
                        if let sets = workoutExercise.sets?.allObjects as? [ExerciseSet] {
                            let completedSets = sets.filter { $0.isCompleted }

                            if !completedSets.isEmpty {
                                routineExercise.targetSets = Int32(completedSets.count)

                                // Calculate average values
                                let avgWeight = completedSets.reduce(0.0) { $0 + $1.weight } / Double(completedSets.count)
                                let avgReps = completedSets.reduce(0) { $0 + $1.reps } / Int32(completedSets.count)
                                let avgRPE = completedSets.reduce(0.0) { $0 + $1.rpe } / Double(completedSets.count)

                                routineExercise.targetWeight = avgWeight
                                routineExercise.targetRPE = avgRPE

                                // Set target reps (use consistent reps if similar, otherwise use average)
                                let repsArray = completedSets.map { $0.reps }
                                if repsArray.allSatisfy({ abs($0 - avgReps) <= 1 }) {
                                    // Similar reps, use consistent scheme
                                    routineExercise.targetRepsArray = Array(repeating: avgReps, count: completedSets.count)
                                } else {
                                    // Varied reps, use actual values
                                    routineExercise.targetRepsArray = repsArray
                                }
                            } else {
                                // Default values if no completed sets
                                routineExercise.targetSets = 3
                                routineExercise.targetRepsArray = [8, 8, 8]
                            }
                        }

                        routineExercise.restTime = workoutExercise.restTimerDuration ?? 120
                        routineExercise.superset = workoutExercise.superset
                        routineExercise.notes = workoutExercise.notes

                        routine.addToExercises(routineExercise)
                    }
                }

                // Update estimated duration
                routine.updateEstimatedDuration()

                try routine.validate()
                try context.save()

                Task { @MainActor in
                    await self.updateRoutinesPublisher()
                }

                return routine
            } catch let error as RoutineServiceError {
                context.rollback()
                throw error
            } catch {
                context.rollback()
                throw RoutineServiceError.coreDataError(error)
            }
        }
    }

    public func getRoutine(routineId: UUID) async throws -> Routine {
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<Routine> = Routine.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", routineId as CVarArg)
            request.fetchLimit = 1

            do {
                guard let routine = try context.fetch(request).first else {
                    throw RoutineServiceError.routineNotFound(routineId)
                }
                return routine
            } catch {
                throw RoutineServiceError.coreDataError(error)
            }
        }
    }

    public func getRoutines(filter: RoutineFilter, sortBy: RoutineSortOption) async throws -> [Routine] {
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<Routine> = Routine.fetchRequest()

            // Build predicate from filter
            var predicates: [NSPredicate] = []

            if let searchText = filter.searchText, !searchText.isEmpty {
                predicates.append(NSPredicate(format: "name CONTAINS[cd] %@ OR notes CONTAINS[cd] %@", searchText, searchText))
            }

            if let isArchived = filter.isArchived {
                predicates.append(NSPredicate(format: "isArchived == %@", NSNumber(value: isArchived)))
            }

            if let lastUsedAfter = filter.lastUsedAfter {
                predicates.append(NSPredicate(format: "lastUsed >= %@", lastUsedAfter as NSDate))
            }

            if let lastUsedBefore = filter.lastUsedBefore {
                predicates.append(NSPredicate(format: "lastUsed <= %@", lastUsedBefore as NSDate))
            }

            if let exerciseId = filter.containsExerciseId {
                predicates.append(NSPredicate(format: "ANY exercises.exercise.id == %@", exerciseId as CVarArg))
            }

            if let minDuration = filter.estimatedDurationMin {
                predicates.append(NSPredicate(format: "estimatedDuration >= %f", minDuration))
            }

            if let maxDuration = filter.estimatedDurationMax {
                predicates.append(NSPredicate(format: "estimatedDuration <= %f", maxDuration))
            }

            if !predicates.isEmpty {
                request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            }

            // Apply sorting
            request.sortDescriptors = self.sortDescriptors(for: sortBy)

            do {
                return try context.fetch(request)
            } catch {
                throw RoutineServiceError.coreDataError(error)
            }
        }
    }

    public func updateRoutine(routineId: UUID, name: String?, notes: String?, estimatedDuration: TimeInterval?) async throws {
        let context = coreDataStack.viewContext

        try await context.perform {
            do {
                let routine = try self.fetchRoutine(id: routineId, context: context)

                if let name = name {
                    // Check for duplicate name (excluding current routine)
                    if routine.name != name && try self.isRoutineNameTaken(name, context: context) {
                        throw RoutineServiceError.duplicateRoutineName(name)
                    }
                    routine.name = name
                }

                if let notes = notes {
                    routine.notes = notes
                }

                if let estimatedDuration = estimatedDuration {
                    guard estimatedDuration >= 0 else {
                        throw RoutineServiceError.validationError("Estimated duration must be non-negative")
                    }
                    routine.estimatedDuration = estimatedDuration
                }

                try routine.validate()
                try context.save()

                Task { @MainActor in
                    await self.updateRoutinesPublisher()
                }
            } catch let error as RoutineServiceError {
                context.rollback()
                throw error
            } catch {
                context.rollback()
                throw RoutineServiceError.coreDataError(error)
            }
        }
    }

    public func archiveRoutine(routineId: UUID, isArchived: Bool) async throws {
        let context = coreDataStack.viewContext

        try await context.perform {
            do {
                let routine = try self.fetchRoutine(id: routineId, context: context)
                routine.setArchived(isArchived)

                try context.save()

                Task { @MainActor in
                    await self.updateRoutinesPublisher()
                }
            } catch {
                context.rollback()
                throw RoutineServiceError.coreDataError(error)
            }
        }
    }

    public func deleteRoutine(routineId: UUID) async throws {
        let context = coreDataStack.viewContext

        try await context.perform {
            do {
                let routine = try self.fetchRoutine(id: routineId, context: context)

                // Check if routine is in use by any workout sessions
                let sessionCount = try self.countWorkoutSessionsUsingRoutine(routineId: routineId, context: context)
                if sessionCount > 0 {
                    throw RoutineServiceError.routineInUse(sessionsCount: sessionCount)
                }

                context.delete(routine)
                try context.save()

                Task { @MainActor in
                    await self.updateRoutinesPublisher()
                }
            } catch let error as RoutineServiceError {
                context.rollback()
                throw error
            } catch {
                context.rollback()
                throw RoutineServiceError.coreDataError(error)
            }
        }
    }

    public func duplicateRoutine(routineId: UUID, newName: String) async throws -> Routine {
        let context = coreDataStack.viewContext

        return try await context.perform {
            do {
                // Check for duplicate name
                if try self.isRoutineNameTaken(newName, context: context) {
                    throw RoutineServiceError.duplicateRoutineName(newName)
                }

                let sourceRoutine = try self.fetchRoutine(id: routineId, context: context)

                // Create new routine
                let newRoutine = Routine(context: context)
                newRoutine.name = newName
                newRoutine.notes = sourceRoutine.notes
                newRoutine.estimatedDuration = sourceRoutine.estimatedDuration

                // Copy exercises
                for routineExercise in sourceRoutine.orderedExercises {
                    let newRoutineExercise = RoutineExercise(context: context)
                    newRoutineExercise.routine = newRoutine
                    newRoutineExercise.exercise = routineExercise.exercise
                    newRoutineExercise.orderIndex = routineExercise.orderIndex
                    newRoutineExercise.targetSets = routineExercise.targetSets
                    newRoutineExercise.targetRepsArray = routineExercise.targetRepsArray
                    newRoutineExercise.targetWeight = routineExercise.targetWeight
                    newRoutineExercise.targetRPE = routineExercise.targetRPE
                    newRoutineExercise.restTime = routineExercise.restTime
                    newRoutineExercise.superset = routineExercise.superset
                    newRoutineExercise.notes = routineExercise.notes

                    newRoutine.addToExercises(newRoutineExercise)
                }

                try newRoutine.validate()
                try context.save()

                Task { @MainActor in
                    await self.updateRoutinesPublisher()
                }

                return newRoutine
            } catch let error as RoutineServiceError {
                context.rollback()
                throw error
            } catch {
                context.rollback()
                throw RoutineServiceError.coreDataError(error)
            }
        }
    }

    // MARK: - Exercise Template Management

    public func addExerciseToRoutine(routineId: UUID, template: RoutineExerciseTemplate) async throws -> RoutineExercise {
        let context = coreDataStack.viewContext

        return try await context.perform {
            do {
                try template.validate()

                let routine = try self.fetchRoutine(id: routineId, context: context)
                let exercise = try self.fetchExercise(id: template.exerciseId, context: context)

                let routineExercise = RoutineExercise(context: context)
                routineExercise.routine = routine
                routineExercise.exercise = exercise
                routineExercise.orderIndex = template.orderIndex ?? Int32(routine.exerciseCount)
                routineExercise.targetSets = template.targetSets
                routineExercise.targetRepsArray = template.targetReps
                routineExercise.targetWeight = template.targetWeight
                routineExercise.targetRPE = template.targetRPE
                routineExercise.restTime = template.restTime
                routineExercise.superset = template.superset
                routineExercise.notes = template.notes

                routine.addToExercises(routineExercise)
                routine.updateEstimatedDuration()

                try routineExercise.validate()
                try context.save()

                Task { @MainActor in
                    await self.updateRoutinesPublisher()
                }

                return routineExercise
            } catch let error as RoutineServiceError {
                context.rollback()
                throw error
            } catch {
                context.rollback()
                throw RoutineServiceError.coreDataError(error)
            }
        }
    }

    public func updateExerciseInRoutine(routineId: UUID, exerciseId: UUID, template: RoutineExerciseTemplate) async throws {
        let context = coreDataStack.viewContext

        try await context.perform {
            do {
                try template.validate()

                let routine = try self.fetchRoutine(id: routineId, context: context)
                guard let routineExercise = routine.orderedExercises.first(where: { $0.id == exerciseId }) else {
                    throw RoutineServiceError.exerciseNotFound(exerciseId)
                }

                routineExercise.targetSets = template.targetSets
                routineExercise.targetRepsArray = template.targetReps
                routineExercise.targetWeight = template.targetWeight
                routineExercise.targetRPE = template.targetRPE
                routineExercise.restTime = template.restTime
                routineExercise.superset = template.superset
                routineExercise.notes = template.notes

                routine.updateEstimatedDuration()

                try routineExercise.validate()
                try context.save()

                Task { @MainActor in
                    await self.updateRoutinesPublisher()
                }
            } catch let error as RoutineServiceError {
                context.rollback()
                throw error
            } catch {
                context.rollback()
                throw RoutineServiceError.coreDataError(error)
            }
        }
    }

    public func removeExerciseFromRoutine(routineId: UUID, exerciseId: UUID) async throws {
        let context = coreDataStack.viewContext

        try await context.perform {
            do {
                let routine = try self.fetchRoutine(id: routineId, context: context)
                guard let routineExercise = routine.orderedExercises.first(where: { $0.id == exerciseId }) else {
                    throw RoutineServiceError.exerciseNotFound(exerciseId)
                }

                routine.removeExercise(routineExercise)
                routine.updateEstimatedDuration()

                try context.save()

                Task { @MainActor in
                    await self.updateRoutinesPublisher()
                }
            } catch let error as RoutineServiceError {
                context.rollback()
                throw error
            } catch {
                context.rollback()
                throw RoutineServiceError.coreDataError(error)
            }
        }
    }

    public func reorderExercisesInRoutine(routineId: UUID, exerciseOrdering: [UUID]) async throws {
        let context = coreDataStack.viewContext

        try await context.perform {
            do {
                let routine = try self.fetchRoutine(id: routineId, context: context)
                routine.reorderExercises(exerciseOrdering)

                try context.save()

                Task { @MainActor in
                    await self.updateRoutinesPublisher()
                }
            } catch let error as RoutineServiceError {
                context.rollback()
                throw error
            } catch {
                context.rollback()
                throw RoutineServiceError.coreDataError(error)
            }
        }
    }

    // MARK: - Routine Usage

    public func createWorkoutFromRoutine(routineId: UUID, sessionName: String?, sessionNotes: String?) async throws -> WorkoutSession {
        do {
            let routine = try await getRoutine(routineId: routineId)

            // Create workout session
            let session = try await workoutRepository.createWorkoutSession(
                name: sessionName ?? routine.name,
                routineId: routineId,
                startDate: Date(),
                notes: sessionNotes
            )

            // Add exercises from routine
            for routineExercise in routine.orderedExercises {
                guard let exercise = routineExercise.exercise else { continue }

                _ = try await workoutRepository.addExercise(
                    sessionId: session.id,
                    exerciseId: exercise.id,
                    orderIndex: routineExercise.orderIndex,
                    restTimerDuration: routineExercise.restTime,
                    superset: routineExercise.superset,
                    notes: routineExercise.notes
                )
            }

            // Mark routine as used
            try await markRoutineAsUsed(routineId: routineId)

            return session
        } catch {
            throw mapToRoutineServiceError(error)
        }
    }

    public func markRoutineAsUsed(routineId: UUID) async throws {
        let context = coreDataStack.viewContext

        try await context.perform {
            do {
                let routine = try self.fetchRoutine(id: routineId, context: context)
                routine.markAsUsed()

                try context.save()

                Task { @MainActor in
                    await self.updateRoutineStatisticsPublisher()
                }
            } catch {
                context.rollback()
                throw RoutineServiceError.coreDataError(error)
            }
        }
    }

    // MARK: - Routine Analytics and Statistics

    public func getRoutineStatistics(routineId: UUID) async throws -> RoutineStatistics {
        let context = coreDataStack.viewContext

        return try await context.perform {
            do {
                let routine = try self.fetchRoutine(id: routineId, context: context)

                // Get related workout sessions
                let sessionStats = try self.getWorkoutSessionStatistics(routineId: routineId, context: context)

                return RoutineStatistics(
                    useCount: routine.useCount,
                    lastUsed: routine.lastUsed,
                    averageDuration: sessionStats.averageDuration,
                    averageVolume: sessionStats.averageVolume,
                    exerciseCount: routine.exerciseCount,
                    estimatedDuration: routine.estimatedDuration,
                    averageRPE: sessionStats.averageRPE,
                    personalRecordsAchieved: sessionStats.personalRecordsAchieved
                )
            } catch {
                throw RoutineServiceError.coreDataError(error)
            }
        }
    }

    public func getAllRoutineStatistics() async throws -> [UUID: RoutineStatistics] {
        let routines = try await getRoutines(filter: RoutineFilter(), sortBy: .nameAscending)
        var statistics: [UUID: RoutineStatistics] = [:]

        for routine in routines {
            let stats = try await getRoutineStatistics(routineId: routine.id)
            statistics[routine.id] = stats
        }

        return statistics
    }

    public func getMostUsedRoutines(limit: Int) async throws -> [Routine] {
        let filter = RoutineFilter(isArchived: false)
        let routines = try await getRoutines(filter: filter, sortBy: .useCountMost)
        return Array(routines.prefix(limit))
    }

    public func getRecentlyUsedRoutines(limit: Int) async throws -> [Routine] {
        let filter = RoutineFilter(isArchived: false)
        let routines = try await getRoutines(filter: filter, sortBy: .lastUsedRecent)
        return Array(routines.prefix(limit))
    }

    public func searchRoutines(searchText: String) async throws -> [Routine] {
        let filter = RoutineFilter(searchText: searchText, isArchived: false)
        return try await getRoutines(filter: filter, sortBy: .nameAscending)
    }

    // MARK: - Routine Validation

    public func validateRoutine(routineId: UUID) async throws -> [String] {
        let routine = try await getRoutine(routineId: routineId)
        var validationErrors: [String] = []

        if routine.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationErrors.append("Routine name cannot be empty")
        }

        if routine.exerciseCount == 0 {
            validationErrors.append("Routine must contain at least one exercise")
        }

        for routineExercise in routine.orderedExercises {
            if routineExercise.exercise == nil {
                validationErrors.append("Routine contains exercise with missing reference")
            }

            if routineExercise.targetSets <= 0 {
                validationErrors.append("All exercises must have target sets > 0")
            }

            if routineExercise.targetRepsArray.isEmpty {
                validationErrors.append("All exercises must have target reps specified")
            }
        }

        return validationErrors
    }

    public func estimateRoutineDuration(routineId: UUID) async throws -> TimeInterval {
        let routine = try await getRoutine(routineId: routineId)
        return routine.calculatedEstimatedDuration
    }

    // MARK: - Private Helper Methods

    private func setupPublisherSubscriptions() {
        // We can add subscriptions to repository changes here if needed
    }

    private func updateRoutinesPublisher() async {
        do {
            let routines = try await getRoutines(filter: RoutineFilter(), sortBy: .nameAscending)
            routinesUpdateSubject.send(routines)
        } catch {
            print("Failed to update routines publisher: \(error)")
        }
    }

    private func updateRoutineStatisticsPublisher() async {
        do {
            let statistics = try await getAllRoutineStatistics()
            routineStatisticsUpdateSubject.send(statistics)
        } catch {
            print("Failed to update routine statistics publisher: \(error)")
        }
    }

    private func fetchRoutine(id: UUID, context: NSManagedObjectContext) throws -> Routine {
        let request: NSFetchRequest<Routine> = Routine.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        do {
            guard let routine = try context.fetch(request).first else {
                throw RoutineServiceError.routineNotFound(id)
            }
            return routine
        } catch {
            throw RoutineServiceError.coreDataError(error)
        }
    }

    private func fetchExercise(id: UUID, context: NSManagedObjectContext) throws -> Exercise {
        let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        do {
            guard let exercise = try context.fetch(request).first else {
                throw RoutineServiceError.coreDataError(NSError(domain: "Exercise not found", code: 404))
            }
            return exercise
        } catch {
            throw RoutineServiceError.coreDataError(error)
        }
    }

    private func isRoutineNameTaken(_ name: String, context: NSManagedObjectContext) throws -> Bool {
        let request: NSFetchRequest<Routine> = Routine.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[cd] %@", name)
        request.fetchLimit = 1

        do {
            let count = try context.count(for: request)
            return count > 0
        } catch {
            throw RoutineServiceError.coreDataError(error)
        }
    }

    private func countWorkoutSessionsUsingRoutine(routineId: UUID, context: NSManagedObjectContext) throws -> Int {
        let request: NSFetchRequest<WorkoutSession> = WorkoutSession.fetchRequest()
        request.predicate = NSPredicate(format: "routineId == %@", routineId as CVarArg)

        do {
            return try context.count(for: request)
        } catch {
            throw RoutineServiceError.coreDataError(error)
        }
    }

    private func getWorkoutSessionStatistics(routineId: UUID, context: NSManagedObjectContext) throws -> (averageDuration: TimeInterval?, averageVolume: Double?, averageRPE: Double?, personalRecordsAchieved: Int) {
        let request: NSFetchRequest<WorkoutSession> = WorkoutSession.fetchRequest()
        request.predicate = NSPredicate(format: "routineId == %@ AND isCompleted == YES", routineId as CVarArg)

        do {
            let sessions = try context.fetch(request)

            guard !sessions.isEmpty else {
                return (nil, nil, nil, 0)
            }

            let totalDuration = sessions.compactMap { $0.endDate?.timeIntervalSince($0.startDate) }.reduce(0, +)
            let averageDuration = totalDuration / Double(sessions.count)

            let totalVolume = sessions.reduce(0.0) { $0 + $1.totalVolume }
            let averageVolume = totalVolume / Double(sessions.count)

            let totalRPE = sessions.compactMap { $0.averageRPE > 0 ? $0.averageRPE : nil }.reduce(0, +)
            let averageRPE = sessions.count > 0 ? totalRPE / Double(sessions.count) : nil

            // Personal records would need to be calculated with ProgressTrackingService
            let personalRecordsAchieved = 0

            return (averageDuration, averageVolume, averageRPE, personalRecordsAchieved)
        } catch {
            throw RoutineServiceError.coreDataError(error)
        }
    }

    private func sortDescriptors(for sortOption: RoutineSortOption) -> [NSSortDescriptor] {
        switch sortOption {
        case .nameAscending:
            return [NSSortDescriptor(keyPath: \Routine.name, ascending: true)]
        case .nameDescending:
            return [NSSortDescriptor(keyPath: \Routine.name, ascending: false)]
        case .lastUsedRecent:
            return [
                NSSortDescriptor(keyPath: \Routine.lastUsed, ascending: false),
                NSSortDescriptor(keyPath: \Routine.name, ascending: true)
            ]
        case .lastUsedOldest:
            return [
                NSSortDescriptor(keyPath: \Routine.lastUsed, ascending: true),
                NSSortDescriptor(keyPath: \Routine.name, ascending: true)
            ]
        case .useCountMost:
            return [
                NSSortDescriptor(keyPath: \Routine.useCount, ascending: false),
                NSSortDescriptor(keyPath: \Routine.name, ascending: true)
            ]
        case .useCountLeast:
            return [
                NSSortDescriptor(keyPath: \Routine.useCount, ascending: true),
                NSSortDescriptor(keyPath: \Routine.name, ascending: true)
            ]
        case .createdRecent:
            return [
                NSSortDescriptor(keyPath: \Routine.createdAt, ascending: false),
                NSSortDescriptor(keyPath: \Routine.name, ascending: true)
            ]
        case .createdOldest:
            return [
                NSSortDescriptor(keyPath: \Routine.createdAt, ascending: true),
                NSSortDescriptor(keyPath: \Routine.name, ascending: true)
            ]
        case .estimatedDurationShortest:
            return [
                NSSortDescriptor(keyPath: \Routine.estimatedDuration, ascending: true),
                NSSortDescriptor(keyPath: \Routine.name, ascending: true)
            ]
        case .estimatedDurationLongest:
            return [
                NSSortDescriptor(keyPath: \Routine.estimatedDuration, ascending: false),
                NSSortDescriptor(keyPath: \Routine.name, ascending: true)
            ]
        }
    }

    private func mapToRoutineServiceError(_ error: Error) -> RoutineServiceError {
        if let workoutRepoError = error as? WorkoutRepositoryError {
            return .coreDataError(workoutRepoError)
        } else if let exerciseRepoError = error as? ExerciseRepositoryError {
            return .coreDataError(exerciseRepoError)
        } else {
            return .coreDataError(error)
        }
    }
}