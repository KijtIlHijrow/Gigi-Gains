import XCTest
import Combine
import HealthKit
@testable import GigiGains

final class HealthKitServiceTests: XCTestCase {

    var healthKitService: HealthKitService!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()

        // This will fail because HealthKitServiceImpl doesn't exist yet
        // This is intentional for TDD - tests MUST fail first
        healthKitService = HealthKitServiceImpl()
    }

    override func tearDown() {
        cancellables = nil
        healthKitService = nil
        super.tearDown()
    }

    // MARK: - Permission Management Tests

    func testIsHealthKitAvailable() {
        let isAvailable = healthKitService.isHealthKitAvailable

        // Should return true on iOS devices, false on simulator/unsupported platforms
        XCTAssertNotNil(isAvailable)
    }

    func testGetAuthorizationStatus() async {
        let status = await healthKitService.getAuthorizationStatus()

        XCTAssertNotNil(status.workoutWritePermission)
        XCTAssertNotNil(status.exerciseReadPermission)
        XCTAssertNotNil(status.heartRateReadPermission)
        XCTAssertNotNil(status.activeEnergyReadPermission)
    }

    func testRequestPermissions() async throws {
        guard healthKitService.isHealthKitAvailable else {
            throw XCTSkip("HealthKit not available on this device")
        }

        let status = try await healthKitService.requestPermissions()

        XCTAssertTrue(status.isHealthKitAvailable)
        // Note: Actual permissions depend on user interaction, so we can't test specific grants
    }

    func testRequestPermissionForSpecificDataType() async throws {
        guard healthKitService.isHealthKitAvailable else {
            throw XCTSkip("HealthKit not available on this device")
        }

        let permissionStatus = try await healthKitService.requestPermission(for: "workouts")

        XCTAssertTrue([
            HealthKitPermissionStatus.notDetermined,
            HealthKitPermissionStatus.authorized,
            HealthKitPermissionStatus.denied,
            HealthKitPermissionStatus.restricted
        ].contains(permissionStatus))
    }

    func testGetPermissionStatusForDataType() async {
        let permissionStatus = await healthKitService.getPermissionStatus(for: "heartRate")

        XCTAssertTrue([
            HealthKitPermissionStatus.notDetermined,
            HealthKitPermissionStatus.authorized,
            HealthKitPermissionStatus.denied,
            HealthKitPermissionStatus.restricted
        ].contains(permissionStatus))
    }

    // MARK: - Workout Export Tests

    func testExportWorkout() async throws {
        guard healthKitService.isHealthKitAvailable else {
            throw XCTSkip("HealthKit not available on this device")
        }

        let sessionId = UUID()
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(3600) // 1 hour workout

        let exerciseData = HealthKitExerciseData(
            name: "Bench Press",
            category: "Compound",
            muscleGroups: ["Chest", "Triceps"],
            sets: [
                HealthKitSetData(weight: 100.0, reps: 8, rpe: 7.0, restDuration: 120),
                HealthKitSetData(weight: 105.0, reps: 6, rpe: 8.0, restDuration: 120),
                HealthKitSetData(weight: 110.0, reps: 4, rpe: 9.0, restDuration: nil)
            ],
            totalVolume: 2440.0, // (100*8 + 105*6 + 110*4)
            averageRPE: 8.0
        )

        let config = HealthKitWorkoutConfig(
            sessionId: sessionId,
            activityType: .traditionalStrengthTraining,
            startDate: startDate,
            endDate: endDate,
            duration: 3600,
            totalEnergyBurned: 300,
            exercises: [exerciseData]
        )

        // This should not throw if implementation exists and permissions are granted
        try await healthKitService.exportWorkout(config: config)

        // Verify workout was exported
        let isExported = await healthKitService.isWorkoutExported(sessionId: sessionId)
        XCTAssertTrue(isExported)
    }

    func testExportWorkoutWithoutPermissions() async throws {
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
            // If no error is thrown, permissions must be granted
        } catch HealthKitServiceError.permissionDenied {
            // Expected if permissions are not granted
        } catch HealthKitServiceError.healthKitNotAvailable {
            // Expected if HealthKit is not available
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testExportMultipleWorkouts() async throws {
        guard healthKitService.isHealthKitAvailable else {
            throw XCTSkip("HealthKit not available on this device")
        }

        let config1 = HealthKitWorkoutConfig(
            sessionId: UUID(),
            activityType: .traditionalStrengthTraining,
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            duration: 3600
        )

        let config2 = HealthKitWorkoutConfig(
            sessionId: UUID(),
            activityType: .functionalStrengthTraining,
            startDate: Date().addingTimeInterval(-7200), // 2 hours ago
            endDate: Date().addingTimeInterval(-3600), // 1 hour ago
            duration: 3600
        )

        let results = try await healthKitService.exportWorkouts(configs: [config1, config2])

        XCTAssertEqual(results.count, 2)
        // Results should contain success/failure status for each workout
    }

    func testIsWorkoutExported() async {
        let sessionId = UUID()

        let isExported = await healthKitService.isWorkoutExported(sessionId: sessionId)

        // Should return false for non-existent workout
        XCTAssertFalse(isExported)
    }

    // MARK: - Exercise Data Import Tests

    func testImportRecentExerciseData() async throws {
        guard healthKitService.isHealthKitAvailable else {
            throw XCTSkip("HealthKit not available on this device")
        }

        let exercises = try await healthKitService.importRecentExerciseData(days: 7)

        XCTAssertNotNil(exercises)
        // Number of exercises depends on user's HealthKit data
    }

    func testImportExerciseDataForDateRange() async throws {
        guard healthKitService.isHealthKitAvailable else {
            throw XCTSkip("HealthKit not available on this device")
        }

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate)!

        let exercises = try await healthKitService.importExerciseData(startDate: startDate, endDate: endDate)

        XCTAssertNotNil(exercises)
        // Verify all exercises are within the date range
        for exercise in exercises {
            XCTAssertGreaterThanOrEqual(exercise.date, startDate)
            XCTAssertLessThanOrEqual(exercise.date, endDate)
        }
    }

    func testGetExerciseDataFromSource() async throws {
        guard healthKitService.isHealthKitAvailable else {
            throw XCTSkip("HealthKit not available on this device")
        }

        let exercises = try await healthKitService.getExerciseDataFromSource(sourceName: "Fitness", days: 30)

        XCTAssertNotNil(exercises)
        // Verify all exercises are from the specified source
        for exercise in exercises {
            if let source = exercise.source {
                XCTAssertTrue(source.contains("Fitness"))
            }
        }
    }

    func testImportHeartRateData() async throws {
        guard healthKitService.isHealthKitAvailable else {
            throw XCTSkip("HealthKit not available on this device")
        }

        let startDate = Date().addingTimeInterval(-3600) // 1 hour ago
        let endDate = Date()

        let heartRateData = try await healthKitService.importHeartRateData(startDate: startDate, endDate: endDate)

        XCTAssertNotNil(heartRateData)
        // Verify heart rate values are reasonable
        for data in heartRateData {
            XCTAssertGreaterThan(data.beatsPerMinute, 30)
            XCTAssertLessThan(data.beatsPerMinute, 250)
            XCTAssertGreaterThanOrEqual(data.timestamp, startDate)
            XCTAssertLessThanOrEqual(data.timestamp, endDate)
        }
    }

    func testImportActiveEnergyData() async throws {
        guard healthKitService.isHealthKitAvailable else {
            throw XCTSkip("HealthKit not available on this device")
        }

        let startDate = Date().addingTimeInterval(-3600) // 1 hour ago
        let endDate = Date()

        let energyData = try await healthKitService.importActiveEnergyData(startDate: startDate, endDate: endDate)

        XCTAssertNotNil(energyData)
        // Verify energy values are reasonable
        for data in energyData {
            XCTAssertGreaterThanOrEqual(data.caloriesBurned, 0)
            XCTAssertGreaterThanOrEqual(data.timestamp, startDate)
            XCTAssertLessThanOrEqual(data.timestamp, endDate)
        }
    }

    // MARK: - Real-time Monitoring Tests

    func testStartHeartRateMonitoring() async throws {
        guard healthKitService.isHealthKitAvailable else {
            throw XCTSkip("HealthKit not available on this device")
        }

        // This should not throw if implementation exists and permissions are granted
        try await healthKitService.startHeartRateMonitoring()

        // Stop monitoring to clean up
        await healthKitService.stopHeartRateMonitoring()
    }

    func testStopHeartRateMonitoring() async {
        await healthKitService.stopHeartRateMonitoring()

        // Should not throw even if monitoring wasn't started
    }

    func testGetCurrentHeartRate() async throws {
        guard healthKitService.isHealthKitAvailable else {
            throw XCTSkip("HealthKit not available on this device")
        }

        let heartRate = try await healthKitService.getCurrentHeartRate()

        // May be nil if no recent heart rate data
        if let heartRate = heartRate {
            XCTAssertGreaterThan(heartRate.beatsPerMinute, 30)
            XCTAssertLessThan(heartRate.beatsPerMinute, 250)
        }
    }

    func testEstimateCaloriesBurned() async {
        let calories = await healthKitService.estimateCaloriesBurned(
            duration: 3600, // 1 hour
            averageHeartRate: 140,
            bodyWeight: 70 // 70 kg
        )

        XCTAssertGreaterThan(calories, 0)
        XCTAssertLessThan(calories, 2000) // Reasonable upper bound for 1 hour
    }

    // MARK: - Sync and Background Tests

    func testSetAutoSyncEnabled() async {
        await healthKitService.setAutoSyncEnabled(true)

        let syncStats = await healthKitService.getSyncStats()
        XCTAssertTrue(syncStats.autoSyncEnabled)

        await healthKitService.setAutoSyncEnabled(false)

        let updatedSyncStats = await healthKitService.getSyncStats()
        XCTAssertFalse(updatedSyncStats.autoSyncEnabled)
    }

    func testPerformManualSync() async throws {
        guard healthKitService.isHealthKitAvailable else {
            throw XCTSkip("HealthKit not available on this device")
        }

        let syncStats = try await healthKitService.performManualSync()

        XCTAssertNotNil(syncStats.lastSyncAttempt)
        XCTAssertGreaterThanOrEqual(syncStats.workoutsExported, 0)
        XCTAssertGreaterThanOrEqual(syncStats.workoutsFailedToExport, 0)
    }

    func testGetSyncStats() async {
        let syncStats = await healthKitService.getSyncStats()

        XCTAssertGreaterThanOrEqual(syncStats.workoutsExported, 0)
        XCTAssertGreaterThanOrEqual(syncStats.workoutsFailedToExport, 0)
        XCTAssertGreaterThanOrEqual(syncStats.exerciseSessionsImported, 0)
    }

    // MARK: - Data Validation Tests

    func testValidateWorkoutData() {
        let validConfig = HealthKitWorkoutConfig(
            sessionId: UUID(),
            activityType: .traditionalStrengthTraining,
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            duration: 3600
        )

        let validationErrors = healthKitService.validateWorkoutData(config: validConfig)
        XCTAssertTrue(validationErrors.isEmpty)

        let invalidConfig = HealthKitWorkoutConfig(
            sessionId: UUID(),
            activityType: .traditionalStrengthTraining,
            startDate: Date(),
            endDate: Date().addingTimeInterval(-3600), // End before start
            duration: -100 // Negative duration
        )

        let invalidValidationErrors = healthKitService.validateWorkoutData(config: invalidConfig)
        XCTAssertFalse(invalidValidationErrors.isEmpty)
    }

    func testConvertToHealthKitWorkout() throws {
        let config = HealthKitWorkoutConfig(
            sessionId: UUID(),
            activityType: .traditionalStrengthTraining,
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            duration: 3600,
            totalEnergyBurned: 300
        )

        let hkWorkout = try healthKitService.convertToHealthKitWorkout(config: config)

        XCTAssertEqual(hkWorkout.workoutActivityType, .traditionalStrengthTraining)
        XCTAssertEqual(hkWorkout.duration, 3600, accuracy: 0.1)
        XCTAssertNotNil(hkWorkout.totalEnergyBurned)
    }

    // MARK: - Publisher Tests

    func testAuthorizationStatusPublisher() async throws {
        let expectation = XCTestExpectation(description: "Authorization status publisher")
        var receivedStatus: HealthKitAuthorizationStatus?

        healthKitService.authorizationStatusPublisher
            .sink { status in
                receivedStatus = status
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // Trigger a permission request to update the publisher
        _ = try? await healthKitService.requestPermissions()

        await fulfillment(of: [expectation], timeout: 2.0)

        XCTAssertNotNil(receivedStatus)
    }

    func testHeartRateUpdatePublisher() async throws {
        guard healthKitService.isHealthKitAvailable else {
            throw XCTSkip("HealthKit not available on this device")
        }

        let expectation = XCTestExpectation(description: "Heart rate update publisher")
        expectation.isInverted = true // We don't expect immediate heart rate data

        healthKitService.heartRateUpdatePublisher
            .sink { heartRateData in
                XCTAssertGreaterThan(heartRateData.beatsPerMinute, 30)
                XCTAssertLessThan(heartRateData.beatsPerMinute, 250)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // Start monitoring to potentially trigger updates
        try? await healthKitService.startHeartRateMonitoring()

        await fulfillment(of: [expectation], timeout: 1.0)

        await healthKitService.stopHeartRateMonitoring()
    }

    // MARK: - Privacy and Settings Tests

    func testGetPrivacyInfo() async {
        let privacyInfo = await healthKitService.getPrivacyInfo()

        XCTAssertNotNil(privacyInfo)
        XCTAssertFalse(privacyInfo.isEmpty)
        // Should contain information about what data is accessed
    }

    func testClearSyncHistory() async {
        await healthKitService.clearSyncHistory()

        let syncStats = await healthKitService.getSyncStats()
        XCTAssertNil(syncStats.lastSyncAttempt)
        XCTAssertNil(syncStats.lastExportDate)
        XCTAssertNil(syncStats.lastImportDate)
    }

    // MARK: - Error Handling Tests

    func testHealthKitNotAvailableError() async throws {
        // This test simulates the case where HealthKit is not available
        // In a real scenario, this would be tested on a platform without HealthKit

        // The actual test depends on the implementation handling unavailable HealthKit
        // For now, we just verify the error type exists
        let error = HealthKitServiceError.healthKitNotAvailable
        XCTAssertEqual(error.localizedDescription, "HealthKit is not available on this device")
        XCTAssertFalse(error.isRetryable)
    }

    func testPermissionDeniedError() {
        let error = HealthKitServiceError.permissionDenied(dataType: "workouts")
        XCTAssertTrue(error.localizedDescription.contains("workouts"))
        XCTAssertFalse(error.isRetryable)
    }

    func testSyncFailedError() {
        let error = HealthKitServiceError.syncFailed(reason: "Network timeout")
        XCTAssertTrue(error.localizedDescription.contains("Network timeout"))
        XCTAssertTrue(error.isRetryable)
    }
}