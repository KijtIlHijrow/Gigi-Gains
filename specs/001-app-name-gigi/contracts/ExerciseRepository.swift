//
//  ExerciseRepository.swift
//  Gigi Gains - Internal API Contract
//
//  Defines the interface for Core Data operations related to exercises,
//  including exercise library management, custom exercises, and data access patterns.
//
//  Created: 2025-09-28
//

import Foundation
import Combine
import CoreData

// MARK: - Supporting Types

/// Errors that can occur during exercise repository operations
public enum ExerciseRepositoryError: Error, LocalizedError {
    case objectNotFound(UUID)
    case duplicateExerciseName(String)
    case saveContextFailed(Error)
    case fetchRequestFailed(Error)
    case batchUpdateFailed(Error)
    case batchDeleteFailed(Error)
    case invalidMuscleGroupData(String)
    case exerciseInUse(routinesCount: Int, sessionsCount: Int)
    case cannotModifyPreBuiltExercise(UUID)
    case invalidObjectState(String)
    case contextMergeFailed(Error)
    case backgroundContextError(Error)

    public var errorDescription: String? {
        switch self {
        case .objectNotFound(let id):
            return "Exercise with ID \(id) not found"
        case .duplicateExerciseName(let name):
            return "An exercise with the name '\(name)' already exists"
        case .saveContextFailed(let error):
            return "Failed to save context: \(error.localizedDescription)"
        case .fetchRequestFailed(let error):
            return "Fetch request failed: \(error.localizedDescription)"
        case .batchUpdateFailed(let error):
            return "Batch update failed: \(error.localizedDescription)"
        case .batchDeleteFailed(let error):
            return "Batch delete failed: \(error.localizedDescription)"
        case .invalidMuscleGroupData(let details):
            return "Invalid muscle group data: \(details)"
        case .exerciseInUse(let routinesCount, let sessionsCount):
            return "Cannot delete exercise: it is used by \(routinesCount) routine(s) and \(sessionsCount) session(s)"
        case .cannotModifyPreBuiltExercise(let id):
            return "Cannot modify pre-built exercise with ID \(id)"
        case .invalidObjectState(let details):
            return "Invalid object state: \(details)"
        case .contextMergeFailed(let error):
            return "Context merge failed: \(error.localizedDescription)"
        case .backgroundContextError(let error):
            return "Background context error: \(error.localizedDescription)"
        }
    }
}

/// Sort options for exercise queries
public enum ExerciseSortOption: String, CaseIterable {
    case nameAscending = "name_asc"
    case nameDescending = "name_desc"
    case categoryThenName = "category_name"
    case muscleGroupThenName = "muscle_name"
    case equipmentThenName = "equipment_name"
    case createdAtAscending = "createdAt_asc"
    case createdAtDescending = "createdAt_desc"
    case usageCountDescending = "usage_desc"
    case customFirst = "custom_first"
    case preBuiltFirst = "prebuilt_first"

    public var description: String {
        switch self {
        case .nameAscending: return "Name (A-Z)"
        case .nameDescending: return "Name (Z-A)"
        case .categoryThenName: return "Category, then Name"
        case .muscleGroupThenName: return "Muscle Group, then Name"
        case .equipmentThenName: return "Equipment, then Name"
        case .createdAtAscending: return "Created (Oldest First)"
        case .createdAtDescending: return "Created (Newest First)"
        case .usageCountDescending: return "Most Used First"
        case .customFirst: return "Custom Exercises First"
        case .preBuiltFirst: return "Pre-built Exercises First"
        }
    }

