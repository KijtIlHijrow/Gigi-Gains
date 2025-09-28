//
//  DependencyContainer.swift
//  Gigi Gains
//
//  Dependency injection container for service management and mocking support.
//  Provides centralized access to all app services with lifecycle management.
//
//  Created: 2025-09-28
//

import Foundation
import CoreData
import CloudKit
import Combine

/// Central dependency injection container for the Gigi Gains app
/// Manages service instances, Core Data stack, and provides mocking capabilities for testing
@MainActor
public class DependencyContainer: ObservableObject {

    // MARK: - Core Data Stack

    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "GigiGains")

        // Configure CloudKit integration
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }

        // Enable CloudKit
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        // Configure CloudKit container
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.gigagains.app")

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                #if DEBUG
                fatalError("Core Data error: \(error), \(error.userInfo)")
                #else
                print("Core Data error: \(error)")
                #endif
            }
        }

        // Configure automatic Core Data -> CloudKit syncing
        container.viewContext.automaticallyMergesChangesFromParent = true

        return container
    }()

    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    // MARK: - Repository Layer

    lazy var workoutRepository: WorkoutRepositoryProtocol = {
        if isTestEnvironment {
            return MockWorkoutRepository()
        } else {
            return WorkoutRepositoryImpl(context: viewContext)
        }
    }()

    lazy var exerciseRepository: ExerciseRepositoryProtocol = {
        if isTestEnvironment {
            return MockExerciseRepository()
        } else {
            return ExerciseRepositoryImpl(context: viewContext)
        }
    }()

    // MARK: - Service Layer

    lazy var workoutService: WorkoutServiceProtocol = {
        if isTestEnvironment {
            return MockWorkoutService()
        } else {
            return WorkoutServiceImpl(
                workoutRepository: workoutRepository,
                exerciseRepository: exerciseRepository,
                timerManager: timerManager
            )
        }
    }()

    lazy var routineService: RoutineServiceProtocol = {
        if isTestEnvironment {
            return MockRoutineService()
        } else {
            return RoutineServiceImpl(workoutRepository: workoutRepository)
        }
    }()

    lazy var exerciseLibraryService: ExerciseLibraryServiceProtocol = {
        if isTestEnvironment {
            return MockExerciseLibraryService()
        } else {
            return ExerciseLibraryServiceImpl(exerciseRepository: exerciseRepository)
        }
    }()

    lazy var progressTrackingService: ProgressTrackingServiceProtocol = {
        if isTestEnvironment {
            return MockProgressTrackingService()
        } else {
            return ProgressTrackingServiceImpl(workoutRepository: workoutRepository)
        }
    }()

    lazy var plateCalculatorService: PlateCalculatorServiceProtocol = {
        if isTestEnvironment {
            return MockPlateCalculatorService()
        } else {
            return PlateCalculatorServiceImpl()
        }
    }()

    // MARK: - Manager Layer

    lazy var timerManager: TimerManagerProtocol = {
        if isTestEnvironment {
            return MockTimerManager()
        } else {
            return TimerManagerImpl()
        }
    }()

    // MARK: - System Integration Services

    lazy var healthKitService: HealthKitServiceProtocol = {
        if isTestEnvironment {
            return MockHealthKitService()
        } else {
            return HealthKitServiceImpl()
        }
    }()

    lazy var cloudSyncService: CloudSyncServiceProtocol = {
        if isTestEnvironment {
            return MockCloudSyncService()
        } else {
            return CloudSyncServiceImpl(container: persistentContainer)
        }
    }()

    lazy var notificationService: NotificationServiceProtocol = {
        if isTestEnvironment {
            return MockNotificationService()
        } else {
            return NotificationServiceImpl()
        }
    }()

    // MARK: - Configuration

    private let isTestEnvironment: Bool

    // MARK: - Initialization

    public init(isTestEnvironment: Bool = false) {
        self.isTestEnvironment = isTestEnvironment

        if isTestEnvironment {
            setupInMemoryStore()
        }

        setupNotificationObservers()
    }

    // MARK: - Core Data Management

    func saveContext() {
        let context = persistentContainer.viewContext

        if context.hasChanges {
            do {
                try context.save()
            } catch {
                #if DEBUG
                fatalError("Core Data save error: \(error)")
                #else
                print("Core Data save error: \(error)")
                #endif
            }
        }
    }

    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistentContainer.performBackgroundTask(block)
    }

    // MARK: - Test Support

    func resetForTesting() {
        guard isTestEnvironment else {
            fatalError("resetForTesting() can only be called in test environment")
        }

        // Clear all data
        let context = viewContext
        let entities = persistentContainer.managedObjectModel.entities

        for entity in entities {
            guard let entityName = entity.name else { continue }

            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            do {
                try context.execute(deleteRequest)
            } catch {
                print("Failed to delete \(entityName): \(error)")
            }
        }

        saveContext()
    }

    // MARK: - Service Factory

    func createWorkoutService() -> WorkoutServiceProtocol {
        return workoutService
    }

    func createProgressTrackingService() -> ProgressTrackingServiceProtocol {
        return progressTrackingService
    }

    // MARK: - Private Methods

    private func setupInMemoryStore() {
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        persistentContainer.persistentStoreDescriptions = [description]
    }

    private func setupNotificationObservers() {
        // Listen for Core Data remote change notifications
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: persistentContainer.persistentStoreCoordinator,
            queue: .main
        ) { [weak self] _ in
            self?.handleRemoteDataChange()
        }

        // Listen for CloudKit account changes
        NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleCloudKitAccountChange()
        }
    }

    private func handleRemoteDataChange() {
        // Merge changes from CloudKit
        viewContext.perform {
            self.viewContext.mergeChanges(fromContextDidSave: Notification(name: .NSManagedObjectContextDidSave))
        }

        // Notify UI of data changes
        objectWillChange.send()
    }

    private func handleCloudKitAccountChange() {
        Task {
            await cloudSyncService.handleAccountChange()
        }
    }
}

