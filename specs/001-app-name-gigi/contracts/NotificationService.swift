//
//  NotificationService.swift
//  Gigi Gains - Internal API Contract
//
//  Defines the interface for local notification management including rest timer
//  notifications, background alerts, and workout reminders.
//
//  Created: 2025-09-28
//

import Foundation
import Combine
import UserNotifications

// MARK: - Supporting Types

/// Types of notifications supported by the app
public enum NotificationType: String, CaseIterable {
    case restTimer = "restTimer"
    case workoutReminder = "workoutReminder"
    case goalAchievement = "goalAchievement"
    case personalRecord = "personalRecord"
    case weeklyProgress = "weeklyProgress"
    case syncAlert = "syncAlert"
    case healthKitError = "healthKitError"

    public var description: String {
        switch self {
        case .restTimer: return "Rest Timer"
        case .workoutReminder: return "Workout Reminder"
        case .goalAchievement: return "Goal Achievement"
        case .personalRecord: return "Personal Record"
        case .weeklyProgress: return "Weekly Progress"
        case .syncAlert: return "Sync Alert"
        case .healthKitError: return "HealthKit Error"
        }
    }

    /// Default category identifier for grouping notifications
    public var categoryIdentifier: String {
        return "category_\(rawValue)"
    }

    /// Priority level for notification delivery
    public var priority: NotificationPriority {
        switch self {
        case .restTimer, .personalRecord:
            return .high
        case .goalAchievement, .workoutReminder:
            return .medium
        case .weeklyProgress, .syncAlert, .healthKitError:
            return .low
        }
    }
}

/// Priority levels for notification delivery
public enum NotificationPriority: Int, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2

    public var description: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

/// Authorization status for notifications
public enum NotificationAuthorizationStatus {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral

    public var description: String {
        switch self {
        case .notDetermined: return "Not Determined"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        }
    }

    /// Whether notifications can be delivered
    public var canDeliverNotifications: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied:
            return false
        }
    }
}

/// Errors that can occur during notification operations
public enum NotificationServiceError: Error, LocalizedError {
    case permissionDenied
    case permissionNotDetermined
    case invalidNotificationData(reason: String)
    case schedulingFailed(reason: String)
    case notificationNotFound(identifier: String)
    case categoryRegistrationFailed
    case systemError(Error)

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Notification permission denied. Please enable notifications in Settings."
        case .permissionNotDetermined:
            return "Notification permission not determined. Please request permission first."
        case .invalidNotificationData(let reason):
            return "Invalid notification data: \(reason)"
        case .schedulingFailed(let reason):
            return "Failed to schedule notification: \(reason)"
        case .notificationNotFound(let identifier):
            return "Notification with identifier '\(identifier)' not found"
        case .categoryRegistrationFailed:
            return "Failed to register notification categories"
        case .systemError(let error):
            return "System error: \(error.localizedDescription)"
        }
    }
}

/// Configuration for scheduling a notification
public struct NotificationConfig {
    public let identifier: String
    public let type: NotificationType
    public let title: String
    public let body: String
    public let subtitle: String?
    public let badge: Int?
    public let sound: UNNotificationSound?
    public let userInfo: [String: Any]
    public let categoryIdentifier: String?
    public let threadIdentifier: String?

    public init(identifier: String, type: NotificationType, title: String, body: String, subtitle: String? = nil, badge: Int? = nil, sound: UNNotificationSound? = .default, userInfo: [String: Any] = [:], categoryIdentifier: String? = nil, threadIdentifier: String? = nil) {
        self.identifier = identifier
        self.type = type
        self.title = title
        self.body = body
        self.subtitle = subtitle
        self.badge = badge
        self.sound = sound
        self.userInfo = userInfo
        self.categoryIdentifier = categoryIdentifier ?? type.categoryIdentifier
        self.threadIdentifier = threadIdentifier
    }
}

