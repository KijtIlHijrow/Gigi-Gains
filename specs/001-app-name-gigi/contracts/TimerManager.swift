//
//  TimerManager.swift
//  Gigi Gains - Internal API Contract
//
//  Defines the interface for rest timer management with background support,
//  including timer lifecycle, background persistence, and notification integration.
//
//  Created: 2025-09-28
//

import Foundation
import Combine

// MARK: - Supporting Types

/// Current state of the rest timer
public enum TimerState: String, CaseIterable {
    case stopped = "stopped"
    case running = "running"
    case paused = "paused"
    case completed = "completed"

    public var description: String {
        switch self {
        case .stopped: return "Stopped"
        case .running: return "Running"
        case .paused: return "Paused"
        case .completed: return "Completed"
        }
    }

    /// Whether the timer is actively counting down
    public var isActive: Bool {
        return self == .running
    }

    /// Whether the timer can be resumed
    public var canResume: Bool {
        return self == .paused
    }

    /// Whether the timer can be paused
    public var canPause: Bool {
        return self == .running
    }
}

/// Errors that can occur during timer operations
public enum TimerManagerError: Error, LocalizedError {
    case timerNotRunning
    case timerAlreadyRunning
    case invalidDuration(TimeInterval)
    case backgroundTaskFailed
    case notificationSchedulingFailed
    case persistenceError(Error)

    public var errorDescription: String? {
        switch self {
        case .timerNotRunning:
            return "Timer is not currently running"
        case .timerAlreadyRunning:
            return "Timer is already running"
        case .invalidDuration(let duration):
            return "Invalid timer duration: \(duration) seconds"
        case .backgroundTaskFailed:
            return "Failed to create background task for timer"
        case .notificationSchedulingFailed:
            return "Failed to schedule timer notification"
        case .persistenceError(let error):
            return "Timer persistence error: \(error.localizedDescription)"
        }
    }
}

/// Configuration for starting a rest timer
public struct RestTimerConfig {
    public let duration: TimeInterval
    public let exerciseName: String?
    public let setNumber: Int?
    public let customMessage: String?
    public let autoStart: Bool
    public let playNotificationSound: Bool
    public let vibrateOnCompletion: Bool
    public let showProgressInApp: Bool

    public init(duration: TimeInterval, exerciseName: String? = nil, setNumber: Int? = nil, customMessage: String? = nil, autoStart: Bool = true, playNotificationSound: Bool = true, vibrateOnCompletion: Bool = true, showProgressInApp: Bool = true) {
        self.duration = duration
        self.exerciseName = exerciseName
        self.setNumber = setNumber
        self.customMessage = customMessage
        self.autoStart = autoStart
        self.playNotificationSound = playNotificationSound
        self.vibrateOnCompletion = vibrateOnCompletion
        self.showProgressInApp = showProgressInApp
    }

    /// Validates the timer configuration
    public func validate() throws {
        guard duration > 0 else {
            throw TimerManagerError.invalidDuration(duration)
        }
        guard duration <= 3600 else { // Maximum 1 hour
            throw TimerManagerError.invalidDuration(duration)
        }
    }
}

/// Current timer information
public struct TimerInfo {
    public let state: TimerState
    public let originalDuration: TimeInterval
    public let remainingTime: TimeInterval
    public let elapsedTime: TimeInterval
    public let startTime: Date?
    public let pauseTime: Date?
    public let exerciseName: String?
    public let setNumber: Int?
    public let notificationScheduled: Bool
    public let backgroundTaskActive: Bool

    public init(state: TimerState, originalDuration: TimeInterval, remainingTime: TimeInterval, elapsedTime: TimeInterval, startTime: Date?, pauseTime: Date?, exerciseName: String?, setNumber: Int?, notificationScheduled: Bool, backgroundTaskActive: Bool) {
        self.state = state
        self.originalDuration = originalDuration
        self.remainingTime = remainingTime
        self.elapsedTime = elapsedTime
        self.startTime = startTime
        self.pauseTime = pauseTime
        self.exerciseName = exerciseName
        self.setNumber = setNumber
        self.notificationScheduled = notificationScheduled
        self.backgroundTaskActive = backgroundTaskActive
    }

    /// Progress as a percentage (0.0 to 1.0)
    public var progress: Double {
        guard originalDuration > 0 else { return 0.0 }
        return min(1.0, max(0.0, elapsedTime / originalDuration))
    }

    /// Whether the timer has completed
    public var isCompleted: Bool {
        return state == .completed || remainingTime <= 0
    }

    /// Formatted remaining time string (e.g., "2:30")
    public var formattedRemainingTime: String {
        return formatTime(remainingTime)
    }

    /// Formatted elapsed time string (e.g., "0:30")
    public var formattedElapsedTime: String {
        return formatTime(elapsedTime)
    }

