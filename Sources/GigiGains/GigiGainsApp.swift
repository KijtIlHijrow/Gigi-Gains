//
//  GigiGainsApp.swift
//  Gigi Gains
//
//  Main app entry point with Core Data stack and dependency injection.
//  Configures the app lifecycle, data persistence, and service container.
//
//  Created: 2025-09-28
//

import SwiftUI
import CoreData
import CloudKit
import UserNotifications

@main
struct GigiGainsApp: App {
    @StateObject private var dependencyContainer = DependencyContainer()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dependencyContainer)
                .onAppear {
                    setupApp()
                }
                .onChange(of: scenePhase) { phase in
                    handleScenePhaseChange(phase)
                }
        }
    }

    private func setupApp() {
        // Configure Core Data stack
        configureCoreData()

        // Initialize services
        initializeServices()

        // Configure notifications
        configureNotifications()

        // Setup HealthKit if available
        setupHealthKit()

        // Configure CloudKit sync
        configureCloudSync()

        // Request initial permissions
        requestInitialPermissions()
    }

    private func configureCoreData() {
        // Core Data stack is configured in DependencyContainer
        print("Core Data stack initialized")
    }

    private func initializeServices() {
        // Services are initialized lazily in DependencyContainer
        print("Services initialized")
    }

    private func configureNotifications() {
        Task {
            await dependencyContainer.notificationService.configureBackgroundNotifications()
        }
    }

    private func setupHealthKit() {
        guard dependencyContainer.healthKitService.isHealthKitAvailable else {
            print("HealthKit not available on this device")
            return
        }

        Task {
            do {
                let status = try await dependencyContainer.healthKitService.requestPermissions()
                print("HealthKit permissions: \(status)")
            } catch {
                print("HealthKit setup failed: \(error)")
            }
        }
    }

    private func configureCloudSync() {
        Task {
            let isSignedIn = await dependencyContainer.cloudSyncService.isSignedInToiCloud()
            if isSignedIn {
                await dependencyContainer.cloudSyncService.startAutoSync()
                print("CloudKit sync started")
            } else {
                print("iCloud account not available")
            }
        }
    }

    private func requestInitialPermissions() {
        Task {
            do {
                let notificationStatus = try await dependencyContainer.notificationService.requestPermissions()
                print("Notification permissions: \(notificationStatus)")
            } catch {
                print("Notification permission request failed: \(error)")
            }
        }
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            print("App became active")
            handleAppDidBecomeActive()

        case .inactive:
            print("App became inactive")
            handleAppWillResignActive()

        case .background:
            print("App entered background")
            handleAppDidEnterBackground()

        @unknown default:
            break
        }
    }

    private func handleAppDidBecomeActive() {
        // Refresh data when app becomes active
        Task {
            // Check for CloudKit changes
            if await dependencyContainer.cloudSyncService.isSignedInToiCloud() {
                try? await dependencyContainer.cloudSyncService.performManualSync()
            }

            // Update HealthKit authorization status
            let _ = await dependencyContainer.healthKitService.getAuthorizationStatus()
        }
    }

    private func handleAppWillResignActive() {
        // Save any pending changes
        dependencyContainer.saveContext()
    }

    private func handleAppDidEnterBackground() {
        // Save context and schedule background tasks
        dependencyContainer.saveContext()

        Task {
            // Schedule background sync
            await dependencyContainer.cloudSyncService.scheduleBackgroundSync()

            // Schedule background notifications if needed
            await dependencyContainer.notificationService.scheduleBackgroundNotifications([])
        }
    }
}

// MARK: - Core Data Error Handling

extension GigiGainsApp {
    private func handleCoreDataError(_ error: Error) {
        // Log the error
        print("Core Data error: \(error)")

        // In a production app, you might want to:
        // 1. Show user-friendly error messages
        // 2. Send crash reports
        // 3. Attempt data recovery
        // 4. Gracefully degrade functionality

        #if DEBUG
        // In debug builds, crash to help identify issues early
        fatalError("Core Data error: \(error)")
        #endif
    }
}

// MARK: - Notification Handling

extension GigiGainsApp {
    private func handleNotificationTap(_ notification: UNNotification) {
        let userInfo = notification.request.content.userInfo

        guard let notificationType = userInfo["type"] as? String else {
            return
        }

        switch notificationType {
        case "restTimer":
            // Navigate to workout session if active
            break

        case "workoutReminder":
            // Navigate to workout tab
            break

        case "goalAchievement", "personalRecord":
            // Navigate to progress tab
            break

        default:
            break
        }
    }
}

// MARK: - App Configuration

extension GigiGainsApp {
    private var isRunningTests: Bool {
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private var isRunningPreviews: Bool {
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private var shouldSkipSetup: Bool {
        return isRunningTests || isRunningPreviews
    }
}