    /// Core Data sort descriptors for this option
    public var sortDescriptors: [NSSortDescriptor] {
        switch self {
        case .nameAscending:
            return [NSSortDescriptor(keyPath: \Exercise.name, ascending: true)]
        case .nameDescending:
            return [NSSortDescriptor(keyPath: \Exercise.name, ascending: false)]
        case .categoryThenName:
            return [
                NSSortDescriptor(keyPath: \Exercise.category, ascending: true),
                NSSortDescriptor(keyPath: \Exercise.name, ascending: true)
            ]
        case .muscleGroupThenName:
            return [
                NSSortDescriptor(keyPath: \Exercise.primaryMuscleGroups, ascending: true),
                NSSortDescriptor(keyPath: \Exercise.name, ascending: true)
            ]
        case .equipmentThenName:
            return [
                NSSortDescriptor(keyPath: \Exercise.equipment, ascending: true),
                NSSortDescriptor(keyPath: \Exercise.name, ascending: true)
            ]
        case .createdAtAscending:
            return [NSSortDescriptor(keyPath: \Exercise.createdAt, ascending: true)]
        case .createdAtDescending:
            return [NSSortDescriptor(keyPath: \Exercise.createdAt, ascending: false)]
        case .usageCountDescending:
            return [
                NSSortDescriptor(keyPath: \Exercise.workoutExercises, ascending: false),
                NSSortDescriptor(keyPath: \Exercise.name, ascending: true)
            ]
        case .customFirst:
            return [
                NSSortDescriptor(keyPath: \Exercise.isCustom, ascending: false),
                NSSortDescriptor(keyPath: \Exercise.name, ascending: true)
            ]
        case .preBuiltFirst:
            return [
                NSSortDescriptor(keyPath: \Exercise.isCustom, ascending: true),
                NSSortDescriptor(keyPath: \Exercise.name, ascending: true)
            ]
        }
    }
}

/// Filter criteria for exercise queries
public struct ExerciseQueryFilter {
    public let nameContains: String?
    public let category: String?
    public let primaryMuscleGroups: [String]
    public let secondaryMuscleGroups: [String]
    public let equipment: String?
    public let isCustom: Bool?
    public let isArchived: Bool?
    public let createdAfter: Date?
    public let createdBefore: Date?
    public let hasInstructions: Bool?

    public init(nameContains: String? = nil, category: String? = nil, primaryMuscleGroups: [String] = [], secondaryMuscleGroups: [String] = [], equipment: String? = nil, isCustom: Bool? = nil, isArchived: Bool? = nil, createdAfter: Date? = nil, createdBefore: Date? = nil, hasInstructions: Bool? = nil) {
        self.nameContains = nameContains
        self.category = category
        self.primaryMuscleGroups = primaryMuscleGroups
        self.secondaryMuscleGroups = secondaryMuscleGroups
        self.equipment = equipment
        self.isCustom = isCustom
        self.isArchived = isArchived
        self.createdAfter = createdAfter
        self.createdBefore = createdBefore
        self.hasInstructions = hasInstructions
    }

    /// Converts filter to NSPredicate for Core Data queries
    public var predicate: NSPredicate? {
        var predicates: [NSPredicate] = []

        if let nameContains = nameContains, !nameContains.isEmpty {
            predicates.append(NSPredicate(format: "name CONTAINS[cd] %@", nameContains))
        }

        if let category = category {
            predicates.append(NSPredicate(format: "category == %@", category))
        }

        if !primaryMuscleGroups.isEmpty {
            let muscleGroupPredicates = primaryMuscleGroups.map { muscleGroup in
                NSPredicate(format: "primaryMuscleGroups CONTAINS[cd] %@", muscleGroup)
            }
            predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: muscleGroupPredicates))
        }

        if !secondaryMuscleGroups.isEmpty {
            let muscleGroupPredicates = secondaryMuscleGroups.map { muscleGroup in
                NSPredicate(format: "secondaryMuscleGroups CONTAINS[cd] %@", muscleGroup)
            }
            predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: muscleGroupPredicates))
        }

        if let equipment = equipment {
            predicates.append(NSPredicate(format: "equipment == %@", equipment))
        }

        if let isCustom = isCustom {
            predicates.append(NSPredicate(format: "isCustom == %@", NSNumber(value: isCustom)))
        }

        if let isArchived = isArchived {
            predicates.append(NSPredicate(format: "isArchived == %@", NSNumber(value: isArchived)))
        }

        if let createdAfter = createdAfter {
            predicates.append(NSPredicate(format: "createdAt >= %@", createdAfter as NSDate))
        }

        if let createdBefore = createdBefore {
            predicates.append(NSPredicate(format: "createdAt <= %@", createdBefore as NSDate))
        }

        if let hasInstructions = hasInstructions {
            if hasInstructions {
                predicates.append(NSPredicate(format: "instructions != nil AND instructions != ''"))
            } else {
                predicates.append(NSPredicate(format: "instructions == nil OR instructions == ''"))
            }
        }

        return predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}

