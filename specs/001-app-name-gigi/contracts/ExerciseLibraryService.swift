//
//  ExerciseLibraryService.swift
//  Gigi Gains - Internal API Contract
//
//  Defines the interface for exercise library management including browsing,
//  categorization, search, and custom exercise creation.
//
//  Created: 2025-09-28
//

import Foundation
import Combine
import CoreData

// MARK: - Supporting Types

/// Exercise categories for organization and filtering
public enum ExerciseCategory: String, CaseIterable {
    case compound = "Compound"
    case isolation = "Isolation"
    case cardio = "Cardio"
    case flexibility = "Flexibility"
    case plyometric = "Plyometric"
    case strongman = "Strongman"
    case bodyweight = "Bodyweight"
    case olympic = "Olympic"

    public var description: String {
        return rawValue
    }

    /// Returns exercises that typically fall under this category
    public var characteristics: [String] {
        switch self {
        case .compound:
            return ["Multi-joint", "Multiple muscle groups", "Functional movement"]
        case .isolation:
            return ["Single joint", "Target specific muscle", "Controlled movement"]
        case .cardio:
            return ["Cardiovascular", "Endurance", "Heart rate elevation"]
        case .flexibility:
            return ["Range of motion", "Stretching", "Mobility"]
        case .plyometric:
            return ["Explosive", "Power development", "Jump training"]
        case .strongman:
            return ["Functional strength", "Real-world application", "Total body"]
        case .bodyweight:
            return ["No equipment", "Body resistance", "Functional"]
        case .olympic:
            return ["Technical", "Power", "Full body coordination"]
        }
    }
}

/// Primary muscle groups for exercise classification
public enum MuscleGroup: String, CaseIterable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case forearms = "Forearms"
    case abs = "Abs"
    case obliques = "Obliques"
    case lowerBack = "Lower Back"
    case glutes = "Glutes"
    case quadriceps = "Quadriceps"
    case hamstrings = "Hamstrings"
    case calves = "Calves"
    case fullBody = "Full Body"
    case core = "Core"

    public var description: String {
        return rawValue
    }

    /// Related muscle groups that often work together
    public var synergisticMuscles: [MuscleGroup] {
        switch self {
        case .chest:
            return [.shoulders, .triceps]
        case .back:
            return [.biceps, .shoulders]
        case .shoulders:
            return [.chest, .triceps]
        case .biceps:
            return [.back, .forearms]
        case .triceps:
            return [.chest, .shoulders]
        case .quadriceps:
            return [.glutes, .calves]
        case .hamstrings:
            return [.glutes, .calves]
        case .glutes:
            return [.quadriceps, .hamstrings]
        default:
            return []
        }
    }
}

/// Equipment required for exercises
public enum ExerciseEquipment: String, CaseIterable {
    case none = "None"
    case barbell = "Barbell"
    case dumbbell = "Dumbbell"
    case kettlebell = "Kettlebell"
    case cable = "Cable"
    case machine = "Machine"
    case resistance_band = "Resistance Band"
    case stability_ball = "Stability Ball"
    case medicine_ball = "Medicine Ball"
    case pull_up_bar = "Pull-up Bar"
    case bench = "Bench"
    case box = "Box"
    case rope = "Rope"
    case other = "Other"

    public var description: String {
        return rawValue
    }

    /// Whether this equipment is typically available in home gyms
    public var isHomeGymFriendly: Bool {
        switch self {
        case .none, .resistance_band, .stability_ball, .medicine_ball, .pull_up_bar, .dumbbell, .kettlebell:
            return true
        case .barbell, .bench, .box, .rope:
            return true  // Commonly available in home gyms
        case .cable, .machine:
            return false // Typically commercial gym equipment
        case .other:
            return false // Unknown, assume not
        }
    }
}

/// Errors that can occur during exercise library operations
public enum ExerciseLibraryError: Error, LocalizedError {
    case exerciseNotFound(UUID)
    case duplicateExerciseName(String)
    case invalidExerciseData(reason: String)
    case customExerciseLimit(limit: Int)
    case cannotDeletePreBuiltExercise
    case exerciseInUse(routinesCount: Int, sessionsCount: Int)
    case coreDataError(Error)
    case validationError(String)

