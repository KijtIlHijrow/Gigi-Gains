//
//  ProgressTrackingService.swift
//  Gigi Gains - Internal API Contract
//
//  Defines the interface for progress tracking including PR calculations,
//  volume tracking, progression analytics, and data export functionality.
//
//  Created: 2025-09-28
//

import Foundation
import Combine
import CoreData

// MARK: - Supporting Types

/// Types of personal records that can be tracked
public enum PersonalRecordType: String, CaseIterable {
    case oneRepMax = "1RM"           // Estimated 1RM using Epley formula
    case maxVolume = "maxVolume"     // Highest volume in a single session
    case maxReps = "maxReps"         // Most reps at a given weight
    case maxWeight = "maxWeight"     // Heaviest weight lifted
    case endurance = "endurance"     // Longest duration or most total reps

    public var description: String {
        switch self {
        case .oneRepMax: return "1-Rep Max"
        case .maxVolume: return "Max Volume"
        case .maxReps: return "Max Reps"
        case .maxWeight: return "Max Weight"
        case .endurance: return "Endurance"
        }
    }

    /// Unit of measurement for this record type
    public var unit: String {
        switch self {
        case .oneRepMax, .maxWeight: return "weight"
        case .maxVolume: return "volume"
        case .maxReps: return "reps"
        case .endurance: return "duration"
        }
    }
}

/// Time periods for progress analysis
public enum ProgressTimePeriod: CaseIterable {
    case week
    case month
    case quarter
    case year
    case allTime
    case custom(startDate: Date, endDate: Date)

    public var description: String {
        switch self {
        case .week: return "This Week"
        case .month: return "This Month"
        case .quarter: return "This Quarter"
        case .year: return "This Year"
        case .allTime: return "All Time"
        case .custom(let start, let end):
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        }
    }

    /// Returns the date range for this time period
    public var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .week:
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return (weekStart, now)
        case .month:
            let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return (monthStart, now)
        case .quarter:
            let quarterStart = calendar.dateInterval(of: .quarter, for: now)?.start ?? now
            return (quarterStart, now)
        case .year:
            let yearStart = calendar.dateInterval(of: .year, for: now)?.start ?? now
            return (yearStart, now)
        case .allTime:
            return (Date.distantPast, now)
        case .custom(let start, let end):
            return (start, end)
        }
    }
}

/// Errors that can occur during progress tracking operations
public enum ProgressTrackingError: Error, LocalizedError {
    case exerciseNotFound(UUID)
    case invalidDateRange(startDate: Date, endDate: Date)
    case noDataAvailable(period: ProgressTimePeriod)
    case exportFailed(reason: String)
    case calculationError(reason: String)
    case coreDataError(Error)

    public var errorDescription: String? {
        switch self {
        case .exerciseNotFound(let id):
            return "Exercise with ID \(id) not found"
        case .invalidDateRange(let start, let end):
            return "Invalid date range: start date \(start) is after end date \(end)"
        case .noDataAvailable(let period):
            return "No workout data available for \(period.description)"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .calculationError(let reason):
            return "Calculation error: \(reason)"
        case .coreDataError(let error):
            return "Core Data error: \(error.localizedDescription)"
        }
    }
}

/// Data structure representing a personal record
public struct PersonalRecordData {
    public let id: UUID
    public let exerciseId: UUID
    public let exerciseName: String
    public let recordType: PersonalRecordType
    public let value: Double
    public let weight: Double?
    public let reps: Int32?
    public let date: Date
    public let notes: String?
    public let sourceSetId: UUID?

    public init(id: UUID, exerciseId: UUID, exerciseName: String, recordType: PersonalRecordType, value: Double, weight: Double?, reps: Int32?, date: Date, notes: String?, sourceSetId: UUID?) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.recordType = recordType
        self.value = value
        self.weight = weight
        self.reps = reps
        self.date = date
        self.notes = notes
        self.sourceSetId = sourceSetId
    }
}

/// Volume tracking data for a specific time period
public struct VolumeData {
    public let date: Date
    public let totalVolume: Double
    public let totalSets: Int
    public let totalReps: Int
    public let averageRPE: Double?
    public let exerciseCount: Int
    public let workoutCount: Int

    public init(date: Date, totalVolume: Double, totalSets: Int, totalReps: Int, averageRPE: Double?, exerciseCount: Int, workoutCount: Int) {
        self.date = date
        self.totalVolume = totalVolume
        self.totalSets = totalSets
        self.totalReps = totalReps
        self.averageRPE = averageRPE
        self.exerciseCount = exerciseCount
        self.workoutCount = workoutCount
    }
}