/// Options for fetch requests
public struct ExerciseFetchOptions {
    public let limit: Int?
    public let offset: Int?
    public let prefetchRelationships: [String]
    public let returnsObjectsAsFaults: Bool
    public let includeUsageStatistics: Bool

    public init(limit: Int? = nil, offset: Int? = nil, prefetchRelationships: [String] = [], returnsObjectsAsFaults: Bool = false, includeUsageStatistics: Bool = false) {
        self.limit = limit
        self.offset = offset
        self.prefetchRelationships = prefetchRelationships
        self.returnsObjectsAsFaults = returnsObjectsAsFaults
        self.includeUsageStatistics = includeUsageStatistics
    }
}

/// Configuration for batch operations
public struct ExerciseBatchOperationConfig {
    public let batchSize: Int
    public let includeSubentities: Bool
    public let resultType: NSBatchUpdateRequestResultType

    public init(batchSize: Int = 100, includeSubentities: Bool = true, resultType: NSBatchUpdateRequestResultType = .statusOnlyResultType) {
        self.batchSize = batchSize
        self.includeSubentities = includeSubentities
        self.resultType = resultType
    }
}

/// Exercise creation configuration
public struct ExerciseCreationConfig {
    public let name: String
    public let category: String
    public let primaryMuscleGroups: [String]
    public let secondaryMuscleGroups: [String]
    public let equipment: String
    public let instructions: String?
    public let defaultRestTime: Double
    public let isCustom: Bool

    public init(name: String, category: String, primaryMuscleGroups: [String], secondaryMuscleGroups: [String] = [], equipment: String, instructions: String? = nil, defaultRestTime: Double = 120, isCustom: Bool = true) {
        self.name = name
        self.category = category
        self.primaryMuscleGroups = primaryMuscleGroups
        self.secondaryMuscleGroups = secondaryMuscleGroups
        self.equipment = equipment
        self.instructions = instructions
        self.defaultRestTime = defaultRestTime
        self.isCustom = isCustom
    }
}

/// Exercise usage statistics
public struct ExerciseUsageStats {
    public let exerciseId: UUID
    public let exerciseName: String
    public let totalUsageCount: Int
    public let routineUsageCount: Int
    public let sessionUsageCount: Int
    public let lastUsedDate: Date?
    public let averageWeight: Double?
    public let averageReps: Double?
    public let averageRPE: Double?
    public let personalRecordsCount: Int

    public init(exerciseId: UUID, exerciseName: String, totalUsageCount: Int, routineUsageCount: Int, sessionUsageCount: Int, lastUsedDate: Date?, averageWeight: Double?, averageReps: Double?, averageRPE: Double?, personalRecordsCount: Int) {
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.totalUsageCount = totalUsageCount
        self.routineUsageCount = routineUsageCount
        self.sessionUsageCount = sessionUsageCount
        self.lastUsedDate = lastUsedDate
        self.averageWeight = averageWeight
        self.averageReps = averageReps
        self.averageRPE = averageRPE
        self.personalRecordsCount = personalRecordsCount
    }
}

// MARK: - Main Protocol

/// Repository protocol for Core Data operations on exercise-related entities
///
/// This protocol defines the data access layer for exercises and their related data in the
/// Gigi Gains app. It provides a clean abstraction over Core Data operations for the exercise
/// library, including both pre-built and custom exercises. All operations are designed to
/// work efficiently with CloudKit synchronization.
///
/// Key responsibilities:
/// - Exercise library CRUD operations
/// - Custom exercise management
/// - Advanced querying with filtering and sorting
/// - Muscle group and category data management
/// - Exercise usage tracking and analytics
/// - Batch operations for performance
/// - Data validation and integrity checks
/// - Pre-built exercise library initialization
///
/// ## Usage Example:
/// ```swift
/// let repository: ExerciseRepository = ExerciseRepositoryImpl()
///
/// // Create a custom exercise
/// let config = ExerciseCreationConfig(
///     name: "Reverse Grip Bench Press",
///     category: "Compound",
///     primaryMuscleGroups: ["Chest"],
///     secondaryMuscleGroups: ["Triceps"],
///     equipment: "Barbell"
/// )
/// let exercise = try await repository.createExercise(config: config)
///
/// // Query exercises by muscle group
/// let filter = ExerciseQueryFilter(
///     primaryMuscleGroups: ["Chest"],
///     isArchived: false
/// )
/// let chestExercises = try await repository.fetchExercises(
///     filter: filter,
///     sortBy: .nameAscending,
///     options: ExerciseFetchOptions(limit: 20)
/// )
/// ```
public protocol ExerciseRepository: AnyObject {

