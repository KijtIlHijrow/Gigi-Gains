//
//  CloudSyncService.swift
//  Gigi Gains - Internal API Contract
//
//  Defines the interface for iCloud synchronization using NSPersistentCloudKitContainer,
//  including sync status monitoring, conflict resolution, and data integrity management.
//
//  Created: 2025-09-28
//

import Foundation
import Combine
import CoreData
import CloudKit

// MARK: - Supporting Types

/// Current sync status with iCloud
public enum CloudSyncStatus {
    case notStarted
    case syncing
    case upToDate
    case error(CloudSyncError)
    case disabled
    case accountNotAvailable

    public var isActive: Bool {
        switch self {
        case .syncing:
            return true
        case .notStarted, .upToDate, .error, .disabled, .accountNotAvailable:
            return false
        }
    }

    public var description: String {
        switch self {
        case .notStarted: return "Not Started"
        case .syncing: return "Syncing"
        case .upToDate: return "Up to Date"
        case .error(let error): return "Error: \(error.localizedDescription)"
        case .disabled: return "Disabled"
        case .accountNotAvailable: return "iCloud Account Not Available"
        }
    }
}

/// CloudKit account status
public enum CloudAccountStatus {
    case available
    case noAccount
    case restricted
    case couldNotDetermine
    case temporarilyUnavailable

    public var description: String {
        switch self {
        case .available: return "Available"
        case .noAccount: return "No iCloud Account"
        case .restricted: return "Restricted"
        case .couldNotDetermine: return "Could Not Determine"
        case .temporarilyUnavailable: return "Temporarily Unavailable"
        }
    }

    /// Whether sync operations can be performed
    public var canSync: Bool {
        return self == .available
    }
}

/// Errors that can occur during cloud synchronization
public enum CloudSyncError: Error, LocalizedError {
    case accountNotAvailable
    case quotaExceeded
    case networkUnavailable
    case permissionFailure
    case conflictResolutionFailed(recordCount: Int)
    case dataCorruption(details: String)
    case unknownError(Error)

    public var errorDescription: String? {
        switch self {
        case .accountNotAvailable:
            return "iCloud account is not available. Please sign in to iCloud in Settings."
        case .quotaExceeded:
            return "iCloud storage quota exceeded. Please free up space or upgrade your iCloud plan."
        case .networkUnavailable:
            return "Network connection is not available. Sync will resume when connection is restored."
        case .permissionFailure:
            return "Permission denied for iCloud access. Please check iCloud settings."
        case .conflictResolutionFailed(let recordCount):
            return "Failed to resolve conflicts for \(recordCount) record(s). Manual intervention may be required."
        case .dataCorruption(let details):
            return "Data corruption detected: \(details)"
        case .unknownError(let error):
            return "Unknown sync error: \(error.localizedDescription)"
        }
    }

    /// Whether this error is recoverable through retry
    public var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .unknownError:
            return true
        case .accountNotAvailable, .quotaExceeded, .permissionFailure, .conflictResolutionFailed, .dataCorruption:
            return false
        }
    }
}

/// Information about a sync conflict that requires resolution
public struct SyncConflict {
    public let recordId: String
    public let recordType: String
    public let localVersion: [String: Any]
    public let remoteVersion: [String: Any]
    public let conflictDate: Date
    public let affectedFields: [String]

    public init(recordId: String, recordType: String, localVersion: [String: Any], remoteVersion: [String: Any], conflictDate: Date, affectedFields: [String]) {
        self.recordId = recordId
        self.recordType = recordType
        self.localVersion = localVersion
        self.remoteVersion = remoteVersion
        self.conflictDate = conflictDate
        self.affectedFields = affectedFields
    }
}

/// Resolution strategy for sync conflicts
public enum ConflictResolutionStrategy {
    case useLocal           // Keep local version
    case useRemote          // Use remote version
    case merge              // Attempt to merge changes
    case manual(choice: [String: Any])  // User-provided resolution

    public var description: String {
        switch self {
        case .useLocal: return "Use Local Version"
        case .useRemote: return "Use Remote Version"
        case .merge: return "Merge Changes"
        case .manual: return "Manual Resolution"
        }
    }
}

