//
//  CoreDataPerformanceTests.swift
//  Gigi Gains Tests
//
//  Performance tests for Core Data operations and query optimization.
//  Ensures database operations remain fast as data volume grows.
//
//  Created: 2025-09-28
//

import XCTest
import CoreData
@testable import GigiGains

final class CoreDataPerformanceTests: XCTestCase {

    private var container: DependencyContainer!
    private var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        container = DependencyContainer(isTestEnvironment: true)
        context = container.viewContext
    }

    override func tearDown() {
        container.resetForTesting()
        container = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Workout Creation Performance

    func testWorkoutCreationPerformance() {
        measure {
            for i in 0..<100 {
                let workout = NSEntityDescription.insertNewObject(forEntityName: "WorkoutSession", into: context)
                workout.setValue(UUID(), forKey: "id")
                workout.setValue("Test Workout \(i)", forKey: "name")
                workout.setValue(Date(), forKey: "startTime")
                workout.setValue(Date().addingTimeInterval(3600), forKey: "endTime")
                workout.setValue(false, forKey: "isCompleted")
            }

            do {
                try context.save()
            } catch {
                XCTFail("Failed to save workouts: \(error)")
            }
        }
    }

    func testBulkWorkoutCreation() {
        let workouts = (0..<1000).map { i in
            let workout = NSEntityDescription.insertNewObject(forEntityName: "WorkoutSession", into: context)
            workout.setValue(UUID(), forKey: "id")
            workout.setValue("Bulk Workout \(i)", forKey: "name")
            workout.setValue(Date().addingTimeInterval(TimeInterval(-i * 86400)), forKey: "startTime")
            workout.setValue(Date().addingTimeInterval(TimeInterval(-i * 86400 + 3600)), forKey: "endTime")
            workout.setValue(true, forKey: "isCompleted")
            return workout
        }

        measure {
            do {
                try context.save()
            } catch {
                XCTFail("Failed to save bulk workouts: \(error)")
            }
        }
    }

    // MARK: - Exercise Data Performance

    func testExerciseLibraryLoadPerformance() {
        // First, create a large exercise library
        for i in 0..<500 {
            let exercise = NSEntityDescription.insertNewObject(forEntityName: "ExerciseDefinition", into: context)
            exercise.setValue(UUID(), forKey: "id")
            exercise.setValue("Exercise \(i)", forKey: "name")
            exercise.setValue(["Chest", "Shoulders"].randomElement(), forKey: "primaryMuscleGroup")
            exercise.setValue(["Barbell", "Dumbbell", "Machine"].randomElement(), forKey: "equipment")
            exercise.setValue("Test instructions for exercise \(i)", forKey: "instructions")
        }

        try! context.save()

        // Test fetching all exercises
        measure {
            let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "ExerciseDefinition")
            do {
                let exercises = try context.fetch(fetchRequest)
                XCTAssertEqual(exercises.count, 500)
            } catch {
                XCTFail("Failed to fetch exercises: \(error)")
            }
        }
    }

    func testExerciseSearchPerformance() {
        // Create exercise data with searchable content
        let muscleGroups = ["Chest", "Back", "Shoulders", "Arms", "Legs", "Core"]
        let equipmentTypes = ["Barbell", "Dumbbell", "Cable", "Machine", "Bodyweight"]

        for i in 0..<1000 {
            let exercise = NSEntityDescription.insertNewObject(forEntityName: "ExerciseDefinition", into: context)
            exercise.setValue(UUID(), forKey: "id")
            exercise.setValue("Exercise \(i) Bench Press Variation", forKey: "name")
            exercise.setValue(muscleGroups.randomElement(), forKey: "primaryMuscleGroup")
            exercise.setValue(equipmentTypes.randomElement(), forKey: "equipment")
        }

        try! context.save()

        // Test search performance
        measure {
            let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "ExerciseDefinition")
            fetchRequest.predicate = NSPredicate(format: "name CONTAINS[cd] %@", "Bench")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

            do {
                let results = try context.fetch(fetchRequest)
                XCTAssertGreaterThan(results.count, 0)
            } catch {
                XCTFail("Failed to search exercises: \(error)")
            }
        }
    }

    // MARK: - Set Data Performance

    func testMassiveSetDataCreation() {
        // Create workout with many sets
        let workout = NSEntityDescription.insertNewObject(forEntityName: "WorkoutSession", into: context)
        workout.setValue(UUID(), forKey: "id")
        workout.setValue("High Volume Workout", forKey: "name")
        workout.setValue(Date(), forKey: "startTime")

        let exercise = NSEntityDescription.insertNewObject(forEntityName: "ExerciseDefinition", into: context)
        exercise.setValue(UUID(), forKey: "id")
        exercise.setValue("Test Exercise", forKey: "name")

        measure {
            // Create 500 sets (representing a very high volume workout)
            for i in 0..<500 {
                let set = NSEntityDescription.insertNewObject(forEntityName: "WorkoutSet", into: context)
                set.setValue(UUID(), forKey: "id")
                set.setValue(Double(100 + i % 200), forKey: "weight")
                set.setValue(Int32(5 + i % 15), forKey: "reps")
                set.setValue(Int32(i), forKey: "setNumber")
                set.setValue(Date().addingTimeInterval(TimeInterval(i * 180)), forKey: "completedAt")
                set.setValue(workout, forKey: "workout")
                set.setValue(exercise, forKey: "exercise")
            }

            do {
                try context.save()
            } catch {
                XCTFail("Failed to save sets: \(error)")
            }
        }
    }

    func testSetHistoryQuery() {
        // Create historical data for performance testing
        let exercise = NSEntityDescription.insertNewObject(forEntityName: "ExerciseDefinition", into: context)
        exercise.setValue(UUID(), forKey: "id")
        exercise.setValue("Bench Press", forKey: "name")

        // Create 100 workouts with sets over time
        for workoutIndex in 0..<100 {
            let workout = NSEntityDescription.insertNewObject(forEntityName: "WorkoutSession", into: context)
            workout.setValue(UUID(), forKey: "id")
            workout.setValue("Workout \(workoutIndex)", forKey: "name")
            workout.setValue(Date().addingTimeInterval(TimeInterval(-workoutIndex * 86400)), forKey: "startTime")

            // 3-5 sets per workout
            for setIndex in 0..<(3 + workoutIndex % 3) {
                let set = NSEntityDescription.insertNewObject(forEntityName: "WorkoutSet", into: context)
                set.setValue(UUID(), forKey: "id")
                set.setValue(Double(135 + workoutIndex), forKey: "weight")
                set.setValue(Int32(8 - setIndex), forKey: "reps")
                set.setValue(Int32(setIndex), forKey: "setNumber")
                set.setValue(workout, forKey: "workout")
                set.setValue(exercise, forKey: "exercise")
            }
        }

        try! context.save()

        // Test querying exercise history
        measure {
            let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "WorkoutSet")
            fetchRequest.predicate = NSPredicate(format: "exercise == %@", exercise)
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(key: "workout.startTime", ascending: false),
                NSSortDescriptor(key: "setNumber", ascending: true)
            ]
            fetchRequest.fetchLimit = 50 // Recent 50 sets

            do {
                let sets = try context.fetch(fetchRequest)
                XCTAssertLessThanOrEqual(sets.count, 50)
            } catch {
                XCTFail("Failed to query exercise history: \(error)")
            }
        }
    }

    // MARK: - Progress Tracking Performance

    func testProgressDataAggregation() {
        // Create substantial historical data
        let exercises = (0..<10).map { i in
            let exercise = NSEntityDescription.insertNewObject(forEntityName: "ExerciseDefinition", into: context)
            exercise.setValue(UUID(), forKey: "id")
            exercise.setValue("Exercise \(i)", forKey: "name")
            return exercise
        }

        // Create 6 months of workout data
        for day in 0..<180 {
            let workout = NSEntityDescription.insertNewObject(forEntityName: "WorkoutSession", into: context)
            workout.setValue(UUID(), forKey: "id")
            workout.setValue("Day \(day) Workout", forKey: "name")
            workout.setValue(Date().addingTimeInterval(TimeInterval(-day * 86400)), forKey: "startTime")

            // Each workout has 2-3 exercises with 3-5 sets each
            for exerciseIndex in 0..<(2 + day % 2) {
                let exercise = exercises[exerciseIndex % exercises.count]

                for setIndex in 0..<(3 + day % 3) {
                    let set = NSEntityDescription.insertNewObject(forEntityName: "WorkoutSet", into: context)
                    set.setValue(UUID(), forKey: "id")
                    set.setValue(Double(100 + day + setIndex * 5), forKey: "weight")
                    set.setValue(Int32(8 + setIndex), forKey: "reps")
                    set.setValue(Int32(setIndex), forKey: "setNumber")
                    set.setValue(workout, forKey: "workout")
                    set.setValue(exercise, forKey: "exercise")
                }
            }
        }

        try! context.save()

        // Test aggregating progress data
        measure {
            let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "WorkoutSet")
            fetchRequest.predicate = NSPredicate(format: "workout.startTime >= %@", Date().addingTimeInterval(-30 * 86400))

            do {
                let recentSets = try context.fetch(fetchRequest)
                let totalVolume = recentSets.reduce(0.0) { total, set in
                    let weight = set.value(forKey: "weight") as? Double ?? 0
                    let reps = set.value(forKey: "reps") as? Int32 ?? 0
                    return total + (weight * Double(reps))
                }
                XCTAssertGreaterThan(totalVolume, 0)
            } catch {
                XCTFail("Failed to aggregate progress data: \(error)")
            }
        }
    }

    func testPersonalRecordCalculation() {
        let exercise = NSEntityDescription.insertNewObject(forEntityName: "ExerciseDefinition", into: context)
        exercise.setValue(UUID(), forKey: "id")
        exercise.setValue("Deadlift", forKey: "name")

        // Create varied weight/rep combinations
        let weightRepCombinations = [
            (135.0, 15), (155.0, 12), (185.0, 10), (205.0, 8),
            (225.0, 6), (245.0, 4), (265.0, 3), (285.0, 2), (315.0, 1)
        ]

        for (index, (weight, reps)) in weightRepCombinations.enumerated() {
            let workout = NSEntityDescription.insertNewObject(forEntityName: "WorkoutSession", into: context)
            workout.setValue(UUID(), forKey: "id")
            workout.setValue("PR Session \(index)", forKey: "name")
            workout.setValue(Date().addingTimeInterval(TimeInterval(-index * 86400 * 7)), forKey: "startTime")

            let set = NSEntityDescription.insertNewObject(forEntityName: "WorkoutSet", into: context)
            set.setValue(UUID(), forKey: "id")
            set.setValue(weight, forKey: "weight")
            set.setValue(Int32(reps), forKey: "reps")
            set.setValue(Int32(0), forKey: "setNumber")
            set.setValue(workout, forKey: "workout")
            set.setValue(exercise, forKey: "exercise")
        }

        try! context.save()

        // Test finding personal records
        measure {
            let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "WorkoutSet")
            fetchRequest.predicate = NSPredicate(format: "exercise == %@", exercise)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "weight", ascending: false)]

            do {
                let sets = try context.fetch(fetchRequest)
                let maxWeight = sets.first?.value(forKey: "weight") as? Double ?? 0
                XCTAssertEqual(maxWeight, 315.0)

                // Calculate estimated 1RM for all sets
                let oneRMs = sets.compactMap { set -> Double? in
                    guard let weight = set.value(forKey: "weight") as? Double,
                          let reps = set.value(forKey: "reps") as? Int32 else { return nil }
                    return weight * (1 + Double(reps) / 30.0) // Epley formula
                }

                let maxOneRM = oneRMs.max() ?? 0
                XCTAssertGreaterThan(maxOneRM, 315.0)
            } catch {
                XCTFail("Failed to calculate personal records: \(error)")
            }
        }
    }

    // MARK: - Memory Usage Tests

    func testMemoryUsageWithLargeDataset() {
        let startMemory = getMemoryUsage()

        // Create significant amount of data
        for i in 0..<1000 {
            let workout = NSEntityDescription.insertNewObject(forEntityName: "WorkoutSession", into: context)
            workout.setValue(UUID(), forKey: "id")
            workout.setValue("Memory Test \(i)", forKey: "name")
            workout.setValue(Date().addingTimeInterval(TimeInterval(-i * 3600)), forKey: "startTime")

            for j in 0..<10 {
                let set = NSEntityDescription.insertNewObject(forEntityName: "WorkoutSet", into: context)
                set.setValue(UUID(), forKey: "id")
                set.setValue(Double(100 + j * 10), forKey: "weight")
                set.setValue(Int32(8), forKey: "reps")
                set.setValue(workout, forKey: "workout")
            }
        }

        try! context.save()

        let endMemory = getMemoryUsage()
        let memoryIncrease = endMemory - startMemory

        // Memory increase should be reasonable (less than 50MB for this dataset)
        XCTAssertLessThan(memoryIncrease, 50_000_000, "Memory usage should be reasonable")

        // Test that context can be reset to free memory
        context.reset()

        let resetMemory = getMemoryUsage()
        XCTAssertLessThan(resetMemory - startMemory, memoryIncrease / 2, "Context reset should free significant memory")
    }

    // MARK: - Concurrent Access Performance

    func testConcurrentReadPerformance() {
        // Create test data
        for i in 0..<100 {
            let workout = NSEntityDescription.insertNewObject(forEntityName: "WorkoutSession", into: context)
            workout.setValue(UUID(), forKey: "id")
            workout.setValue("Concurrent Test \(i)", forKey: "name")
            workout.setValue(Date(), forKey: "startTime")
        }
        try! context.save()

        let expectation = XCTestExpectation(description: "Concurrent reads complete")
        expectation.expectedFulfillmentCount = 5

        measure {
            for _ in 0..<5 {
                container.performBackgroundTask { backgroundContext in
                    let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "WorkoutSession")
                    do {
                        let workouts = try backgroundContext.fetch(fetchRequest)
                        XCTAssertEqual(workouts.count, 100)
                    } catch {
                        XCTFail("Concurrent read failed: \(error)")
                    }
                    expectation.fulfill()
                }
            }
        }

        wait(for: [expectation], timeout: 10.0)
    }

    // MARK: - Query Optimization Tests

    func testIndexedQueryPerformance() {
        // Create data that will benefit from indexing
        for i in 0..<1000 {
            let workout = NSEntityDescription.insertNewObject(forEntityName: "WorkoutSession", into: context)
            workout.setValue(UUID(), forKey: "id")
            workout.setValue("Indexed Test \(i)", forKey: "name")
            workout.setValue(Date().addingTimeInterval(TimeInterval(-i * 86400)), forKey: "startTime")
            workout.setValue(i % 10 == 0, forKey: "isCompleted") // 10% completed
        }
        try! context.save()

        // Test date-based queries (should be indexed)
        measure {
            let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "WorkoutSession")
            fetchRequest.predicate = NSPredicate(format: "startTime >= %@", Date().addingTimeInterval(-30 * 86400))
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]

            do {
                let recentWorkouts = try context.fetch(fetchRequest)
                XCTAssertLessThanOrEqual(recentWorkouts.count, 30)
            } catch {
                XCTFail("Indexed query failed: \(error)")
            }
        }
    }

    func testCompoundQueryPerformance() {
        // Create exercise data
        let exercises = (0..<50).map { i in
            let exercise = NSEntityDescription.insertNewObject(forEntityName: "ExerciseDefinition", into: context)
            exercise.setValue(UUID(), forKey: "id")
            exercise.setValue("Exercise \(i)", forKey: "name")
            exercise.setValue(["Chest", "Back", "Legs"][i % 3], forKey: "primaryMuscleGroup")
            return exercise
        }

        // Create workout data
        for i in 0..<200 {
            let workout = NSEntityDescription.insertNewObject(forEntityName: "WorkoutSession", into: context)
            workout.setValue(UUID(), forKey: "id")
            workout.setValue("Compound Query Test \(i)", forKey: "name")
            workout.setValue(Date().addingTimeInterval(TimeInterval(-i * 86400)), forKey: "startTime")

            let set = NSEntityDescription.insertNewObject(forEntityName: "WorkoutSet", into: context)
            set.setValue(UUID(), forKey: "id")
            set.setValue(Double(100 + i), forKey: "weight")
            set.setValue(Int32(8), forKey: "reps")
            set.setValue(workout, forKey: "workout")
            set.setValue(exercises[i % exercises.count], forKey: "exercise")
        }

        try! context.save()

        // Test complex compound query
        measure {
            let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "WorkoutSet")
            fetchRequest.predicate = NSPredicate(format: "exercise.primaryMuscleGroup == %@ AND weight >= %@ AND workout.startTime >= %@",
                                                "Chest", 150.0, Date().addingTimeInterval(-60 * 86400))
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(key: "workout.startTime", ascending: false),
                NSSortDescriptor(key: "weight", ascending: false)
            ]

            do {
                let results = try context.fetch(fetchRequest)
                XCTAssertGreaterThan(results.count, 0)
            } catch {
                XCTFail("Compound query failed: \(error)")
            }
        }
    }

    // MARK: - Helper Methods

    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return kerr == KERN_SUCCESS ? info.resident_size : 0
    }
}