// MARK: - Protocol Definitions

// These protocols would typically be defined in separate files,
// but including them here for completeness of the dependency container

public protocol WorkoutRepositoryProtocol {
    func saveWorkout(_ workout: WorkoutSession) async throws
    func fetchWorkouts() async throws -> [WorkoutSession]
    func deleteWorkout(id: UUID) async throws
}

public protocol ExerciseRepositoryProtocol {
    func saveExercise(_ exercise: ExerciseDefinition) async throws
    func fetchExercises() async throws -> [ExerciseDefinition]
    func searchExercises(query: String) async throws -> [ExerciseDefinition]
}

public protocol WorkoutServiceProtocol {
    func startWorkout() async throws -> UUID
    func addExerciseToWorkout(_ exerciseId: UUID, workoutId: UUID) async throws
    func completeWorkout(_ workoutId: UUID) async throws
}

public protocol RoutineServiceProtocol {
    func createRoutine(_ routine: WorkoutRoutine) async throws
    func fetchRoutines() async throws -> [WorkoutRoutine]
    func deleteRoutine(id: UUID) async throws
}

public protocol ExerciseLibraryServiceProtocol {
    func getExerciseLibrary() async throws -> [ExerciseDefinition]
    func searchExercises(query: String, muscleGroup: String?) async throws -> [ExerciseDefinition]
    func addCustomExercise(_ exercise: ExerciseDefinition) async throws
}

public protocol ProgressTrackingServiceProtocol {
    func calculatePersonalRecords(for exerciseId: UUID) async throws -> PersonalRecords
    func getProgressData(for exerciseId: UUID, timeframe: TimeFrame) async throws -> [ProgressDataPoint]
    func getWorkoutStatistics(timeframe: TimeFrame) async throws -> WorkoutStatistics
}

public protocol PlateCalculatorServiceProtocol {
    func calculatePlateLoading(targetWeight: Double, barWeight: Double, availablePlates: [PlateWeight]) -> PlateLoadingResult
    func getStandardPlateSets() -> [PlateSet]
}