/// Progress analysis for a specific exercise
public struct ExerciseProgressData {
    public let exerciseId: UUID
    public let exerciseName: String
    public let currentOneRM: Double?
    public let previousOneRM: Double?
    public let oneRMChange: Double?
    public let oneRMChangePercent: Double?
    public let totalVolume: Double
    public let volumeChange: Double?
    public let averageRPE: Double?
    public let sessionCount: Int
    public let totalSets: Int
    public let personalRecords: [PersonalRecordData]
    public let recentPerformance: [ExercisePerformancePoint]

    public init(exerciseId: UUID, exerciseName: String, currentOneRM: Double?, previousOneRM: Double?, oneRMChange: Double?, oneRMChangePercent: Double?, totalVolume: Double, volumeChange: Double?, averageRPE: Double?, sessionCount: Int, totalSets: Int, personalRecords: [PersonalRecordData], recentPerformance: [ExercisePerformancePoint]) {
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.currentOneRM = currentOneRM
        self.previousOneRM = previousOneRM
        self.oneRMChange = oneRMChange
        self.oneRMChangePercent = oneRMChangePercent
        self.totalVolume = totalVolume
        self.volumeChange = volumeChange
        self.averageRPE = averageRPE
        self.sessionCount = sessionCount
        self.totalSets = totalSets
        self.personalRecords = personalRecords
        self.recentPerformance = recentPerformance
    }
}

/// Single data point for exercise performance tracking
public struct ExercisePerformancePoint {
    public let date: Date
    public let weight: Double
    public let reps: Int32
    public let estimatedOneRM: Double
    public let rpe: Double?
    public let volume: Double

    public init(date: Date, weight: Double, reps: Int32, estimatedOneRM: Double, rpe: Double?, volume: Double) {
        self.date = date
        self.weight = weight
        self.reps = reps
        self.estimatedOneRM = estimatedOneRM
        self.rpe = rpe
        self.volume = volume
    }
}

/// Overall progress summary for a time period
public struct ProgressSummary {
    public let period: ProgressTimePeriod
    public let totalWorkouts: Int
    public let totalVolume: Double
    public let volumeChange: Double?
    public let totalSets: Int
    public let averageWorkoutDuration: TimeInterval?
    public let personalRecordsAchieved: Int
    public let mostImprovedExercises: [ExerciseProgressData]
    public let volumeByMuscleGroup: [String: Double]
    public let averageRPE: Double?
    public let consistencyScore: Double // 0-1 scale based on workout frequency

    public init(period: ProgressTimePeriod, totalWorkouts: Int, totalVolume: Double, volumeChange: Double?, totalSets: Int, averageWorkoutDuration: TimeInterval?, personalRecordsAchieved: Int, mostImprovedExercises: [ExerciseProgressData], volumeByMuscleGroup: [String: Double], averageRPE: Double?, consistencyScore: Double) {
        self.period = period
        self.totalWorkouts = totalWorkouts
        self.totalVolume = totalVolume
        self.volumeChange = volumeChange
        self.totalSets = totalSets
        self.averageWorkoutDuration = averageWorkoutDuration
        self.personalRecordsAchieved = personalRecordsAchieved
        self.mostImprovedExercises = mostImprovedExercises
        self.volumeByMuscleGroup = volumeByMuscleGroup
        self.averageRPE = averageRPE
        self.consistencyScore = consistencyScore
    }
}

/// Export format options
public enum ExportFormat: String, CaseIterable {
    case csv = "CSV"
    case json = "JSON"

    public var fileExtension: String {
        return rawValue.lowercased()
    }

    public var mimeType: String {
        switch self {
        case .csv: return "text/csv"
        case .json: return "application/json"
        }
    }
}

/// Export data configuration
public struct ExportConfig {
    public let format: ExportFormat
    public let includePersonalRecords: Bool
    public let includeProgressData: Bool
    public let includeVolumeData: Bool
    public let dateRange: (start: Date, end: Date)?
    public let exerciseIds: [UUID]? // nil means all exercises

    public init(format: ExportFormat, includePersonalRecords: Bool = true, includeProgressData: Bool = true, includeVolumeData: Bool = true, dateRange: (start: Date, end: Date)? = nil, exerciseIds: [UUID]? = nil) {
        self.format = format
        self.includePersonalRecords = includePersonalRecords
        self.includeProgressData = includeProgressData
        self.includeVolumeData = includeVolumeData
        self.dateRange = dateRange
        self.exerciseIds = exerciseIds
    }
}