    /// Formatted original duration string (e.g., "3:00")
    public var formattedOriginalDuration: String {
        return formatTime(originalDuration)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Timer completion information
public struct TimerCompletion {
    public let originalDuration: TimeInterval
    public let actualDuration: TimeInterval
    public let exerciseName: String?
    public let setNumber: Int?
    public let completedAt: Date
    public let wasInterrupted: Bool

    public init(originalDuration: TimeInterval, actualDuration: TimeInterval, exerciseName: String?, setNumber: Int?, completedAt: Date, wasInterrupted: Bool) {
        self.originalDuration = originalDuration
        self.actualDuration = actualDuration
        self.exerciseName = exerciseName
        self.setNumber = setNumber
        self.completedAt = completedAt
        self.wasInterrupted = wasInterrupted
    }

    /// Whether the timer ran for the full duration
    public var ranToCompletion: Bool {
        return !wasInterrupted && abs(actualDuration - originalDuration) < 1.0
    }
}

/// Settings for timer behavior and appearance
public struct TimerSettings {
    public let defaultDuration: TimeInterval
    public let autoStartNextSet: Bool
    public let playTickingSound: Bool
    public let playCompletionSound: Bool
    public let vibrateOnCompletion: Bool
    public let showNotificationBanner: Bool
    public let continueInBackground: Bool
    public let warningThreshold: TimeInterval // Show warning when this much time remains
    public let tickInterval: TimeInterval // How often to update UI (seconds)

    public init(defaultDuration: TimeInterval = 120, autoStartNextSet: Bool = false, playTickingSound: Bool = false, playCompletionSound: Bool = true, vibrateOnCompletion: Bool = true, showNotificationBanner: Bool = true, continueInBackground: Bool = true, warningThreshold: TimeInterval = 10, tickInterval: TimeInterval = 1.0) {
        self.defaultDuration = defaultDuration
        self.autoStartNextSet = autoStartNextSet
        self.playTickingSound = playTickingSound
        self.playCompletionSound = playCompletionSound
        self.vibrateOnCompletion = vibrateOnCompletion
        self.showNotificationBanner = showNotificationBanner
        self.continueInBackground = continueInBackground
        self.warningThreshold = warningThreshold
        self.tickInterval = tickInterval
    }
}

/// Timer history entry for analytics
public struct TimerHistoryEntry {
    public let id: UUID
    public let startTime: Date
    public let endTime: Date?
    public let originalDuration: TimeInterval
    public let actualDuration: TimeInterval?
    public let exerciseName: String?
    public let setNumber: Int?
    public let completed: Bool
    public let cancelled: Bool
    public let pauseCount: Int
    public let backgroundTime: TimeInterval?

    public init(id: UUID, startTime: Date, endTime: Date?, originalDuration: TimeInterval, actualDuration: TimeInterval?, exerciseName: String?, setNumber: Int?, completed: Bool, cancelled: Bool, pauseCount: Int, backgroundTime: TimeInterval?) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.originalDuration = originalDuration
        self.actualDuration = actualDuration
        self.exerciseName = exerciseName
        self.setNumber = setNumber
        self.completed = completed
        self.cancelled = cancelled
        self.pauseCount = pauseCount
        self.backgroundTime = backgroundTime
    }
}

// MARK: - Main Protocol

/// Manager protocol for rest timer functionality with background support
///
/// This protocol defines the complete interface for rest timer management in the Gigi Gains app.
/// It provides timer lifecycle management, background execution, notification integration, and
/// persistence across app launches. The timer continues running when the app is backgrounded
/// and provides appropriate notifications when time expires.
///
/// Key responsibilities:
/// - Rest timer lifecycle management (start, pause, resume, stop)
/// - Background timer execution and persistence
/// - Integration with notification service for timer completion alerts
/// - Timer state synchronization across app lifecycle events
/// - Timer history tracking and analytics
/// - Customizable timer behavior and user preferences
/// - Audio and haptic feedback for timer events
///
/// ## Usage Example:
/// ```swift
/// let timerManager: TimerManager = TimerManagerImpl()
///
/// // Configure and start a rest timer
/// let config = RestTimerConfig(
///     duration: 120,
///     exerciseName: "Bench Press",
///     setNumber: 2
/// )
/// try await timerManager.startTimer(config: config)
///
/// // Monitor timer updates
/// timerManager.timerUpdatePublisher
///     .sink { timerInfo in
///         updateTimerUI(with: timerInfo)
///     }
///     .store(in: &cancellables)
///
/// // Handle timer completion
/// timerManager.timerCompletionPublisher
///     .sink { completion in
///         handleTimerCompletion(completion)
///     }
///     .store(in: &cancellables)
/// ```
public protocol TimerManager: AnyObject {