    public var errorDescription: String? {
        switch self {
        case .exerciseNotFound(let id):
            return "Exercise with ID \(id) not found"
        case .duplicateExerciseName(let name):
            return "An exercise with the name '\(name)' already exists"
        case .invalidExerciseData(let reason):
            return "Invalid exercise data: \(reason)"
        case .customExerciseLimit(let limit):
            return "Cannot create more than \(limit) custom exercises"
        case .cannotDeletePreBuiltExercise:
            return "Cannot delete pre-built exercises from the library"
        case .exerciseInUse(let routinesCount, let sessionsCount):
            return "Cannot delete exercise: it is used by \(routinesCount) routine(s) and \(sessionsCount) session(s)"
        case .coreDataError(let error):
            return "Core Data error: \(error.localizedDescription)"
        case .validationError(let message):
            return "Validation error: \(message)"
        }
    }
}

/// Configuration for creating a custom exercise
public struct CustomExerciseConfig {
    public let name: String
    public let category: ExerciseCategory
    public let primaryMuscleGroups: [MuscleGroup]
    public let secondaryMuscleGroups: [MuscleGroup]
    public let equipment: ExerciseEquipment
    public let instructions: String?
    public let defaultRestTime: TimeInterval

    public init(name: String, category: ExerciseCategory, primaryMuscleGroups: [MuscleGroup], secondaryMuscleGroups: [MuscleGroup] = [], equipment: ExerciseEquipment, instructions: String? = nil, defaultRestTime: TimeInterval = 120) {
        self.name = name
        self.category = category
        self.primaryMuscleGroups = primaryMuscleGroups
        self.secondaryMuscleGroups = secondaryMuscleGroups
        self.equipment = equipment
        self.instructions = instructions
        self.defaultRestTime = defaultRestTime
    }

    /// Validates the exercise configuration
    public func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ExerciseLibraryError.validationError("Exercise name cannot be empty")
        }
        guard !primaryMuscleGroups.isEmpty else {
            throw ExerciseLibraryError.validationError("At least one primary muscle group must be specified")
        }
        guard defaultRestTime >= 0 else {
            throw ExerciseLibraryError.validationError("Default rest time must be non-negative")
        }

        // Check for overlap between primary and secondary muscle groups
        let primarySet = Set(primaryMuscleGroups)
        let secondarySet = Set(secondaryMuscleGroups)
        guard primarySet.isDisjoint(with: secondarySet) else {
            throw ExerciseLibraryError.validationError("Primary and secondary muscle groups cannot overlap")
        }
    }
}

/// Filter criteria for searching exercises
public struct ExerciseFilter {
    public let searchText: String?
    public let category: ExerciseCategory?
    public let primaryMuscleGroups: [MuscleGroup]
    public let secondaryMuscleGroups: [MuscleGroup]
    public let equipment: [ExerciseEquipment]
    public let isCustom: Bool?
    public let isArchived: Bool?
    public let isHomeGymFriendly: Bool?

    public init(searchText: String? = nil, category: ExerciseCategory? = nil, primaryMuscleGroups: [MuscleGroup] = [], secondaryMuscleGroups: [MuscleGroup] = [], equipment: [ExerciseEquipment] = [], isCustom: Bool? = nil, isArchived: Bool? = nil, isHomeGymFriendly: Bool? = nil) {
        self.searchText = searchText
        self.category = category
        self.primaryMuscleGroups = primaryMuscleGroups
        self.secondaryMuscleGroups = secondaryMuscleGroups
        self.equipment = equipment
        self.isCustom = isCustom
        self.isArchived = isArchived
        self.isHomeGymFriendly = isHomeGymFriendly
    }
}

/// Sort options for exercise queries
public enum ExerciseSortOption: CaseIterable {
    case nameAscending
    case nameDescending
    case categoryThenName
    case muscleGroupThenName
    case equipmentThenName
    case recentlyUsed
    case mostUsed
    case recentlyCreated

    public var description: String {
        switch self {
        case .nameAscending: return "Name (A-Z)"
        case .nameDescending: return "Name (Z-A)"
        case .categoryThenName: return "Category, then Name"
        case .muscleGroupThenName: return "Muscle Group, then Name"
        case .equipmentThenName: return "Equipment, then Name"
        case .recentlyUsed: return "Recently Used"
        case .mostUsed: return "Most Used"
        case .recentlyCreated: return "Recently Created"
        }
    }
}