public protocol TimerManagerProtocol {
    func startTimer(duration: TimeInterval) async
    func pauseTimer() async
    func resumeTimer() async
    func stopTimer() async
    var isRunning: Bool { get }
    var timeRemaining: TimeInterval { get }
}

public protocol HealthKitServiceProtocol {
    var isHealthKitAvailable: Bool { get }
    func requestPermissions() async throws -> HealthKitAuthorizationStatus
    func getAuthorizationStatus() async -> HealthKitAuthorizationStatus
    func exportWorkout(config: HealthKitWorkoutConfig) async throws
}

public protocol CloudSyncServiceProtocol {
    func isSignedInToiCloud() async -> Bool
    func startAutoSync() async
    func performManualSync() async throws
    func scheduleBackgroundSync() async
    func handleAccountChange() async
}

public protocol NotificationServiceProtocol {
    func requestPermissions() async throws -> NotificationAuthorizationStatus
    func getAuthorizationStatus() async -> NotificationAuthorizationStatus
    func scheduleRestTimerNotification(config: RestTimerNotificationConfig) async throws -> String
    func configureBackgroundNotifications() async
    func scheduleBackgroundNotifications(_ notifications: [NotificationConfig]) async throws
}

// MARK: - Mock Implementations for Testing

// These would typically be in separate test files, but including key ones here

class MockWorkoutRepository: WorkoutRepositoryProtocol {
    private var workouts: [WorkoutSession] = []

    func saveWorkout(_ workout: WorkoutSession) async throws {
        workouts.append(workout)
    }

    func fetchWorkouts() async throws -> [WorkoutSession] {
        return workouts
    }

    func deleteWorkout(id: UUID) async throws {
        workouts.removeAll { $0.id == id }
    }
}

class MockExerciseRepository: ExerciseRepositoryProtocol {
    private var exercises: [ExerciseDefinition] = []

    func saveExercise(_ exercise: ExerciseDefinition) async throws {
        exercises.append(exercise)
    }

    func fetchExercises() async throws -> [ExerciseDefinition] {
        return exercises
    }

    func searchExercises(query: String) async throws -> [ExerciseDefinition] {
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
}

class MockWorkoutService: WorkoutServiceProtocol {
    func startWorkout() async throws -> UUID {
        return UUID()
    }

    func addExerciseToWorkout(_ exerciseId: UUID, workoutId: UUID) async throws {
        // Mock implementation
    }

    func completeWorkout(_ workoutId: UUID) async throws {
        // Mock implementation
    }
}

class MockRoutineService: RoutineServiceProtocol {
    private var routines: [WorkoutRoutine] = []

    func createRoutine(_ routine: WorkoutRoutine) async throws {
        routines.append(routine)
    }

    func fetchRoutines() async throws -> [WorkoutRoutine] {
        return routines
    }

    func deleteRoutine(id: UUID) async throws {
        routines.removeAll { $0.id == id }
    }
}

class MockExerciseLibraryService: ExerciseLibraryServiceProtocol {
    func getExerciseLibrary() async throws -> [ExerciseDefinition] {
        return []
    }

    func searchExercises(query: String, muscleGroup: String?) async throws -> [ExerciseDefinition] {
        return []
    }

    func addCustomExercise(_ exercise: ExerciseDefinition) async throws {
        // Mock implementation
    }
}

class MockProgressTrackingService: ProgressTrackingServiceProtocol {
    func calculatePersonalRecords(for exerciseId: UUID) async throws -> PersonalRecords {
        return PersonalRecords(oneRepMax: 0, maxVolume: 0, maxReps: 0)
    }

    func getProgressData(for exerciseId: UUID, timeframe: TimeFrame) async throws -> [ProgressDataPoint] {
        return []
    }

    func getWorkoutStatistics(timeframe: TimeFrame) async throws -> WorkoutStatistics {
        return WorkoutStatistics(totalWorkouts: 0, thisMonth: 0, averageDuration: 0, totalVolume: 0)
    }
}

class MockPlateCalculatorService: PlateCalculatorServiceProtocol {
    func calculatePlateLoading(targetWeight: Double, barWeight: Double, availablePlates: [PlateWeight]) -> PlateLoadingResult {
        return PlateLoadingResult(plates: [], totalWeight: barWeight, isExact: true)
    }

