import XCTest
import Combine
@testable import GigiGains

final class WorkoutServiceTests: XCTestCase {

    var workoutService: WorkoutService!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()

        // This will fail because WorkoutServiceImpl doesn't exist yet
        // This is intentional for TDD - tests MUST fail first
        workoutService = WorkoutServiceImpl()
    }

    override func tearDown() {
        cancellables = nil
        workoutService = nil
        super.tearDown()
    }

    // MARK: - Session Management Tests

    func testCreateSession() async throws {
        let config = WorkoutSessionConfig(name: "Test Workout")

        let session = try await workoutService.createSession(config: config)

        XCTAssertEqual(session.name, "Test Workout")
        XCTAssertNotNil(session.id)
        XCTAssertFalse(session.isCompleted)
    }

    func testGetSession() async throws {
        let config = WorkoutSessionConfig(name: "Test Workout")
        let createdSession = try await workoutService.createSession(config: config)

        let retrievedSession = try await workoutService.getSession(sessionId: createdSession.id)

        XCTAssertEqual(retrievedSession.id, createdSession.id)
        XCTAssertEqual(retrievedSession.name, "Test Workout")
    }

    func testGetSessionNotFound() async {
        let nonExistentId = UUID()

        do {
            _ = try await workoutService.getSession(sessionId: nonExistentId)
            XCTFail("Expected WorkoutServiceError.sessionNotFound")
        } catch WorkoutServiceError.sessionNotFound(let id) {
            XCTAssertEqual(id, nonExistentId)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testStartSession() async throws {
        let config = WorkoutSessionConfig(name: "Test Workout")
        let session = try await workoutService.createSession(config: config)

        try await workoutService.startSession(sessionId: session.id)

        let updatedSession = try await workoutService.getSession(sessionId: session.id)
        XCTAssertEqual(updatedSession.startDate.timeIntervalSinceNow, 0, accuracy: 5)
    }

    func testCompleteSession() async throws {
        let config = WorkoutSessionConfig(name: "Test Workout")
        let session = try await workoutService.createSession(config: config)

        try await workoutService.startSession(sessionId: session.id)
        try await workoutService.completeSession(sessionId: session.id)

        let completedSession = try await workoutService.getSession(sessionId: session.id)
        XCTAssertTrue(completedSession.isCompleted)
        XCTAssertNotNil(completedSession.endDate)
    }

    // MARK: - Exercise Management Tests

    func testAddExercise() async throws {
        let config = WorkoutSessionConfig(name: "Test Workout")
        let session = try await workoutService.createSession(config: config)

        let exerciseId = UUID()
        let request = AddExerciseRequest(exerciseId: exerciseId)

        let workoutExercise = try await workoutService.addExercise(sessionId: session.id, request: request)

        XCTAssertNotNil(workoutExercise.id)
        XCTAssertEqual(workoutExercise.exercise.id, exerciseId)
    }

    func testRemoveExercise() async throws {
        let config = WorkoutSessionConfig(name: "Test Workout")
        let session = try await workoutService.createSession(config: config)

        let exerciseId = UUID()
        let request = AddExerciseRequest(exerciseId: exerciseId)
        let workoutExercise = try await workoutService.addExercise(sessionId: session.id, request: request)

        try await workoutService.removeExercise(sessionId: session.id, exerciseId: workoutExercise.id)

        // Verify exercise is removed
        let updatedSession = try await workoutService.getSession(sessionId: session.id)
        XCTAssertTrue(updatedSession.exercises.isEmpty)
    }

    // MARK: - Set Management Tests

    func testAddSet() async throws {
        let config = WorkoutSessionConfig(name: "Test Workout")
        let session = try await workoutService.createSession(config: config)

        let exerciseId = UUID()
        let request = AddExerciseRequest(exerciseId: exerciseId)
        let workoutExercise = try await workoutService.addExercise(sessionId: session.id, request: request)

        let setData = SetData(weight: 100.0, reps: 10, rpe: 7.5)
        let exerciseSet = try await workoutService.addSet(sessionId: session.id, exerciseId: workoutExercise.id, setData: setData)

        XCTAssertNotNil(exerciseSet.id)
        XCTAssertEqual(exerciseSet.weight, 100.0)
        XCTAssertEqual(exerciseSet.reps, 10)
        XCTAssertEqual(exerciseSet.rpe, 7.5, accuracy: 0.1)
    }

    func testAddSetValidation() async throws {
        let config = WorkoutSessionConfig(name: "Test Workout")
        let session = try await workoutService.createSession(config: config)

        let exerciseId = UUID()
        let request = AddExerciseRequest(exerciseId: exerciseId)
        let workoutExercise = try await workoutService.addExercise(sessionId: session.id, request: request)

        // Test invalid RPE
        let invalidSetData = SetData(weight: 100.0, reps: 10, rpe: 15.0)

        do {
            _ = try await workoutService.addSet(sessionId: session.id, exerciseId: workoutExercise.id, setData: invalidSetData)
            XCTFail("Expected validation error")
        } catch WorkoutServiceError.validationError(let message) {
            XCTAssertTrue(message.contains("RPE"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDuplicateLastSet() async throws {
        let config = WorkoutSessionConfig(name: "Test Workout")
        let session = try await workoutService.createSession(config: config)

        let exerciseId = UUID()
        let request = AddExerciseRequest(exerciseId: exerciseId)
        let workoutExercise = try await workoutService.addExercise(sessionId: session.id, request: request)

        let setData = SetData(weight: 100.0, reps: 10, rpe: 7.5)
        _ = try await workoutService.addSet(sessionId: session.id, exerciseId: workoutExercise.id, setData: setData)

        let duplicatedSet = try await workoutService.duplicateLastSet(sessionId: session.id, exerciseId: workoutExercise.id)

        XCTAssertEqual(duplicatedSet.weight, 100.0)
        XCTAssertEqual(duplicatedSet.reps, 10)
        XCTAssertEqual(duplicatedSet.rpe, 7.5, accuracy: 0.1)
    }

    // MARK: - Session Statistics Tests

    func testGetSessionStatistics() async throws {
        let config = WorkoutSessionConfig(name: "Test Workout")
        let session = try await workoutService.createSession(config: config)

        let stats = try await workoutService.getSessionStatistics(sessionId: session.id)

        XCTAssertEqual(stats.totalSets, 0)
        XCTAssertEqual(stats.totalExercises, 0)
        XCTAssertEqual(stats.totalVolume, 0.0)
    }

    // MARK: - Publisher Tests

    func testCurrentSessionPublisher() async throws {
        let expectation = XCTestExpectation(description: "Current session publisher")
        var receivedSession: WorkoutSession?

        workoutService.currentSessionPublisher
            .sink { session in
                receivedSession = session
                expectation.fulfill()
            }
            .store(in: &cancellables)

        let config = WorkoutSessionConfig(name: "Test Workout")
        let session = try await workoutService.createSession(config: config)
        try await workoutService.startSession(sessionId: session.id)

        await fulfillment(of: [expectation], timeout: 1.0)

        XCTAssertNotNil(receivedSession)
        XCTAssertEqual(receivedSession?.id, session.id)
    }

    // MARK: - Error Handling Tests

    func testInvalidSessionStateTransition() async throws {
        let config = WorkoutSessionConfig(name: "Test Workout")
        let session = try await workoutService.createSession(config: config)

        // Try to complete session without starting it
        do {
            try await workoutService.completeSession(sessionId: session.id)
            XCTFail("Expected invalidSessionState error")
        } catch WorkoutServiceError.invalidSessionState(let current, let required) {
            XCTAssertEqual(current, .draft)
            XCTAssertEqual(required, .inProgress)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testConcurrentAccess() async throws {
        let config = WorkoutSessionConfig(name: "Test Workout")
        let session = try await workoutService.createSession(config: config)

        // Simulate concurrent modifications
        async let task1: () = workoutService.startSession(sessionId: session.id)
        async let task2: () = workoutService.updateSession(sessionId: session.id, name: "Updated Name", notes: nil)

        // One or both should succeed, but no data corruption
        do {
            _ = try await task1
            _ = try await task2
        } catch {
            // Concurrent modification errors are acceptable
            XCTAssertTrue(error is WorkoutServiceError)
        }
    }
}