    // MARK: - Publishers for Reactive Updates

    /// Publishes changes to exercises
    /// Emits when exercises are created, updated, or deleted
    var exercisesChangedPublisher: AnyPublisher<Void, Never> { get }

    /// Publishes changes to exercise usage statistics
    /// Emits when exercise usage patterns change
    var exerciseUsageChangedPublisher: AnyPublisher<Void, Never> { get }

    // MARK: - Exercise CRUD Operations

    /// Creates a new exercise
    /// - Parameter config: Configuration for the new exercise
    /// - Returns: The created Exercise object
    /// - Throws: `ExerciseRepositoryError.duplicateExerciseName` if name already exists
    /// - Throws: `ExerciseRepositoryError.saveContextFailed` if save fails
    func createExercise(config: ExerciseCreationConfig) async throws -> Exercise

    /// Fetches an exercise by ID
    /// - Parameter id: The unique identifier of the exercise
    /// - Returns: The Exercise object if found
    /// - Throws: `ExerciseRepositoryError.objectNotFound` if exercise doesn't exist
    /// - Throws: `ExerciseRepositoryError.fetchRequestFailed` if fetch fails
    func fetchExercise(id: UUID) async throws -> Exercise

    /// Fetches an exercise by name
    /// - Parameter name: The name of the exercise
    /// - Returns: The Exercise object if found
    /// - Throws: `ExerciseRepositoryError.objectNotFound` if exercise doesn't exist
    /// - Throws: `ExerciseRepositoryError.fetchRequestFailed` if fetch fails
    func fetchExercise(name: String) async throws -> Exercise

    /// Fetches exercises with filtering and sorting
    /// - Parameters:
    ///   - filter: Filter criteria for the query
    ///   - sortBy: Sort option for the results
    ///   - options: Fetch options including limits and prefetching
    /// - Returns: Array of Exercise objects matching the criteria
    /// - Throws: `ExerciseRepositoryError.fetchRequestFailed` if query fails
    func fetchExercises(filter: ExerciseQueryFilter, sortBy: ExerciseSortOption, options: ExerciseFetchOptions) async throws -> [Exercise]

    /// Fetches all exercises (use with caution for large datasets)
    /// - Returns: Array of all Exercise objects
    /// - Throws: `ExerciseRepositoryError.fetchRequestFailed` if query fails
    func fetchAllExercises() async throws -> [Exercise]

    /// Updates an existing exercise
    /// - Parameters:
    ///   - exercise: The Exercise object to update
    ///   - config: New configuration for the exercise
    /// - Throws: `ExerciseRepositoryError.cannotModifyPreBuiltExercise` if trying to modify pre-built exercise
    /// - Throws: `ExerciseRepositoryError.duplicateExerciseName` if name conflicts with existing exercise
    /// - Throws: `ExerciseRepositoryError.saveContextFailed` if save fails
    func updateExercise(_ exercise: Exercise, config: ExerciseCreationConfig) async throws

    /// Archives or unarchives an exercise
    /// - Parameters:
    ///   - exercise: The Exercise object to archive/unarchive
    ///   - isArchived: Whether the exercise should be archived
    /// - Throws: `ExerciseRepositoryError.cannotModifyPreBuiltExercise` if trying to archive pre-built exercise
    /// - Throws: `ExerciseRepositoryError.saveContextFailed` if save fails
    func archiveExercise(_ exercise: Exercise, isArchived: Bool) async throws

    /// Deletes an exercise
    /// - Parameter exercise: The Exercise object to delete
    /// - Throws: `ExerciseRepositoryError.cannotModifyPreBuiltExercise` if trying to delete pre-built exercise
    /// - Throws: `ExerciseRepositoryError.exerciseInUse` if exercise is referenced by routines or sessions
    /// - Throws: `ExerciseRepositoryError.saveContextFailed` if deletion fails
    func deleteExercise(_ exercise: Exercise) async throws

    /// Checks if an exercise name is available (not already used)
    /// - Parameter name: The exercise name to check
    /// - Returns: True if the name is available, false if it's already used
    func isExerciseNameAvailable(_ name: String) async throws -> Bool