    // MARK: - Publishers for Reactive Updates

    /// Publishes real-time timer updates
    /// Emits TimerInfo with current state, remaining time, and progress
    var timerUpdatePublisher: AnyPublisher<TimerInfo, Never> { get }

    /// Publishes timer state changes
    /// Emits when timer starts, pauses, resumes, or stops
    var timerStatePublisher: AnyPublisher<TimerState, Never> { get }

    /// Publishes timer completion events
    /// Emits when timer reaches zero or is manually completed
    var timerCompletionPublisher: AnyPublisher<TimerCompletion, Never> { get }

    /// Publishes timer warning events
    /// Emits when timer reaches warning threshold (e.g., 10 seconds remaining)
    var timerWarningPublisher: AnyPublisher<TimeInterval, Never> { get }

    // MARK: - Timer Lifecycle

    /// Starts a new rest timer with the specified configuration
    /// - Parameter config: Configuration for the timer including duration and context
    /// - Throws: `TimerManagerError.timerAlreadyRunning` if a timer is already active
    /// - Throws: `TimerManagerError.invalidDuration` if duration is invalid
    /// - Throws: `TimerManagerError.notificationSchedulingFailed` if background notification fails
    func startTimer(config: RestTimerConfig) async throws

    /// Starts a timer with a simple duration (uses default settings)
    /// - Parameter duration: Timer duration in seconds
    /// - Throws: `TimerManagerError.timerAlreadyRunning` if a timer is already active
    /// - Throws: `TimerManagerError.invalidDuration` if duration is invalid
    func startTimer(duration: TimeInterval) async throws

    /// Pauses the currently running timer
    /// - Throws: `TimerManagerError.timerNotRunning` if no timer is active
    /// - Note: Timer can be resumed later from the paused point
    func pauseTimer() async throws

    /// Resumes a paused timer
    /// - Throws: `TimerManagerError.timerNotRunning` if no timer is paused
    func resumeTimer() async throws

    /// Stops the current timer
    /// - Parameter recordHistory: Whether to record this timer session in history
    /// - Note: Stopping a timer cancels any scheduled notifications
    func stopTimer(recordHistory: Bool) async

    /// Resets the timer to its original duration
    /// - Note: Timer must be stopped before resetting
    func resetTimer() async

    /// Adds time to the current timer
    /// - Parameter additionalTime: Time to add in seconds
    /// - Throws: `TimerManagerError.timerNotRunning` if no timer is active
    func addTime(_ additionalTime: TimeInterval) async throws

    /// Subtracts time from the current timer
    /// - Parameter timeToSubtract: Time to subtract in seconds
    /// - Throws: `TimerManagerError.timerNotRunning` if no timer is active
    /// - Note: Timer will complete immediately if remaining time becomes <= 0
    func subtractTime(_ timeToSubtract: TimeInterval) async throws

    // MARK: - Timer State and Information

    /// Gets the current timer information
    /// - Returns: Current timer state, times, and context, or nil if no timer is active
    var currentTimerInfo: TimerInfo? { get async }

    /// Gets the current timer state
    /// - Returns: Current timer state
    var currentState: TimerState { get async }

    /// Checks if a timer is currently running
    /// - Returns: True if a timer is active (running or paused)
    var isTimerActive: Bool { get async }

    /// Gets the remaining time on the current timer
    /// - Returns: Remaining time in seconds, or nil if no timer is active
    var remainingTime: TimeInterval? { get async }

    /// Gets the elapsed time on the current timer
    /// - Returns: Elapsed time in seconds, or nil if no timer is active
    var elapsedTime: TimeInterval? { get async }

    /// Gets the original duration of the current timer
    /// - Returns: Original timer duration in seconds, or nil if no timer is active
    var originalDuration: TimeInterval? { get async }

    // MARK: - Background and Persistence

    /// Handles app entering background state
    /// - Note: Ensures timer continues running and schedules appropriate notifications
    func handleAppDidEnterBackground() async

    /// Handles app returning to foreground state
    /// - Note: Synchronizes timer state and cancels redundant notifications
    func handleAppWillEnterForeground() async

    /// Handles app termination
    /// - Note: Persists timer state for potential restoration
    func handleAppWillTerminate() async

    /// Restores timer state from persistence
    /// - Returns: True if a timer was successfully restored
    /// - Note: Called during app launch to restore interrupted timers
    func restoreTimerState() async -> Bool

    /// Persists current timer state
    /// - Throws: `TimerManagerError.persistenceError` if persistence fails
    /// - Note: Called automatically during state changes and app lifecycle events
    func persistTimerState() async throws

    /// Clears persisted timer state
    /// - Note: Called when timer completes or is manually stopped
    func clearPersistedState() async

    // MARK: - Settings and Configuration

