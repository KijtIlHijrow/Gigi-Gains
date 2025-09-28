//
//  HealthKitService.swift
//  Gigi Gains - Internal API Contract
//
//  Defines the interface for HealthKit integration including reading exercise data,
//  writing completed workouts, managing permissions, and data synchronization.
//
//  Created: 2025-09-28
//

import Foundation
import Combine
import HealthKit

// MARK: - Supporting Types

/// HealthKit permission status for specific data types
public enum HealthKitPermissionStatus {
    case notDetermined
    case denied
    case authorized
    case restricted
}

/// Current authorization status for all requested HealthKit permissions
public struct HealthKitAuthorizationStatus {
    /// Whether the app can write workout data to HealthKit
    public let workoutWritePermission: HealthKitPermissionStatus

    /// Whether the app can read exercise/activity data from HealthKit
    public let exerciseReadPermission: HealthKitPermissionStatus

    /// Whether the app can read heart rate data
    public let heartRateReadPermission: HealthKitPermissionStatus

    /// Whether the app can read active energy burned data
    public let activeEnergyReadPermission: HealthKitPermissionStatus

    /// Whether HealthKit is available on this device
    public let isHealthKitAvailable: Bool

    /// Whether all required permissions have been granted
    public var hasRequiredPermissions: Bool {
        return isHealthKitAvailable &&
               workoutWritePermission == .authorized &&
               exerciseReadPermission == .authorized
    }

    /// Whether optional permissions (heart rate, energy) are granted
    public var hasOptionalPermissions: Bool {
        return heartRateReadPermission == .authorized &&
               activeEnergyReadPermission == .authorized
    }

    public init(workoutWritePermission: HealthKitPermissionStatus, exerciseReadPermission: HealthKitPermissionStatus, heartRateReadPermission: HealthKitPermissionStatus, activeEnergyReadPermission: HealthKitPermissionStatus, isHealthKitAvailable: Bool) {
        self.workoutWritePermission = workoutWritePermission
        self.exerciseReadPermission = exerciseReadPermission
        self.heartRateReadPermission = heartRateReadPermission
        self.activeEnergyReadPermission = activeEnergyReadPermission
        self.isHealthKitAvailable = isHealthKitAvailable
    }
}

/// Errors that can occur during HealthKit operations
public enum HealthKitServiceError: Error, LocalizedError {
    case healthKitNotAvailable
    case permissionDenied(dataType: String)
    case permissionNotDetermined
    case workoutNotFound(UUID)
    case invalidWorkoutData(reason: String)
    case syncFailed(reason: String)
    case healthKitError(Error)
    case dataConversionError(reason: String)

    public var errorDescription: String? {
        switch self {
        case .healthKitNotAvailable:
            return "HealthKit is not available on this device"
        case .permissionDenied(let dataType):
            return "Permission denied for \(dataType). Please check your Health app settings."
        case .permissionNotDetermined:
            return "HealthKit permissions have not been determined"
        case .workoutNotFound(let id):
            return "Workout with ID \(id) not found in HealthKit"
        case .invalidWorkoutData(let reason):
            return "Invalid workout data: \(reason)"
        case .syncFailed(let reason):
            return "HealthKit sync failed: \(reason)"
        case .healthKitError(let error):
            return "HealthKit error: \(error.localizedDescription)"
        case .dataConversionError(let reason):
            return "Data conversion error: \(reason)"
        }
    }

    /// Whether this error indicates a temporary issue that might be resolved by retrying
    public var isRetryable: Bool {
        switch self {
        case .syncFailed, .healthKitError:
            return true
        case .healthKitNotAvailable, .permissionDenied, .permissionNotDetermined, .workoutNotFound, .invalidWorkoutData, .dataConversionError:
            return false
        }
    }
}

/// HealthKit workout activity type mapping for Gigi Gains exercises
public enum WorkoutActivityType: String, CaseIterable {
    case traditionalStrengthTraining = "traditionalStrengthTraining"
    case functionalStrengthTraining = "functionalStrengthTraining"
    case crossTraining = "crossTraining"
    case coreTraining = "coreTraining"
    case flexibility = "flexibility"
    case other = "other"