    // MARK: - Batch Operations

    /// Creates multiple exercises in batch
    /// - Parameters:
    ///   - configs: Array of exercise configurations to create
    ///   - config: Batch operation configuration
    /// - Returns: Array of created Exercise objects
    /// - Throws: `ExerciseRepositoryError.saveContextFailed` if batch operation fails
    func createExercises(configs: [ExerciseCreationConfig], batchConfig: ExerciseBatchOperationConfig) async throws -> [Exercise]

    /// Updates multiple exercises in batch
    /// - Parameters:
    ///   - updates: Dictionary mapping exercise IDs to their new configurations
    ///   - config: Batch operation configuration
    /// - Returns: Number of exercises successfully updated
    /// - Throws: `ExerciseRepositoryError.batchUpdateFailed` if batch operation fails
    func updateExercises(updates: [UUID: ExerciseCreationConfig], batchConfig: ExerciseBatchOperationConfig) async throws -> Int

    /// Archives multiple exercises in batch
    /// - Parameters:
    ///   - exerciseIds: Array of exercise IDs to archive
    ///   - isArchived: Whether the exercises should be archived
    ///   - config: Batch operation configuration
    /// - Returns: Number of exercises successfully archived
    /// - Throws: `ExerciseRepositoryError.batchUpdateFailed` if batch operation fails
    func archiveExercises(ids exerciseIds: [UUID], isArchived: Bool, batchConfig: ExerciseBatchOperationConfig) async throws -> Int

    // MARK: - Exercise Categories and Muscle Groups

    /// Fetches all unique exercise categories
    /// - Returns: Array of category strings
    /// - Throws: `ExerciseRepositoryError.fetchRequestFailed` if query fails
    func fetchExerciseCategories() async throws -> [String]

    /// Fetches all unique muscle groups
    /// - Returns: Array of muscle group strings
    /// - Throws: `ExerciseRepositoryError.fetchRequestFailed` if query fails
    func fetchMuscleGroups() async throws -> [String]

    /// Fetches all unique equipment types
    /// - Returns: Array of equipment strings
    /// - Throws: `ExerciseRepositoryError.fetchRequestFailed` if query fails
    func fetchEquipmentTypes() async throws -> [String]

    /// Fetches exercises grouped by category
    /// - Returns: Dictionary mapping categories to their exercises
    /// - Throws: `ExerciseRepositoryError.fetchRequestFailed` if query fails
    func fetchExercisesGroupedByCategory() async throws -> [String: [Exercise]]

    /// Fetches exercises grouped by primary muscle group
    /// - Returns: Dictionary mapping muscle groups to their exercises
    /// - Throws: `ExerciseRepositoryError.fetchRequestFailed` if query fails
    func fetchExercisesGroupedByMuscleGroup() async throws -> [String: [Exercise]]

    /// Fetches exercises for specific equipment types
    /// - Parameter equipmentTypes: Array of equipment types to filter by
    /// - Returns: Array of exercises that use the specified equipment
    /// - Throws: `ExerciseRepositoryError.fetchRequestFailed` if query fails
    func fetchExercisesForEquipment(_ equipmentTypes: [String]) async throws -> [Exercise]

    // MARK: - Exercise Search and Discovery

    /// Searches exercises by name with fuzzy matching
    /// - Parameter searchText: Text to search for in exercise names
    /// - Returns: Array of exercises matching the search text, sorted by relevance
    /// - Throws: `ExerciseRepositoryError.fetchRequestFailed` if query fails
    func searchExercisesByName(_ searchText: String) async throws -> [Exercise]

    /// Searches exercises by multiple criteria
    /// - Parameter searchText: Text to search for in names, categories, and muscle groups
    /// - Returns: Array of exercises matching the search criteria
    /// - Throws: `ExerciseRepositoryError.fetchRequestFailed` if query fails
    func searchExercises(_ searchText: String) async throws -> [Exercise]

    /// Suggests exercises based on muscle groups
    /// - Parameters:
    ///   - muscleGroups: Target muscle groups
    ///   - excludeIds: Exercise IDs to exclude from suggestions
    ///   - limit: Maximum number of suggestions
    /// - Returns: Array of suggested exercises
    /// - Throws: `ExerciseRepositoryError.fetchRequestFailed` if query fails
    func suggestExercises(muscleGroups: [String], excludeIds: [UUID], limit: Int) async throws -> [Exercise]