/// Statistics about sync operations and data
public struct SyncStatistics {
    /// Last successful sync timestamp
    public let lastSuccessfulSync: Date?

    /// Last sync attempt timestamp
    public let lastSyncAttempt: Date?

    /// Number of records uploaded in last sync
    public let recordsUploaded: Int

    /// Number of records downloaded in last sync
    public let recordsDownloaded: Int

    /// Number of conflicts encountered
    public let conflictsEncountered: Int

    /// Number of conflicts resolved automatically
    public let conflictsResolved: Int

    /// Number of sync errors in last 24 hours
    public let recentErrorCount: Int

    /// Total data size in CloudKit (bytes)
    public let totalCloudKitDataSize: Int64

    /// iCloud storage quota usage (bytes)
    public let quotaUsage: Int64

    /// iCloud storage quota limit (bytes)
    public let quotaLimit: Int64

    /// Whether automatic sync is enabled
    public let autoSyncEnabled: Bool

    /// Current sync frequency in seconds
    public let syncFrequency: TimeInterval

    public init(lastSuccessfulSync: Date?, lastSyncAttempt: Date?, recordsUploaded: Int, recordsDownloaded: Int, conflictsEncountered: Int, conflictsResolved: Int, recentErrorCount: Int, totalCloudKitDataSize: Int64, quotaUsage: Int64, quotaLimit: Int64, autoSyncEnabled: Bool, syncFrequency: TimeInterval) {
        self.lastSuccessfulSync = lastSuccessfulSync
        self.lastSyncAttempt = lastSyncAttempt
        self.recordsUploaded = recordsUploaded
        self.recordsDownloaded = recordsDownloaded
        self.conflictsEncountered = conflictsEncountered
        self.conflictsResolved = conflictsResolved
        self.recentErrorCount = recentErrorCount
        self.totalCloudKitDataSize = totalCloudKitDataSize
        self.quotaUsage = quotaUsage
        self.quotaLimit = quotaLimit
        self.autoSyncEnabled = autoSyncEnabled
        self.syncFrequency = syncFrequency
    }

    /// Percentage of quota used (0.0 to 1.0)
    public var quotaUsagePercent: Double {
        guard quotaLimit > 0 else { return 0.0 }
        return Double(quotaUsage) / Double(quotaLimit)
    }
}

/// Configuration for sync behavior
public struct SyncConfiguration {
    /// Whether automatic sync is enabled
    public let autoSyncEnabled: Bool

    /// Sync frequency in seconds (minimum 60 seconds)
    public let syncFrequency: TimeInterval

    /// Whether to sync on app launch
    public let syncOnLaunch: Bool

    /// Whether to sync when app enters background
    public let syncOnBackground: Bool

    /// Whether to sync when network becomes available
    public let syncOnNetworkReconnect: Bool

    /// Maximum number of retry attempts for failed syncs
    public let maxRetryAttempts: Int

    /// Retry delay in seconds (exponential backoff)
    public let retryDelay: TimeInterval

    /// Whether to automatically resolve simple conflicts
    public let autoResolveConflicts: Bool

    public init(autoSyncEnabled: Bool = true, syncFrequency: TimeInterval = 300, syncOnLaunch: Bool = true, syncOnBackground: Bool = true, syncOnNetworkReconnect: Bool = true, maxRetryAttempts: Int = 3, retryDelay: TimeInterval = 30, autoResolveConflicts: Bool = true) {
        self.autoSyncEnabled = autoSyncEnabled
        self.syncFrequency = max(60, syncFrequency) // Minimum 1 minute
        self.syncOnLaunch = syncOnLaunch
        self.syncOnBackground = syncOnBackground
        self.syncOnNetworkReconnect = syncOnNetworkReconnect
        self.maxRetryAttempts = maxRetryAttempts
        self.retryDelay = retryDelay
        self.autoResolveConflicts = autoResolveConflicts
    }
}

// MARK: - Main Protocol