// MARK: - Main Protocol

/// Service protocol for tracking workout progress and calculating statistics
///
/// This protocol defines the complete interface for progress tracking in the Gigi Gains app.
/// It handles personal record (PR) calculations using the Epley formula, volume tracking,
/// progression analytics, and data export functionality. All calculations work with offline
/// data and provide real-time updates via Combine publishers.
///
/// Key responsibilities:
/// - Personal record calculation and tracking using Epley formula (weight × (1 + reps/30))
/// - Volume progression analysis and trend tracking
/// - Exercise-specific progress monitoring
/// - Weekly/monthly/yearly progress summaries
/// - CSV/JSON data export functionality
/// - Performance analytics and insights
/// - Goal tracking and achievement notifications
///
/// ## Usage Example:
/// ```swift
/// let service: ProgressTrackingService = ProgressTrackingServiceImpl()
///
/// // Get current personal records
/// let prs = try await service.getPersonalRecords(exerciseId: benchPressId)
///
/// // Analyze progress over the last month
/// let progress = try await service.getExerciseProgress(
///     exerciseId: benchPressId,
///     period: .month
/// )
///
/// // Export workout data
/// let config = ExportConfig(format: .csv)
/// let exportData = try await service.exportProgressData(config: config)
/// ```
public protocol ProgressTrackingService: AnyObject {

    // MARK: - Publishers for Reactive Updates

    /// Publishes updates to personal records
    /// Emits new PRs as they are achieved during workouts
    var personalRecordsUpdatePublisher: AnyPublisher<[PersonalRecordData], Never> { get }

    /// Publishes weekly volume data updates
    /// Useful for updating progress charts and graphs
    var weeklyVolumeUpdatePublisher: AnyPublisher<[VolumeData], Never> { get }

    /// Publishes overall progress summary updates
    /// Emits when significant progress milestones are reached
    var progressSummaryUpdatePublisher: AnyPublisher<ProgressSummary, Never> { get }

    // MARK: - Personal Record Management

    /// Gets all personal records for a specific exercise
    /// - Parameter exerciseId: The unique identifier of the exercise
    /// - Returns: Array of personal records sorted by date (most recent first)
    /// - Throws: `ProgressTrackingError.exerciseNotFound` if exercise doesn't exist
    func getPersonalRecords(exerciseId: UUID) async throws -> [PersonalRecordData]

    /// Gets personal records of a specific type for an exercise
    /// - Parameters:
    ///   - exerciseId: The unique identifier of the exercise
    ///   - recordType: The type of personal record to retrieve
    /// - Returns: Array of personal records of the specified type
    /// - Throws: `ProgressTrackingError.exerciseNotFound` if exercise doesn't exist
    func getPersonalRecords(exerciseId: UUID, recordType: PersonalRecordType) async throws -> [PersonalRecordData]

    /// Gets the current best personal record for an exercise and record type
    /// - Parameters:
    ///   - exerciseId: The unique identifier of the exercise
    ///   - recordType: The type of personal record to retrieve
    /// - Returns: The best personal record, or nil if none exists
    /// - Throws: `ProgressTrackingError.exerciseNotFound` if exercise doesn't exist
    func getBestPersonalRecord(exerciseId: UUID, recordType: PersonalRecordType) async throws -> PersonalRecordData?

    /// Gets all personal records achieved within a time period
    /// - Parameter period: The time period to analyze
    /// - Returns: Array of personal records achieved during the period
    func getPersonalRecords(period: ProgressTimePeriod) async throws -> [PersonalRecordData]

    /// Calculates and updates personal records from a completed set
    /// - Parameters:
    ///   - setId: The ID of the exercise set to analyze
    ///   - exerciseId: The ID of the exercise
    /// - Returns: Array of new personal records achieved, empty if none
    /// - Note: Uses Epley formula for 1RM calculation: weight × (1 + reps/30)
    func calculatePersonalRecords(fromSet setId: UUID, exerciseId: UUID) async throws -> [PersonalRecordData]

    /// Manually records a personal record achievement
    /// - Parameters:
    ///   - exerciseId: The exercise the record is for
    ///   - recordType: The type of record
    ///   - value: The record value
    ///   - weight: The weight used (if applicable)
    ///   - reps: The reps performed (if applicable)
    ///   - notes: Optional notes about the achievement
    /// - Returns: The created personal record
    /// - Throws: `ProgressTrackingError.exerciseNotFound` if exercise doesn't exist
    func recordPersonalRecord(exerciseId: UUID, recordType: PersonalRecordType, value: Double, weight: Double?, reps: Int32?, notes: String?) async throws -> PersonalRecordData

