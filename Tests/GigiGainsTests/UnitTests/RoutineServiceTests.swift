import XCTest
import Combine
@testable import GigiGains

final class RoutineServiceTests: XCTestCase {

    var routineService: RoutineService!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()

        // This will fail because RoutineServiceImpl doesn't exist yet
        // This is intentional for TDD - tests MUST fail first
        routineService = RoutineServiceImpl()
    }

    override func tearDown() {
        cancellables = nil
        routineService = nil
        super.tearDown()
    }

    // MARK: - Routine Management Tests

    func testCreateRoutine() async throws {
        let config = RoutineCreationConfig(name: "Push Day", estimatedDuration: 3600)

        let routine = try await routineService.createRoutine(config: config)

        XCTAssertEqual(routine.name, "Push Day")
        XCTAssertNotNil(routine.id)
        XCTAssertFalse(routine.isArchived)
        XCTAssertEqual(routine.estimatedDuration, 3600, accuracy: 0.1)
    }

    func testCreateRoutineValidation() async throws {
        let invalidConfig = RoutineCreationConfig(name: "", estimatedDuration: -100)

        do {
            _ = try await routineService.createRoutine(config: invalidConfig)
            XCTFail("Expected validation error")
        } catch RoutineServiceError.validationError(let message) {
            XCTAssertTrue(message.contains("name"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGetRoutine() async throws {
        let config = RoutineCreationConfig(name: "Pull Day")
        let createdRoutine = try await routineService.createRoutine(config: config)

        let retrievedRoutine = try await routineService.getRoutine(routineId: createdRoutine.id)

        XCTAssertEqual(retrievedRoutine.id, createdRoutine.id)
        XCTAssertEqual(retrievedRoutine.name, "Pull Day")
    }

    func testGetRoutineNotFound() async {
        let nonExistentId = UUID()

        do {
            _ = try await routineService.getRoutine(routineId: nonExistentId)
            XCTFail("Expected RoutineServiceError.routineNotFound")
        } catch RoutineServiceError.routineNotFound(let id) {
            XCTAssertEqual(id, nonExistentId)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testUpdateRoutine() async throws {
        let config = RoutineCreationConfig(name: "Original Name")
        let routine = try await routineService.createRoutine(config: config)

        try await routineService.updateRoutine(routineId: routine.id, name: "Updated Name", notes: "New notes", estimatedDuration: 1800)

        let updatedRoutine = try await routineService.getRoutine(routineId: routine.id)
        XCTAssertEqual(updatedRoutine.name, "Updated Name")
        XCTAssertEqual(updatedRoutine.notes, "New notes")
        XCTAssertEqual(updatedRoutine.estimatedDuration, 1800, accuracy: 0.1)
    }

    func testDuplicateRoutineName() async throws {
        let config1 = RoutineCreationConfig(name: "Duplicate Name")
        let config2 = RoutineCreationConfig(name: "Duplicate Name")

        _ = try await routineService.createRoutine(config: config1)

        do {
            _ = try await routineService.createRoutine(config: config2)
            XCTFail("Expected duplicate name error")
        } catch RoutineServiceError.duplicateRoutineName(let name) {
            XCTAssertEqual(name, "Duplicate Name")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Exercise Template Management Tests

    func testAddExerciseToRoutine() async throws {
        let config = RoutineCreationConfig(name: "Test Routine")
        let routine = try await routineService.createRoutine(config: config)

        let exerciseId = UUID()
        let template = RoutineExerciseTemplate(
            exerciseId: exerciseId,
            targetSets: 3,
            targetReps: [8, 8, 8],
            restTime: 180
        )

        let routineExercise = try await routineService.addExerciseToRoutine(routineId: routine.id, template: template)

        XCTAssertNotNil(routineExercise.id)
        XCTAssertEqual(routineExercise.exercise.id, exerciseId)
        XCTAssertEqual(routineExercise.targetSets, 3)
        XCTAssertEqual(routineExercise.restTime, 180, accuracy: 0.1)
    }

    func testUpdateExerciseInRoutine() async throws {
        let config = RoutineCreationConfig(name: "Test Routine")
        let routine = try await routineService.createRoutine(config: config)

        let exerciseId = UUID()
        let template = RoutineExerciseTemplate(
            exerciseId: exerciseId,
            targetSets: 3,
            targetReps: [8, 8, 8],
            restTime: 180
        )
        let routineExercise = try await routineService.addExerciseToRoutine(routineId: routine.id, template: template)

        let updatedTemplate = RoutineExerciseTemplate(
            exerciseId: exerciseId,
            targetSets: 4,
            targetReps: [10, 8, 6, 4],
            restTime: 240
        )
        try await routineService.updateExerciseInRoutine(routineId: routine.id, exerciseId: routineExercise.id, template: updatedTemplate)

        let updatedRoutine = try await routineService.getRoutine(routineId: routine.id)
        let updatedExercise = updatedRoutine.exercises.first { $0.id == routineExercise.id }
        XCTAssertNotNil(updatedExercise)
        XCTAssertEqual(updatedExercise?.targetSets, 4)
        XCTAssertEqual(updatedExercise?.restTime, 240, accuracy: 0.1)
    }

    func testRemoveExerciseFromRoutine() async throws {
        let config = RoutineCreationConfig(name: "Test Routine")
        let routine = try await routineService.createRoutine(config: config)

        let exerciseId = UUID()
        let template = RoutineExerciseTemplate(
            exerciseId: exerciseId,
            targetSets: 3,
            targetReps: [8, 8, 8]
        )
        let routineExercise = try await routineService.addExerciseToRoutine(routineId: routine.id, template: template)

        try await routineService.removeExerciseFromRoutine(routineId: routine.id, exerciseId: routineExercise.id)

        let updatedRoutine = try await routineService.getRoutine(routineId: routine.id)
        XCTAssertTrue(updatedRoutine.exercises.isEmpty)
    }

    // MARK: - Routine Usage Tests

    func testCreateWorkoutFromRoutine() async throws {
        let config = RoutineCreationConfig(name: "Test Routine")
        let routine = try await routineService.createRoutine(config: config)

        let workoutSession = try await routineService.createWorkoutFromRoutine(routineId: routine.id, sessionName: "Test Session", sessionNotes: nil)

        XCTAssertEqual(workoutSession.name, "Test Session")
        XCTAssertEqual(workoutSession.routine?.id, routine.id)
        XCTAssertNotNil(workoutSession.id)
    }

    func testMarkRoutineAsUsed() async throws {
        let config = RoutineCreationConfig(name: "Test Routine")
        let routine = try await routineService.createRoutine(config: config)

        let initialStats = try await routineService.getRoutineStatistics(routineId: routine.id)
        XCTAssertEqual(initialStats.useCount, 0)

        try await routineService.markRoutineAsUsed(routineId: routine.id)

        let updatedStats = try await routineService.getRoutineStatistics(routineId: routine.id)
        XCTAssertEqual(updatedStats.useCount, 1)
        XCTAssertNotNil(updatedStats.lastUsed)
    }

    // MARK: - Routine Search and Filtering Tests

    func testGetRoutinesWithFilter() async throws {
        let config1 = RoutineCreationConfig(name: "Push Day")
        let config2 = RoutineCreationConfig(name: "Pull Day")
        let config3 = RoutineCreationConfig(name: "Leg Day")

        let routine1 = try await routineService.createRoutine(config: config1)
        let routine2 = try await routineService.createRoutine(config: config2)
        let routine3 = try await routineService.createRoutine(config: config3)

        // Archive one routine
        try await routineService.archiveRoutine(routineId: routine3.id, isArchived: true)

        let filter = RoutineFilter(isArchived: false)
        let activeRoutines = try await routineService.getRoutines(filter: filter, sortBy: .nameAscending)

        XCTAssertEqual(activeRoutines.count, 2)
        XCTAssertTrue(activeRoutines.contains { $0.id == routine1.id })
        XCTAssertTrue(activeRoutines.contains { $0.id == routine2.id })
        XCTAssertFalse(activeRoutines.contains { $0.id == routine3.id })
    }

    func testSearchRoutines() async throws {
        let config1 = RoutineCreationConfig(name: "Upper Body Workout")
        let config2 = RoutineCreationConfig(name: "Lower Body Session")
        let config3 = RoutineCreationConfig(name: "Full Body Training")

        _ = try await routineService.createRoutine(config: config1)
        _ = try await routineService.createRoutine(config: config2)
        _ = try await routineService.createRoutine(config: config3)

        let searchResults = try await routineService.searchRoutines(searchText: "Body")

        XCTAssertEqual(searchResults.count, 3)
    }

    // MARK: - Routine Statistics Tests

    func testGetRoutineStatistics() async throws {
        let config = RoutineCreationConfig(name: "Test Routine", estimatedDuration: 3600)
        let routine = try await routineService.createRoutine(config: config)

        let stats = try await routineService.getRoutineStatistics(routineId: routine.id)

        XCTAssertEqual(stats.useCount, 0)
        XCTAssertNil(stats.lastUsed)
        XCTAssertEqual(stats.exerciseCount, 0)
        XCTAssertEqual(stats.estimatedDuration, 3600, accuracy: 0.1)
    }

    func testGetMostUsedRoutines() async throws {
        let config1 = RoutineCreationConfig(name: "Routine 1")
        let config2 = RoutineCreationConfig(name: "Routine 2")

        let routine1 = try await routineService.createRoutine(config: config1)
        let routine2 = try await routineService.createRoutine(config: config2)

        // Use routine1 more than routine2
        try await routineService.markRoutineAsUsed(routineId: routine1.id)
        try await routineService.markRoutineAsUsed(routineId: routine1.id)
        try await routineService.markRoutineAsUsed(routineId: routine2.id)

        let mostUsed = try await routineService.getMostUsedRoutines(limit: 2)

        XCTAssertEqual(mostUsed.count, 2)
        XCTAssertEqual(mostUsed.first?.id, routine1.id) // Most used should be first
    }

    // MARK: - Publisher Tests

    func testRoutinesUpdatePublisher() async throws {
        let expectation = XCTestExpectation(description: "Routines update publisher")
        var receivedRoutines: [Routine] = []

        routineService.routinesUpdatePublisher
            .sink { routines in
                receivedRoutines = routines
                expectation.fulfill()
            }
            .store(in: &cancellables)

        let config = RoutineCreationConfig(name: "Test Routine")
        _ = try await routineService.createRoutine(config: config)

        await fulfillment(of: [expectation], timeout: 1.0)

        XCTAssertEqual(receivedRoutines.count, 1)
        XCTAssertEqual(receivedRoutines.first?.name, "Test Routine")
    }

    // MARK: - Validation Tests

    func testValidateRoutine() async throws {
        let config = RoutineCreationConfig(name: "Test Routine")
        let routine = try await routineService.createRoutine(config: config)

        let validationIssues = try await routineService.validateRoutine(routineId: routine.id)

        // A routine with no exercises should have validation issues
        XCTAssertFalse(validationIssues.isEmpty)
        XCTAssertTrue(validationIssues.contains { $0.contains("exercise") })
    }

    func testEstimateRoutineDuration() async throws {
        let config = RoutineCreationConfig(name: "Test Routine")
        let routine = try await routineService.createRoutine(config: config)

        let exerciseId = UUID()
        let template = RoutineExerciseTemplate(
            exerciseId: exerciseId,
            targetSets: 3,
            targetReps: [8, 8, 8],
            restTime: 120
        )
        _ = try await routineService.addExerciseToRoutine(routineId: routine.id, template: template)

        let estimatedDuration = try await routineService.estimateRoutineDuration(routineId: routine.id)

        // Should include rest time calculations: 3 sets * 120 seconds rest = 360 seconds
        XCTAssertGreaterThan(estimatedDuration, 360)
    }

    // MARK: - Archiving Tests

    func testArchiveRoutine() async throws {
        let config = RoutineCreationConfig(name: "Test Routine")
        let routine = try await routineService.createRoutine(config: config)

        try await routineService.archiveRoutine(routineId: routine.id, isArchived: true)

        let archivedRoutine = try await routineService.getRoutine(routineId: routine.id)
        XCTAssertTrue(archivedRoutine.isArchived)
    }

    func testDeleteRoutine() async throws {
        let config = RoutineCreationConfig(name: "Test Routine")
        let routine = try await routineService.createRoutine(config: config)

        try await routineService.deleteRoutine(routineId: routine.id)

        do {
            _ = try await routineService.getRoutine(routineId: routine.id)
            XCTFail("Expected routine to be deleted")
        } catch RoutineServiceError.routineNotFound {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}