/// Configuration for rest timer notifications
public struct RestTimerNotificationConfig {
    public let duration: TimeInterval
    public let exerciseName: String?
    public let setNumber: Int?
    public let customMessage: String?
    public let playSound: Bool
    public let vibrate: Bool

    public init(duration: TimeInterval, exerciseName: String? = nil, setNumber: Int? = nil, customMessage: String? = nil, playSound: Bool = true, vibrate: Bool = true) {
        self.duration = duration
        self.exerciseName = exerciseName
        self.setNumber = setNumber
        self.customMessage = customMessage
        self.playSound = playSound
        self.vibrate = vibrate
    }

    /// Generates notification content based on configuration
    public var notificationContent: (title: String, body: String) {
        let title = "Rest Timer Complete"

        if let customMessage = customMessage {
            return (title, customMessage)
        }

        var body = "Time to get back to your workout!"

        if let exerciseName = exerciseName {
            if let setNumber = setNumber {
                body = "Ready for set \(setNumber) of \(exerciseName)"
            } else {
                body = "Ready to continue \(exerciseName)"
            }
        }

        return (title, body)
    }
}

/// Settings for different types of notifications
public struct NotificationSettings {
    public let restTimerEnabled: Bool
    public let workoutRemindersEnabled: Bool
    public let goalAchievementsEnabled: Bool
    public let personalRecordsEnabled: Bool
    public let weeklyProgressEnabled: Bool
    public let syncAlertsEnabled: Bool
    public let healthKitErrorsEnabled: Bool
    public let soundEnabled: Bool
    public let badgeEnabled: Bool
    public let lockScreenEnabled: Bool
    public let notificationCenterEnabled: Bool
    public let bannerEnabled: Bool

    public init(restTimerEnabled: Bool = true, workoutRemindersEnabled: Bool = true, goalAchievementsEnabled: Bool = true, personalRecordsEnabled: Bool = true, weeklyProgressEnabled: Bool = true, syncAlertsEnabled: Bool = true, healthKitErrorsEnabled: Bool = true, soundEnabled: Bool = true, badgeEnabled: Bool = true, lockScreenEnabled: Bool = true, notificationCenterEnabled: Bool = true, bannerEnabled: Bool = true) {
        self.restTimerEnabled = restTimerEnabled
        self.workoutRemindersEnabled = workoutRemindersEnabled
        self.goalAchievementsEnabled = goalAchievementsEnabled
        self.personalRecordsEnabled = personalRecordsEnabled
        self.weeklyProgressEnabled = weeklyProgressEnabled
        self.syncAlertsEnabled = syncAlertsEnabled
        self.healthKitErrorsEnabled = healthKitErrorsEnabled
        self.soundEnabled = soundEnabled
        self.badgeEnabled = badgeEnabled
        self.lockScreenEnabled = lockScreenEnabled
        self.notificationCenterEnabled = notificationCenterEnabled
        self.bannerEnabled = bannerEnabled
    }

    /// Whether a specific notification type is enabled
    public func isEnabled(for type: NotificationType) -> Bool {
        switch type {
        case .restTimer: return restTimerEnabled
        case .workoutReminder: return workoutRemindersEnabled
        case .goalAchievement: return goalAchievementsEnabled
        case .personalRecord: return personalRecordsEnabled
        case .weeklyProgress: return weeklyProgressEnabled
        case .syncAlert: return syncAlertsEnabled
        case .healthKitError: return healthKitErrorsEnabled
        }
    }
}

/// Information about a scheduled notification
public struct ScheduledNotification {
    public let identifier: String
    public let type: NotificationType
    public let title: String
    public let body: String
    public let scheduledDate: Date
    public let delivered: Bool
    public let userInfo: [String: Any]