    func getStandardPlateSets() -> [PlateSet] {
        return []
    }
}

class MockTimerManager: TimerManagerProtocol {
    var isRunning = false
    var timeRemaining: TimeInterval = 0

    func startTimer(duration: TimeInterval) async {
        isRunning = true
        timeRemaining = duration
    }

    func pauseTimer() async {
        isRunning = false
    }

    func resumeTimer() async {
        isRunning = true
    }

    func stopTimer() async {
        isRunning = false
        timeRemaining = 0
    }
}

class MockHealthKitService: HealthKitServiceProtocol {
    var isHealthKitAvailable = true

    func requestPermissions() async throws -> HealthKitAuthorizationStatus {
        return HealthKitAuthorizationStatus(
            workoutWritePermission: .authorized,
            exerciseReadPermission: .authorized,
            heartRateReadPermission: .authorized,
            activeEnergyReadPermission: .authorized,
            isHealthKitAvailable: true
        )
    }

    func getAuthorizationStatus() async -> HealthKitAuthorizationStatus {
        return HealthKitAuthorizationStatus(
            workoutWritePermission: .authorized,
            exerciseReadPermission: .authorized,
            heartRateReadPermission: .authorized,
            activeEnergyReadPermission: .authorized,
            isHealthKitAvailable: true
        )
    }

    func exportWorkout(config: HealthKitWorkoutConfig) async throws {
        // Mock implementation
    }
}

class MockCloudSyncService: CloudSyncServiceProtocol {
    func isSignedInToiCloud() async -> Bool {
        return true
    }

    func startAutoSync() async {
        // Mock implementation
    }

    func performManualSync() async throws {
        // Mock implementation
    }

    func scheduleBackgroundSync() async {
        // Mock implementation
    }

    func handleAccountChange() async {
        // Mock implementation
    }
}

class MockNotificationService: NotificationServiceProtocol {
    func requestPermissions() async throws -> NotificationAuthorizationStatus {
        return .authorized
    }

    func getAuthorizationStatus() async -> NotificationAuthorizationStatus {
        return .authorized
    }

    func scheduleRestTimerNotification(config: RestTimerNotificationConfig) async throws -> String {
        return UUID().uuidString
    }

    func configureBackgroundNotifications() async {
        // Mock implementation
    }

    func scheduleBackgroundNotifications(_ notifications: [NotificationConfig]) async throws {
        // Mock implementation
    }
}

// MARK: - Supporting Types

public struct ExerciseDefinition {
    public let id: UUID
    public let name: String
    public let muscleGroups: [String]
    public let equipment: String?
    public let instructions: String?

    public init(id: UUID, name: String, muscleGroups: [String], equipment: String? = nil, instructions: String? = nil) {
        self.id = id
        self.name = name
        self.muscleGroups = muscleGroups
        self.equipment = equipment
        self.instructions = instructions
    }
}

public struct PersonalRecords {
    public let oneRepMax: Double
    public let maxVolume: Double
    public let maxReps: Int

    public init(oneRepMax: Double, maxVolume: Double, maxReps: Int) {
        self.oneRepMax = oneRepMax
        self.maxVolume = maxVolume
        self.maxReps = maxReps
    }
}

public enum TimeFrame {
    case week, month, threeMonths, year, all
}

public struct PlateWeight {
    public let weight: Double
    public let available: Int

    public init(weight: Double, available: Int) {
        self.weight = weight
        self.available = available
    }
}

public struct PlateLoadingResult {
    public let plates: [PlateWeight]
    public let totalWeight: Double
    public let isExact: Bool

    public init(plates: [PlateWeight], totalWeight: Double, isExact: Bool) {
        self.plates = plates
        self.totalWeight = totalWeight
        self.isExact = isExact
    }
}

public struct PlateSet {
    public let name: String
    public let plates: [PlateWeight]

    public init(name: String, plates: [PlateWeight]) {
        self.name = name
        self.plates = plates
    }
}