    // MARK: - Volume Tracking and Analysis

    /// Gets weekly volume data for a specific time period
    /// - Parameter period: The time period to analyze
    /// - Returns: Array of weekly volume data points
    /// - Throws: `ProgressTrackingError.noDataAvailable` if no data exists for the period
    func getWeeklyVolumeData(period: ProgressTimePeriod) async throws -> [VolumeData]

    /// Gets volume data for a specific exercise over time
    /// - Parameters:
    ///   - exerciseId: The unique identifier of the exercise
    ///   - period: The time period to analyze
    /// - Returns: Array of volume data points for the exercise
    /// - Throws: `ProgressTrackingError.exerciseNotFound` if exercise doesn't exist
    func getExerciseVolumeData(exerciseId: UUID, period: ProgressTimePeriod) async throws -> [VolumeData]

    /// Calculates total volume for all exercises in a time period
    /// - Parameter period: The time period to analyze
    /// - Returns: Total volume (weight × reps) for the period
    func getTotalVolume(period: ProgressTimePeriod) async throws -> Double

    /// Gets volume breakdown by muscle group for a time period
    /// - Parameter period: The time period to analyze
    /// - Returns: Dictionary mapping muscle groups to their total volume
    func getVolumeByMuscleGroup(period: ProgressTimePeriod) async throws -> [String: Double]

    /// Compares volume between two time periods
    /// - Parameters:
    ///   - currentPeriod: The current time period
    ///   - previousPeriod: The previous time period to compare against
    /// - Returns: Tuple containing current volume, previous volume, and percentage change
    func compareVolume(currentPeriod: ProgressTimePeriod, previousPeriod: ProgressTimePeriod) async throws -> (current: Double, previous: Double, change: Double)

    // MARK: - Exercise Progress Analysis

    /// Gets comprehensive progress data for a specific exercise
    /// - Parameters:
    ///   - exerciseId: The unique identifier of the exercise
    ///   - period: The time period to analyze
    /// - Returns: Detailed progress analysis for the exercise
    /// - Throws: `ProgressTrackingError.exerciseNotFound` if exercise doesn't exist
    func getExerciseProgress(exerciseId: UUID, period: ProgressTimePeriod) async throws -> ExerciseProgressData

    /// Gets progress data for multiple exercises
    /// - Parameters:
    ///   - exerciseIds: Array of exercise IDs to analyze
    ///   - period: The time period to analyze
    /// - Returns: Array of exercise progress data
    func getExercisesProgress(exerciseIds: [UUID], period: ProgressTimePeriod) async throws -> [ExerciseProgressData]

    /// Gets the most improved exercises for a time period
    /// - Parameters:
    ///   - period: The time period to analyze
    ///   - limit: Maximum number of exercises to return
    /// - Returns: Array of exercises sorted by improvement (best first)
    func getMostImprovedExercises(period: ProgressTimePeriod, limit: Int) async throws -> [ExerciseProgressData]

    /// Gets exercise performance history as data points for charting
    /// - Parameters:
    ///   - exerciseId: The unique identifier of the exercise
    ///   - period: The time period to analyze
    /// - Returns: Array of performance data points chronologically ordered
    /// - Throws: `ProgressTrackingError.exerciseNotFound` if exercise doesn't exist
    func getExercisePerformanceHistory(exerciseId: UUID, period: ProgressTimePeriod) async throws -> [ExercisePerformancePoint]

    // MARK: - Overall Progress Analysis

    /// Gets a comprehensive progress summary for a time period
    /// - Parameter period: The time period to analyze
    /// - Returns: Complete progress summary with all key metrics
    /// - Throws: `ProgressTrackingError.noDataAvailable` if no data exists for the period
    func getProgressSummary(period: ProgressTimePeriod) async throws -> ProgressSummary

    /// Compares progress between two time periods
    /// - Parameters:
    ///   - currentPeriod: The current time period
    ///   - previousPeriod: The previous time period to compare against
    /// - Returns: Tuple containing current and previous progress summaries
    func compareProgress(currentPeriod: ProgressTimePeriod, previousPeriod: ProgressTimePeriod) async throws -> (current: ProgressSummary, previous: ProgressSummary)