    public init(identifier: String, type: NotificationType, title: String, body: String, scheduledDate: Date, delivered: Bool, userInfo: [String: Any]) {
        self.identifier = identifier
        self.type = type
        self.title = title
        self.body = body
        self.scheduledDate = scheduledDate
        self.delivered = delivered
        self.userInfo = userInfo
    }
}

/// Statistics about notification delivery and engagement
public struct NotificationStatistics {
    public let totalScheduled: Int
    public let totalDelivered: Int
    public let totalTapped: Int
    public let restTimerNotifications: Int
    public let workoutReminders: Int
    public let achievementNotifications: Int
    public let lastDeliveredDate: Date?
    public let averageResponseTime: TimeInterval?

    public init(totalScheduled: Int, totalDelivered: Int, totalTapped: Int, restTimerNotifications: Int, workoutReminders: Int, achievementNotifications: Int, lastDeliveredDate: Date?, averageResponseTime: TimeInterval?) {
        self.totalScheduled = totalScheduled
        self.totalDelivered = totalDelivered
        self.totalTapped = totalTapped
        self.restTimerNotifications = restTimerNotifications
        self.workoutReminders = workoutReminders
        self.achievementNotifications = achievementNotifications
        self.lastDeliveredDate = lastDeliveredDate
        self.averageResponseTime = averageResponseTime
    }

    /// Delivery success rate (0.0 to 1.0)
    public var deliveryRate: Double {
        guard totalScheduled > 0 else { return 0.0 }
        return Double(totalDelivered) / Double(totalScheduled)
    }

    /// Engagement rate (0.0 to 1.0)
    public var engagementRate: Double {
        guard totalDelivered > 0 else { return 0.0 }
        return Double(totalTapped) / Double(totalDelivered)
    }
}

// MARK: - Main Protocol

/// Service protocol for managing local notifications
///
/// This protocol defines the complete interface for notification management in the Gigi Gains app.
/// It handles rest timer notifications, workout reminders, achievement alerts, and other local
/// notifications. All operations respect user permissions and preferences while providing
/// seamless background notification delivery.
///
/// Key responsibilities:
/// - Rest timer notifications with background support
/// - Workout reminder scheduling and management
/// - Achievement and personal record notifications
/// - Permission management and user settings
/// - Background notification handling
/// - Notification analytics and engagement tracking
/// - Custom notification sounds and vibration
///
/// ## Usage Example:
/// ```swift
/// let service: NotificationService = NotificationServiceImpl()
///
/// // Request notification permissions
/// try await service.requestPermissions()
///
/// // Schedule a rest timer notification
/// let timerConfig = RestTimerNotificationConfig(
///     duration: 120,
///     exerciseName: "Bench Press",
///     setNumber: 2
/// )
/// try await service.scheduleRestTimerNotification(config: timerConfig)
///
/// // Send achievement notification
/// try await service.sendAchievementNotification(
///     title: "New Personal Record!",
///     message: "You just benched 100kg for the first time!"
/// )
/// ```
public protocol NotificationService: AnyObject {

    // MARK: - Publishers for Reactive Updates

    /// Publishes notification authorization status changes
    /// Emits when permissions are granted, denied, or changed
    var authorizationStatusPublisher: AnyPublisher<NotificationAuthorizationStatus, Never> { get }

    /// Publishes notification settings changes
    /// Useful for updating UI based on user preferences
    var notificationSettingsPublisher: AnyPublisher<NotificationSettings, Never> { get }

    /// Publishes notification tap events
    /// Emits when user taps on a delivered notification
    var notificationTapPublisher: AnyPublisher<ScheduledNotification, Never> { get }

    // MARK: - Permission Management

    /// Gets the current notification authorization status
    /// - Returns: Current authorization status
    func getAuthorizationStatus() async -> NotificationAuthorizationStatus

    /// Requests notification permissions from the user
    /// - Returns: Authorization status after the request
    /// - Note: Shows system permission dialog
    func requestPermissions() async throws -> NotificationAuthorizationStatus