    /// Gets complementary exercises for a given exercise
    /// - Parameters:
    ///   - exercise: The base exercise to find complements for
    ///   - limit: Maximum number of complementary exercises
    /// - Returns: Array of exercises that complement the given exercise
    /// - Throws: `ExerciseRepositoryError.fetchRequestFailed` if query fails
    func getComplementaryExercises(for exercise: Exercise, limit: Int) async throws -> [Exercise]

    /// Gets similar exercises based on muscle groups and category
    /// - Parameters:
    ///   - exercise: The base exercise to find similar exercises for
    ///   - limit: Maximum number of similar exercises
    /// - Returns: Array of similar exercises
    /// - Throws: `ExerciseRepositoryError.fetchRequestFailed` if query fails
    func getSimilarExercises(to exercise: Exercise, limit: Int) async throws -> [Exercise]

    // MARK: - Custom Exercise Management

    /// Fetches all custom exercises created by the user
    /// - Returns: Array of custom Exercise objects sorted by creation date
    /// - Throws: `ExerciseRepositoryError.fetchRequestFailed` if query fails
    func fetchCustomExercises() async throws -> [Exercise]

    /// Fetches recently created custom exercises
    /// - Parameter days: Number of days to look back
    /// - Returns: Array of recently created custom exercises
    /// - Throws: `ExerciseRepositoryError.fetchRequestFailed` if query fails
    func fetchRecentCustomExercises(days: Int) async throws -> [Exercise]

    /// Counts custom exercises
    /// - Returns: Number of custom exercises created by the user
    /// - Throws: `ExerciseRepositoryError.fetchRequestFailed` if query fails
    func countCustomExercises() async throws -> Int

    /// Validates custom exercise data
    /// - Parameter config: Exercise configuration to validate
    /// - Returns: Array of validation errors, empty if valid
    func validateExerciseConfig(_ config: ExerciseCreationConfig) async -> [String]

    // MARK: - Exercise Usage and Analytics

    /// Records exercise usage when it's added to a workout
    /// - Parameter exerciseId: ID of the exercise that was used
    /// - Throws: `ExerciseRepositoryError.saveContextFailed` if recording fails
    func recordExerciseUsage(exerciseId: UUID) async throws

    /// Gets usage statistics for an exercise
    /// - Parameter exerciseId: ID of the exercise
    /// - Returns: Usage statistics for the exercise
    /// - Throws: `ExerciseRepositoryError.objectNotFound` if exercise doesn't exist
    func getExerciseUsageStats(exerciseId: UUID) async throws -> ExerciseUsageStats

    /// Gets usage statistics for multiple exercises
    /// - Parameter exerciseIds: Array of exercise IDs
    /// - Returns: Dictionary mapping exercise IDs to their usage statistics
    func getExerciseUsageStats(exerciseIds: [UUID]) async throws -> [UUID: ExerciseUsageStats]

    /// Gets the most popular exercises based on usage
    /// - Parameter limit: Maximum number of exercises to return
    /// - Returns: Array of exercises sorted by usage count (most used first)
    /// - Throws: `ExerciseRepositoryError.fetchRequestFailed` if query fails
    func getMostPopularExercises(limit: Int) async throws -> [Exercise]

    /// Gets recently used exercises
    /// - Parameter limit: Maximum number of exercises to return
    /// - Returns: Array of exercises sorted by last used date (most recent first)
    /// - Throws: `ExerciseRepositoryError.fetchRequestFailed` if query fails
    func getRecentlyUsedExercises(limit: Int) async throws -> [Exercise]

    /// Gets unused exercises (never used in workouts)
    /// - Returns: Array of exercises that have never been used
    /// - Throws: `ExerciseRepositoryError.fetchRequestFailed` if query fails
    func getUnusedExercises() async throws -> [Exercise]

    // MARK: - Pre-built Exercise Library Management

    /// Initializes the pre-built exercise library
    /// - Returns: Number of pre-built exercises created
    /// - Throws: `ExerciseRepositoryError.saveContextFailed` if initialization fails
    /// - Note: This should be called on first app launch
    func initializePreBuiltExerciseLibrary() async throws -> Int

    /// Checks if the pre-built exercise library has been initialized
    /// - Returns: True if pre-built exercises exist in the database
    func isPreBuiltLibraryInitialized() async throws -> Bool