/// Exercise usage statistics
public struct ExerciseUsageStatistics {
    /// Number of times this exercise has been used in workouts
    public let usageCount: Int

    /// Date when the exercise was last used
    public let lastUsed: Date?

    /// Average weight used for this exercise (if applicable)
    public let averageWeight: Double?

    /// Most common rep range for this exercise
    public let commonRepRange: ClosedRange<Int>?

    /// Average RPE when performing this exercise
    public let averageRPE: Double?

    /// Number of personal records achieved with this exercise
    public let personalRecordsCount: Int

    /// Best estimated 1RM for this exercise
    public let bestEstimatedOneRM: Double?

    public init(usageCount: Int, lastUsed: Date?, averageWeight: Double?, commonRepRange: ClosedRange<Int>?, averageRPE: Double?, personalRecordsCount: Int, bestEstimatedOneRM: Double?) {
        self.usageCount = usageCount
        self.lastUsed = lastUsed
        self.averageWeight = averageWeight
        self.commonRepRange = commonRepRange
        self.averageRPE = averageRPE
        self.personalRecordsCount = personalRecordsCount
        self.bestEstimatedOneRM = bestEstimatedOneRM
    }
}

// MARK: - Main Protocol

/// Service protocol for managing the exercise library
///
/// This protocol defines the complete interface for exercise library management in the Gigi Gains app.
/// It supports browsing pre-built exercises, creating custom exercises, advanced filtering and search,
/// and tracking exercise usage statistics. All operations work offline-first with CloudKit synchronization.
///
/// Key responsibilities:
/// - Exercise library browsing and discovery
/// - Advanced filtering by muscle groups, equipment, and categories
/// - Custom exercise creation and management
/// - Exercise search with intelligent ranking
/// - Exercise usage tracking and statistics
/// - Muscle group and equipment management
/// - Exercise validation and data integrity
///
/// ## Usage Example:
/// ```swift
/// let service: ExerciseLibraryService = ExerciseLibraryServiceImpl()
///
/// // Browse exercises by muscle group
/// let filter = ExerciseFilter(primaryMuscleGroups: [.chest])
/// let chestExercises = try await service.getExercises(filter: filter, sortBy: .nameAscending)
///
/// // Create a custom exercise
/// let config = CustomExerciseConfig(
///     name: "Reverse Grip Bench Press",
///     category: .compound,
///     primaryMuscleGroups: [.chest],
///     secondaryMuscleGroups: [.triceps],
///     equipment: .barbell
/// )
/// let customExercise = try await service.createCustomExercise(config: config)
///
/// // Search exercises
/// let results = try await service.searchExercises(query: "bench press")
/// ```
public protocol ExerciseLibraryService: AnyObject {

    // MARK: - Publishers for Reactive Updates

    /// Publishes updates to the exercise library
    /// Emits the complete list of available exercises whenever any exercise is modified
    var exercisesUpdatePublisher: AnyPublisher<[Exercise], Never> { get }

    /// Publishes updates to exercise usage statistics
    /// Useful for updating exercise popularity and recommendations
    var exerciseStatisticsUpdatePublisher: AnyPublisher<[UUID: ExerciseUsageStatistics], Never> { get }

    // MARK: - Exercise Browsing and Discovery

    /// Retrieves an exercise by ID
    /// - Parameter exerciseId: The unique identifier of the exercise
    /// - Returns: The exercise if found
    /// - Throws: `ExerciseLibraryError.exerciseNotFound` if exercise doesn't exist
    func getExercise(exerciseId: UUID) async throws -> Exercise

    /// Retrieves all exercises matching the filter criteria
    /// - Parameters:
    ///   - filter: Filter criteria for querying exercises
    ///   - sortBy: Sort option for the results
    /// - Returns: Array of matching exercises, sorted according to the specified option
    /// - Throws: `ExerciseLibraryError.coreDataError` if query fails
    func getExercises(filter: ExerciseFilter, sortBy: ExerciseSortOption) async throws -> [Exercise]

    /// Gets exercises organized by category
    /// - Returns: Dictionary mapping categories to their exercises
    func getExercisesByCategory() async throws -> [ExerciseCategory: [Exercise]]

    /// Gets exercises organized by primary muscle group
    /// - Returns: Dictionary mapping muscle groups to their exercises
    func getExercisesByMuscleGroup() async throws -> [MuscleGroup: [Exercise]]

