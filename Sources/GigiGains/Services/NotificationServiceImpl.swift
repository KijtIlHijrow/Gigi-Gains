//
//  NotificationServiceImpl.swift
//  Gigi Gains
//
//  Implementation of NotificationService protocol providing comprehensive
//  local notification management for rest timers and workout reminders.
//
//  Created: 2025-09-28
//

import Foundation
import Combine
import UserNotifications
import UIKit

public class NotificationServiceImpl: NSObject, NotificationService {

    // MARK: - Properties

    private let center = UNUserNotificationCenter.current()

    private let authorizationStatusSubject = CurrentValueSubject<NotificationAuthorizationStatus, Never>(.notDetermined)
    private let notificationSettingsSubject = CurrentValueSubject<NotificationSettings, Never>(NotificationSettings())
    private let notificationTapSubject = PassthroughSubject<ScheduledNotification, Never>()

    private var notificationSettings = NotificationSettings()
    private var notificationStatistics = NotificationStatistics(
        totalScheduled: 0,
        totalDelivered: 0,
        totalTapped: 0,
        restTimerNotifications: 0,
        workoutReminders: 0,
        achievementNotifications: 0,
        lastDeliveredDate: nil,
        averageResponseTime: nil
    )
    private var defaultNotificationSound: UNNotificationSound? = .default
    private var notificationInteractions: [String: [NotificationAction]] = [:]

    // MARK: - Publishers

    public var authorizationStatusPublisher: AnyPublisher<NotificationAuthorizationStatus, Never> {
        authorizationStatusSubject.eraseToAnyPublisher()
    }

    public var notificationSettingsPublisher: AnyPublisher<NotificationSettings, Never> {
        notificationSettingsSubject.eraseToAnyPublisher()
    }

    public var notificationTapPublisher: AnyPublisher<ScheduledNotification, Never> {
        notificationTapSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    public override init() {
        super.init()

        center.delegate = self

        Task {
            await setupNotificationCategories()
            let status = await getAuthorizationStatus()
            authorizationStatusSubject.send(status)
        }
    }

    // MARK: - Permission Management

    public func getAuthorizationStatus() async -> NotificationAuthorizationStatus {
        let settings = await center.notificationSettings()

        let status: NotificationAuthorizationStatus
        switch settings.authorizationStatus {
        case .notDetermined:
            status = .notDetermined
        case .denied:
            status = .denied
        case .authorized:
            status = .authorized
        case .provisional:
            status = .provisional
        case .ephemeral:
            status = .ephemeral
        @unknown default:
            status = .denied
        }

        authorizationStatusSubject.send(status)
        return status
    }

    public func requestPermissions() async throws -> NotificationAuthorizationStatus {
        return try await withCheckedThrowingContinuation { continuation in
            center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                Task {
                    if let error = error {
                        continuation.resume(throwing: NotificationServiceError.systemError(error))
                    } else {
                        let status = await self.getAuthorizationStatus()
                        continuation.resume(returning: status)
                    }
                }
            }
        }
    }

    public func checkPermissions(for types: [NotificationType]) async -> [NotificationType: Bool] {
        let status = await getAuthorizationStatus()
        let canDeliver = status.canDeliverNotifications

        var result: [NotificationType: Bool] = [:]
        for type in types {
            result[type] = canDeliver && notificationSettings.isEnabled(for: type)
        }

        return result
    }