    /// Maps to HKWorkoutActivityType
    public var healthKitType: HKWorkoutActivityType {
        switch self {
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
        case .other:
            return .other
        }
    }

    /// Determines the best activity type based on exercise categories
    public static func fromExerciseCategories(_ categories: [String]) -> WorkoutActivityType {
        let categorySet = Set(categories.map { $0.lowercased() })

        if categorySet.contains("flexibility") || categorySet.contains("stretching") {
            return .flexibility
        } else if categorySet.contains("core") || categorySet.contains("abs") {
            return .coreTraining
        } else if categorySet.contains("functional") || categorySet.contains("bodyweight") {
            return .functionalStrengthTraining
        } else if categorySet.contains("compound") || categorySet.contains("isolation") {
            return .traditionalStrengthTraining
        } else if categorySet.contains("circuit") || categorySet.contains("superset") {
            return .crossTraining
        } else {
            return .traditionalStrengthTraining
        }
    }
}

/// Configuration for writing a workout to HealthKit
public struct HealthKitWorkoutConfig {
    public let sessionId: UUID
    public let activityType: WorkoutActivityType
    public let startDate: Date
    public let endDate: Date
    public let duration: TimeInterval
    public let totalEnergyBurned: Double?
    public let metadata: [String: Any]
    public let exercises: [HealthKitExerciseData]

    public init(sessionId: UUID, activityType: WorkoutActivityType, startDate: Date, endDate: Date, duration: TimeInterval, totalEnergyBurned: Double? = nil, metadata: [String: Any] = [:], exercises: [HealthKitExerciseData] = []) {
        self.sessionId = sessionId
        self.activityType = activityType
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration
        self.totalEnergyBurned = totalEnergyBurned
        self.metadata = metadata
        self.exercises = exercises
    }
}

/// Exercise data for HealthKit export
public struct HealthKitExerciseData {
    public let name: String
    public let category: String
    public let muscleGroups: [String]
    public let sets: [HealthKitSetData]
    public let totalVolume: Double
    public let averageRPE: Double?

    public init(name: String, category: String, muscleGroups: [String], sets: [HealthKitSetData], totalVolume: Double, averageRPE: Double?) {
        self.name = name
        self.category = category
        self.muscleGroups = muscleGroups
        self.sets = sets
        self.totalVolume = totalVolume
        self.averageRPE = averageRPE
    }
}

/// Set data for HealthKit export
public struct HealthKitSetData {
    public let weight: Double
    public let reps: Int32
    public let rpe: Double?
    public let restDuration: TimeInterval?

    public init(weight: Double, reps: Int32, rpe: Double?, restDuration: TimeInterval?) {
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.restDuration = restDuration
    }
}

/// Heart rate data retrieved from HealthKit
public struct HeartRateData {
    public let timestamp: Date
    public let beatsPerMinute: Double
    public let source: String?

    public init(timestamp: Date, beatsPerMinute: Double, source: String?) {
        self.timestamp = timestamp
        self.beatsPerMinute = beatsPerMinute
        self.source = source
    }
}

/// Active energy data retrieved from HealthKit
public struct ActiveEnergyData {
    public let timestamp: Date
    public let caloriesBurned: Double
    public let source: String?

    public init(timestamp: Date, caloriesBurned: Double, source: String?) {
        self.timestamp = timestamp
        self.caloriesBurned = caloriesBurned
        self.source = source
    }
}

/// Exercise data retrieved from HealthKit
public struct HealthKitExerciseInfo {
    public let date: Date
    public let activityType: WorkoutActivityType
    public let duration: TimeInterval
    public let totalEnergyBurned: Double?
    public let averageHeartRate: Double?
    public let source: String?
    public let metadata: [String: Any]

    public init(date: Date, activityType: WorkoutActivityType, duration: TimeInterval, totalEnergyBurned: Double?, averageHeartRate: Double?, source: String?, metadata: [String: Any]) {
        self.date = date
        self.activityType = activityType
        self.duration = duration
        self.totalEnergyBurned = totalEnergyBurned
        self.averageHeartRate = averageHeartRate
        self.source = source
        self.metadata = metadata
    }
}

/// Sync statistics showing HealthKit integration status
public struct HealthKitSyncStats {
    /// Number of workouts successfully exported to HealthKit
    public let workoutsExported: Int