    /// Gets exercises filtered by available equipment
    /// - Parameter availableEquipment: List of equipment the user has access to
    /// - Returns: Array of exercises that can be performed with the available equipment
    func getExercisesForEquipment(_ availableEquipment: [ExerciseEquipment]) async throws -> [Exercise]

    /// Gets exercises suitable for home gym workouts
    /// - Returns: Array of exercises that can be performed with minimal equipment
    func getHomeGymExercises() async throws -> [Exercise]

    // MARK: - Exercise Search

    /// Searches exercises by name, muscle groups, and other criteria
    /// - Parameter query: Search query text
    /// - Returns: Array of matching exercises sorted by relevance
    /// - Note: Search includes exercise names, muscle groups, categories, and equipment
    func searchExercises(query: String) async throws -> [Exercise]

    /// Advanced search with multiple criteria
    /// - Parameters:
    ///   - query: Text query for names and descriptions
    ///   - filter: Additional filter criteria
    ///   - sortBy: Sort option for results
    /// - Returns: Array of matching exercises
    func searchExercises(query: String, filter: ExerciseFilter, sortBy: ExerciseSortOption) async throws -> [Exercise]

    /// Gets exercise suggestions based on muscle groups
    /// - Parameters:
    ///   - targetMuscleGroups: Muscle groups to target
    ///   - excludeExerciseIds: Exercise IDs to exclude from suggestions
    ///   - limit: Maximum number of suggestions to return
    /// - Returns: Array of suggested exercises
    func suggestExercises(targetMuscleGroups: [MuscleGroup], excludeExerciseIds: [UUID], limit: Int) async throws -> [Exercise]

    /// Gets complementary exercises for a given exercise
    /// - Parameters:
    ///   - exerciseId: The base exercise to find complements for
    ///   - limit: Maximum number of complementary exercises to return
    /// - Returns: Array of exercises that work well with the given exercise
    /// - Throws: `ExerciseLibraryError.exerciseNotFound` if base exercise doesn't exist
    func getComplementaryExercises(for exerciseId: UUID, limit: Int) async throws -> [Exercise]

    // MARK: - Custom Exercise Management

    /// Creates a new custom exercise
    /// - Parameter config: Configuration for the new exercise
    /// - Returns: The created exercise
    /// - Throws: `ExerciseLibraryError.duplicateExerciseName` if name already exists
    /// - Throws: `ExerciseLibraryError.validationError` if config is invalid
    /// - Throws: `ExerciseLibraryError.customExerciseLimit` if custom exercise limit is reached
    /// - Throws: `ExerciseLibraryError.coreDataError` if creation fails
    func createCustomExercise(config: CustomExerciseConfig) async throws -> Exercise

    /// Updates a custom exercise
    /// - Parameters:
    ///   - exerciseId: The ID of the exercise to update
    ///   - config: Updated configuration for the exercise
    /// - Throws: `ExerciseLibraryError.exerciseNotFound` if exercise doesn't exist
    /// - Throws: `ExerciseLibraryError.cannotDeletePreBuiltExercise` if trying to modify pre-built exercise
    /// - Throws: `ExerciseLibraryError.duplicateExerciseName` if new name conflicts
    /// - Throws: `ExerciseLibraryError.validationError` if config is invalid
    func updateCustomExercise(exerciseId: UUID, config: CustomExerciseConfig) async throws

    /// Archives or unarchives an exercise
    /// - Parameters:
    ///   - exerciseId: The ID of the exercise to archive/unarchive
    ///   - isArchived: Whether the exercise should be archived
    /// - Throws: `ExerciseLibraryError.exerciseNotFound` if exercise doesn't exist
    /// - Throws: `ExerciseLibraryError.cannotDeletePreBuiltExercise` if trying to archive pre-built exercise
    func archiveExercise(exerciseId: UUID, isArchived: Bool) async throws

    /// Deletes a custom exercise
    /// - Parameter exerciseId: The ID of the exercise to delete
    /// - Throws: `ExerciseLibraryError.exerciseNotFound` if exercise doesn't exist
    /// - Throws: `ExerciseLibraryError.cannotDeletePreBuiltExercise` if trying to delete pre-built exercise
    /// - Throws: `ExerciseLibraryError.exerciseInUse` if exercise is referenced by routines or sessions
    func deleteCustomExercise(exerciseId: UUID) async throws