    public func openNotificationSettings() async {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            await MainActor.run {
                UIApplication.shared.open(settingsUrl)
            }
        }
    }

    // MARK: - Rest Timer Notifications

    public func scheduleRestTimerNotification(config: RestTimerNotificationConfig) async throws -> String {
        let status = await getAuthorizationStatus()
        guard status.canDeliverNotifications else {
            throw NotificationServiceError.permissionDenied
        }

        guard notificationSettings.restTimerEnabled else {
            throw NotificationServiceError.permissionDenied
        }

        let identifier = "rest_timer_\(UUID().uuidString)"
        let (title, body) = config.notificationContent

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = NotificationType.restTimer.categoryIdentifier
        content.userInfo = [
            "type": NotificationType.restTimer.rawValue,
            "exerciseName": config.exerciseName ?? "",
            "setNumber": config.setNumber ?? 0,
            "timestamp": Date().timeIntervalSince1970
        ]

        if config.playSound && notificationSettings.soundEnabled {
            content.sound = defaultNotificationSound
        }

        if notificationSettings.badgeEnabled {
            content.badge = 1
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: config.duration, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)

            // Update statistics
            notificationStatistics = NotificationStatistics(
                totalScheduled: notificationStatistics.totalScheduled + 1,
                totalDelivered: notificationStatistics.totalDelivered,
                totalTapped: notificationStatistics.totalTapped,
                restTimerNotifications: notificationStatistics.restTimerNotifications + 1,
                workoutReminders: notificationStatistics.workoutReminders,
                achievementNotifications: notificationStatistics.achievementNotifications,
                lastDeliveredDate: notificationStatistics.lastDeliveredDate,
                averageResponseTime: notificationStatistics.averageResponseTime
            )

            return identifier
        } catch {
            throw NotificationServiceError.schedulingFailed(reason: error.localizedDescription)
        }
    }

    public func cancelRestTimerNotification() async {
        let pendingNotifications = await center.pendingNotificationRequests()
        let restTimerIdentifiers = pendingNotifications
            .filter { $0.content.userInfo["type"] as? String == NotificationType.restTimer.rawValue }
            .map { $0.identifier }

        center.removePendingNotificationRequests(withIdentifiers: restTimerIdentifiers)
    }

    public func updateRestTimerNotification(identifier: String, remainingTime: TimeInterval) async throws {
        // Cancel existing notification
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        // Create updated notification
        let content = UNMutableNotificationContent()
        content.title = "Rest Timer"
        content.body = "Time remaining: \(Int(remainingTime)) seconds"
        content.categoryIdentifier = NotificationType.restTimer.categoryIdentifier

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remainingTime, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try await center.add(request)
    }

    public func getCurrentRestTimerNotification() async -> ScheduledNotification? {
        let pendingNotifications = await center.pendingNotificationRequests()

        guard let restTimerRequest = pendingNotifications.first(where: {
            $0.content.userInfo["type"] as? String == NotificationType.restTimer.rawValue
        }) else {
            return nil
        }

        let scheduledDate: Date
        if let trigger = restTimerRequest.trigger as? UNTimeIntervalNotificationTrigger {
            scheduledDate = Date().addingTimeInterval(trigger.timeInterval)
        } else {
            scheduledDate = Date()
        }

        return ScheduledNotification(
            identifier: restTimerRequest.identifier,
            type: .restTimer,
            title: restTimerRequest.content.title,
            body: restTimerRequest.content.body,
            scheduledDate: scheduledDate,
            delivered: false,
            userInfo: restTimerRequest.content.userInfo
        )
    }

    // MARK: - Workout Reminders

    public func scheduleWorkoutReminder(title: String, message: String, scheduledDate: Date, repeatInterval: DateComponents?) async throws -> String {
        let status = await getAuthorizationStatus()
        guard status.canDeliverNotifications else {
            throw NotificationServiceError.permissionDenied
        }

        guard notificationSettings.workoutRemindersEnabled else {
            throw NotificationServiceError.permissionDenied
        }

        let identifier = "workout_reminder_\(UUID().uuidString)"

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.categoryIdentifier = NotificationType.workoutReminder.categoryIdentifier
        content.userInfo = [
            "type": NotificationType.workoutReminder.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ]

        if notificationSettings.soundEnabled {
            content.sound = defaultNotificationSound
        }

        if notificationSettings.badgeEnabled {
            content.badge = 1
        }

        let trigger: UNNotificationTrigger
        if let repeatInterval = repeatInterval {
            let dateComponents = Calendar.current.dateComponents([.hour, .minute], from: scheduledDate)
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        } else {
            trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: scheduledDate), repeats: false)
        }

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try await center.add(request)

        notificationStatistics = NotificationStatistics(
            totalScheduled: notificationStatistics.totalScheduled + 1,
            totalDelivered: notificationStatistics.totalDelivered,
            totalTapped: notificationStatistics.totalTapped,
            restTimerNotifications: notificationStatistics.restTimerNotifications,
            workoutReminders: notificationStatistics.workoutReminders + 1,
            achievementNotifications: notificationStatistics.achievementNotifications,
            lastDeliveredDate: notificationStatistics.lastDeliveredDate,
            averageResponseTime: notificationStatistics.averageResponseTime
        )

        return identifier
    }

    public func cancelWorkoutReminder(identifier: String) async {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    public func cancelAllWorkoutReminders() async {
        let pendingNotifications = await center.pendingNotificationRequests()
        let reminderIdentifiers = pendingNotifications
            .filter { $0.content.userInfo["type"] as? String == NotificationType.workoutReminder.rawValue }
            .map { $0.identifier }

        center.removePendingNotificationRequests(withIdentifiers: reminderIdentifiers)
    }

    public func getScheduledWorkoutReminders() async -> [ScheduledNotification] {
        let pendingNotifications = await center.pendingNotificationRequests()

        return pendingNotifications
            .filter { $0.content.userInfo["type"] as? String == NotificationType.workoutReminder.rawValue }
            .map { request in
                let scheduledDate: Date
                if let trigger = request.trigger as? UNCalendarNotificationTrigger,
                   let nextDate = trigger.nextTriggerDate() {
                    scheduledDate = nextDate
                } else {
                    scheduledDate = Date()
                }

                return ScheduledNotification(
                    identifier: request.identifier,
                    type: .workoutReminder,
                    title: request.content.title,
                    body: request.content.body,
                    scheduledDate: scheduledDate,
                    delivered: false,
                    userInfo: request.content.userInfo
                )
            }
    }

    public func updateWorkoutReminder(identifier: String, title: String, message: String, scheduledDate: Date) async throws {
        // Cancel existing reminder
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        // Schedule updated reminder
        _ = try await scheduleWorkoutReminder(title: title, message: message, scheduledDate: scheduledDate, repeatInterval: nil)
    }

    // MARK: - Achievement and Progress Notifications

    public func sendPersonalRecordNotification(exerciseName: String, recordType: String, value: String, improvement: String?) async throws {
        let status = await getAuthorizationStatus()
        guard status.canDeliverNotifications && notificationSettings.personalRecordsEnabled else {
            throw NotificationServiceError.permissionDenied
        }

        let title = "New Personal Record! 🎉"
        let body = improvement != nil
            ? "\(exerciseName) \(recordType): \(value) (improved by \(improvement!))"
            : "\(exerciseName) \(recordType): \(value)"

        let config = NotificationConfig(
            identifier: "pr_\(UUID().uuidString)",
            type: .personalRecord,
            title: title,
            body: body,
            userInfo: [
                "exerciseName": exerciseName,
                "recordType": recordType,
                "value": value,
                "improvement": improvement ?? ""
            ]
        )

        _ = try await sendSystemNotification(config: config)
    }

    public func sendGoalAchievementNotification(title: String, message: String, goalName: String) async throws {
        let status = await getAuthorizationStatus()
        guard status.canDeliverNotifications && notificationSettings.goalAchievementsEnabled else {
            throw NotificationServiceError.permissionDenied
        }

        let config = NotificationConfig(
            identifier: "goal_\(UUID().uuidString)",
            type: .goalAchievement,
            title: title,
            body: message,
            userInfo: ["goalName": goalName]
        )

        _ = try await sendSystemNotification(config: config)
    }

    public func sendWeeklyProgressNotification(weeklyStats: [String: Any], highlights: [String]) async throws {
        let status = await getAuthorizationStatus()
        guard status.canDeliverNotifications && notificationSettings.weeklyProgressEnabled else {
            throw NotificationServiceError.permissionDenied
        }

        let title = "Weekly Progress Report"
        let body = highlights.isEmpty ? "Check out your weekly progress!" : highlights.joined(separator: " • ")

        let config = NotificationConfig(
            identifier: "weekly_\(UUID().uuidString)",
            type: .weeklyProgress,
            title: title,
            body: body,
            userInfo: weeklyStats
        )

        _ = try await sendSystemNotification(config: config)
    }

    public func sendMilestoneNotification(milestone: String, category: String) async throws {
        let status = await getAuthorizationStatus()
        guard status.canDeliverNotifications && notificationSettings.goalAchievementsEnabled else {
            throw NotificationServiceError.permissionDenied
        }

        let config = NotificationConfig(
            identifier: "milestone_\(UUID().uuidString)",
            type: .goalAchievement,
            title: "Milestone Achieved! 🏆",
            body: "\(milestone) (\(category))",
            userInfo: [
                "milestone": milestone,
                "category": category
            ]
        )

        _ = try await sendSystemNotification(config: config)
    }

    // MARK: - System and Error Notifications

    public func sendSyncErrorNotification(errorType: String, message: String, actionRequired: Bool) async throws {
        let status = await getAuthorizationStatus()
        guard status.canDeliverNotifications && notificationSettings.syncAlertsEnabled else {
            throw NotificationServiceError.permissionDenied
        }

        let title = actionRequired ? "Sync Error - Action Required" : "Sync Error"

        let config = NotificationConfig(
            identifier: "sync_error_\(UUID().uuidString)",
            type: .syncAlert,
            title: title,
            body: message,
            userInfo: [
                "errorType": errorType,
                "actionRequired": actionRequired
            ]
        )

        _ = try await sendSystemNotification(config: config)
    }

    public func sendHealthKitErrorNotification(errorType: String, message: String) async throws {
        let status = await getAuthorizationStatus()
        guard status.canDeliverNotifications && notificationSettings.healthKitErrorsEnabled else {
            throw NotificationServiceError.permissionDenied
        }

        let config = NotificationConfig(
            identifier: "healthkit_error_\(UUID().uuidString)",
            type: .healthKitError,
            title: "HealthKit Error",
            body: message,
            userInfo: ["errorType": errorType]
        )

        _ = try await sendSystemNotification(config: config)
    }

    public func sendSystemNotification(config: NotificationConfig) async throws -> String {
        let status = await getAuthorizationStatus()
        guard status.canDeliverNotifications else {
            throw NotificationServiceError.permissionDenied
        }

        guard notificationSettings.isEnabled(for: config.type) else {
            throw NotificationServiceError.permissionDenied
        }

        let content = UNMutableNotificationContent()
        content.title = config.title
        content.body = config.body
        content.categoryIdentifier = config.categoryIdentifier ?? config.type.categoryIdentifier
        content.userInfo = config.userInfo.merging(["type": config.type.rawValue]) { _, new in new }

        if let subtitle = config.subtitle {
            content.subtitle = subtitle
        }

        if notificationSettings.soundEnabled {
            content.sound = config.sound ?? defaultNotificationSound
        }

        if notificationSettings.badgeEnabled, let badge = config.badge {
            content.badge = NSNumber(value: badge)
        }

        if let threadIdentifier = config.threadIdentifier {
            content.threadIdentifier = threadIdentifier
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: config.identifier, content: content, trigger: trigger)

        try await center.add(request)

        notificationStatistics = NotificationStatistics(
            totalScheduled: notificationStatistics.totalScheduled + 1,
            totalDelivered: notificationStatistics.totalDelivered,
            totalTapped: notificationStatistics.totalTapped,
            restTimerNotifications: notificationStatistics.restTimerNotifications,
            workoutReminders: notificationStatistics.workoutReminders,
            achievementNotifications: notificationStatistics.achievementNotifications + (config.type == .goalAchievement || config.type == .personalRecord ? 1 : 0),
            lastDeliveredDate: notificationStatistics.lastDeliveredDate,
            averageResponseTime: notificationStatistics.averageResponseTime
        )

        return config.identifier
    }

    // MARK: - Notification Management

    public func getPendingNotifications() async -> [ScheduledNotification] {
        let pendingNotifications = await center.pendingNotificationRequests()

        return pendingNotifications.compactMap { request in
            guard let typeString = request.content.userInfo["type"] as? String,
                  let type = NotificationType(rawValue: typeString) else {
                return nil
            }

            let scheduledDate: Date
            if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                scheduledDate = Date().addingTimeInterval(trigger.timeInterval)
            } else if let trigger = request.trigger as? UNCalendarNotificationTrigger,
                      let nextDate = trigger.nextTriggerDate() {
                scheduledDate = nextDate
            } else {
                scheduledDate = Date()
            }

            return ScheduledNotification(
                identifier: request.identifier,
                type: type,
                title: request.content.title,
                body: request.content.body,
                scheduledDate: scheduledDate,
                delivered: false,
                userInfo: request.content.userInfo
            )
        }
    }

    public func getDeliveredNotifications() async -> [ScheduledNotification] {
        let deliveredNotifications = await center.deliveredNotifications()

        return deliveredNotifications.compactMap { notification in
            guard let typeString = notification.request.content.userInfo["type"] as? String,
                  let type = NotificationType(rawValue: typeString) else {
                return nil
            }

            return ScheduledNotification(
                identifier: notification.request.identifier,
                type: type,
                title: notification.request.content.title,
                body: notification.request.content.body,
                scheduledDate: notification.date,
                delivered: true,
                userInfo: notification.request.content.userInfo
            )
        }
    }

    public func cancelNotification(identifier: String) async {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    public func cancelNotifications(ofType type: NotificationType) async {
        let pendingNotifications = await center.pendingNotificationRequests()
        let typeIdentifiers = pendingNotifications
            .filter { $0.content.userInfo["type"] as? String == type.rawValue }
            .map { $0.identifier }

        center.removePendingNotificationRequests(withIdentifiers: typeIdentifiers)
    }

    public func cancelAllNotifications() async {
        center.removeAllPendingNotificationRequests()
    }

    public func removeDeliveredNotifications(identifiers: [String]) async {
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    public func removeAllDeliveredNotifications() async {
        center.removeAllDeliveredNotifications()
    }

    // MARK: - Settings and Preferences

    public func getNotificationSettings() async -> NotificationSettings {
        return notificationSettings
    }

    public func updateNotificationSettings(_ settings: NotificationSettings) async {
        notificationSettings = settings
        notificationSettingsSubject.send(settings)
    }

    public func setNotificationEnabled(for type: NotificationType, enabled: Bool) async {
        let newSettings = NotificationSettings(
            restTimerEnabled: type == .restTimer ? enabled : notificationSettings.restTimerEnabled,
            workoutRemindersEnabled: type == .workoutReminder ? enabled : notificationSettings.workoutRemindersEnabled,
            goalAchievementsEnabled: type == .goalAchievement ? enabled : notificationSettings.goalAchievementsEnabled,
            personalRecordsEnabled: type == .personalRecord ? enabled : notificationSettings.personalRecordsEnabled,
            weeklyProgressEnabled: type == .weeklyProgress ? enabled : notificationSettings.weeklyProgressEnabled,
            syncAlertsEnabled: type == .syncAlert ? enabled : notificationSettings.syncAlertsEnabled,
            healthKitErrorsEnabled: type == .healthKitError ? enabled : notificationSettings.healthKitErrorsEnabled,
            soundEnabled: notificationSettings.soundEnabled,
            badgeEnabled: notificationSettings.badgeEnabled,
            lockScreenEnabled: notificationSettings.lockScreenEnabled,
            notificationCenterEnabled: notificationSettings.notificationCenterEnabled,
            bannerEnabled: notificationSettings.bannerEnabled
        )

        await updateNotificationSettings(newSettings)
    }

    public func setDefaultNotificationSound(_ sound: UNNotificationSound?) async {
        defaultNotificationSound = sound
    }

    public func getDefaultNotificationSound() async -> UNNotificationSound? {
        return defaultNotificationSound
    }

    // MARK: - Background Notifications

    public func handleBackgroundNotification(userInfo: [AnyHashable: Any]) async -> BackgroundNotificationResult {
        // Process background notification
        // In a real implementation, this would handle background data updates
        return .newData
    }

    public func configureBackgroundNotifications() async {
        // Configure background notification handling
        await setupNotificationCategories()
    }

    public func scheduleBackgroundNotifications(_ notifications: [NotificationConfig]) async throws {
        for config in notifications {
            _ = try await sendSystemNotification(config: config)
        }
    }

    // MARK: - Analytics and Statistics

    public func getNotificationStatistics() async -> NotificationStatistics {
        return notificationStatistics
    }

    public func recordNotificationInteraction(identifier: String, action: NotificationAction) async {
        if notificationInteractions[identifier] == nil {
            notificationInteractions[identifier] = []
        }
        notificationInteractions[identifier]?.append(action)

        if action == .tap {
            notificationStatistics = NotificationStatistics(
                totalScheduled: notificationStatistics.totalScheduled,
                totalDelivered: notificationStatistics.totalDelivered,
                totalTapped: notificationStatistics.totalTapped + 1,
                restTimerNotifications: notificationStatistics.restTimerNotifications,
                workoutReminders: notificationStatistics.workoutReminders,
                achievementNotifications: notificationStatistics.achievementNotifications,
                lastDeliveredDate: notificationStatistics.lastDeliveredDate,
                averageResponseTime: notificationStatistics.averageResponseTime
            )
        }
    }

    public func getNotificationPerformance(for type: NotificationType) async -> NotificationPerformanceMetrics {
        let typeInteractions = notificationInteractions.filter { _, actions in
            actions.contains(.tap)
        }

        return NotificationPerformanceMetrics(
            notificationType: type,
            totalSent: 0, // Would be tracked in real implementation
            totalDelivered: 0, // Would be tracked in real implementation
            totalTapped: typeInteractions.count,
            averageDeliveryTime: 1.0, // Would be calculated in real implementation
            bestDeliveryTime: 0.5, // Would be calculated in real implementation
            engagementRate: 0.8 // Would be calculated in real implementation
        )
    }

    public func optimizeNotificationDelivery() async {
        // In a real implementation, this would analyze user behavior and optimize delivery timing
    }

    // MARK: - Testing and Development

    public func sendTestNotification(type: NotificationType) async throws {
        let config = NotificationConfig(
            identifier: "test_\(UUID().uuidString)",
            type: type,
            title: "Test Notification",
            body: "This is a test notification for \(type.description)",
            userInfo: ["isTest": true]
        )

        _ = try await sendSystemNotification(config: config)
    }

    public func validateNotificationConfig(_ config: NotificationConfig) -> [String] {
        var errors: [String] = []

        if config.title.isEmpty {
            errors.append("Title cannot be empty")
        }

        if config.body.isEmpty {
            errors.append("Body cannot be empty")
        }

        if config.identifier.isEmpty {
            errors.append("Identifier cannot be empty")
        }

        return errors
    }

    // MARK: - Private Helper Methods

    private func setupNotificationCategories() async {
        let categories = NotificationType.allCases.map { type in
            UNNotificationCategory(
                identifier: type.categoryIdentifier,
                actions: [],
                intentIdentifiers: [],
                options: []
            )
        }

        center.setNotificationCategories(Set(categories))
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationServiceImpl: UNUserNotificationCenterDelegate {

    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let notification = response.notification

        guard let typeString = notification.request.content.userInfo["type"] as? String,
              let type = NotificationType(rawValue: typeString) else {
            completionHandler()
            return
        }

        let scheduledNotification = ScheduledNotification(
            identifier: notification.request.identifier,
            type: type,
            title: notification.request.content.title,
            body: notification.request.content.body,
            scheduledDate: notification.date,
            delivered: true,
            userInfo: notification.request.content.userInfo
        )

        // Record interaction
        Task {
            await recordNotificationInteraction(identifier: notification.request.identifier, action: .tap)
        }

        // Publish notification tap
        notificationTapSubject.send(scheduledNotification)

        completionHandler()
    }
}