    /// Number of workouts that failed to export
    public let workoutsFailedToExport: Int

    /// Last successful export date
    public let lastExportDate: Date?

    /// Last sync attempt date
    public let lastSyncAttempt: Date?

    /// Number of exercise sessions imported from HealthKit
    public let exerciseSessionsImported: Int

    /// Last import date
    public let lastImportDate: Date?

    /// Whether automatic sync is enabled
    public let autoSyncEnabled: Bool

    public init(workoutsExported: Int, workoutsFailedToExport: Int, lastExportDate: Date?, lastSyncAttempt: Date?, exerciseSessionsImported: Int, lastImportDate: Date?, autoSyncEnabled: Bool) {
        self.workoutsExported = workoutsExported
        self.workoutsFailedToExport = workoutsFailedToExport
        self.lastExportDate = lastExportDate
        self.lastSyncAttempt = lastSyncAttempt
        self.exerciseSessionsImported = exerciseSessionsImported
        self.lastImportDate = lastImportDate
        self.autoSyncEnabled = autoSyncEnabled
    }
}

// MARK: - Main Protocol

/// Service protocol for HealthKit integration
///
/// This protocol defines the complete interface for HealthKit integration in the Gigi Gains app.
/// It handles reading exercise data from HealthKit, writing completed workouts, managing permissions,
/// and maintaining data synchronization. All operations respect user privacy and follow HealthKit
/// best practices.
///
/// Key responsibilities:
/// - HealthKit permission management with clear user prompts
/// - Writing completed workout sessions to HealthKit
/// - Reading exercise and activity data from other apps
/// - Heart rate and energy data integration
/// - Background sync and data consistency
/// - Privacy compliance and data security
/// - Error handling and permission recovery
///
/// ## Usage Example:
/// ```swift
/// let service: HealthKitService = HealthKitServiceImpl()
///
/// // Request permissions
/// try await service.requestPermissions()
///
/// // Export a completed workout
/// let config = HealthKitWorkoutConfig(
///     sessionId: session.id,
///     activityType: .traditionalStrengthTraining,
///     startDate: session.startDate,
///     endDate: session.endDate!,
///     duration: session.duration
/// )
/// try await service.exportWorkout(config: config)
///
/// // Import recent exercise data
/// let exercises = try await service.importRecentExerciseData(days: 7)
/// ```
public protocol HealthKitService: AnyObject {

    // MARK: - Publishers for Reactive Updates

    /// Publishes updates to HealthKit authorization status
    /// Emits when permissions are granted, denied, or changed
    var authorizationStatusPublisher: AnyPublisher<HealthKitAuthorizationStatus, Never> { get }

    /// Publishes sync status updates
    /// Useful for showing sync progress and errors in UI
    var syncStatusPublisher: AnyPublisher<HealthKitSyncStats, Never> { get }

    /// Publishes heart rate data updates during workouts
    /// Only emits when heart rate permission is granted and data is available
    var heartRateUpdatePublisher: AnyPublisher<HeartRateData, Never> { get }

    // MARK: - Permission Management

    /// Checks if HealthKit is available on the current device
    /// - Returns: True if HealthKit is available, false otherwise
    var isHealthKitAvailable: Bool { get }

    /// Gets the current authorization status for all HealthKit permissions
    /// - Returns: Current authorization status for all requested data types
    func getAuthorizationStatus() async -> HealthKitAuthorizationStatus

    /// Requests HealthKit permissions with user-friendly prompts
    /// - Returns: The authorization status after the request
    /// - Note: Shows system permission dialog with privacy explanations
    func requestPermissions() async throws -> HealthKitAuthorizationStatus

    /// Requests specific permission for a data type
    /// - Parameter dataType: The specific HealthKit data type to request
    /// - Returns: The permission status for the requested data type
    func requestPermission(for dataType: String) async throws -> HealthKitPermissionStatus

    /// Checks permission status for a specific data type
    /// - Parameter dataType: The HealthKit data type to check
    /// - Returns: Current permission status for the data type
    func getPermissionStatus(for dataType: String) async -> HealthKitPermissionStatus