    /// Checks if specific notification types are authorized
    /// - Parameter types: Array of notification types to check
    /// - Returns: Dictionary mapping types to their authorization status
    func checkPermissions(for types: [NotificationType]) async -> [NotificationType: Bool]

    /// Opens the app's notification settings in System Settings
    /// - Note: Useful when users need to modify permissions manually
    func openNotificationSettings() async

    // MARK: - Rest Timer Notifications

    /// Schedules a rest timer notification
    /// - Parameter config: Configuration for the rest timer notification
    /// - Returns: Unique identifier for the scheduled notification
    /// - Throws: `NotificationServiceError.permissionDenied` if notifications are disabled
    /// - Throws: `NotificationServiceError.schedulingFailed` if scheduling fails
    func scheduleRestTimerNotification(config: RestTimerNotificationConfig) async throws -> String

    /// Cancels the current rest timer notification
    /// - Note: Cancels any active rest timer notification
    func cancelRestTimerNotification() async

    /// Updates the rest timer notification with remaining time
    /// - Parameters:
    ///   - identifier: The notification identifier to update
    ///   - remainingTime: Remaining time in seconds
    /// - Throws: `NotificationServiceError.notificationNotFound` if notification doesn't exist
    func updateRestTimerNotification(identifier: String, remainingTime: TimeInterval) async throws

    /// Gets the currently active rest timer notification
    /// - Returns: The active rest timer notification, or nil if none
    func getCurrentRestTimerNotification() async -> ScheduledNotification?

    // MARK: - Workout Reminders

    /// Schedules a workout reminder notification
    /// - Parameters:
    ///   - title: Title for the reminder
    ///   - message: Reminder message
    ///   - scheduledDate: When to deliver the reminder
    ///   - repeatInterval: Optional repeat interval for recurring reminders
    /// - Returns: Unique identifier for the scheduled reminder
    /// - Throws: `NotificationServiceError.permissionDenied` if notifications are disabled
    func scheduleWorkoutReminder(title: String, message: String, scheduledDate: Date, repeatInterval: DateComponents?) async throws -> String

    /// Cancels a specific workout reminder
    /// - Parameter identifier: The identifier of the reminder to cancel
    func cancelWorkoutReminder(identifier: String) async

    /// Cancels all workout reminders
    func cancelAllWorkoutReminders() async

    /// Gets all scheduled workout reminders
    /// - Returns: Array of scheduled workout reminder notifications
    func getScheduledWorkoutReminders() async -> [ScheduledNotification]

    /// Updates a workout reminder
    /// - Parameters:
    ///   - identifier: The identifier of the reminder to update
    ///   - title: New title for the reminder
    ///   - message: New message for the reminder
    ///   - scheduledDate: New scheduled date
    func updateWorkoutReminder(identifier: String, title: String, message: String, scheduledDate: Date) async throws

    // MARK: - Achievement and Progress Notifications

    /// Sends a personal record achievement notification
    /// - Parameters:
    ///   - exerciseName: Name of the exercise
    ///   - recordType: Type of record achieved
    ///   - value: The record value
    ///   - improvement: Optional improvement from previous record
    /// - Throws: `NotificationServiceError.permissionDenied` if notifications are disabled
    func sendPersonalRecordNotification(exerciseName: String, recordType: String, value: String, improvement: String?) async throws

    /// Sends a goal achievement notification
    /// - Parameters:
    ///   - title: Title for the achievement
    ///   - message: Achievement message
    ///   - goalName: Name of the achieved goal
    /// - Throws: `NotificationServiceError.permissionDenied` if notifications are disabled
    func sendGoalAchievementNotification(title: String, message: String, goalName: String) async throws

    /// Sends a weekly progress summary notification
    /// - Parameters:
    ///   - weeklyStats: Statistics for the week
    ///   - highlights: Key highlights to feature
    /// - Throws: `NotificationServiceError.permissionDenied` if notifications are disabled
    func sendWeeklyProgressNotification(weeklyStats: [String: Any], highlights: [String]) async throws

