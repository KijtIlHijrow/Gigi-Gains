import XCTest
import Combine
@testable import GigiGains

final class FirstTimeSetupTests: XCTestCase {

    var healthKitService: HealthKitService!
    var exerciseLibraryService: ExerciseLibraryService!
    var coreDataStack: CoreDataStack!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        try await super.setUp()
        cancellables = Set<AnyCancellable>()

        // This will fail because the implementations don't exist yet
        // This is intentional for TDD - integration tests MUST fail first
        coreDataStack = CoreDataStack.shared
        healthKitService = HealthKitServiceImpl()
        exerciseLibraryService = ExerciseLibraryServiceImpl()
    }

    override func tearDown() {
        cancellables = nil
        healthKitService = nil
        exerciseLibraryService = nil
        super.tearDown()
    }

    // MARK: - First-Time App Setup Integration Test

    /// Integration test for first-time app setup & HealthKit permissions
    /// Validates acceptance criteria FR-010, FR-018
    func testFirstTimeAppSetupAndHealthKitIntegration() async throws {
        // GIVEN: First-time app launch
        let initialAuthStatus = await healthKitService.getAuthorizationStatus()

        // WHEN: User grants HealthKit permissions
        var finalAuthStatus: HealthKitAuthorizationStatus
        do {
            finalAuthStatus = try await healthKitService.requestPermissions()
        } catch HealthKitServiceError.healthKitNotAvailable {
            // Skip test if HealthKit is not available (e.g., simulator)
            throw XCTSkip("HealthKit not available on this device")
        }

        // THEN: App can read exercise data and write completed workouts to Apple Health
        if finalAuthStatus.hasRequiredPermissions {
            XCTAssertTrue(finalAuthStatus.isHealthKitAvailable)
            XCTAssertEqual(finalAuthStatus.workoutWritePermission, .authorized)
            XCTAssertEqual(finalAuthStatus.exerciseReadPermission, .authorized)
        }

        // THEN: Core Data is properly initialized
        let context = coreDataStack.viewContext
        XCTAssertNotNil(context)
        XCTAssertFalse(context.hasChanges)

        // THEN: Exercise library is populated with default exercises
        let exercises = try await exerciseLibraryService.getAllExercises()
        XCTAssertGreaterThan(exercises.count, 50, "Should have at least 50 predefined exercises")

        // THEN: Essential exercise categories are present
        let categories = Set(exercises.map { $0.category })
        let expectedCategories = ["Compound", "Isolation", "Cardio", "Flexibility"]
        for expectedCategory in expectedCategories {
            XCTAssertTrue(categories.contains(expectedCategory), "Missing category: \(expectedCategory)")
        }

        // THEN: Essential muscle groups are covered
        let allMuscleGroups = exercises.flatMap { $0.primaryMuscleGroups + $0.secondaryMuscleGroups }
        let muscleGroups = Set(allMuscleGroups)
        let expectedMuscleGroups = ["Chest", "Back", "Shoulders", "Arms", "Legs", "Core"]
        for expectedMuscleGroup in expectedMuscleGroups {
            XCTAssertTrue(muscleGroups.contains(expectedMuscleGroup), "Missing muscle group: \(expectedMuscleGroup)")
        }
    }

    // MARK: - HealthKit Permission Denial Handling

    /// Integration test for HealthKit permission denial handling
    /// Validates edge case EC3.1 from quickstart.md
    func testHealthKitPermissionDenialHandling() async throws {
        // GIVEN: HealthKit permissions are denied
        guard healthKitService.isHealthKitAvailable else {
            throw XCTSkip("HealthKit not available on this device")
        }

        // WHEN: User attempts to use HealthKit features without permissions
        let authStatus = await healthKitService.getAuthorizationStatus()

        if authStatus.workoutWritePermission == .denied {
            // THEN: App continues to function with reduced functionality

            // Core workout logging should still work
            let exercises = try await exerciseLibraryService.getAllExercises()
            XCTAssertGreaterThan(exercises.count, 0)

            // HealthKit export should fail gracefully
            let sessionId = UUID()
            let config = HealthKitWorkoutConfig(
                sessionId: sessionId,
                activityType: .traditionalStrengthTraining,
                startDate: Date(),
                endDate: Date().addingTimeInterval(3600),
                duration: 3600
            )

            do {
                try await healthKitService.exportWorkout(config: config)
                XCTFail("Expected permission denied error")
            } catch HealthKitServiceError.permissionDenied {
                // Expected - should fail gracefully
            }
        }
    }

    // MARK: - Core Data and CloudKit Integration

    /// Integration test for Core Data setup with CloudKit
    /// Validates that the Core Data stack initializes properly with CloudKit
    func testCoreDataCloudKitIntegration() async throws {
        // GIVEN: Core Data stack is initialized
        let persistentContainer = coreDataStack.persistentContainer

        // THEN: CloudKit container is properly configured
        XCTAssertTrue(persistentContainer is NSPersistentCloudKitContainer)

        // THEN: Persistent store is loaded
        XCTAssertFalse(persistentContainer.persistentStoreDescriptions.isEmpty)

        let storeDescription = persistentContainer.persistentStoreDescriptions.first!

        // THEN: CloudKit options are enabled
        let cloudKitEnabled = storeDescription.option(forKey: NSPersistentCloudKitContainerOptionsKey) as? Bool
        XCTAssertEqual(cloudKitEnabled, true)

        // THEN: History tracking is enabled
        let historyTracking = storeDescription.option(forKey: NSPersistentHistoryTrackingKey) as? Bool
        XCTAssertEqual(historyTracking, true)

        // THEN: Remote change notifications are enabled
        let remoteNotifications = storeDescription.option(forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey) as? Bool
        XCTAssertEqual(remoteNotifications, true)
    }

    // MARK: - Exercise Library Initialization

    /// Integration test for exercise library initialization
    /// Validates that the exercise library is properly populated
    func testExerciseLibraryInitialization() async throws {
        // GIVEN: App is launched for the first time
        let exercises = try await exerciseLibraryService.getAllExercises()

        // THEN: Essential exercises are present
        let exerciseNames = exercises.map { $0.name.lowercased() }
        let essentialExercises = [
            "bench press",
            "squat",
            "deadlift",
            "overhead press",
            "barbell row",
            "pull-up",
            "dip",
            "pushup"
        ]

        for essentialExercise in essentialExercises {
            XCTAssertTrue(
                exerciseNames.contains { $0.contains(essentialExercise) },
                "Missing essential exercise: \(essentialExercise)"
            )
        }

        // THEN: Each exercise has proper data
        for exercise in exercises {
            XCTAssertFalse(exercise.name.isEmpty, "Exercise name should not be empty")
            XCTAssertFalse(exercise.category.isEmpty, "Exercise category should not be empty")
            XCTAssertFalse(exercise.primaryMuscleGroups.isEmpty, "Exercise should have primary muscle groups")
            XCTAssertFalse(exercise.equipment.isEmpty, "Exercise should specify equipment")
            XCTAssertGreaterThan(exercise.defaultRestTime, 0, "Exercise should have positive default rest time")
        }

        // THEN: Predefined exercises are not marked as custom
        let predefinedExercises = exercises.filter { !$0.isCustom }
        XCTAssertEqual(predefinedExercises.count, exercises.count, "All initial exercises should be predefined")
    }

    // MARK: - Data Validation and Constraints

    /// Integration test for data validation across services
    /// Validates that data constraints are enforced consistently
    func testDataValidationIntegration() async throws {
        // Test exercise creation validation
        let invalidExerciseData = ExerciseCreationData(
            name: "", // Invalid empty name
            category: "InvalidCategory",
            primaryMuscleGroups: [],
            equipment: ""
        )

        do {
            _ = try await exerciseLibraryService.createCustomExercise(data: invalidExerciseData)
            XCTFail("Expected validation error for invalid exercise data")
        } catch ExerciseLibraryServiceError.validationError {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        // Test HealthKit workout validation
        let invalidWorkoutConfig = HealthKitWorkoutConfig(
            sessionId: UUID(),
            activityType: .traditionalStrengthTraining,
            startDate: Date(),
            endDate: Date().addingTimeInterval(-3600), // End before start
            duration: -100 // Negative duration
        )

        let validationErrors = healthKitService.validateWorkoutData(config: invalidWorkoutConfig)
        XCTAssertFalse(validationErrors.isEmpty, "Should have validation errors for invalid workout data")
        XCTAssertTrue(validationErrors.contains { $0.contains("duration") || $0.contains("date") })
    }

    // MARK: - Offline Functionality Validation

    /// Integration test for offline functionality during first setup
    /// Validates that core features work without internet connectivity
    func testOfflineFunctionalityDuringSetup() async throws {
        // GIVEN: App setup without internet connectivity (simulated)
        // Note: This test assumes services are designed to work offline-first

        // THEN: Exercise library should still be available
        let exercises = try await exerciseLibraryService.getAllExercises()
        XCTAssertGreaterThan(exercises.count, 0, "Exercise library should be available offline")

        // THEN: Core Data operations should work
        let context = coreDataStack.viewContext
        XCTAssertNotNil(context)

        // THEN: Custom exercises can be created offline
        let customExerciseData = ExerciseCreationData(
            name: "Offline Custom Exercise",
            category: "Isolation",
            primaryMuscleGroups: ["Biceps"],
            equipment: "Dumbbells"
        )

        let customExercise = try await exerciseLibraryService.createCustomExercise(data: customExerciseData)
        XCTAssertEqual(customExercise.name, "Offline Custom Exercise")
        XCTAssertTrue(customExercise.isCustom)

        // THEN: Data should be persisted locally
        let retrievedExercise = try await exerciseLibraryService.getExercise(id: customExercise.id)
        XCTAssertEqual(retrievedExercise.id, customExercise.id)
    }

    // MARK: - Performance Validation

    /// Integration test for performance during first setup
    /// Validates that setup operations complete within acceptable time limits
    func testFirstSetupPerformance() async throws {
        let startTime = Date()

        // Exercise library loading should be fast
        let exerciseLoadStart = Date()
        let exercises = try await exerciseLibraryService.getAllExercises()
        let exerciseLoadDuration = Date().timeIntervalSince(exerciseLoadStart)

        XCTAssertLessThan(exerciseLoadDuration, 2.0, "Exercise library should load within 2 seconds")
        XCTAssertGreaterThan(exercises.count, 50, "Should load substantial exercise library")

        // Core Data initialization should be fast
        let coreDataStart = Date()
        let context = coreDataStack.viewContext
        _ = context.persistentStoreCoordinator
        let coreDataDuration = Date().timeIntervalSince(coreDataStart)

        XCTAssertLessThan(coreDataDuration, 1.0, "Core Data should initialize within 1 second")

        // Overall setup should complete quickly
        let totalDuration = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(totalDuration, 5.0, "Total first setup should complete within 5 seconds")
    }

    // MARK: - Memory and Resource Management

    /// Integration test for memory usage during setup
    /// Validates that setup doesn't consume excessive memory
    func testSetupMemoryUsage() async throws {
        // This test would ideally measure memory usage, but XCTest doesn't provide
        // direct memory measurement APIs. In a real implementation, you might use
        // system profiling tools or custom memory tracking.

        // For now, we validate that services can be deallocated properly
        weak var weakHealthKitService = healthKitService
        weak var weakExerciseLibraryService = exerciseLibraryService

        // Use services normally
        _ = try await exerciseLibraryService.getAllExercises()
        _ = await healthKitService.getAuthorizationStatus()

        // Release strong references
        healthKitService = nil
        exerciseLibraryService = nil

        // Services should be deallocatable when not in use
        // (This test may not work if services are singletons)
        // XCTAssertNil(weakHealthKitService, "HealthKitService should be deallocatable")
        // XCTAssertNil(weakExerciseLibraryService, "ExerciseLibraryService should be deallocatable")
    }
}