    /// Opens the Health app to the Gigi Gains data source settings
    /// - Note: Useful when users need to modify permissions manually
    func openHealthAppSettings() async

    // MARK: - Workout Export

    /// Exports a completed workout session to HealthKit
    /// - Parameter config: Configuration containing workout data and metadata
    /// - Throws: `HealthKitServiceError.permissionDenied` if write permission is not granted
    /// - Throws: `HealthKitServiceError.invalidWorkoutData` if workout data is invalid
    /// - Throws: `HealthKitServiceError.syncFailed` if export fails
    func exportWorkout(config: HealthKitWorkoutConfig) async throws

    /// Exports multiple workout sessions in batch
    /// - Parameter configs: Array of workout configurations to export
    /// - Returns: Array of successful export results (true) and failures (false)
    /// - Note: Continues processing even if individual workouts fail
    func exportWorkouts(configs: [HealthKitWorkoutConfig]) async throws -> [Bool]

    /// Checks if a workout session has already been exported to HealthKit
    /// - Parameter sessionId: The ID of the workout session
    /// - Returns: True if the workout has been exported, false otherwise
    func isWorkoutExported(sessionId: UUID) async -> Bool

    /// Removes a workout from HealthKit (if it was exported by this app)
    /// - Parameter sessionId: The ID of the workout session to remove
    /// - Throws: `HealthKitServiceError.workoutNotFound` if workout is not found
    /// - Throws: `HealthKitServiceError.permissionDenied` if delete permission is not granted
    func removeExportedWorkout(sessionId: UUID) async throws

    /// Updates an exported workout with new data
    /// - Parameters:
    ///   - sessionId: The ID of the workout session to update
    ///   - config: Updated workout configuration
    /// - Throws: `HealthKitServiceError.workoutNotFound` if workout is not found
    func updateExportedWorkout(sessionId: UUID, config: HealthKitWorkoutConfig) async throws

    // MARK: - Exercise Data Import

    /// Imports recent exercise/workout data from HealthKit
    /// - Parameter days: Number of days to look back for exercise data
    /// - Returns: Array of exercise information from other apps
    /// - Throws: `HealthKitServiceError.permissionDenied` if read permission is not granted
    func importRecentExerciseData(days: Int) async throws -> [HealthKitExerciseInfo]

    /// Imports exercise data for a specific date range
    /// - Parameters:
    ///   - startDate: Start date for import range
    ///   - endDate: End date for import range
    /// - Returns: Array of exercise information for the date range
    /// - Throws: `HealthKitServiceError.permissionDenied` if read permission is not granted
    func importExerciseData(startDate: Date, endDate: Date) async throws -> [HealthKitExerciseInfo]

    /// Gets exercise data from a specific source app
    /// - Parameters:
    ///   - sourceName: Name of the source app (e.g., "Nike Training Club")
    ///   - days: Number of days to look back
    /// - Returns: Array of exercise information from the specified source
    func getExerciseDataFromSource(sourceName: String, days: Int) async throws -> [HealthKitExerciseInfo]

    /// Imports heart rate data for a workout session time period
    /// - Parameters:
    ///   - startDate: Start time of the workout
    ///   - endDate: End time of the workout
    /// - Returns: Array of heart rate readings during the workout
    /// - Throws: `HealthKitServiceError.permissionDenied` if heart rate permission is not granted
    func importHeartRateData(startDate: Date, endDate: Date) async throws -> [HeartRateData]

    /// Imports active energy data for a workout session
    /// - Parameters:
    ///   - startDate: Start time of the workout
    ///   - endDate: End time of the workout
    /// - Returns: Array of active energy readings during the workout
    /// - Throws: `HealthKitServiceError.permissionDenied` if energy permission is not granted
    func importActiveEnergyData(startDate: Date, endDate: Date) async throws -> [ActiveEnergyData]

    // MARK: - Real-time Data Monitoring

    /// Starts monitoring heart rate during a workout
    /// - Note: Publishes updates via heartRateUpdatePublisher
    /// - Throws: `HealthKitServiceError.permissionDenied` if heart rate permission is not granted
    func startHeartRateMonitoring() async throws

    /// Stops heart rate monitoring
    func stopHeartRateMonitoring() async

