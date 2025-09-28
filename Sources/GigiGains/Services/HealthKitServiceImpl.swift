//
//  HealthKitServiceImpl.swift
//  Gigi Gains
//
//  Implementation of HealthKitService protocol providing comprehensive
//  HealthKit integration for workout export and exercise data import.
//
//  Created: 2025-09-28
//

import Foundation
import HealthKit
import Combine

public class HealthKitServiceImpl: HealthKitService {

    // MARK: - Properties

    private let healthStore = HKHealthStore()
    private let authorizationStatusSubject = CurrentValueSubject<HealthKitAuthorizationStatus, Never>(
        HealthKitAuthorizationStatus(
            workoutWritePermission: .notDetermined,
            exerciseReadPermission: .notDetermined,
            heartRateReadPermission: .notDetermined,
            activeEnergyReadPermission: .notDetermined,
            isHealthKitAvailable: HKHealthStore.isHealthDataAvailable()
        )
    )
    private let syncStatusSubject = CurrentValueSubject<HealthKitSyncStats, Never>(
        HealthKitSyncStats(
            workoutsExported: 0,
            workoutsFailedToExport: 0,
            lastExportDate: nil,
            lastSyncAttempt: nil,
            exerciseSessionsImported: 0,
            lastImportDate: nil,
            autoSyncEnabled: false
        )
    )
    private let heartRateUpdateSubject = PassthroughSubject<HeartRateData, Never>()

    private var heartRateQuery: HKAnchoredObjectQuery?
    private var exportedWorkoutIds: Set<UUID> = []
    private var syncStats = HealthKitSyncStats(
        workoutsExported: 0,
        workoutsFailedToExport: 0,
        lastExportDate: nil,
        lastSyncAttempt: nil,
        exerciseSessionsImported: 0,
        lastImportDate: nil,
        autoSyncEnabled: false
    )

    // MARK: - Publishers

    public var authorizationStatusPublisher: AnyPublisher<HealthKitAuthorizationStatus, Never> {
        authorizationStatusSubject.eraseToAnyPublisher()
    }

    public var syncStatusPublisher: AnyPublisher<HealthKitSyncStats, Never> {
        syncStatusSubject.eraseToAnyPublisher()
    }

    public var heartRateUpdatePublisher: AnyPublisher<HeartRateData, Never> {
        heartRateUpdateSubject.eraseToAnyPublisher()
    }

    // MARK: - Computed Properties