/// Service protocol for iCloud synchronization using NSPersistentCloudKitContainer
///
/// This protocol defines the complete interface for iCloud synchronization in the Gigi Gains app.
/// It manages automatic sync with CloudKit through NSPersistentCloudKitContainer, handles conflict
/// resolution, monitors sync status, and provides data integrity guarantees. All operations are
/// designed to work seamlessly with Core Data and respect user privacy.
///
/// Key responsibilities:
/// - Automatic iCloud sync via NSPersistentCloudKitContainer
/// - Sync status monitoring and error handling
/// - Conflict detection and resolution
/// - Account status monitoring and quota management
/// - Background sync scheduling and network handling
/// - Data integrity validation and corruption recovery
/// - User preferences and sync configuration
///
/// ## Usage Example:
/// ```swift
/// let service: CloudSyncService = CloudSyncServiceImpl()
///
/// // Monitor sync status
/// service.syncStatusPublisher
///     .sink { status in
///         updateUI(with: status)
///     }
///     .store(in: &cancellables)
///
/// // Perform manual sync
/// try await service.performManualSync()
///
/// // Handle conflicts
/// let conflicts = try await service.getPendingConflicts()
/// for conflict in conflicts {
///     try await service.resolveConflict(conflict, strategy: .useLocal)
/// }
/// ```
public protocol CloudSyncService: AnyObject {

    // MARK: - Publishers for Reactive Updates

    /// Publishes sync status changes
    /// Emits when sync starts, completes, or encounters errors
    var syncStatusPublisher: AnyPublisher<CloudSyncStatus, Never> { get }

    /// Publishes account status changes
    /// Emits when iCloud account availability changes
    var accountStatusPublisher: AnyPublisher<CloudAccountStatus, Never> { get }

    /// Publishes sync statistics updates
    /// Useful for displaying sync progress and data usage
    var syncStatisticsPublisher: AnyPublisher<SyncStatistics, Never> { get }

    /// Publishes conflict notifications
    /// Emits when sync conflicts are detected that require user intervention
    var conflictNotificationPublisher: AnyPublisher<[SyncConflict], Never> { get }

    // MARK: - Sync Management

    /// Gets the current sync status
    /// - Returns: Current synchronization status
    var currentSyncStatus: CloudSyncStatus { get async }

    /// Gets the current account status
    /// - Returns: Current iCloud account status
    func getAccountStatus() async -> CloudAccountStatus

    /// Performs a manual sync operation
    /// - Returns: Result indicating success or failure with details
    /// - Throws: `CloudSyncError` if sync fails
    /// - Note: This forces an immediate sync regardless of automatic sync settings
    func performManualSync() async throws

    /// Starts automatic synchronization
    /// - Note: Begins background sync according to configuration settings
    func startAutoSync() async

    /// Stops automatic synchronization
    /// - Note: Cancels background sync but allows manual sync operations
    func stopAutoSync() async

    /// Checks if sync is currently active
    /// - Returns: True if a sync operation is in progress
    var isSyncInProgress: Bool { get async }

    /// Forces a complete re-sync of all data
    /// - Note: Use sparingly, typically only for data recovery scenarios
    /// - Throws: `CloudSyncError` if re-sync fails
    func forceCompleteResync() async throws

    // MARK: - Configuration Management

    /// Gets the current sync configuration
    /// - Returns: Current sync settings and behavior configuration
    func getSyncConfiguration() async -> SyncConfiguration

    /// Updates sync configuration
    /// - Parameter configuration: New sync configuration to apply
    /// - Note: Changes take effect immediately for ongoing sync operations
    func updateSyncConfiguration(_ configuration: SyncConfiguration) async

    /// Enables or disables automatic synchronization
    /// - Parameter enabled: Whether automatic sync should be enabled
    func setAutoSyncEnabled(_ enabled: Bool) async

    /// Sets the frequency for automatic sync operations
    /// - Parameter frequency: Sync frequency in seconds (minimum 60 seconds)
    func setSyncFrequency(_ frequency: TimeInterval) async

    // MARK: - Conflict Resolution