    /// Sends a milestone achievement notification
    /// - Parameters:
    ///   - milestone: Description of the milestone
    ///   - category: Category of achievement (e.g., "Consistency", "Strength")
    /// - Throws: `NotificationServiceError.permissionDenied` if notifications are disabled
    func sendMilestoneNotification(milestone: String, category: String) async throws

    // MARK: - System and Error Notifications

    /// Sends a sync error notification
    /// - Parameters:
    ///   - errorType: Type of sync error
    ///   - message: Error message for the user
    ///   - actionRequired: Whether user action is required
    /// - Throws: `NotificationServiceError.permissionDenied` if notifications are disabled
    func sendSyncErrorNotification(errorType: String, message: String, actionRequired: Bool) async throws

    /// Sends a HealthKit error notification
    /// - Parameters:
    ///   - errorType: Type of HealthKit error
    ///   - message: Error message for the user
    /// - Throws: `NotificationServiceError.permissionDenied` if notifications are disabled
    func sendHealthKitErrorNotification(errorType: String, message: String) async throws

    /// Sends a generic system notification
    /// - Parameter config: Notification configuration
    /// - Returns: Unique identifier for the scheduled notification
    /// - Throws: `NotificationServiceError.permissionDenied` if notifications are disabled
    func sendSystemNotification(config: NotificationConfig) async throws -> String

    // MARK: - Notification Management

    /// Gets all pending (scheduled but not delivered) notifications
    /// - Returns: Array of pending notifications
    func getPendingNotifications() async -> [ScheduledNotification]

    /// Gets all delivered notifications in the notification center
    /// - Returns: Array of delivered notifications
    func getDeliveredNotifications() async -> [ScheduledNotification]

    /// Cancels a specific notification
    /// - Parameter identifier: The identifier of the notification to cancel
    func cancelNotification(identifier: String) async

    /// Cancels notifications of a specific type
    /// - Parameter type: The type of notifications to cancel
    func cancelNotifications(ofType type: NotificationType) async

    /// Cancels all notifications
    func cancelAllNotifications() async

    /// Removes delivered notifications from the notification center
    /// - Parameter identifiers: Array of notification identifiers to remove
    func removeDeliveredNotifications(identifiers: [String]) async

    /// Removes all delivered notifications from the notification center
    func removeAllDeliveredNotifications() async

    // MARK: - Settings and Preferences

    /// Gets the current notification settings
    /// - Returns: Current notification preferences
    func getNotificationSettings() async -> NotificationSettings

    /// Updates notification settings
    /// - Parameter settings: New notification settings to apply
    func updateNotificationSettings(_ settings: NotificationSettings) async

    /// Enables or disables notifications for a specific type
    /// - Parameters:
    ///   - type: The notification type to configure
    ///   - enabled: Whether notifications of this type should be enabled
    func setNotificationEnabled(for type: NotificationType, enabled: Bool) async

    /// Sets the default sound for notifications
    /// - Parameter sound: The sound to use for notifications
    func setDefaultNotificationSound(_ sound: UNNotificationSound?) async

    /// Gets the default sound for notifications
    /// - Returns: The current default notification sound
    func getDefaultNotificationSound() async -> UNNotificationSound?

    // MARK: - Background Notifications

    /// Handles background notification delivery
    /// - Parameter userInfo: Notification payload
    /// - Returns: Background task result
    func handleBackgroundNotification(userInfo: [AnyHashable: Any]) async -> BackgroundNotificationResult

    /// Configures the app to handle background notifications
    /// - Note: Called during app initialization
    func configureBackgroundNotifications() async

    /// Schedules background notifications for when app is not active
    /// - Parameter notifications: Array of notifications to schedule
    func scheduleBackgroundNotifications(_ notifications: [NotificationConfig]) async throws

