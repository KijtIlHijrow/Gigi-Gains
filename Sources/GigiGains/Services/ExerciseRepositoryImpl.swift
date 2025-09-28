//
//  ExerciseRepositoryImpl.swift
//  Gigi Gains
//
//  Core Data implementation of ExerciseRepository protocol providing
//  exercise library management, custom exercises, and analytics.
//
//  Created: 2025-09-28
//

import Foundation
import CoreData
import Combine

public class ExerciseRepositoryImpl: ExerciseRepository {

    // MARK: - Properties

    private let coreDataStack: CoreDataStack
    private let exercisesChangedSubject = PassthroughSubject<Void, Never>()
    private let exerciseUsageChangedSubject = PassthroughSubject<Void, Never>()

    // MARK: - Publishers

    public var exercisesChangedPublisher: AnyPublisher<Void, Never> {
        exercisesChangedSubject.eraseToAnyPublisher()
    }

    public var exerciseUsageChangedPublisher: AnyPublisher<Void, Never> {
        exerciseUsageChangedSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    public init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }

    // MARK: - Exercise CRUD Operations

    public func createExercise(config: ExerciseCreationConfig) async throws -> Exercise {
        let context = coreDataStack.viewContext

        return try await context.perform {
            // Check for duplicate name
            let existingExercise = try self.fetchExerciseByName(config.name, context: context)
            if existingExercise != nil {
                throw ExerciseRepositoryError.duplicateExerciseName(config.name)
            }

            // Create new exercise
            let exercise = Exercise(context: context)
            exercise.name = config.name
            exercise.category = config.category
            exercise.primaryMuscleGroupsArray = config.primaryMuscleGroups
            exercise.secondaryMuscleGroupsArray = config.secondaryMuscleGroups
            exercise.equipment = config.equipment
            exercise.instructions = config.instructions
            exercise.defaultRestTime = config.defaultRestTime
            exercise.isCustom = config.isCustom
            exercise.isArchived = false

            do {
                try exercise.validate()
                try context.save()
                self.exercisesChangedSubject.send()
                return exercise
            } catch {
                context.rollback()
                throw ExerciseRepositoryError.saveContextFailed(error)
            }
        }
    }