    /// Gets all pending sync conflicts that require resolution
    /// - Returns: Array of conflicts waiting for resolution
    func getPendingConflicts() async throws -> [SyncConflict]

    /// Resolves a specific sync conflict
    /// - Parameters:
    ///   - conflict: The conflict to resolve
    ///   - strategy: Resolution strategy to apply
    /// - Throws: `CloudSyncError.conflictResolutionFailed` if resolution fails
    func resolveConflict(_ conflict: SyncConflict, strategy: ConflictResolutionStrategy) async throws

    /// Resolves multiple conflicts with the same strategy
    /// - Parameters:
    ///   - conflicts: Array of conflicts to resolve
    ///   - strategy: Resolution strategy to apply to all conflicts
    /// - Returns: Array of resolution results (true for success, false for failure)
    func resolveConflicts(_ conflicts: [SyncConflict], strategy: ConflictResolutionStrategy) async throws -> [Bool]

    /// Gets suggested resolution strategy for a conflict
    /// - Parameter conflict: The conflict to analyze
    /// - Returns: Recommended resolution strategy based on conflict type and data
    func getSuggestedResolution(for conflict: SyncConflict) async -> ConflictResolutionStrategy

    /// Enables or disables automatic conflict resolution
    /// - Parameter enabled: Whether simple conflicts should be resolved automatically
    func setAutoConflictResolution(_ enabled: Bool) async

    // MARK: - Statistics and Monitoring

    /// Gets comprehensive sync statistics
    /// - Returns: Detailed statistics about sync operations and data usage
    func getSyncStatistics() async -> SyncStatistics

    /// Gets CloudKit quota information
    /// - Returns: Tuple of (used bytes, total bytes, percentage used)
    func getQuotaInformation() async throws -> (used: Int64, total: Int64, percentage: Double)

    /// Gets sync history for a specific time period
    /// - Parameter days: Number of days to look back
    /// - Returns: Array of sync events with timestamps and results
    func getSyncHistory(days: Int) async -> [SyncEvent]

    /// Gets error history for troubleshooting
    /// - Parameter days: Number of days to look back
    /// - Returns: Array of sync errors with details
    func getErrorHistory(days: Int) async -> [CloudSyncError]

    /// Validates data integrity between local and remote
    /// - Returns: Array of validation issues found, empty if all data is consistent
    func validateDataIntegrity() async throws -> [String]

    // MARK: - Network and Connectivity

    /// Checks if network is available for sync operations
    /// - Returns: True if network connection allows CloudKit operations
    var isNetworkAvailable: Bool { get async }

    /// Forces sync when network becomes available
    /// - Note: Automatically called when network connectivity is restored
    func syncOnNetworkReconnect() async

    /// Gets current network status for CloudKit
    /// - Returns: Network reachability status for CloudKit services
    func getNetworkStatus() async -> NetworkStatus

    /// Retries failed sync operations
    /// - Returns: Number of operations successfully retried
    func retryFailedOperations() async throws -> Int

    // MARK: - Background Sync

    /// Schedules background sync tasks
    /// - Note: Called when app enters background to schedule future sync
    func scheduleBackgroundSync() async

    /// Handles background app refresh for sync
    /// - Returns: Background task result indicating completion status
    func performBackgroundSync() async -> BackgroundTaskResult

    /// Cancels all pending background sync tasks
    func cancelBackgroundSync() async

    /// Gets background sync status and permissions
    /// - Returns: Information about background sync capabilities and permissions
    func getBackgroundSyncStatus() async -> BackgroundSyncStatus

    // MARK: - Data Management

    /// Clears local sync metadata (keeps user data)
    /// - Note: Forces fresh sync on next operation
    func clearSyncMetadata() async

    /// Resets CloudKit container (removes all remote data)
    /// - Warning: This permanently deletes all data in CloudKit
    /// - Parameter confirmation: Must be "DELETE_ALL_REMOTE_DATA" to proceed
    /// - Throws: `CloudSyncError` if reset fails or confirmation is incorrect
    func resetCloudKitContainer(confirmation: String) async throws