    /// Calculates workout consistency score for a time period
    /// - Parameter period: The time period to analyze
    /// - Returns: Consistency score from 0.0 to 1.0 (1.0 = perfect consistency)
    /// - Note: Based on workout frequency, adherence to planned sessions, and regularity
    func getConsistencyScore(period: ProgressTimePeriod) async throws -> Double

    /// Gets achievement milestones reached in a time period
    /// - Parameter period: The time period to analyze
    /// - Returns: Array of milestone descriptions (e.g., "First 100kg bench press")
    func getAchievements(period: ProgressTimePeriod) async throws -> [String]

    // MARK: - Data Export

    /// Exports progress data in the specified format
    /// - Parameter config: Export configuration specifying format and data to include
    /// - Returns: Data object containing the exported information
    /// - Throws: `ProgressTrackingError.exportFailed` if export fails
    /// - Note: For CSV format, includes columns: Session Date, Duration, Exercise, Set Number, Reps, Weight, RPE
    func exportProgressData(config: ExportConfig) async throws -> Data

    /// Gets a preview of export data structure
    /// - Parameter config: Export configuration
    /// - Returns: String preview of the export format and structure
    func getExportPreview(config: ExportConfig) async throws -> String

    /// Exports personal records data
    /// - Parameters:
    ///   - exerciseIds: Array of exercise IDs to include (nil for all exercises)
    ///   - format: Export format
    /// - Returns: Data object containing personal records
    func exportPersonalRecords(exerciseIds: [UUID]?, format: ExportFormat) async throws -> Data

    /// Exports volume progression data
    /// - Parameters:
    ///   - period: Time period to export
    ///   - format: Export format
    /// - Returns: Data object containing volume progression data
    func exportVolumeData(period: ProgressTimePeriod, format: ExportFormat) async throws -> Data

    // MARK: - Goal Tracking

    /// Sets a goal for an exercise (e.g., "Bench 100kg")
    /// - Parameters:
    ///   - exerciseId: The exercise to set a goal for
    ///   - recordType: The type of record to target
    ///   - targetValue: The target value to achieve
    ///   - targetDate: Optional target date to achieve the goal
    /// - Throws: `ProgressTrackingError.exerciseNotFound` if exercise doesn't exist
    func setGoal(exerciseId: UUID, recordType: PersonalRecordType, targetValue: Double, targetDate: Date?) async throws

    /// Gets all active goals
    /// - Returns: Array of goal data with current progress
    func getActiveGoals() async throws -> [GoalData]

    /// Checks if any goals were achieved in recent workouts
    /// - Returns: Array of recently achieved goals
    func checkForAchievedGoals() async throws -> [GoalData]

    /// Updates progress towards goals based on recent workout data
    /// - Note: This is typically called after completing a workout session
    func updateGoalProgress() async throws
}

// MARK: - Supporting Goal Types

/// Goal tracking data structure
public struct GoalData {
    public let id: UUID
    public let exerciseId: UUID
    public let exerciseName: String
    public let recordType: PersonalRecordType
    public let targetValue: Double
    public let currentValue: Double?
    public let targetDate: Date?
    public let createdDate: Date
    public let achievedDate: Date?
    public let progress: Double // 0.0 to 1.0
    public let isAchieved: Bool

    public init(id: UUID, exerciseId: UUID, exerciseName: String, recordType: PersonalRecordType, targetValue: Double, currentValue: Double?, targetDate: Date?, createdDate: Date, achievedDate: Date?, progress: Double, isAchieved: Bool) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.recordType = recordType
        self.targetValue = targetValue
        self.currentValue = currentValue
        self.targetDate = targetDate
        self.createdDate = createdDate
        self.achievedDate = achievedDate
        self.progress = progress
        self.isAchieved = isAchieved
    }
}

// MARK: - Test Helper Protocol

/// Protocol for test implementations and mocking
/// Enables dependency injection and unit testing of components that depend on ProgressTrackingService
public protocol MockableProgressTrackingService: ProgressTrackingService {
    /// Allows tests to inject mock personal records
    func setMockPersonalRecords(_ records: [PersonalRecordData])

    /// Allows tests to inject mock volume data
    func setMockVolumeData(_ volumeData: [VolumeData])

    /// Allows tests to simulate errors
    func setMockError(_ error: ProgressTrackingError?)

    /// Allows tests to control progress calculations
    func setMockProgressSummary(_ summary: ProgressSummary)

    /// Allows tests to control goal data
    func setMockGoals(_ goals: [GoalData])
}