    public var isHealthKitAvailable: Bool {
        return HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Initialization

    public init() {
        Task {
            await updateAuthorizationStatus()
        }
    }

    // MARK: - Permission Management

    public func getAuthorizationStatus() async -> HealthKitAuthorizationStatus {
        await updateAuthorizationStatus()
        return authorizationStatusSubject.value
    }

    public func requestPermissions() async throws -> HealthKitAuthorizationStatus {
        guard isHealthKitAvailable else {
            throw HealthKitServiceError.healthKitNotAvailable
        }

        // Define the types we want to read and write
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!
        ]

        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.workoutType()
        ]

        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { success, error in
                Task {
                    if let error = error {
                        continuation.resume(throwing: HealthKitServiceError.healthKitError(error))
                    } else {
                        let status = await self.updateAuthorizationStatus()
                        continuation.resume(returning: status)
                    }
                }
            }
        }
    }

    public func requestPermission(for dataType: String) async throws -> HealthKitPermissionStatus {
        guard isHealthKitAvailable else {
            throw HealthKitServiceError.healthKitNotAvailable
        }

        guard let objectType = getHealthKitType(for: dataType) else {
            throw HealthKitServiceError.healthKitError(NSError(domain: "Invalid data type", code: 400))
        }

        let typesToRead: Set<HKObjectType> = [objectType]
        let typesToWrite: Set<HKSampleType> = objectType is HKSampleType ? [objectType as! HKSampleType] : []

        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { success, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitServiceError.healthKitError(error))
                } else {
                    let status = self.healthStore.authorizationStatus(for: objectType)
                    continuation.resume(returning: self.mapAuthorizationStatus(status))
                }
            }
        }
    }

    public func getPermissionStatus(for dataType: String) async -> HealthKitPermissionStatus {
        guard isHealthKitAvailable else { return .denied }
        guard let objectType = getHealthKitType(for: dataType) else { return .denied }

        let status = healthStore.authorizationStatus(for: objectType)
        return mapAuthorizationStatus(status)
    }

    public func openHealthAppSettings() async {
        if let settingsUrl = URL(string: "x-apple-health://") {
            await MainActor.run {
                if UIApplication.shared.canOpenURL(settingsUrl) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
        }
    }

    // MARK: - Workout Export

    public func exportWorkout(config: HealthKitWorkoutConfig) async throws {
        guard isHealthKitAvailable else {
            throw HealthKitServiceError.healthKitNotAvailable
        }

        let status = await getAuthorizationStatus()
        guard status.workoutWritePermission == .authorized else {
            throw HealthKitServiceError.permissionDenied(dataType: "workout")
        }

        // Validate workout data
        let validationErrors = validateWorkoutData(config: config)
        guard validationErrors.isEmpty else {
            throw HealthKitServiceError.invalidWorkoutData(reason: validationErrors.joined(separator: ", "))
        }

        do {
            let workout = try convertToHealthKitWorkout(config: config)

            return try await withCheckedThrowingContinuation { continuation in
                healthStore.save(workout) { success, error in
                    if let error = error {
                        Task {
                            self.syncStats = HealthKitSyncStats(
                                workoutsExported: self.syncStats.workoutsExported,
                                workoutsFailedToExport: self.syncStats.workoutsFailedToExport + 1,
                                lastExportDate: self.syncStats.lastExportDate,
                                lastSyncAttempt: Date(),
                                exerciseSessionsImported: self.syncStats.exerciseSessionsImported,
                                lastImportDate: self.syncStats.lastImportDate,
                                autoSyncEnabled: self.syncStats.autoSyncEnabled
                            )
                            self.syncStatusSubject.send(self.syncStats)
                        }
                        continuation.resume(throwing: HealthKitServiceError.syncFailed(reason: error.localizedDescription))
                    } else {
                        Task {
                            self.exportedWorkoutIds.insert(config.sessionId)
                            self.syncStats = HealthKitSyncStats(
                                workoutsExported: self.syncStats.workoutsExported + 1,
                                workoutsFailedToExport: self.syncStats.workoutsFailedToExport,
                                lastExportDate: Date(),
                                lastSyncAttempt: Date(),
                                exerciseSessionsImported: self.syncStats.exerciseSessionsImported,
                                lastImportDate: self.syncStats.lastImportDate,
                                autoSyncEnabled: self.syncStats.autoSyncEnabled
                            )
                            self.syncStatusSubject.send(self.syncStats)
                        }
                        continuation.resume()
                    }
                }
            }
        } catch {
            throw HealthKitServiceError.dataConversionError(reason: error.localizedDescription)
        }
    }

    public func exportWorkouts(configs: [HealthKitWorkoutConfig]) async throws -> [Bool] {
        var results: [Bool] = []

        for config in configs {
            do {
                try await exportWorkout(config: config)
                results.append(true)
            } catch {
                results.append(false)
            }
        }

        return results
    }

    public func isWorkoutExported(sessionId: UUID) async -> Bool {
        return exportedWorkoutIds.contains(sessionId)
    }

    public func removeExportedWorkout(sessionId: UUID) async throws {
        // For now, we don't implement workout removal as it's complex
        // In a full implementation, we'd need to track workout objects and delete them
        throw HealthKitServiceError.workoutNotFound(sessionId)
    }

    public func updateExportedWorkout(sessionId: UUID, config: HealthKitWorkoutConfig) async throws {
        // For now, we don't implement workout updates
        // In a full implementation, we'd delete the old workout and create a new one
        throw HealthKitServiceError.workoutNotFound(sessionId)
    }

    // MARK: - Exercise Data Import

    public func importRecentExerciseData(days: Int) async throws -> [HealthKitExerciseInfo] {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        return try await importExerciseData(startDate: startDate, endDate: endDate)
    }

    public func importExerciseData(startDate: Date, endDate: Date) async throws -> [HealthKitExerciseInfo] {
        guard isHealthKitAvailable else {
            throw HealthKitServiceError.healthKitNotAvailable
        }

        let status = await getAuthorizationStatus()
        guard status.exerciseReadPermission == .authorized else {
            throw HealthKitServiceError.permissionDenied(dataType: "exercise")
        }

        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { query, samples, error in

                if let error = error {
                    continuation.resume(throwing: HealthKitServiceError.healthKitError(error))
                    return
                }

                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: [])
                    return
                }

                do {
                    let exerciseInfos = try workouts.map { workout in
                        try self.convertFromHealthKitExercise(workout)
                    }

                    Task {
                        self.syncStats = HealthKitSyncStats(
                            workoutsExported: self.syncStats.workoutsExported,
                            workoutsFailedToExport: self.syncStats.workoutsFailedToExport,
                            lastExportDate: self.syncStats.lastExportDate,
                            lastSyncAttempt: Date(),
                            exerciseSessionsImported: self.syncStats.exerciseSessionsImported + workouts.count,
                            lastImportDate: Date(),
                            autoSyncEnabled: self.syncStats.autoSyncEnabled
                        )
                        self.syncStatusSubject.send(self.syncStats)
                    }

                    continuation.resume(returning: exerciseInfos)
                } catch {
                    continuation.resume(throwing: HealthKitServiceError.dataConversionError(reason: error.localizedDescription))
                }
            }

            self.healthStore.execute(query)
        }
    }

    public func getExerciseDataFromSource(sourceName: String, days: Int) async throws -> [HealthKitExerciseInfo] {
        let allExercises = try await importRecentExerciseData(days: days)
        return allExercises.filter { $0.source?.contains(sourceName) == true }
    }

    public func importHeartRateData(startDate: Date, endDate: Date) async throws -> [HeartRateData] {
        guard isHealthKitAvailable else {
            throw HealthKitServiceError.healthKitNotAvailable
        }

        let status = await getAuthorizationStatus()
        guard status.heartRateReadPermission == .authorized else {
            throw HealthKitServiceError.permissionDenied(dataType: "heart rate")
        }

        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            throw HealthKitServiceError.healthKitError(NSError(domain: "Invalid heart rate type", code: 400))
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { query, samples, error in

                if let error = error {
                    continuation.resume(throwing: HealthKitServiceError.healthKitError(error))
                    return
                }

                guard let heartRateSamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }

                let heartRateData = heartRateSamples.map { sample in
                    HeartRateData(
                        timestamp: sample.startDate,
                        beatsPerMinute: sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute())),
                        source: sample.sourceRevision.source.name
                    )
                }

                continuation.resume(returning: heartRateData)
            }

            self.healthStore.execute(query)
        }
    }

    public func importActiveEnergyData(startDate: Date, endDate: Date) async throws -> [ActiveEnergyData] {
        guard isHealthKitAvailable else {
            throw HealthKitServiceError.healthKitNotAvailable
        }

        let status = await getAuthorizationStatus()
        guard status.activeEnergyReadPermission == .authorized else {
            throw HealthKitServiceError.permissionDenied(dataType: "active energy")
        }

        guard let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            throw HealthKitServiceError.healthKitError(NSError(domain: "Invalid energy type", code: 400))
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: energyType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { query, samples, error in

                if let error = error {
                    continuation.resume(throwing: HealthKitServiceError.healthKitError(error))
                    return
                }

                guard let energySamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }

                let energyData = energySamples.map { sample in
                    ActiveEnergyData(
                        timestamp: sample.startDate,
                        caloriesBurned: sample.quantity.doubleValue(for: HKUnit.kilocalorie()),
                        source: sample.sourceRevision.source.name
                    )
                }

                continuation.resume(returning: energyData)
            }

            self.healthStore.execute(query)
        }
    }

    // MARK: - Real-time Data Monitoring

    public func startHeartRateMonitoring() async throws {
        guard isHealthKitAvailable else {
            throw HealthKitServiceError.healthKitNotAvailable
        }

        let status = await getAuthorizationStatus()
        guard status.heartRateReadPermission == .authorized else {
            throw HealthKitServiceError.permissionDenied(dataType: "heart rate")
        }

        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            throw HealthKitServiceError.healthKitError(NSError(domain: "Invalid heart rate type", code: 400))
        }

        let predicate = HKQuery.predicateForSamples(withStart: Date(), end: nil, options: [])

        heartRateQuery = HKAnchoredObjectQuery(type: heartRateType, predicate: predicate, anchor: nil, limit: HKObjectQueryNoLimit) { [weak self] query, samples, deletedObjects, anchor, error in

            guard let self = self else { return }

            if let error = error {
                print("Heart rate monitoring error: \(error)")
                return
            }

            guard let heartRateSamples = samples as? [HKQuantitySample] else { return }

            for sample in heartRateSamples {
                let heartRateData = HeartRateData(
                    timestamp: sample.startDate,
                    beatsPerMinute: sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute())),
                    source: sample.sourceRevision.source.name
                )
                self.heartRateUpdateSubject.send(heartRateData)
            }
        }

        heartRateQuery?.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            guard let self = self else { return }

            if let error = error {
                print("Heart rate update error: \(error)")
                return
            }

            guard let heartRateSamples = samples as? [HKQuantitySample] else { return }

            for sample in heartRateSamples {
                let heartRateData = HeartRateData(
                    timestamp: sample.startDate,
                    beatsPerMinute: sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute())),
                    source: sample.sourceRevision.source.name
                )
                self.heartRateUpdateSubject.send(heartRateData)
            }
        }

        if let query = heartRateQuery {
            healthStore.execute(query)
        }
    }

    public func stopHeartRateMonitoring() async {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
    }

    public func getCurrentHeartRate() async throws -> HeartRateData? {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .minute, value: -1, to: endDate) ?? endDate
        let heartRateData = try await importHeartRateData(startDate: startDate, endDate: endDate)
        return heartRateData.last
    }

    public func estimateCaloriesBurned(duration: TimeInterval, averageHeartRate: Double?, bodyWeight: Double?) async -> Double {
        // Simple estimation using MET values for strength training
        let metValue = 6.0 // MET value for general weight lifting
        let bodyWeightKg = bodyWeight ?? 70.0 // Default to 70kg if not available
        let hours = duration / 3600.0

        // Base calculation: METs × weight in kg × hours
        var calories = metValue * bodyWeightKg * hours

        // Adjust based on heart rate if available
        if let heartRate = averageHeartRate {
            // Simple adjustment: higher heart rate = more calories
            let heartRateMultiplier = min(heartRate / 120.0, 1.5) // Cap at 1.5x
            calories *= heartRateMultiplier
        }

        return calories
    }

    // MARK: - Background Sync

    public func setAutoSyncEnabled(_ enabled: Bool) async {
        syncStats = HealthKitSyncStats(
            workoutsExported: syncStats.workoutsExported,
            workoutsFailedToExport: syncStats.workoutsFailedToExport,
            lastExportDate: syncStats.lastExportDate,
            lastSyncAttempt: syncStats.lastSyncAttempt,
            exerciseSessionsImported: syncStats.exerciseSessionsImported,
            lastImportDate: syncStats.lastImportDate,
            autoSyncEnabled: enabled
        )
        syncStatusSubject.send(syncStats)
    }

    public func performManualSync() async throws -> HealthKitSyncStats {
        syncStats = HealthKitSyncStats(
            workoutsExported: syncStats.workoutsExported,
            workoutsFailedToExport: syncStats.workoutsFailedToExport,
            lastExportDate: syncStats.lastExportDate,
            lastSyncAttempt: Date(),
            exerciseSessionsImported: syncStats.exerciseSessionsImported,
            lastImportDate: syncStats.lastImportDate,
            autoSyncEnabled: syncStats.autoSyncEnabled
        )
        syncStatusSubject.send(syncStats)
        return syncStats
    }

    public func getSyncStats() async -> HealthKitSyncStats {
        return syncStats
    }

    public func retryFailedExports() async throws -> Int {
        // In a full implementation, we'd retry failed exports
        return 0
    }

    public func scheduleBackgroundSync() async {
        // Background sync scheduling would be implemented here
    }

    // MARK: - Data Management

    public func getExportedWorkoutSessions() async -> [UUID] {
        return Array(exportedWorkoutIds)
    }

    public func validateWorkoutData(config: HealthKitWorkoutConfig) -> [String] {
        var errors: [String] = []

        if config.startDate >= config.endDate {
            errors.append("Start date must be before end date")
        }

        if config.duration <= 0 {
            errors.append("Duration must be positive")
        }

        if config.startDate > Date() {
            errors.append("Start date cannot be in the future")
        }

        return errors
    }

    public func convertToHealthKitWorkout(config: HealthKitWorkoutConfig) throws -> HKWorkout {
        let metadata: [String: Any] = [
            "sessionId": config.sessionId.uuidString,
            "appName": "Gigi Gains"
        ].merging(config.metadata) { _, new in new }

        let workout = HKWorkout(
            activityType: config.activityType.healthKitType,
            start: config.startDate,
            end: config.endDate,
            duration: config.duration,
            totalEnergyBurned: config.totalEnergyBurned != nil ? HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: config.totalEnergyBurned!) : nil,
            totalDistance: nil,
            metadata: metadata
        )

        return workout
    }

    public func convertFromHealthKitExercise(_ healthKitData: HKWorkout) throws -> HealthKitExerciseInfo {
        let activityType = mapWorkoutActivityType(healthKitData.workoutActivityType)

        return HealthKitExerciseInfo(
            date: healthKitData.startDate,
            activityType: activityType,
            duration: healthKitData.duration,
            totalEnergyBurned: healthKitData.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie()),
            averageHeartRate: nil, // Would need separate query for heart rate
            source: healthKitData.sourceRevision.source.name,
            metadata: healthKitData.metadata ?? [:]
        )
    }

    // MARK: - Privacy and Settings

    public func getPrivacyInfo() async -> [String: Any] {
        let status = await getAuthorizationStatus()

        return [
            "healthKitAvailable": status.isHealthKitAvailable,
            "workoutWritePermission": status.workoutWritePermission.description,
            "exerciseReadPermission": status.exerciseReadPermission.description,
            "heartRateReadPermission": status.heartRateReadPermission.description,
            "activeEnergyReadPermission": status.activeEnergyReadPermission.description,
            "dataRetention": "Data is stored in Apple Health and is controlled by your Health app privacy settings",
            "dataSharing": "Gigi Gains only exports workouts you complete and only imports data you authorize"
        ]
    }

    public func clearSyncHistory() async {
        syncStats = HealthKitSyncStats(
            workoutsExported: 0,
            workoutsFailedToExport: 0,
            lastExportDate: nil,
            lastSyncAttempt: nil,
            exerciseSessionsImported: 0,
            lastImportDate: nil,
            autoSyncEnabled: syncStats.autoSyncEnabled
        )
        syncStatusSubject.send(syncStats)
    }

    public func disableHealthKitIntegration(removeExportedWorkouts: Bool) async throws {
        await clearSyncHistory()
        await stopHeartRateMonitoring()

        if removeExportedWorkouts {
            // In a full implementation, we'd remove exported workouts
            exportedWorkoutIds.removeAll()
        }
    }

    // MARK: - Private Helper Methods

    @discardableResult
    private func updateAuthorizationStatus() async -> HealthKitAuthorizationStatus {
        guard isHealthKitAvailable else {
            let status = HealthKitAuthorizationStatus(
                workoutWritePermission: .denied,
                exerciseReadPermission: .denied,
                heartRateReadPermission: .denied,
                activeEnergyReadPermission: .denied,
                isHealthKitAvailable: false
            )
            authorizationStatusSubject.send(status)
            return status
        }

        let workoutType = HKObjectType.workoutType()
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!

        let workoutWriteStatus = healthStore.authorizationStatus(for: workoutType)
        let exerciseReadStatus = healthStore.authorizationStatus(for: workoutType)
        let heartRateReadStatus = healthStore.authorizationStatus(for: heartRateType)
        let energyReadStatus = healthStore.authorizationStatus(for: energyType)

        let status = HealthKitAuthorizationStatus(
            workoutWritePermission: mapAuthorizationStatus(workoutWriteStatus),
            exerciseReadPermission: mapAuthorizationStatus(exerciseReadStatus),
            heartRateReadPermission: mapAuthorizationStatus(heartRateReadStatus),
            activeEnergyReadPermission: mapAuthorizationStatus(energyReadStatus),
            isHealthKitAvailable: true
        )

        authorizationStatusSubject.send(status)
        return status
    }

    private func mapAuthorizationStatus(_ status: HKAuthorizationStatus) -> HealthKitPermissionStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .sharingDenied:
            return .denied
        case .sharingAuthorized:
            return .authorized
        @unknown default:
            return .denied
        }
    }

    private func getHealthKitType(for dataType: String) -> HKObjectType? {
        switch dataType.lowercased() {
        case "workout":
            return HKObjectType.workoutType()
        case "heartrate", "heart_rate":
            return HKObjectType.quantityType(forIdentifier: .heartRate)
        case "activeenergy", "active_energy":
            return HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)
        case "bodymass", "body_mass", "weight":
            return HKObjectType.quantityType(forIdentifier: .bodyMass)
        default:
            return nil
        }
    }

    private func mapWorkoutActivityType(_ healthKitType: HKWorkoutActivityType) -> WorkoutActivityType {
        switch healthKitType {
        case .traditionalStrengthTraining:
            return .traditionalStrengthTraining
        case .functionalStrengthTraining:
            return .functionalStrengthTraining
        case .crossTraining:
            return .crossTraining
        case .coreTraining:
            return .coreTraining
        case .flexibility:
            return .flexibility
        default:
            return .other
        }
    }
}

// MARK: - HealthKitPermissionStatus Extension

extension HealthKitPermissionStatus {
    var description: String {
        switch self {
        case .notDetermined: return "Not Determined"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        case .restricted: return "Restricted"
        }
    }
}