    /// Gets the current timer settings
    /// - Returns: Current timer behavior settings
    func getTimerSettings() async -> TimerSettings

    /// Updates timer settings
    /// - Parameter settings: New timer settings to apply
    /// - Note: Settings apply to future timers, not the currently running timer
    func updateTimerSettings(_ settings: TimerSettings) async

    /// Gets the default timer duration
    /// - Returns: Default duration for new timers in seconds
    var defaultDuration: TimeInterval { get async }

    /// Sets the default timer duration
    /// - Parameter duration: New default duration in seconds
    func setDefaultDuration(_ duration: TimeInterval) async

    /// Gets predefined timer duration presets
    /// - Returns: Array of common timer durations in seconds
    func getTimerPresets() async -> [TimeInterval]

    /// Updates timer duration presets
    /// - Parameter presets: Array of preset durations in seconds
    func updateTimerPresets(_ presets: [TimeInterval]) async

    // MARK: - History and Analytics

    /// Gets timer history for a specific time period
    /// - Parameter days: Number of days to look back
    /// - Returns: Array of timer history entries
    func getTimerHistory(days: Int) async -> [TimerHistoryEntry]

    /// Gets timer statistics
    /// - Returns: Dictionary of timer usage statistics
    func getTimerStatistics() async -> [String: Any]

    /// Gets average timer completion rate
    /// - Returns: Percentage of timers that run to completion (0.0 to 1.0)
    func getTimerCompletionRate() async -> Double

    /// Gets most commonly used timer durations
    /// - Parameter limit: Maximum number of durations to return
    /// - Returns: Array of durations sorted by frequency of use
    func getMostUsedDurations(limit: Int) async -> [TimeInterval]

    /// Records timer usage for analytics
    /// - Parameter completion: Timer completion information
    /// - Note: Called automatically when timers complete
    func recordTimerUsage(_ completion: TimerCompletion) async

    /// Clears timer history
    /// - Parameter olderThan: Clear entries older than this date (nil for all)
    func clearTimerHistory(olderThan: Date?) async

    // MARK: - Audio and Haptic Feedback

    /// Plays timer completion sound
    /// - Note: Respects user settings for sound preferences
    func playCompletionSound() async

    /// Plays timer warning sound
    /// - Note: Plays when timer reaches warning threshold
    func playWarningSound() async

    /// Triggers haptic feedback for timer events
    /// - Parameter type: Type of haptic feedback to trigger
    func triggerHapticFeedback(type: HapticFeedbackType) async

    /// Enables or disables timer sounds
    /// - Parameter enabled: Whether timer sounds should be enabled
    func setSoundsEnabled(_ enabled: Bool) async

    /// Enables or disables haptic feedback
    /// - Parameter enabled: Whether haptic feedback should be enabled
    func setHapticFeedbackEnabled(_ enabled: Bool) async

    // MARK: - Testing and Development

    /// Fast-forwards the timer for testing purposes
    /// - Parameter seconds: Number of seconds to advance the timer
    /// - Note: Only available in debug builds
    func fastForwardTimer(seconds: TimeInterval) async

    /// Simulates timer completion for testing
    /// - Note: Only available in debug builds
    func simulateTimerCompletion() async

    /// Validates timer configuration
    /// - Parameter config: Configuration to validate
    /// - Returns: Array of validation errors, empty if valid
    func validateTimerConfig(_ config: RestTimerConfig) -> [String]
}

// MARK: - Supporting Types for Additional Functionality

/// Types of haptic feedback for timer events
public enum HapticFeedbackType: CaseIterable {
    case timerStart
    case timerComplete
    case timerWarning
    case timerPause
    case timerResume

    public var description: String {
        switch self {
        case .timerStart: return "Timer Start"
        case .timerComplete: return "Timer Complete"
        case .timerWarning: return "Timer Warning"
        case .timerPause: return "Timer Pause"
        case .timerResume: return "Timer Resume"
        }
    }
}

// MARK: - Test Helper Protocol

/// Protocol for test implementations and mocking
/// Enables dependency injection and unit testing of components that depend on TimerManager
public protocol MockableTimerManager: TimerManager {
    /// Allows tests to simulate timer state
    func setMockTimerState(_ state: TimerState)

    /// Allows tests to control timer info
    func setMockTimerInfo(_ info: TimerInfo?)

    /// Allows tests to simulate errors
    func setMockError(_ error: TimerManagerError?)

    /// Allows tests to control timer settings
    func setMockSettings(_ settings: TimerSettings)

    /// Allows tests to inject timer history
    func setMockHistory(_ history: [TimerHistoryEntry])

    /// Allows tests to simulate time passage
    func simulateTimePassage(_ seconds: TimeInterval)

    /// Allows tests to trigger timer completion
    func triggerMockCompletion()
}