import XCTest
import Combine
@testable import GigiGains

final class ExerciseLibraryServiceTests: XCTestCase {

    var exerciseLibraryService: ExerciseLibraryService!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()

        // This will fail because ExerciseLibraryServiceImpl doesn't exist yet
        // This is intentional for TDD - tests MUST fail first
        exerciseLibraryService = ExerciseLibraryServiceImpl()
    }

    override func tearDown() {
        cancellables = nil
        exerciseLibraryService = nil
        super.tearDown()
    }

    // MARK: - Exercise Management Tests

    func testGetAllExercises() async throws {
        let exercises = try await exerciseLibraryService.getAllExercises()

        XCTAssertNotNil(exercises)
        // Should have some predefined exercises
        XCTAssertGreaterThan(exercises.count, 0)
    }

    func testGetExerciseById() async throws {
        let exercises = try await exerciseLibraryService.getAllExercises()
        guard let firstExercise = exercises.first else {
            XCTFail("No exercises found")
            return
        }

        let retrievedExercise = try await exerciseLibraryService.getExercise(id: firstExercise.id)

        XCTAssertEqual(retrievedExercise.id, firstExercise.id)
        XCTAssertEqual(retrievedExercise.name, firstExercise.name)
    }

    func testGetExerciseNotFound() async {
        let nonExistentId = UUID()

        do {
            _ = try await exerciseLibraryService.getExercise(id: nonExistentId)
            XCTFail("Expected ExerciseLibraryServiceError.exerciseNotFound")
        } catch ExerciseLibraryServiceError.exerciseNotFound(let id) {
            XCTAssertEqual(id, nonExistentId)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCreateCustomExercise() async throws {
        let exerciseData = ExerciseCreationData(
            name: "Custom Exercise",
            category: "Isolation",
            primaryMuscleGroups: ["Biceps"],
            secondaryMuscleGroups: ["Forearms"],
            equipment: "Dumbbells",
            instructions: "Custom exercise instructions",
            defaultRestTime: 90
        )

        let exercise = try await exerciseLibraryService.createCustomExercise(data: exerciseData)

        XCTAssertEqual(exercise.name, "Custom Exercise")
        XCTAssertEqual(exercise.category, "Isolation")
        XCTAssertTrue(exercise.isCustom)
        XCTAssertFalse(exercise.isArchived)
    }

    func testSearchExercises() async throws {
        let searchResults = try await exerciseLibraryService.searchExercises(query: "bench")

        XCTAssertNotNil(searchResults)
        // Should find exercises with "bench" in the name
        for exercise in searchResults {
            XCTAssertTrue(exercise.name.lowercased().contains("bench"))
        }
    }

    func testGetExercisesByCategory() async throws {
        let chestExercises = try await exerciseLibraryService.getExercisesByCategory("Compound")

        XCTAssertNotNil(chestExercises)
        for exercise in chestExercises {
            XCTAssertEqual(exercise.category, "Compound")
        }
    }

    func testGetExercisesByMuscleGroup() async throws {
        let chestExercises = try await exerciseLibraryService.getExercisesByMuscleGroup("Chest")

        XCTAssertNotNil(chestExercises)
        for exercise in chestExercises {
            let muscleGroups = exercise.primaryMuscleGroups + exercise.secondaryMuscleGroups
            XCTAssertTrue(muscleGroups.contains("Chest"))
        }
    }

    func testUpdateCustomExercise() async throws {
        let exerciseData = ExerciseCreationData(
            name: "Original Name",
            category: "Isolation",
            primaryMuscleGroups: ["Biceps"],
            equipment: "Dumbbells"
        )

        let exercise = try await exerciseLibraryService.createCustomExercise(data: exerciseData)

        let updateData = ExerciseUpdateData(
            name: "Updated Name",
            instructions: "Updated instructions",
            defaultRestTime: 120
        )

        try await exerciseLibraryService.updateCustomExercise(id: exercise.id, data: updateData)

        let updatedExercise = try await exerciseLibraryService.getExercise(id: exercise.id)
        XCTAssertEqual(updatedExercise.name, "Updated Name")
        XCTAssertEqual(updatedExercise.instructions, "Updated instructions")
        XCTAssertEqual(updatedExercise.defaultRestTime, 120, accuracy: 0.1)
    }

    func testArchiveCustomExercise() async throws {
        let exerciseData = ExerciseCreationData(
            name: "Test Exercise",
            category: "Isolation",
            primaryMuscleGroups: ["Biceps"],
            equipment: "Dumbbells"
        )

        let exercise = try await exerciseLibraryService.createCustomExercise(data: exerciseData)

        try await exerciseLibraryService.archiveExercise(id: exercise.id, isArchived: true)

        let archivedExercise = try await exerciseLibraryService.getExercise(id: exercise.id)
        XCTAssertTrue(archivedExercise.isArchived)
    }

    func testCannotArchivePredefinedExercise() async throws {
        let exercises = try await exerciseLibraryService.getAllExercises()
        guard let predefinedExercise = exercises.first(where: { !$0.isCustom }) else {
            XCTFail("No predefined exercises found")
            return
        }

        do {
            try await exerciseLibraryService.archiveExercise(id: predefinedExercise.id, isArchived: true)
            XCTFail("Expected error when archiving predefined exercise")
        } catch ExerciseLibraryServiceError.cannotModifyPredefinedExercise {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGetExerciseHistory() async throws {
        let exercises = try await exerciseLibraryService.getAllExercises()
        guard let exercise = exercises.first else {
            XCTFail("No exercises found")
            return
        }

        let history = try await exerciseLibraryService.getExerciseHistory(id: exercise.id, limit: 10)

        XCTAssertNotNil(history)
        // History might be empty for new exercises
    }

    func testGetPersonalRecords() async throws {
        let exercises = try await exerciseLibraryService.getAllExercises()
        guard let exercise = exercises.first else {
            XCTFail("No exercises found")
            return
        }

        let personalRecords = try await exerciseLibraryService.getPersonalRecords(exerciseId: exercise.id)

        XCTAssertNotNil(personalRecords)
        // Personal records might be empty for exercises with no history
    }

    func testGetExerciseStatistics() async throws {
        let exercises = try await exerciseLibraryService.getAllExercises()
        guard let exercise = exercises.first else {
            XCTFail("No exercises found")
            return
        }

        let stats = try await exerciseLibraryService.getExerciseStatistics(id: exercise.id)

        XCTAssertNotNil(stats)
        XCTAssertGreaterThanOrEqual(stats.totalSets, 0)
        XCTAssertGreaterThanOrEqual(stats.totalVolume, 0)
    }

    // MARK: - Publisher Tests

    func testExerciseLibraryUpdatePublisher() async throws {
        let expectation = XCTestExpectation(description: "Exercise library update publisher")
        var receivedExercises: [Exercise] = []

        exerciseLibraryService.exerciseLibraryUpdatePublisher
            .sink { exercises in
                receivedExercises = exercises
                expectation.fulfill()
            }
            .store(in: &cancellables)

        let exerciseData = ExerciseCreationData(
            name: "Publisher Test Exercise",
            category: "Isolation",
            primaryMuscleGroups: ["Biceps"],
            equipment: "Dumbbells"
        )

        _ = try await exerciseLibraryService.createCustomExercise(data: exerciseData)

        await fulfillment(of: [expectation], timeout: 1.0)

        XCTAssertTrue(receivedExercises.contains { $0.name == "Publisher Test Exercise" })
    }

    // MARK: - Validation Tests

    func testCreateExerciseValidation() async throws {
        let invalidData = ExerciseCreationData(
            name: "", // Empty name should fail validation
            category: "Invalid Category",
            primaryMuscleGroups: [],
            equipment: ""
        )

        do {
            _ = try await exerciseLibraryService.createCustomExercise(data: invalidData)
            XCTFail("Expected validation error")
        } catch ExerciseLibraryServiceError.validationError(let message) {
            XCTAssertTrue(message.contains("name"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDuplicateExerciseName() async throws {
        let exerciseData = ExerciseCreationData(
            name: "Duplicate Exercise",
            category: "Isolation",
            primaryMuscleGroups: ["Biceps"],
            equipment: "Dumbbells"
        )

        _ = try await exerciseLibraryService.createCustomExercise(data: exerciseData)

        do {
            _ = try await exerciseLibraryService.createCustomExercise(data: exerciseData)
            XCTFail("Expected duplicate name error")
        } catch ExerciseLibraryServiceError.duplicateExerciseName(let name) {
            XCTAssertEqual(name, "Duplicate Exercise")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Filter and Sort Tests

    func testFilterExercises() async throws {
        let filter = ExerciseFilter(
            category: "Compound",
            muscleGroup: "Chest",
            equipment: "Barbell",
            isCustom: false,
            isArchived: false
        )

        let filteredExercises = try await exerciseLibraryService.getFilteredExercises(filter: filter)

        XCTAssertNotNil(filteredExercises)
        for exercise in filteredExercises {
            XCTAssertEqual(exercise.category, "Compound")
            XCTAssertFalse(exercise.isCustom)
            XCTAssertFalse(exercise.isArchived)
            XCTAssertEqual(exercise.equipment, "Barbell")
        }
    }

    func testSortExercises() async throws {
        let exercises = try await exerciseLibraryService.getSortedExercises(sortBy: .nameAscending)

        XCTAssertNotNil(exercises)
        // Verify exercises are sorted by name
        for i in 1..<exercises.count {
            XCTAssertLessThanOrEqual(exercises[i-1].name, exercises[i].name)
        }
    }
}