    /// Gets the version of the pre-built exercise library
    /// - Returns: Version string of the current library
    func getPreBuiltLibraryVersion() async throws -> String

    /// Updates the pre-built exercise library to a new version
    /// - Parameter version: Target version to update to
    /// - Returns: Number of exercises added or updated
    /// - Throws: `ExerciseRepositoryError.saveContextFailed` if update fails
    func updatePreBuiltLibraryToVersion(_ version: String) async throws -> Int

    /// Gets all pre-built exercises
    /// - Returns: Array of pre-built Exercise objects
    /// - Throws: `ExerciseRepositoryError.fetchRequestFailed` if query fails
    func fetchPreBuiltExercises() async throws -> [Exercise]

    /// Validates the integrity of the pre-built exercise library
    /// - Returns: Array of validation issues found, empty if library is valid
    func validatePreBuiltLibrary() async throws -> [String]

    // MARK: - Data Integrity and Validation

    /// Validates an exercise object
    /// - Parameter exercise: The Exercise to validate
    /// - Returns: Array of validation errors, empty if valid
    func validateExercise(_ exercise: Exercise) async -> [String]

    /// Checks for exercises with invalid muscle group data
    /// - Returns: Array of exercises with invalid muscle group JSON
    func findExercisesWithInvalidMuscleGroups() async throws -> [Exercise]

    /// Fixes muscle group data for exercises with invalid JSON
    /// - Returns: Number of exercises that were fixed
    /// - Throws: `ExerciseRepositoryError.saveContextFailed` if fixes fail
    func fixInvalidMuscleGroupData() async throws -> Int

    /// Checks for duplicate exercise names
    /// - Returns: Dictionary mapping duplicate names to arrays of exercise IDs
    func findDuplicateExerciseNames() async throws -> [String: [UUID]]

    /// Finds orphaned exercises (not referenced by any routines or sessions)
    /// - Returns: Array of Exercise objects that are not used anywhere
    func findOrphanedExercises() async throws -> [Exercise]

    // MARK: - Background Operations

    /// Performs operations in a background context
    /// - Parameter operation: Closure containing operations to perform
    /// - Throws: `ExerciseRepositoryError.backgroundContextError` if operation fails
    func performBackgroundOperation(_ operation: @escaping (NSManagedObjectContext) throws -> Void) async throws

    /// Saves changes in a background context
    /// - Parameter context: The background context to save
    /// - Throws: `ExerciseRepositoryError.saveContextFailed` if save fails
    func saveBackgroundContext(_ context: NSManagedObjectContext) async throws

    // MARK: - Performance and Statistics

    /// Gets database statistics for exercise data
    /// - Returns: Dictionary containing various database statistics
    func getDatabaseStatistics() async throws -> [String: Any]

    /// Counts exercises matching filter criteria
    /// - Parameter filter: Filter criteria for the count
    /// - Returns: Number of exercises matching the filter
    /// - Throws: `ExerciseRepositoryError.fetchRequestFailed` if query fails
    func countExercises(filter: ExerciseQueryFilter) async throws -> Int

    /// Estimates memory usage of loaded exercise objects
    /// - Returns: Estimated memory usage in bytes
    func estimateMemoryUsage() async -> Int64

    /// Refreshes exercise objects to free memory
    /// - Parameter olderThan: Refresh objects not accessed since this date
    func refreshObjects(olderThan: Date) async
}

// MARK: - Test Helper Protocol

/// Protocol for test implementations and mocking
/// Enables dependency injection and unit testing of components that depend on ExerciseRepository
public protocol MockableExerciseRepository: ExerciseRepository {
    /// Allows tests to inject mock exercises
    func setMockExercises(_ exercises: [Exercise])

    /// Allows tests to simulate errors
    func setMockError(_ error: ExerciseRepositoryError?)

    /// Allows tests to control save operations
    func setShouldFailSave(_ shouldFail: Bool)

    /// Allows tests to control fetch operations
    func setShouldFailFetch(_ shouldFail: Bool)

    /// Allows tests to inject mock usage statistics
    func setMockUsageStats(_ stats: [UUID: ExerciseUsageStats])

    /// Allows tests to verify method calls
    var lastSearchText: String? { get }
    var lastFilter: ExerciseQueryFilter? { get }
    var createCallCount: Int { get }
}