    // MARK: - Analytics and Statistics

    /// Gets notification delivery and engagement statistics
    /// - Returns: Statistics about notification performance
    func getNotificationStatistics() async -> NotificationStatistics

    /// Records a notification interaction (tap, dismiss, etc.)
    /// - Parameters:
    ///   - identifier: The notification identifier
    ///   - action: The action taken by the user
    func recordNotificationInteraction(identifier: String, action: NotificationAction) async

    /// Gets notification performance for a specific type
    /// - Parameter type: The notification type to analyze
    /// - Returns: Performance metrics for the specified type
    func getNotificationPerformance(for type: NotificationType) async -> NotificationPerformanceMetrics

    /// Optimizes notification delivery based on user behavior
    /// - Note: Adjusts timing and content based on user engagement patterns
    func optimizeNotificationDelivery() async

    // MARK: - Testing and Development

    /// Sends a test notification for debugging
    /// - Parameter type: Type of test notification to send
    /// - Throws: `NotificationServiceError.permissionDenied` if notifications are disabled
    func sendTestNotification(type: NotificationType) async throws

    /// Validates notification configuration
    /// - Parameter config: Configuration to validate
    /// - Returns: Array of validation errors, empty if valid
    func validateNotificationConfig(_ config: NotificationConfig) -> [String]
}

// MARK: - Supporting Types for Additional Functionality

/// Result of background notification handling
public enum BackgroundNotificationResult {
    case newData
    case noData
    case failed

    public var description: String {
        switch self {
        case .newData: return "New Data"
        case .noData: return "No Data"
        case .failed: return "Failed"
        }
    }
}

/// Actions users can take on notifications
public enum NotificationAction: String, CaseIterable {
    case tap = "tap"
    case dismiss = "dismiss"
    case ignore = "ignore"
    case action1 = "action1"  // Custom action buttons
    case action2 = "action2"

    public var description: String {
        switch self {
        case .tap: return "Tapped"
        case .dismiss: return "Dismissed"
        case .ignore: return "Ignored"
        case .action1: return "Action 1"
        case .action2: return "Action 2"
        }
    }
}

/// Performance metrics for notifications
public struct NotificationPerformanceMetrics {
    public let notificationType: NotificationType
    public let totalSent: Int
    public let totalDelivered: Int
    public let totalTapped: Int
    public let averageDeliveryTime: TimeInterval
    public let bestDeliveryTime: TimeInterval?
    public let engagementRate: Double

    public init(notificationType: NotificationType, totalSent: Int, totalDelivered: Int, totalTapped: Int, averageDeliveryTime: TimeInterval, bestDeliveryTime: TimeInterval?, engagementRate: Double) {
        self.notificationType = notificationType
        self.totalSent = totalSent
        self.totalDelivered = totalDelivered
        self.totalTapped = totalTapped
        self.averageDeliveryTime = averageDeliveryTime
        self.bestDeliveryTime = bestDeliveryTime
        self.engagementRate = engagementRate
    }
}

// MARK: - Test Helper Protocol

/// Protocol for test implementations and mocking
/// Enables dependency injection and unit testing of components that depend on NotificationService
public protocol MockableNotificationService: NotificationService {
    /// Allows tests to simulate authorization status
    func setMockAuthorizationStatus(_ status: NotificationAuthorizationStatus)

    /// Allows tests to simulate errors
    func setMockError(_ error: NotificationServiceError?)

    /// Allows tests to inject mock scheduled notifications
    func setMockScheduledNotifications(_ notifications: [ScheduledNotification])

    /// Allows tests to control notification settings
    func setMockSettings(_ settings: NotificationSettings)

    /// Allows tests to simulate notification interactions
    func simulateNotificationTap(identifier: String)

    /// Allows tests to control statistics
    func setMockStatistics(_ statistics: NotificationStatistics)
}