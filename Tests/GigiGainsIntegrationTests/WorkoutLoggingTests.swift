import XCTest
import Combine
@testable import GigiGains

final class WorkoutLoggingTests: XCTestCase {

    var workoutService: WorkoutService!
    var exerciseLibraryService: ExerciseLibraryService!
    var healthKitService: HealthKitService!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        try await super.setUp()
        cancellables = Set<AnyCancellable>()

        // This will fail because the implementations don't exist yet
        // This is intentional for TDD - integration tests MUST fail first
        workoutService = WorkoutServiceImpl()
        exerciseLibraryService = ExerciseLibraryServiceImpl()
        healthKitService = HealthKitServiceImpl()
    }

    override func tearDown() {
        cancellables = nil
        workoutService = nil
        exerciseLibraryService = nil
        healthKitService = nil
        super.tearDown()
    }

    // MARK: - Complete Workout Logging Flow Integration Test

    /// Integration test for starting new workout & exercise logging
    /// Validates acceptance criteria FR-001, FR-002
    func testCompleteWorkoutLoggingFlow() async throws {
        // GIVEN: User starts a new workout
        let workoutConfig = WorkoutSessionConfig(name: "Integration Test Workout")
        let session = try await workoutService.createSession(config: workoutConfig)

        XCTAssertEqual(session.name, "Integration Test Workout")
        XCTAssertFalse(session.isCompleted)
        XCTAssertNotNil(session.id)

        // WHEN: User starts the workout session
        try await workoutService.startSession(sessionId: session.id)

        let startedSession = try await workoutService.getSession(sessionId: session.id)
        XCTAssertNotNil(startedSession.startDate)

        // WHEN: User selects exercises from the library
        let exercises = try await exerciseLibraryService.getAllExercises()
        XCTAssertGreaterThan(exercises.count, 0, "Exercise library should be populated")

        let benchPress = exercises.first { $0.name.lowercased().contains("bench press") }
        XCTAssertNotNil(benchPress, "Should have bench press exercise in library")

        let squat = exercises.first { $0.name.lowercased().contains("squat") }
        XCTAssertNotNil(squat, "Should have squat exercise in library")

        // WHEN: User adds exercises to workout
        let benchPressRequest = AddExerciseRequest(exerciseId: benchPress!.id, restTimerDuration: 180)
        let workoutBenchPress = try await workoutService.addExercise(sessionId: session.id, request: benchPressRequest)

        let squatRequest = AddExerciseRequest(exerciseId: squat!.id, restTimerDuration: 120)
        let workoutSquat = try await workoutService.addExercise(sessionId: session.id, request: squatRequest)

        XCTAssertEqual(workoutBenchPress.exercise.id, benchPress!.id)
        XCTAssertEqual(workoutSquat.exercise.id, squat!.id)

        // WHEN: User logs sets with weight, reps, and RPE values
        // Bench Press Sets
        let benchSet1 = SetData(weight: 135.0, reps: 8, rpe: 6.0)
        let benchSet2 = SetData(weight: 155.0, reps: 6, rpe: 7.5)
        let benchSet3 = SetData(weight: 175.0, reps: 4, rpe: 9.0)

        let loggedBenchSet1 = try await workoutService.addSet(
            sessionId: session.id,
            exerciseId: workoutBenchPress.id,
            setData: benchSet1
        )
        let loggedBenchSet2 = try await workoutService.addSet(
            sessionId: session.id,
            exerciseId: workoutBenchPress.id,
            setData: benchSet2
        )
        let loggedBenchSet3 = try await workoutService.addSet(
            sessionId: session.id,
            exerciseId: workoutBenchPress.id,
            setData: benchSet3
        )

        // Validate bench press sets
        XCTAssertEqual(loggedBenchSet1.weight, 135.0)
        XCTAssertEqual(loggedBenchSet1.reps, 8)
        XCTAssertEqual(loggedBenchSet1.rpe, 6.0, accuracy: 0.1)

        XCTAssertEqual(loggedBenchSet2.weight, 155.0)
        XCTAssertEqual(loggedBenchSet2.reps, 6)
        XCTAssertEqual(loggedBenchSet2.rpe, 7.5, accuracy: 0.1)

        XCTAssertEqual(loggedBenchSet3.weight, 175.0)
        XCTAssertEqual(loggedBenchSet3.reps, 4)
        XCTAssertEqual(loggedBenchSet3.rpe, 9.0, accuracy: 0.1)

        // Squat Sets
        let squatSet1 = SetData(weight: 225.0, reps: 5, rpe: 7.0)
        let squatSet2 = SetData(weight: 245.0, reps: 3, rpe: 8.5)
        let squatSet3 = SetData(weight: 265.0, reps: 1, rpe: 10.0)

        let loggedSquatSet1 = try await workoutService.addSet(
            sessionId: session.id,
            exerciseId: workoutSquat.id,
            setData: squatSet1
        )
        let loggedSquatSet2 = try await workoutService.addSet(
            sessionId: session.id,
            exerciseId: workoutSquat.id,
            setData: squatSet2
        )
        let loggedSquatSet3 = try await workoutService.addSet(
            sessionId: session.id,
            exerciseId: workoutSquat.id,
            setData: squatSet3
        )

        // Validate squat sets
        XCTAssertEqual(loggedSquatSet1.weight, 225.0)
        XCTAssertEqual(loggedSquatSet1.reps, 5)
        XCTAssertEqual(loggedSquatSet1.rpe, 7.0, accuracy: 0.1)

        // WHEN: User completes the workout
        try await workoutService.completeSession(sessionId: session.id)

        let completedSession = try await workoutService.getSession(sessionId: session.id)
        XCTAssertTrue(completedSession.isCompleted)
        XCTAssertNotNil(completedSession.endDate)

        // THEN: Workout statistics are calculated correctly
        let stats = try await workoutService.getSessionStatistics(sessionId: session.id)

        XCTAssertEqual(stats.totalSets, 6) // 3 bench + 3 squat
        XCTAssertEqual(stats.totalExercises, 2) // bench press + squat

        // Calculate expected total volume:
        // Bench: (135*8) + (155*6) + (175*4) = 1080 + 930 + 700 = 2710
        // Squat: (225*5) + (245*3) + (265*1) = 1125 + 735 + 265 = 2125
        // Total: 2710 + 2125 = 4835
        let expectedVolume = 4835.0
        XCTAssertEqual(stats.totalVolume, expectedVolume, accuracy: 0.1)

        // Calculate expected average RPE:
        // (6.0 + 7.5 + 9.0 + 7.0 + 8.5 + 10.0) / 6 = 48.0 / 6 = 8.0
        let expectedAverageRPE = 8.0
        XCTAssertEqual(stats.averageRPE, expectedAverageRPE, accuracy: 0.1)

        XCTAssertGreaterThan(stats.duration, 0)
    }

    // MARK: - Set Data Validation Integration Test

    /// Integration test for set data validation
    /// Validates that invalid set data is properly rejected
    func testSetDataValidationIntegration() async throws {
        // GIVEN: Active workout session with exercise
        let workoutConfig = WorkoutSessionConfig(name: "Validation Test Workout")
        let session = try await workoutService.createSession(config: workoutConfig)
        try await workoutService.startSession(sessionId: session.id)

        let exercises = try await exerciseLibraryService.getAllExercises()
        let exercise = exercises.first!
        let request = AddExerciseRequest(exerciseId: exercise.id)
        let workoutExercise = try await workoutService.addExercise(sessionId: session.id, request: request)

        // WHEN: User attempts to log invalid set data
        let invalidSetData = [
            SetData(weight: -50.0, reps: 10, rpe: 7.0), // Negative weight
            SetData(weight: 100.0, reps: -5, rpe: 7.0), // Negative reps
            SetData(weight: 100.0, reps: 1500, rpe: 7.0), // Excessive reps
            SetData(weight: 100.0, reps: 10, rpe: 15.0), // Invalid RPE
            SetData(weight: 100.0, reps: 10, rpe: 0.5), // Invalid RPE
        ]

        // THEN: All invalid set data should be rejected
        for (index, invalidSet) in invalidSetData.enumerated() {
            do {
                _ = try await workoutService.addSet(
                    sessionId: session.id,
                    exerciseId: workoutExercise.id,
                    setData: invalidSet
                )
                XCTFail("Expected validation error for invalid set data at index \(index)")
            } catch WorkoutServiceError.validationError {
                // Expected - validation should catch the error
            } catch {
                XCTFail("Unexpected error for invalid set data at index \(index): \(error)")
            }
        }

        // WHEN: User logs valid set data
        let validSetData = SetData(weight: 100.0, reps: 10, rpe: 7.5)
        let validSet = try await workoutService.addSet(
            sessionId: session.id,
            exerciseId: workoutExercise.id,
            setData: validSetData
        )

        // THEN: Valid set data should be accepted
        XCTAssertEqual(validSet.weight, 100.0)
        XCTAssertEqual(validSet.reps, 10)
        XCTAssertEqual(validSet.rpe, 7.5, accuracy: 0.1)
    }

    // MARK: - Duplicate Last Set Integration Test

    /// Integration test for duplicating the last set
    /// Validates that users can quickly duplicate previous set data
    func testDuplicateLastSetIntegration() async throws {
        // GIVEN: Active workout with logged sets
        let workoutConfig = WorkoutSessionConfig(name: "Duplicate Set Test")
        let session = try await workoutService.createSession(config: workoutConfig)
        try await workoutService.startSession(sessionId: session.id)

        let exercises = try await exerciseLibraryService.getAllExercises()
        let exercise = exercises.first!
        let request = AddExerciseRequest(exerciseId: exercise.id)
        let workoutExercise = try await workoutService.addExercise(sessionId: session.id, request: request)

        // Log initial sets
        let set1Data = SetData(weight: 100.0, reps: 10, rpe: 7.0)
        let set2Data = SetData(weight: 110.0, reps: 8, rpe: 8.0)

        _ = try await workoutService.addSet(sessionId: session.id, exerciseId: workoutExercise.id, setData: set1Data)
        let lastSet = try await workoutService.addSet(sessionId: session.id, exerciseId: workoutExercise.id, setData: set2Data)

        // WHEN: User duplicates the last set
        let duplicatedSet = try await workoutService.duplicateLastSet(
            sessionId: session.id,
            exerciseId: workoutExercise.id
        )

        // THEN: Duplicated set has the same data as the last set
        XCTAssertEqual(duplicatedSet.weight, lastSet.weight)
        XCTAssertEqual(duplicatedSet.reps, lastSet.reps)
        XCTAssertEqual(duplicatedSet.rpe, lastSet.rpe, accuracy: 0.1)
        XCTAssertNotEqual(duplicatedSet.id, lastSet.id) // Should be a new set with new ID
    }

    // MARK: - Exercise Management Integration Test

    /// Integration test for adding and removing exercises during workout
    /// Validates that exercise management works properly within active sessions
    func testExerciseManagementIntegration() async throws {
        // GIVEN: Active workout session
        let workoutConfig = WorkoutSessionConfig(name: "Exercise Management Test")
        let session = try await workoutService.createSession(config: workoutConfig)
        try await workoutService.startSession(sessionId: session.id)

        let exercises = try await exerciseLibraryService.getAllExercises()
        XCTAssertGreaterThanOrEqual(exercises.count, 3, "Need at least 3 exercises for test")

        // WHEN: User adds multiple exercises
        let exercise1 = exercises[0]
        let exercise2 = exercises[1]
        let exercise3 = exercises[2]

        let request1 = AddExerciseRequest(exerciseId: exercise1.id, orderIndex: 1)
        let request2 = AddExerciseRequest(exerciseId: exercise2.id, orderIndex: 2)
        let request3 = AddExerciseRequest(exerciseId: exercise3.id, orderIndex: 3)

        let workoutExercise1 = try await workoutService.addExercise(sessionId: session.id, request: request1)
        let workoutExercise2 = try await workoutService.addExercise(sessionId: session.id, request: request2)
        let workoutExercise3 = try await workoutService.addExercise(sessionId: session.id, request: request3)

        // THEN: All exercises should be added to the session
        let sessionWithExercises = try await workoutService.getSession(sessionId: session.id)
        XCTAssertEqual(sessionWithExercises.exercises.count, 3)

        // WHEN: User removes the middle exercise
        try await workoutService.removeExercise(sessionId: session.id, exerciseId: workoutExercise2.id)

        // THEN: Session should have 2 exercises remaining
        let sessionAfterRemoval = try await workoutService.getSession(sessionId: session.id)
        XCTAssertEqual(sessionAfterRemoval.exercises.count, 2)

        // Verify correct exercises remain
        let remainingExerciseIds = sessionAfterRemoval.exercises.map { $0.exercise.id }
        XCTAssertTrue(remainingExerciseIds.contains(exercise1.id))
        XCTAssertFalse(remainingExerciseIds.contains(exercise2.id))
        XCTAssertTrue(remainingExerciseIds.contains(exercise3.id))

        // WHEN: User reorders exercises
        let reorderedIds = [workoutExercise3.id, workoutExercise1.id]
        try await workoutService.reorderExercises(sessionId: session.id, exerciseOrdering: reorderedIds)

        // THEN: Exercises should be in the new order
        let reorderedSession = try await workoutService.getSession(sessionId: session.id)
        let orderedExercises = reorderedSession.exercises.sorted { $0.orderIndex < $1.orderIndex }
        XCTAssertEqual(orderedExercises[0].id, workoutExercise3.id)
        XCTAssertEqual(orderedExercises[1].id, workoutExercise1.id)
    }

    // MARK: - Session State Management Integration Test

    /// Integration test for workout session state transitions
    /// Validates that session states are managed correctly
    func testSessionStateManagementIntegration() async throws {
        // GIVEN: New workout session
        let workoutConfig = WorkoutSessionConfig(name: "State Management Test")
        let session = try await workoutService.createSession(config: workoutConfig)

        // THEN: Session should be in draft state initially
        let draftSession = try await workoutService.getSession(sessionId: session.id)
        XCTAssertFalse(draftSession.isCompleted)
        XCTAssertNil(draftSession.endDate)

        // WHEN: User starts the session
        try await workoutService.startSession(sessionId: session.id)

        // THEN: Session should be in progress
        let inProgressSession = try await workoutService.getSession(sessionId: session.id)
        XCTAssertNotNil(inProgressSession.startDate)
        XCTAssertNil(inProgressSession.endDate)
        XCTAssertFalse(inProgressSession.isCompleted)

        // WHEN: User attempts invalid state transition (complete without any exercises)
        // This should work, but result in a workout with no exercises
        try await workoutService.completeSession(sessionId: session.id)

        // THEN: Session should be completed
        let completedSession = try await workoutService.getSession(sessionId: session.id)
        XCTAssertTrue(completedSession.isCompleted)
        XCTAssertNotNil(completedSession.endDate)
        XCTAssertNotNil(completedSession.startDate)
        XCTAssertGreaterThanOrEqual(completedSession.endDate!, completedSession.startDate)
    }

    // MARK: - HealthKit Integration Test

    /// Integration test for HealthKit export after workout completion
    /// Validates that completed workouts can be exported to HealthKit
    func testHealthKitExportIntegration() async throws {
        guard healthKitService.isHealthKitAvailable else {
            throw XCTSkip("HealthKit not available on this device")
        }

        // GIVEN: Completed workout session
        let workoutConfig = WorkoutSessionConfig(name: "HealthKit Export Test")
        let session = try await workoutService.createSession(config: workoutConfig)
        try await workoutService.startSession(sessionId: session.id)

        let exercises = try await exerciseLibraryService.getAllExercises()
        let exercise = exercises.first!
        let request = AddExerciseRequest(exerciseId: exercise.id)
        let workoutExercise = try await workoutService.addExercise(sessionId: session.id, request: request)

        let setData = SetData(weight: 100.0, reps: 10, rpe: 7.5)
        _ = try await workoutService.addSet(sessionId: session.id, exerciseId: workoutExercise.id, setData: setData)

        try await workoutService.completeSession(sessionId: session.id)

        let completedSession = try await workoutService.getSession(sessionId: session.id)

        // WHEN: User exports workout to HealthKit
        let healthKitConfig = HealthKitWorkoutConfig(
            sessionId: completedSession.id,
            activityType: .traditionalStrengthTraining,
            startDate: completedSession.startDate,
            endDate: completedSession.endDate!,
            duration: completedSession.duration
        )

        // Validate the config first
        let validationErrors = healthKitService.validateWorkoutData(config: healthKitConfig)
        XCTAssertTrue(validationErrors.isEmpty, "HealthKit config should be valid")

        // THEN: Export should succeed (if permissions are granted)
        do {
            try await healthKitService.exportWorkout(config: healthKitConfig)

            // Verify export was recorded
            let isExported = await healthKitService.isWorkoutExported(sessionId: completedSession.id)
            XCTAssertTrue(isExported)

        } catch HealthKitServiceError.permissionDenied {
            // Expected if permissions are not granted - test passes
            print("HealthKit export skipped due to permission denial")
        } catch {
            XCTFail("Unexpected error during HealthKit export: \(error)")
        }
    }

    // MARK: - Performance Integration Test

    /// Integration test for workout logging performance
    /// Validates that workout operations complete within acceptable time limits
    func testWorkoutLoggingPerformance() async throws {
        let startTime = Date()

        // Create and start session
        let sessionStart = Date()
        let workoutConfig = WorkoutSessionConfig(name: "Performance Test")
        let session = try await workoutService.createSession(config: workoutConfig)
        try await workoutService.startSession(sessionId: session.id)
        let sessionDuration = Date().timeIntervalSince(sessionStart)

        XCTAssertLessThan(sessionDuration, 0.5, "Session creation and start should complete within 500ms")

        // Add exercise
        let exerciseStart = Date()
        let exercises = try await exerciseLibraryService.getAllExercises()
        let exercise = exercises.first!
        let request = AddExerciseRequest(exerciseId: exercise.id)
        let workoutExercise = try await workoutService.addExercise(sessionId: session.id, request: request)
        let exerciseDuration = Date().timeIntervalSince(exerciseStart)

        XCTAssertLessThan(exerciseDuration, 0.5, "Adding exercise should complete within 500ms")

        // Log multiple sets
        let setsStart = Date()
        for i in 1...10 {
            let setData = SetData(weight: Double(100 + i * 10), reps: Int32(10 - i), rpe: 7.0)
            _ = try await workoutService.addSet(sessionId: session.id, exerciseId: workoutExercise.id, setData: setData)
        }
        let setsDuration = Date().timeIntervalSince(setsStart)

        XCTAssertLessThan(setsDuration, 2.0, "Logging 10 sets should complete within 2 seconds")

        // Complete session
        let completeStart = Date()
        try await workoutService.completeSession(sessionId: session.id)
        let completeDuration = Date().timeIntervalSince(completeStart)

        XCTAssertLessThan(completeDuration, 1.0, "Completing session should finish within 1 second")

        // Overall workout logging performance
        let totalDuration = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(totalDuration, 5.0, "Complete workout logging flow should finish within 5 seconds")
    }
}