    public func fetchExercise(id: UUID) async throws -> Exercise {
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            do {
                let exercises = try context.fetch(request)
                guard let exercise = exercises.first else {
                    throw ExerciseRepositoryError.objectNotFound(id)
                }
                return exercise
            } catch let error as ExerciseRepositoryError {
                throw error
            } catch {
                throw ExerciseRepositoryError.fetchRequestFailed(error)
            }
        }
    }

    public func fetchExercise(name: String) async throws -> Exercise {
        let context = coreDataStack.viewContext

        return try await context.perform {
            guard let exercise = try self.fetchExerciseByName(name, context: context) else {
                throw ExerciseRepositoryError.objectNotFound(UUID()) // Name-based lookup
            }
            return exercise
        }
    }

    public func fetchExercises(filter: ExerciseQueryFilter, sortBy: ExerciseSortOption, options: ExerciseFetchOptions) async throws -> [Exercise] {
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()

            // Apply filter
            request.predicate = filter.predicate

            // Apply sorting
            request.sortDescriptors = sortBy.sortDescriptors

            // Apply fetch options
            if let limit = options.limit {
                request.fetchLimit = limit
            }

            if let offset = options.offset {
                request.fetchOffset = offset
            }

            if !options.prefetchRelationships.isEmpty {
                request.relationshipKeyPathsForPrefetching = options.prefetchRelationships
            }

            request.returnsObjectsAsFaults = options.returnsObjectsAsFaults

            do {
                return try context.fetch(request)
            } catch {
                throw ExerciseRepositoryError.fetchRequestFailed(error)
            }
        }
    }

    public func fetchAllExercises() async throws -> [Exercise] {
        let filter = ExerciseQueryFilter()
        let options = ExerciseFetchOptions()
        return try await fetchExercises(filter: filter, sortBy: .nameAscending, options: options)
    }

    public func updateExercise(_ exercise: Exercise, config: ExerciseCreationConfig) async throws {
        let context = coreDataStack.viewContext

        try await context.perform {
            // Prevent modification of pre-built exercises
            if !exercise.isCustom {
                throw ExerciseRepositoryError.cannotModifyPreBuiltExercise(exercise.id)
            }

            // Check for duplicate name (excluding current exercise)
            if exercise.name != config.name {
                let existingExercise = try self.fetchExerciseByName(config.name, context: context)
                if existingExercise != nil && existingExercise!.id != exercise.id {
                    throw ExerciseRepositoryError.duplicateExerciseName(config.name)
                }
            }

            // Update properties
            exercise.name = config.name
            exercise.category = config.category
            exercise.primaryMuscleGroupsArray = config.primaryMuscleGroups
            exercise.secondaryMuscleGroupsArray = config.secondaryMuscleGroups
            exercise.equipment = config.equipment
            exercise.instructions = config.instructions
            exercise.defaultRestTime = config.defaultRestTime

            do {
                try exercise.validate()
                try context.save()
                self.exercisesChangedSubject.send()
            } catch {
                context.rollback()
                throw ExerciseRepositoryError.saveContextFailed(error)
            }
        }
    }

    public func archiveExercise(_ exercise: Exercise, isArchived: Bool) async throws {
        let context = coreDataStack.viewContext

        try await context.perform {
            // Prevent archiving of pre-built exercises
            if !exercise.isCustom {
                throw ExerciseRepositoryError.cannotModifyPreBuiltExercise(exercise.id)
            }

            exercise.isArchived = isArchived

            do {
                try context.save()
                self.exercisesChangedSubject.send()
            } catch {
                context.rollback()
                throw ExerciseRepositoryError.saveContextFailed(error)
            }
        }
    }

    public func deleteExercise(_ exercise: Exercise) async throws {
        let context = coreDataStack.viewContext

        try await context.perform {
            // Prevent deletion of pre-built exercises
            if !exercise.isCustom {
                throw ExerciseRepositoryError.cannotModifyPreBuiltExercise(exercise.id)
            }

            // Check if exercise is in use
            let routineCount = exercise.routineExercises?.count ?? 0
            let sessionCount = exercise.workoutExercises?.count ?? 0

            if routineCount > 0 || sessionCount > 0 {
                throw ExerciseRepositoryError.exerciseInUse(routinesCount: routineCount, sessionsCount: sessionCount)
            }

            // Delete the exercise
            context.delete(exercise)

            do {
                try context.save()
                self.exercisesChangedSubject.send()
            } catch {
                context.rollback()
                throw ExerciseRepositoryError.saveContextFailed(error)
            }
        }
    }

    public func isExerciseNameAvailable(_ name: String) async throws -> Bool {
        let context = coreDataStack.viewContext

        return try await context.perform {
            return try self.fetchExerciseByName(name, context: context) == nil
        }
    }

    // MARK: - Batch Operations

    public func createExercises(configs: [ExerciseCreationConfig], batchConfig: ExerciseBatchOperationConfig) async throws -> [Exercise] {
        let context = coreDataStack.viewContext
        var createdExercises: [Exercise] = []

        return try await context.perform {
            // Process in batches
            for batch in configs.chunked(into: batchConfig.batchSize) {
                for config in batch {
                    // Check for duplicates
                    if try self.fetchExerciseByName(config.name, context: context) != nil {
                        throw ExerciseRepositoryError.duplicateExerciseName(config.name)
                    }

                    let exercise = Exercise(context: context)
                    exercise.name = config.name
                    exercise.category = config.category
                    exercise.primaryMuscleGroupsArray = config.primaryMuscleGroups
                    exercise.secondaryMuscleGroupsArray = config.secondaryMuscleGroups
                    exercise.equipment = config.equipment
                    exercise.instructions = config.instructions
                    exercise.defaultRestTime = config.defaultRestTime
                    exercise.isCustom = config.isCustom
                    exercise.isArchived = false

                    try exercise.validate()
                    createdExercises.append(exercise)
                }

                // Save batch
                do {
                    try context.save()
                } catch {
                    context.rollback()
                    throw ExerciseRepositoryError.saveContextFailed(error)
                }
            }

            self.exercisesChangedSubject.send()
            return createdExercises
        }
    }

    public func updateExercises(updates: [UUID: ExerciseCreationConfig], batchConfig: ExerciseBatchOperationConfig) async throws -> Int {
        let context = coreDataStack.viewContext
        var updatedCount = 0

        return try await context.perform {
            let exerciseIds = Array(updates.keys)

            // Process in batches
            for batch in exerciseIds.chunked(into: batchConfig.batchSize) {
                let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
                request.predicate = NSPredicate(format: "id IN %@", batch)

                do {
                    let exercises = try context.fetch(request)

                    for exercise in exercises {
                        guard let config = updates[exercise.id] else { continue }

                        // Skip pre-built exercises
                        if !exercise.isCustom {
                            continue
                        }

                        exercise.name = config.name
                        exercise.category = config.category
                        exercise.primaryMuscleGroupsArray = config.primaryMuscleGroups
                        exercise.secondaryMuscleGroupsArray = config.secondaryMuscleGroups
                        exercise.equipment = config.equipment
                        exercise.instructions = config.instructions
                        exercise.defaultRestTime = config.defaultRestTime

                        try exercise.validate()
                        updatedCount += 1
                    }

                    try context.save()
                } catch {
                    context.rollback()
                    throw ExerciseRepositoryError.batchUpdateFailed(error)
                }
            }

            if updatedCount > 0 {
                self.exercisesChangedSubject.send()
            }

            return updatedCount
        }
    }

    public func archiveExercises(ids exerciseIds: [UUID], isArchived: Bool, batchConfig: ExerciseBatchOperationConfig) async throws -> Int {
        let context = coreDataStack.viewContext
        var archivedCount = 0

        return try await context.perform {
            // Process in batches
            for batch in exerciseIds.chunked(into: batchConfig.batchSize) {
                let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
                request.predicate = NSPredicate(format: "id IN %@ AND isCustom == YES", batch)

                do {
                    let exercises = try context.fetch(request)

                    for exercise in exercises {
                        exercise.isArchived = isArchived
                        archivedCount += 1
                    }

                    try context.save()
                } catch {
                    context.rollback()
                    throw ExerciseRepositoryError.batchUpdateFailed(error)
                }
            }

            if archivedCount > 0 {
                self.exercisesChangedSubject.send()
            }

            return archivedCount
        }
    }

    // MARK: - Exercise Categories and Muscle Groups

    public func fetchExerciseCategories() async throws -> [String] {
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
            request.resultType = .dictionaryResultType
            request.propertiesToFetch = ["category"]
            request.returnsDistinctResults = true
            request.predicate = NSPredicate(format: "isArchived == NO")

            do {
                let results = try context.fetch(request) as! [[String: Any]]
                return results.compactMap { $0["category"] as? String }.sorted()
            } catch {
                throw ExerciseRepositoryError.fetchRequestFailed(error)
            }
        }
    }

    public func fetchMuscleGroups() async throws -> [String] {
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
            request.predicate = NSPredicate(format: "isArchived == NO")

            do {
                let exercises = try context.fetch(request)
                var muscleGroups = Set<String>()

                for exercise in exercises {
                    muscleGroups.formUnion(exercise.primaryMuscleGroupsArray)
                    muscleGroups.formUnion(exercise.secondaryMuscleGroupsArray)
                }

                return Array(muscleGroups).sorted()
            } catch {
                throw ExerciseRepositoryError.fetchRequestFailed(error)
            }
        }
    }

    public func fetchEquipmentTypes() async throws -> [String] {
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
            request.resultType = .dictionaryResultType
            request.propertiesToFetch = ["equipment"]
            request.returnsDistinctResults = true
            request.predicate = NSPredicate(format: "isArchived == NO")

            do {
                let results = try context.fetch(request) as! [[String: Any]]
                return results.compactMap { $0["equipment"] as? String }.sorted()
            } catch {
                throw ExerciseRepositoryError.fetchRequestFailed(error)
            }
        }
    }

    public func fetchExercisesGroupedByCategory() async throws -> [String: [Exercise]] {
        let exercises = try await fetchAllExercises()
        let activeExercises = exercises.filter { !$0.isArchived }
        return Dictionary(grouping: activeExercises) { $0.category }
    }

    public func fetchExercisesGroupedByMuscleGroup() async throws -> [String: [Exercise]] {
        let exercises = try await fetchAllExercises()
        let activeExercises = exercises.filter { !$0.isArchived }

        var groupedExercises: [String: [Exercise]] = [:]

        for exercise in activeExercises {
            for muscleGroup in exercise.primaryMuscleGroupsArray {
                groupedExercises[muscleGroup, default: []].append(exercise)
            }
        }

        return groupedExercises
    }

    public func fetchExercisesForEquipment(_ equipmentTypes: [String]) async throws -> [Exercise] {
        let filter = ExerciseQueryFilter(equipment: nil, isArchived: false)
        let options = ExerciseFetchOptions()

        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "equipment IN %@", equipmentTypes),
                NSPredicate(format: "isArchived == NO")
            ])
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Exercise.name, ascending: true)]

            do {
                return try context.fetch(request)
            } catch {
                throw ExerciseRepositoryError.fetchRequestFailed(error)
            }
        }
    }

    // MARK: - Exercise Search and Discovery

    public func searchExercisesByName(_ searchText: String) async throws -> [Exercise] {
        let filter = ExerciseQueryFilter(nameContains: searchText, isArchived: false)
        let options = ExerciseFetchOptions()
        return try await fetchExercises(filter: filter, sortBy: .nameAscending, options: options)
    }

    public func searchExercises(_ searchText: String) async throws -> [Exercise] {
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()

            let predicates = [
                NSPredicate(format: "name CONTAINS[cd] %@", searchText),
                NSPredicate(format: "category CONTAINS[cd] %@", searchText),
                NSPredicate(format: "primaryMuscleGroups CONTAINS[cd] %@", searchText),
                NSPredicate(format: "secondaryMuscleGroups CONTAINS[cd] %@", searchText)
            ]

            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSCompoundPredicate(orPredicateWithSubpredicates: predicates),
                NSPredicate(format: "isArchived == NO")
            ])

            request.sortDescriptors = [NSSortDescriptor(keyPath: \Exercise.name, ascending: true)]

            do {
                return try context.fetch(request)
            } catch {
                throw ExerciseRepositoryError.fetchRequestFailed(error)
            }
        }
    }

    public func suggestExercises(muscleGroups: [String], excludeIds: [UUID], limit: Int) async throws -> [Exercise] {
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()

            var predicates: [NSPredicate] = [
                NSPredicate(format: "isArchived == NO")
            ]

            if !excludeIds.isEmpty {
                predicates.append(NSPredicate(format: "NOT (id IN %@)", excludeIds))
            }

            if !muscleGroups.isEmpty {
                let muscleGroupPredicates = muscleGroups.map { muscleGroup in
                    NSPredicate(format: "primaryMuscleGroups CONTAINS[cd] %@ OR secondaryMuscleGroups CONTAINS[cd] %@", muscleGroup, muscleGroup)
                }
                predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: muscleGroupPredicates))
            }

            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Exercise.name, ascending: true)]
            request.fetchLimit = limit

            do {
                return try context.fetch(request)
            } catch {
                throw ExerciseRepositoryError.fetchRequestFailed(error)
            }
        }
    }

    public func getComplementaryExercises(for exercise: Exercise, limit: Int) async throws -> [Exercise] {
        // Find exercises that work opposing muscle groups or different movement patterns
        let primaryMuscleGroups = exercise.primaryMuscleGroupsArray
        let complementaryMuscleGroups = getComplementaryMuscleGroups(for: primaryMuscleGroups)

        return try await suggestExercises(
            muscleGroups: complementaryMuscleGroups,
            excludeIds: [exercise.id],
            limit: limit
        )
    }

    public func getSimilarExercises(to exercise: Exercise, limit: Int) async throws -> [Exercise] {
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()

            let predicates: [NSPredicate] = [
                NSPredicate(format: "id != %@", exercise.id as CVarArg),
                NSPredicate(format: "isArchived == NO"),
                NSPredicate(format: "category == %@ OR equipment == %@", exercise.category, exercise.equipment)
            ]

            // Add muscle group similarity
            let muscleGroupPredicates = exercise.primaryMuscleGroupsArray.map { muscleGroup in
                NSPredicate(format: "primaryMuscleGroups CONTAINS[cd] %@", muscleGroup)
            }

            if !muscleGroupPredicates.isEmpty {
                predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: muscleGroupPredicates))
            }

            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Exercise.name, ascending: true)]
            request.fetchLimit = limit

            do {
                return try context.fetch(request)
            } catch {
                throw ExerciseRepositoryError.fetchRequestFailed(error)
            }
        }
    }

    // MARK: - Custom Exercise Management

    public func fetchCustomExercises() async throws -> [Exercise] {
        let filter = ExerciseQueryFilter(isCustom: true, isArchived: false)
        let options = ExerciseFetchOptions()
        return try await fetchExercises(filter: filter, sortBy: .createdAtDescending, options: options)
    }

    public func fetchRecentCustomExercises(days: Int) async throws -> [Exercise] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let filter = ExerciseQueryFilter(isCustom: true, isArchived: false, createdAfter: cutoffDate)
        let options = ExerciseFetchOptions()
        return try await fetchExercises(filter: filter, sortBy: .createdAtDescending, options: options)
    }

    public func countCustomExercises() async throws -> Int {
        let filter = ExerciseQueryFilter(isCustom: true, isArchived: false)
        return try await countExercises(filter: filter)
    }

    public func validateExerciseConfig(_ config: ExerciseCreationConfig) async -> [String] {
        var errors: [String] = []

        if config.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Exercise name cannot be empty")
        }

        if config.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Exercise category cannot be empty")
        }

        if config.primaryMuscleGroups.isEmpty {
            errors.append("At least one primary muscle group is required")
        }

        if config.equipment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Equipment type cannot be empty")
        }

        if config.defaultRestTime < 0 {
            errors.append("Default rest time cannot be negative")
        }

        // Check for existing name
        do {
            let isAvailable = try await isExerciseNameAvailable(config.name)
            if !isAvailable {
                errors.append("An exercise with this name already exists")
            }
        } catch {
            errors.append("Could not validate exercise name uniqueness")
        }

        return errors
    }

    // MARK: - Exercise Usage and Analytics

    public func recordExerciseUsage(exerciseId: UUID) async throws {
        let context = coreDataStack.viewContext

        try await context.perform {
            let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", exerciseId as CVarArg)
            request.fetchLimit = 1

            do {
                guard let exercise = try context.fetch(request).first else {
                    return // Exercise not found, silently ignore
                }

                exercise.lastUsed = Date()
                try context.save()

                self.exerciseUsageChangedSubject.send()
            } catch {
                throw ExerciseRepositoryError.saveContextFailed(error)
            }
        }
    }

    public func getExerciseUsageStats(exerciseId: UUID) async throws -> ExerciseUsageStats {
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", exerciseId as CVarArg)
            request.fetchLimit = 1
            request.relationshipKeyPathsForPrefetching = ["workoutExercises", "routineExercises", "personalRecords"]

            do {
                guard let exercise = try context.fetch(request).first else {
                    throw ExerciseRepositoryError.objectNotFound(exerciseId)
                }

                let workoutExercises = exercise.workoutExercises?.allObjects as? [WorkoutExercise] ?? []
                let routineExercises = exercise.routineExercises?.allObjects as? [RoutineExercise] ?? []
                let personalRecords = exercise.personalRecords?.allObjects as? [PersonalRecord] ?? []

                // Calculate statistics
                let weights = workoutExercises.compactMap { workoutExercise in
                    (workoutExercise.sets?.allObjects as? [ExerciseSet])?.compactMap { $0.weight }
                }.flatMap { $0 }

                let reps = workoutExercises.compactMap { workoutExercise in
                    (workoutExercise.sets?.allObjects as? [ExerciseSet])?.compactMap { $0.reps }
                }.flatMap { $0 }

                let rpes = workoutExercises.compactMap { workoutExercise in
                    (workoutExercise.sets?.allObjects as? [ExerciseSet])?.compactMap { $0.rpe }
                }.flatMap { $0 }

                return ExerciseUsageStats(
                    exerciseId: exerciseId,
                    exerciseName: exercise.name,
                    totalUsageCount: workoutExercises.count + routineExercises.count,
                    routineUsageCount: routineExercises.count,
                    sessionUsageCount: workoutExercises.count,
                    lastUsedDate: exercise.lastUsed,
                    averageWeight: weights.isEmpty ? nil : weights.reduce(0, +) / Double(weights.count),
                    averageReps: reps.isEmpty ? nil : Double(reps.reduce(0, +)) / Double(reps.count),
                    averageRPE: rpes.isEmpty ? nil : rpes.reduce(0, +) / Double(rpes.count),
                    personalRecordsCount: personalRecords.count
                )
            } catch let error as ExerciseRepositoryError {
                throw error
            } catch {
                throw ExerciseRepositoryError.fetchRequestFailed(error)
            }
        }
    }

    public func getExerciseUsageStats(exerciseIds: [UUID]) async throws -> [UUID: ExerciseUsageStats] {
        var stats: [UUID: ExerciseUsageStats] = [:]

        for exerciseId in exerciseIds {
            do {
                let stat = try await getExerciseUsageStats(exerciseId: exerciseId)
                stats[exerciseId] = stat
            } catch ExerciseRepositoryError.objectNotFound {
                // Skip missing exercises
                continue
            }
        }

        return stats
    }

    public func getMostPopularExercises(limit: Int) async throws -> [Exercise] {
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
            request.predicate = NSPredicate(format: "isArchived == NO")
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \Exercise.workoutExercises, ascending: false),
                NSSortDescriptor(keyPath: \Exercise.name, ascending: true)
            ]
            request.fetchLimit = limit

            do {
                return try context.fetch(request)
            } catch {
                throw ExerciseRepositoryError.fetchRequestFailed(error)
            }
        }
    }

    public func getRecentlyUsedExercises(limit: Int) async throws -> [Exercise] {
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "isArchived == NO"),
                NSPredicate(format: "lastUsed != nil")
            ])
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \Exercise.lastUsed, ascending: false),
                NSSortDescriptor(keyPath: \Exercise.name, ascending: true)
            ]
            request.fetchLimit = limit

            do {
                return try context.fetch(request)
            } catch {
                throw ExerciseRepositoryError.fetchRequestFailed(error)
            }
        }
    }

    public func getUnusedExercises() async throws -> [Exercise] {
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "isArchived == NO"),
                NSPredicate(format: "workoutExercises.@count == 0"),
                NSPredicate(format: "routineExercises.@count == 0")
            ])
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Exercise.name, ascending: true)]

            do {
                return try context.fetch(request)
            } catch {
                throw ExerciseRepositoryError.fetchRequestFailed(error)
            }
        }
    }

    // MARK: - Pre-built Exercise Library Management

    public func initializePreBuiltExerciseLibrary() async throws -> Int {
        let context = coreDataStack.backgroundContext
        var createdCount = 0

        return try await context.perform {
            let preBuiltExercises = self.getPreBuiltExerciseData()

            for exerciseData in preBuiltExercises {
                let config = ExerciseCreationConfig(
                    name: exerciseData.name,
                    category: exerciseData.category,
                    primaryMuscleGroups: exerciseData.primaryMuscleGroups,
                    secondaryMuscleGroups: exerciseData.secondaryMuscleGroups,
                    equipment: exerciseData.equipment,
                    instructions: exerciseData.instructions,
                    defaultRestTime: exerciseData.defaultRestTime,
                    isCustom: false
                )

                // Check if exercise already exists
                if try self.fetchExerciseByName(config.name, context: context) == nil {
                    let exercise = Exercise(context: context)
                    exercise.name = config.name
                    exercise.category = config.category
                    exercise.primaryMuscleGroupsArray = config.primaryMuscleGroups
                    exercise.secondaryMuscleGroupsArray = config.secondaryMuscleGroups
                    exercise.equipment = config.equipment
                    exercise.instructions = config.instructions
                    exercise.defaultRestTime = config.defaultRestTime
                    exercise.isCustom = false
                    exercise.isArchived = false

                    try exercise.validate()
                    createdCount += 1
                }
            }

            try context.save()
            self.exercisesChangedSubject.send()
            return createdCount
        }
    }

    public func isPreBuiltLibraryInitialized() async throws -> Bool {
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
            request.predicate = NSPredicate(format: "isCustom == NO")
            request.fetchLimit = 1

            do {
                let count = try context.count(for: request)
                return count > 0
            } catch {
                throw ExerciseRepositoryError.fetchRequestFailed(error)
            }
        }
    }

    public func getPreBuiltLibraryVersion() async throws -> String {
        return "1.0.0" // Version of pre-built exercise library
    }

    public func updatePreBuiltLibraryToVersion(_ version: String) async throws -> Int {
        // For now, just reinitialize the library
        return try await initializePreBuiltExerciseLibrary()
    }

    public func fetchPreBuiltExercises() async throws -> [Exercise] {
        let filter = ExerciseQueryFilter(isCustom: false, isArchived: false)
        let options = ExerciseFetchOptions()
        return try await fetchExercises(filter: filter, sortBy: .categoryThenName, options: options)
    }

    public func validatePreBuiltLibrary() async throws -> [String] {
        var validationErrors: [String] = []

        let preBuiltExercises = try await fetchPreBuiltExercises()
        let expectedExercises = getPreBuiltExerciseData()

        if preBuiltExercises.count < expectedExercises.count {
            validationErrors.append("Missing pre-built exercises: expected \(expectedExercises.count), found \(preBuiltExercises.count)")
        }

        for exercise in preBuiltExercises {
            let errors = await validateExercise(exercise)
            validationErrors.append(contentsOf: errors)
        }

        return validationErrors
    }

    // MARK: - Data Integrity and Validation

    public func validateExercise(_ exercise: Exercise) async -> [String] {
        var errors: [String] = []

        if exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Exercise \(exercise.id): Name cannot be empty")
        }

        if exercise.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Exercise \(exercise.id): Category cannot be empty")
        }

        if exercise.primaryMuscleGroupsArray.isEmpty {
            errors.append("Exercise \(exercise.id): Must have at least one primary muscle group")
        }

        if exercise.equipment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Exercise \(exercise.id): Equipment type cannot be empty")
        }

        if exercise.defaultRestTime < 0 {
            errors.append("Exercise \(exercise.id): Default rest time cannot be negative")
        }

        return errors
    }

    public func findExercisesWithInvalidMuscleGroups() async throws -> [Exercise] {
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()

            do {
                let exercises = try context.fetch(request)
                return exercises.filter { exercise in
                    // Check if muscle group JSON is invalid
                    guard let primaryData = exercise.primaryMuscleGroups?.data(using: .utf8),
                          let secondaryData = exercise.secondaryMuscleGroups?.data(using: .utf8) else {
                        return true
                    }

                    do {
                        _ = try JSONDecoder().decode([String].self, from: primaryData)
                        _ = try JSONDecoder().decode([String].self, from: secondaryData)
                        return false
                    } catch {
                        return true
                    }
                }
            } catch {
                throw ExerciseRepositoryError.fetchRequestFailed(error)
            }
        }
    }

    public func fixInvalidMuscleGroupData() async throws -> Int {
        let invalidExercises = try await findExercisesWithInvalidMuscleGroups()
        let context = coreDataStack.viewContext

        return try await context.perform {
            var fixedCount = 0

            for exercise in invalidExercises {
                // Reset to empty arrays if invalid
                exercise.primaryMuscleGroupsArray = []
                exercise.secondaryMuscleGroupsArray = []
                fixedCount += 1
            }

            if fixedCount > 0 {
                do {
                    try context.save()
                    self.exercisesChangedSubject.send()
                } catch {
                    context.rollback()
                    throw ExerciseRepositoryError.saveContextFailed(error)
                }
            }

            return fixedCount
        }
    }

    public func findDuplicateExerciseNames() async throws -> [String: [UUID]] {
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()

            do {
                let exercises = try context.fetch(request)
                let groupedByName = Dictionary(grouping: exercises) { $0.name.lowercased() }

                var duplicates: [String: [UUID]] = [:]
                for (name, exercisesArray) in groupedByName {
                    if exercisesArray.count > 1 {
                        duplicates[name] = exercisesArray.map { $0.id }
                    }
                }

                return duplicates
            } catch {
                throw ExerciseRepositoryError.fetchRequestFailed(error)
            }
        }
    }

    public func findOrphanedExercises() async throws -> [Exercise] {
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "isCustom == YES"),
                NSPredicate(format: "workoutExercises.@count == 0"),
                NSPredicate(format: "routineExercises.@count == 0"),
                NSPredicate(format: "personalRecords.@count == 0")
            ])

            do {
                return try context.fetch(request)
            } catch {
                throw ExerciseRepositoryError.fetchRequestFailed(error)
            }
        }
    }

    // MARK: - Background Operations

    public func performBackgroundOperation(_ operation: @escaping (NSManagedObjectContext) throws -> Void) async throws {
        let context = coreDataStack.backgroundContext

        try await context.perform {
            do {
                try operation(context)
            } catch {
                throw ExerciseRepositoryError.backgroundContextError(error)
            }
        }
    }

    public func saveBackgroundContext(_ context: NSManagedObjectContext) async throws {
        try await context.perform {
            do {
                try context.save()
            } catch {
                throw ExerciseRepositoryError.saveContextFailed(error)
            }
        }
    }

    // MARK: - Performance and Statistics

    public func getDatabaseStatistics() async throws -> [String: Any] {
        let context = coreDataStack.viewContext

        return try await context.perform {
            let exerciseRequest: NSFetchRequest<Exercise> = Exercise.fetchRequest()

            do {
                let totalExercises = try context.count(for: exerciseRequest)

                let customRequest = exerciseRequest.copy() as! NSFetchRequest<Exercise>
                customRequest.predicate = NSPredicate(format: "isCustom == YES")
                let customExercises = try context.count(for: customRequest)

                let archivedRequest = exerciseRequest.copy() as! NSFetchRequest<Exercise>
                archivedRequest.predicate = NSPredicate(format: "isArchived == YES")
                let archivedExercises = try context.count(for: archivedRequest)

                return [
                    "totalExercises": totalExercises,
                    "customExercises": customExercises,
                    "preBuiltExercises": totalExercises - customExercises,
                    "archivedExercises": archivedExercises,
                    "activeExercises": totalExercises - archivedExercises
                ]
            } catch {
                throw ExerciseRepositoryError.fetchRequestFailed(error)
            }
        }
    }

    public func countExercises(filter: ExerciseQueryFilter) async throws -> Int {
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
            request.predicate = filter.predicate

            do {
                return try context.count(for: request)
            } catch {
                throw ExerciseRepositoryError.fetchRequestFailed(error)
            }
        }
    }

    public func estimateMemoryUsage() async -> Int64 {
        // Simple estimation based on loaded objects
        let context = coreDataStack.viewContext
        let registeredObjects = context.registeredObjects
        let exerciseObjects = registeredObjects.compactMap { $0 as? Exercise }

        // Rough estimate: 1KB per exercise object
        return Int64(exerciseObjects.count * 1024)
    }

    public func refreshObjects(olderThan: Date) async {
        let context = coreDataStack.viewContext

        await context.perform {
            let registeredObjects = context.registeredObjects

            for object in registeredObjects {
                if let exercise = object as? Exercise,
                   exercise.modifiedAt < olderThan {
                    context.refresh(exercise, mergeChanges: false)
                }
            }
        }
    }

    // MARK: - Private Helper Methods

    private func fetchExerciseByName(_ name: String, context: NSManagedObjectContext) throws -> Exercise? {
        let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[cd] %@", name)
        request.fetchLimit = 1

        do {
            return try context.fetch(request).first
        } catch {
            throw ExerciseRepositoryError.fetchRequestFailed(error)
        }
    }

    private func getComplementaryMuscleGroups(for primaryGroups: [String]) -> [String] {
        let complementaryMap: [String: [String]] = [
            "Chest": ["Back", "Rear Delts"],
            "Back": ["Chest", "Front Delts"],
            "Shoulders": ["Back"],
            "Biceps": ["Triceps"],
            "Triceps": ["Biceps"],
            "Quadriceps": ["Hamstrings", "Glutes"],
            "Hamstrings": ["Quadriceps"],
            "Calves": ["Shins"],
            "Abs": ["Lower Back"],
            "Lower Back": ["Abs"]
        ]

        var complementary: [String] = []
        for group in primaryGroups {
            if let complements = complementaryMap[group] {
                complementary.append(contentsOf: complements)
            }
        }

        return Array(Set(complementary)) // Remove duplicates
    }

    private func getPreBuiltExerciseData() -> [ExerciseCreationConfig] {
        return [
            // Chest Exercises
            ExerciseCreationConfig(name: "Bench Press", category: "Compound", primaryMuscleGroups: ["Chest"], secondaryMuscleGroups: ["Triceps", "Front Delts"], equipment: "Barbell", instructions: "Lie on bench, grip bar shoulder-width apart, lower to chest, press up.", defaultRestTime: 180, isCustom: false),
            ExerciseCreationConfig(name: "Incline Bench Press", category: "Compound", primaryMuscleGroups: ["Chest"], secondaryMuscleGroups: ["Triceps", "Front Delts"], equipment: "Barbell", instructions: "Set bench to 30-45 degrees, perform bench press motion.", defaultRestTime: 180, isCustom: false),
            ExerciseCreationConfig(name: "Dumbbell Bench Press", category: "Compound", primaryMuscleGroups: ["Chest"], secondaryMuscleGroups: ["Triceps", "Front Delts"], equipment: "Dumbbell", instructions: "Lie on bench with dumbbells, press from chest level to arms extended.", defaultRestTime: 180, isCustom: false),
            ExerciseCreationConfig(name: "Push-ups", category: "Bodyweight", primaryMuscleGroups: ["Chest"], secondaryMuscleGroups: ["Triceps", "Front Delts"], equipment: "Bodyweight", instructions: "Start in plank position, lower chest to ground, push back up.", defaultRestTime: 60, isCustom: false),
            ExerciseCreationConfig(name: "Chest Flyes", category: "Isolation", primaryMuscleGroups: ["Chest"], secondaryMuscleGroups: [], equipment: "Dumbbell", instructions: "Lie on bench, arms extended, lower dumbbells in arc motion, squeeze chest.", defaultRestTime: 90, isCustom: false),

            // Back Exercises
            ExerciseCreationConfig(name: "Deadlift", category: "Compound", primaryMuscleGroups: ["Back"], secondaryMuscleGroups: ["Hamstrings", "Glutes", "Traps"], equipment: "Barbell", instructions: "Stand with bar over mid-foot, bend at hips and knees, lift with straight back.", defaultRestTime: 180, isCustom: false),
            ExerciseCreationConfig(name: "Pull-ups", category: "Compound", primaryMuscleGroups: ["Back"], secondaryMuscleGroups: ["Biceps", "Rear Delts"], equipment: "Bodyweight", instructions: "Hang from bar, pull body up until chin over bar, lower with control.", defaultRestTime: 120, isCustom: false),
            ExerciseCreationConfig(name: "Bent-over Row", category: "Compound", primaryMuscleGroups: ["Back"], secondaryMuscleGroups: ["Biceps", "Rear Delts"], equipment: "Barbell", instructions: "Bend forward at hips, pull bar to lower chest, squeeze shoulder blades.", defaultRestTime: 120, isCustom: false),
            ExerciseCreationConfig(name: "Lat Pulldown", category: "Compound", primaryMuscleGroups: ["Back"], secondaryMuscleGroups: ["Biceps"], equipment: "Cable", instructions: "Pull bar down to upper chest, squeeze lats, control the return.", defaultRestTime: 90, isCustom: false),
            ExerciseCreationConfig(name: "Seated Cable Row", category: "Compound", primaryMuscleGroups: ["Back"], secondaryMuscleGroups: ["Biceps", "Rear Delts"], equipment: "Cable", instructions: "Pull handle to torso, squeeze shoulder blades, keep back straight.", defaultRestTime: 90, isCustom: false),

            // Leg Exercises
            ExerciseCreationConfig(name: "Squat", category: "Compound", primaryMuscleGroups: ["Quadriceps"], secondaryMuscleGroups: ["Glutes", "Hamstrings"], equipment: "Barbell", instructions: "Stand with bar on shoulders, descend by bending knees and hips, drive up.", defaultRestTime: 180, isCustom: false),
            ExerciseCreationConfig(name: "Romanian Deadlift", category: "Compound", primaryMuscleGroups: ["Hamstrings"], secondaryMuscleGroups: ["Glutes", "Lower Back"], equipment: "Barbell", instructions: "Stand with bar, hinge at hips keeping legs straight, feel hamstring stretch.", defaultRestTime: 120, isCustom: false),
            ExerciseCreationConfig(name: "Leg Press", category: "Compound", primaryMuscleGroups: ["Quadriceps"], secondaryMuscleGroups: ["Glutes"], equipment: "Machine", instructions: "Sit in machine, place feet on platform, press weight away from body.", defaultRestTime: 120, isCustom: false),
            ExerciseCreationConfig(name: "Walking Lunges", category: "Compound", primaryMuscleGroups: ["Quadriceps"], secondaryMuscleGroups: ["Glutes", "Hamstrings"], equipment: "Dumbbell", instructions: "Step forward into lunge position, alternate legs while walking forward.", defaultRestTime: 90, isCustom: false),
            ExerciseCreationConfig(name: "Calf Raises", category: "Isolation", primaryMuscleGroups: ["Calves"], secondaryMuscleGroups: [], equipment: "Dumbbell", instructions: "Rise up on toes, squeeze calves at top, lower with control.", defaultRestTime: 60, isCustom: false),

            // Shoulder Exercises
            ExerciseCreationConfig(name: "Overhead Press", category: "Compound", primaryMuscleGroups: ["Shoulders"], secondaryMuscleGroups: ["Triceps"], equipment: "Barbell", instructions: "Press bar from shoulders to overhead, keep core tight.", defaultRestTime: 120, isCustom: false),
            ExerciseCreationConfig(name: "Lateral Raises", category: "Isolation", primaryMuscleGroups: ["Shoulders"], secondaryMuscleGroups: [], equipment: "Dumbbell", instructions: "Raise arms to sides until parallel to floor, control the descent.", defaultRestTime: 60, isCustom: false),
            ExerciseCreationConfig(name: "Front Raises", category: "Isolation", primaryMuscleGroups: ["Shoulders"], secondaryMuscleGroups: [], equipment: "Dumbbell", instructions: "Raise arms forward to shoulder height, control the movement.", defaultRestTime: 60, isCustom: false),
            ExerciseCreationConfig(name: "Rear Delt Flyes", category: "Isolation", primaryMuscleGroups: ["Rear Delts"], secondaryMuscleGroups: [], equipment: "Dumbbell", instructions: "Bend forward, raise arms to sides squeezing rear delts.", defaultRestTime: 60, isCustom: false),

            // Arm Exercises
            ExerciseCreationConfig(name: "Bicep Curls", category: "Isolation", primaryMuscleGroups: ["Biceps"], secondaryMuscleGroups: [], equipment: "Dumbbell", instructions: "Curl weights up to shoulders, squeeze biceps, lower with control.", defaultRestTime: 60, isCustom: false),
            ExerciseCreationConfig(name: "Hammer Curls", category: "Isolation", primaryMuscleGroups: ["Biceps"], secondaryMuscleGroups: ["Forearms"], equipment: "Dumbbell", instructions: "Curl with neutral grip, target biceps and forearms.", defaultRestTime: 60, isCustom: false),
            ExerciseCreationConfig(name: "Tricep Dips", category: "Compound", primaryMuscleGroups: ["Triceps"], secondaryMuscleGroups: ["Chest"], equipment: "Bodyweight", instructions: "Lower body by bending arms, push back up using triceps.", defaultRestTime: 90, isCustom: false),
            ExerciseCreationConfig(name: "Overhead Tricep Extension", category: "Isolation", primaryMuscleGroups: ["Triceps"], secondaryMuscleGroups: [], equipment: "Dumbbell", instructions: "Hold weight overhead, lower behind head, extend back up.", defaultRestTime: 60, isCustom: false),

            // Core Exercises
            ExerciseCreationConfig(name: "Plank", category: "Isometric", primaryMuscleGroups: ["Abs"], secondaryMuscleGroups: ["Lower Back"], equipment: "Bodyweight", instructions: "Hold push-up position, keep body straight, engage core.", defaultRestTime: 60, isCustom: false),
            ExerciseCreationConfig(name: "Crunches", category: "Isolation", primaryMuscleGroups: ["Abs"], secondaryMuscleGroups: [], equipment: "Bodyweight", instructions: "Lie on back, lift shoulders off ground, squeeze abs.", defaultRestTime: 45, isCustom: false),
            ExerciseCreationConfig(name: "Russian Twists", category: "Isolation", primaryMuscleGroups: ["Abs"], secondaryMuscleGroups: ["Obliques"], equipment: "Bodyweight", instructions: "Sit with knees bent, rotate torso side to side.", defaultRestTime: 45, isCustom: false)
        ]
    }
}

// MARK: - Array Extension for Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}