    /// Gets the current heart rate reading
    /// - Returns: Most recent heart rate data, or nil if not available
    /// - Throws: `HealthKitServiceError.permissionDenied` if heart rate permission is not granted
    func getCurrentHeartRate() async throws -> HeartRateData?

    /// Estimates calories burned for a workout session
    /// - Parameters:
    ///   - duration: Duration of the workout in seconds
    ///   - averageHeartRate: Average heart rate during the workout (optional)
    ///   - bodyWeight: User's body weight in kg (retrieved from HealthKit if available)
    /// - Returns: Estimated calories burned
    func estimateCaloriesBurned(duration: TimeInterval, averageHeartRate: Double?, bodyWeight: Double?) async -> Double

    // MARK: - Background Sync

    /// Enables automatic background sync with HealthKit
    /// - Parameter enabled: Whether to enable background sync
    /// - Note: Requires background app refresh permission
    func setAutoSyncEnabled(_ enabled: Bool) async

    /// Performs a manual sync with HealthKit
    /// - Returns: Sync statistics showing the results
    /// - Throws: `HealthKitServiceError.syncFailed` if sync fails
    func performManualSync() async throws -> HealthKitSyncStats

    /// Gets sync statistics and status
    /// - Returns: Current sync statistics
    func getSyncStats() async -> HealthKitSyncStats

    /// Checks for any workouts that failed to export and retries them
    /// - Returns: Number of workouts successfully retried
    func retryFailedExports() async throws -> Int

    /// Schedules background sync tasks
    /// - Note: Called when app enters background to schedule future sync
    func scheduleBackgroundSync() async

    // MARK: - Data Management

    /// Gets all workout sessions exported to HealthKit by this app
    /// - Returns: Array of session IDs that have been exported
    func getExportedWorkoutSessions() async -> [UUID]

    /// Validates workout data before export
    /// - Parameter config: Workout configuration to validate
    /// - Returns: Array of validation errors, empty if valid
    func validateWorkoutData(config: HealthKitWorkoutConfig) -> [String]

    /// Converts Gigi Gains workout data to HealthKit format
    /// - Parameter config: Workout configuration to convert
    /// - Returns: HKWorkout object ready for export
    /// - Throws: `HealthKitServiceError.dataConversionError` if conversion fails
    func convertToHealthKitWorkout(config: HealthKitWorkoutConfig) throws -> HKWorkout

    /// Converts HealthKit exercise data to Gigi Gains format
    /// - Parameter healthKitData: Exercise data from HealthKit
    /// - Returns: Converted exercise information
    /// - Throws: `HealthKitServiceError.dataConversionError` if conversion fails
    func convertFromHealthKitExercise(_ healthKitData: HKWorkout) throws -> HealthKitExerciseInfo

    // MARK: - Privacy and Settings

    /// Gets privacy information for display in settings
    /// - Returns: Dictionary of privacy information and current permissions
    func getPrivacyInfo() async -> [String: Any]

    /// Clears all HealthKit sync history (keeps workouts in HealthKit)
    /// - Note: Resets sync statistics but doesn't remove exported workouts
    func clearSyncHistory() async

    /// Disables HealthKit integration and clears sync data
    /// - Parameter removeExportedWorkouts: Whether to also remove exported workouts
    func disableHealthKitIntegration(removeExportedWorkouts: Bool) async throws
}

// MARK: - Test Helper Protocol

/// Protocol for test implementations and mocking
/// Enables dependency injection and unit testing of components that depend on HealthKitService
public protocol MockableHealthKitService: HealthKitService {
    /// Allows tests to control HealthKit availability
    func setMockHealthKitAvailable(_ available: Bool)

    /// Allows tests to simulate permission status
    func setMockAuthorizationStatus(_ status: HealthKitAuthorizationStatus)

    /// Allows tests to simulate errors
    func setMockError(_ error: HealthKitServiceError?)

    /// Allows tests to inject mock exercise data
    func setMockExerciseData(_ exercises: [HealthKitExerciseInfo])

    /// Allows tests to inject mock heart rate data
    func setMockHeartRateData(_ heartRateData: [HeartRateData])

    /// Allows tests to control sync statistics
    func setMockSyncStats(_ stats: HealthKitSyncStats)
}