    /// Gets all custom exercises created by the user
    /// - Returns: Array of custom exercises sorted by creation date
    func getCustomExercises() async throws -> [Exercise]

    /// Validates that an exercise name is available for use
    /// - Parameter name: The exercise name to check
    /// - Returns: True if the name is available, false if it conflicts with existing exercises
    func isExerciseNameAvailable(_ name: String) async throws -> Bool

    // MARK: - Exercise Statistics and Analytics

    /// Gets usage statistics for a specific exercise
    /// - Parameter exerciseId: The ID of the exercise
    /// - Returns: Detailed usage statistics for the exercise
    /// - Throws: `ExerciseLibraryError.exerciseNotFound` if exercise doesn't exist
    func getExerciseStatistics(exerciseId: UUID) async throws -> ExerciseUsageStatistics

    /// Gets usage statistics for all exercises
    /// - Returns: Dictionary mapping exercise IDs to their statistics
    func getAllExerciseStatistics() async throws -> [UUID: ExerciseUsageStatistics]

    /// Gets the most popular exercises
    /// - Parameter limit: Maximum number of exercises to return
    /// - Returns: Array of exercises sorted by usage count (most used first)
    func getMostPopularExercises(limit: Int) async throws -> [Exercise]

    /// Gets recently used exercises
    /// - Parameter limit: Maximum number of exercises to return
    /// - Returns: Array of exercises sorted by last used date (most recent first)
    func getRecentlyUsedExercises(limit: Int) async throws -> [Exercise]

    /// Updates exercise usage statistics
    /// - Parameter exerciseId: The ID of the exercise that was used
    /// - Throws: `ExerciseLibraryError.exerciseNotFound` if exercise doesn't exist
    /// - Note: This is typically called when an exercise is added to a workout session
    func recordExerciseUsage(exerciseId: UUID) async throws

    // MARK: - Muscle Group and Equipment Management

    /// Gets all available muscle groups
    /// - Returns: Array of all muscle groups
    func getAllMuscleGroups() -> [MuscleGroup]

    /// Gets all exercise categories
    /// - Returns: Array of all exercise categories
    func getAllCategories() -> [ExerciseCategory]

    /// Gets all equipment types
    /// - Returns: Array of all equipment types
    func getAllEquipment() -> [ExerciseEquipment]

    /// Gets muscle groups that work well together
    /// - Parameter muscleGroup: The primary muscle group
    /// - Returns: Array of complementary muscle groups
    func getComplementaryMuscleGroups(for muscleGroup: MuscleGroup) -> [MuscleGroup]

    /// Gets equipment that is commonly available in home gyms
    /// - Returns: Array of home gym friendly equipment
    func getHomeGymEquipment() -> [ExerciseEquipment]

    // MARK: - Exercise Library Initialization

    /// Initializes the exercise library with pre-built exercises
    /// - Note: This should be called on first app launch to populate the library
    /// - Returns: Number of exercises that were created
    func initializePreBuiltExercises() async throws -> Int

    /// Checks if the pre-built exercise library has been initialized
    /// - Returns: True if the library contains pre-built exercises
    func isLibraryInitialized() async throws -> Bool

    /// Gets the version of the pre-built exercise library
    /// - Returns: Version string of the current exercise library
    func getLibraryVersion() async throws -> String

    /// Updates the pre-built exercise library to a new version
    /// - Parameter version: Target version to update to
    /// - Returns: Number of exercises that were added or updated
    /// - Note: This preserves custom exercises and user modifications
    func updateLibraryToVersion(_ version: String) async throws -> Int
}

// MARK: - Test Helper Protocol

/// Protocol for test implementations and mocking
/// Enables dependency injection and unit testing of components that depend on ExerciseLibraryService
public protocol MockableExerciseLibraryService: ExerciseLibraryService {
    /// Allows tests to inject mock exercises
    func setMockExercises(_ exercises: [Exercise])

    /// Allows tests to simulate errors
    func setMockError(_ error: ExerciseLibraryError?)

    /// Allows tests to control exercise statistics
    func setMockStatistics(_ statistics: [UUID: ExerciseUsageStatistics])

    /// Allows tests to control library initialization state
    func setMockLibraryInitialized(_ isInitialized: Bool)
}