    /// Exports sync debug information
    /// - Returns: Diagnostic information for troubleshooting sync issues
    func exportSyncDiagnostics() async -> String

    /// Imports data from CloudKit backup
    /// - Parameter backupData: Previously exported backup data
    /// - Throws: `CloudSyncError` if import fails
    func importFromBackup(_ backupData: Data) async throws

    // MARK: - User Account Management

    /// Checks if user is signed in to iCloud
    /// - Returns: True if user has an active iCloud account
    func isSignedInToiCloud() async -> Bool

    /// Prompts user to sign in to iCloud
    /// - Note: Shows system dialog for iCloud sign-in
    func promptiCloudSignIn() async

    /// Handles iCloud account changes
    /// - Note: Called automatically when account status changes
    func handleAccountChange() async

    /// Migrates data when switching iCloud accounts
    /// - Parameters:
    ///   - fromAccount: Previous account identifier
    ///   - toAccount: New account identifier
    /// - Throws: `CloudSyncError` if migration fails
    func migrateToNewAccount(fromAccount: String, toAccount: String) async throws
}

// MARK: - Supporting Types for Additional Functionality

/// Sync event for history tracking
public struct SyncEvent {
    public let timestamp: Date
    public let eventType: SyncEventType
    public let recordsAffected: Int
    public let duration: TimeInterval
    public let success: Bool
    public let errorMessage: String?

    public init(timestamp: Date, eventType: SyncEventType, recordsAffected: Int, duration: TimeInterval, success: Bool, errorMessage: String?) {
        self.timestamp = timestamp
        self.eventType = eventType
        self.recordsAffected = recordsAffected
        self.duration = duration
        self.success = success
        self.errorMessage = errorMessage
    }
}

/// Types of sync events
public enum SyncEventType: String, CaseIterable {
    case manualSync = "Manual Sync"
    case autoSync = "Automatic Sync"
    case backgroundSync = "Background Sync"
    case conflictResolution = "Conflict Resolution"
    case networkReconnect = "Network Reconnect"
    case appLaunch = "App Launch"

    public var description: String {
        return rawValue
    }
}

/// Network status for CloudKit operations
public enum NetworkStatus {
    case available
    case unavailable
    case cellularOnly
    case wifiOnly
    case limited

    public var description: String {
        switch self {
        case .available: return "Available"
        case .unavailable: return "Unavailable"
        case .cellularOnly: return "Cellular Only"
        case .wifiOnly: return "WiFi Only"
        case .limited: return "Limited"
        }
    }
}

/// Background task result
public enum BackgroundTaskResult {
    case completed
    case expired
    case failed(Error)

    public var isSuccess: Bool {
        switch self {
        case .completed: return true
        case .expired, .failed: return false
        }
    }
}

/// Background sync status
public struct BackgroundSyncStatus {
    public let isEnabled: Bool
    public let hasPermission: Bool
    public let nextScheduledSync: Date?
    public let lastBackgroundSync: Date?

    public init(isEnabled: Bool, hasPermission: Bool, nextScheduledSync: Date?, lastBackgroundSync: Date?) {
        self.isEnabled = isEnabled
        self.hasPermission = hasPermission
        self.nextScheduledSync = nextScheduledSync
        self.lastBackgroundSync = lastBackgroundSync
    }
}

// MARK: - Test Helper Protocol

/// Protocol for test implementations and mocking
/// Enables dependency injection and unit testing of components that depend on CloudSyncService
public protocol MockableCloudSyncService: CloudSyncService {
    /// Allows tests to simulate sync status
    func setMockSyncStatus(_ status: CloudSyncStatus)

    /// Allows tests to simulate account status
    func setMockAccountStatus(_ status: CloudAccountStatus)

    /// Allows tests to inject mock conflicts
    func setMockConflicts(_ conflicts: [SyncConflict])

    /// Allows tests to simulate errors
    func setMockError(_ error: CloudSyncError?)

    /// Allows tests to control sync statistics
    func setMockStatistics(_ statistics: SyncStatistics)

    /// Allows tests to simulate network status
    func setMockNetworkStatus(_ status: NetworkStatus)
}