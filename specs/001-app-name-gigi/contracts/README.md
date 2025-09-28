# Gigi Gains iOS App - Internal API Contracts

This directory contains comprehensive Swift protocol contracts that define the interfaces between different layers of the Gigi Gains iOS application architecture. These contracts are designed to enable test-driven development (TDD), dependency injection, and clean architecture principles.

## Overview

All contracts have been designed with the following principles in mind:

- **Testability**: Protocols enable dependency injection and mocking
- **Constitutional Compliance**: TDD-ready interfaces that support the project's constitutional requirements
- **Clean Architecture**: Clear separation of concerns between layers
- **SwiftUI + Combine Integration**: Reactive programming patterns with publishers
- **Offline-First Design**: All operations work without network connectivity
- **CloudKit Compatibility**: Designed for automatic sync via NSPersistentCloudKitContainer

## Contract Files

### Core Service Contracts

#### 1. WorkoutService.swift
**Purpose**: Workout session management including CRUD operations, real-time session tracking, and exercise management.

**Key Features**:
- Complete workout session lifecycle (create, start, pause, complete)
- Exercise and set management within sessions
- Real-time updates via Combine publishers
- Session statistics and analytics
- Offline-first with CloudKit sync

**Main Methods**:
- `createSession(config:)` - Creates new workout sessions
- `addExercise(sessionId:request:)` - Adds exercises to sessions
- `addSet(sessionId:exerciseId:setData:)` - Logs individual sets
- `completeSession(sessionId:)` - Finalizes workout sessions

#### 2. RoutineService.swift
**Purpose**: Routine management and template operations for reusable workout plans.

**Key Features**:
- Routine template creation and management
- Exercise template configuration within routines
- Routine usage tracking and statistics
- Creating workout sessions from templates
- Routine discovery and search

**Main Methods**:
- `createRoutine(config:)` - Creates new routine templates
- `addExerciseToRoutine(routineId:template:)` - Configures exercise templates
- `createWorkoutFromRoutine(routineId:sessionName:sessionNotes:)` - Instantiates workouts

#### 3. ExerciseLibraryService.swift
**Purpose**: Exercise library management including browsing, categorization, search, and custom exercise creation.

**Key Features**:
- Comprehensive exercise library browsing
- Advanced filtering by muscle groups, equipment, categories
- Custom exercise creation and management
- Exercise search with intelligent ranking
- Exercise usage tracking and statistics

**Main Methods**:
- `getExercises(filter:sortBy:)` - Advanced exercise filtering
- `createCustomExercise(config:)` - Creates user-defined exercises
- `searchExercises(query:)` - Intelligent exercise search
- `suggestExercises(targetMuscleGroups:excludeExerciseIds:limit:)` - Exercise recommendations

#### 4. ProgressTrackingService.swift
**Purpose**: Progress tracking including PR calculations, volume tracking, progression analytics, and data export.

**Key Features**:
- Personal record calculation using Epley formula (weight × (1 + reps/30))
- Volume progression analysis and trend tracking
- Exercise-specific progress monitoring
- CSV/JSON data export functionality
- Goal tracking and achievement notifications

**Main Methods**:
- `getPersonalRecords(exerciseId:)` - Retrieves PR history
- `calculatePersonalRecords(fromSet:exerciseId:)` - Computes new PRs
- `getWeeklyVolumeData(period:)` - Volume progression data
- `exportProgressData(config:)` - Data export functionality

#### 5. HealthKitService.swift
**Purpose**: HealthKit integration including reading exercise data, writing completed workouts, and managing permissions.

**Key Features**:
- HealthKit permission management with clear user prompts
- Writing completed workout sessions to HealthKit
- Reading exercise and activity data from other apps
- Heart rate and energy data integration
- Background sync and data consistency

**Main Methods**:
- `requestPermissions()` - Manages HealthKit authorization
- `exportWorkout(config:)` - Writes workouts to HealthKit
- `importRecentExerciseData(days:)` - Reads external exercise data
- `startHeartRateMonitoring()` - Real-time heart rate tracking

#### 6. CloudSyncService.swift
**Purpose**: iCloud synchronization using NSPersistentCloudKitContainer, including sync status monitoring and conflict resolution.

**Key Features**:
- Automatic iCloud sync via NSPersistentCloudKitContainer
- Sync status monitoring and error handling
- Conflict detection and resolution
- Account status monitoring and quota management
- Background sync scheduling

**Main Methods**:
- `performManualSync()` - Forces immediate sync
- `getPendingConflicts()` - Retrieves sync conflicts
- `resolveConflict(_:strategy:)` - Handles conflict resolution
- `getSyncStatistics()` - Provides sync analytics

#### 7. NotificationService.swift
**Purpose**: Local notification management including rest timer notifications, background alerts, and workout reminders.

**Key Features**:
- Rest timer notifications with background support
- Workout reminder scheduling and management
- Achievement and personal record notifications
- Permission management and user settings
- Notification analytics and engagement tracking

**Main Methods**:
- `scheduleRestTimerNotification(config:)` - Timer completion alerts
- `scheduleWorkoutReminder(title:message:scheduledDate:repeatInterval:)` - Workout reminders
- `sendPersonalRecordNotification(exerciseName:recordType:value:improvement:)` - Achievement alerts

### Manager Contracts

#### 8. TimerManager.swift
**Purpose**: Rest timer management with background support, including timer lifecycle and notification integration.

**Key Features**:
- Rest timer lifecycle management (start, pause, resume, stop)
- Background timer execution and persistence
- Integration with notification service for completion alerts
- Timer state synchronization across app lifecycle
- Timer history tracking and analytics

**Main Methods**:
- `startTimer(config:)` - Begins rest timer with configuration
- `pauseTimer()` / `resumeTimer()` - Timer control
- `handleAppDidEnterBackground()` - Background execution support
- `getTimerStatistics()` - Usage analytics

#### 9. PlateCalculatorService.swift
**Purpose**: Weight plate calculation utilities supporting both kg and lb weight systems with customizable plate configurations.

**Key Features**:
- Weight plate calculations for target weights
- Support for multiple weight units (kg/lb)
- Customizable plate set configurations
- Optimal plate loading algorithms
- Weight conversion utilities

**Main Methods**:
- `calculatePlates(targetWeight:unit:plateSetName:)` - Computes plate loading
- `convertWeight(_:from:to:)` - Unit conversions
- `getOlympicPlateSet(unit:)` - Standard plate configurations
- `suggestOptimalPlateSet(minWeight:maxWeight:unit:)` - Configuration recommendations

### Data Repository Contracts

#### 10. WorkoutRepository.swift
**Purpose**: Core Data operations for workout sessions, including CRUD operations, querying, and relationship management.

**Key Features**:
- Workout session CRUD operations
- Complex querying with filtering and sorting
- Batch operations for performance
- Relationship management between workout entities
- Background context operations

**Main Methods**:
- `createWorkoutSession(name:routineId:startDate:notes:)` - Creates sessions
- `fetchWorkoutSessions(filter:sortBy:options:)` - Advanced querying
- `addExerciseToWorkoutSession(_:exerciseId:orderIndex:restTimerDuration:superset:notes:)` - Exercise management
- `performBackgroundOperation(_:)` - Background Core Data operations

#### 11. ExerciseRepository.swift
**Purpose**: Exercise data access patterns including exercise library management and custom exercises.

**Key Features**:
- Exercise library CRUD operations
- Custom exercise management
- Advanced querying with filtering and sorting
- Exercise usage tracking and analytics
- Pre-built exercise library initialization

**Main Methods**:
- `createExercise(config:)` - Creates custom exercises
- `fetchExercises(filter:sortBy:options:)` - Advanced exercise querying
- `searchExercises(_:)` - Exercise search functionality
- `initializePreBuiltExerciseLibrary()` - Library initialization

## Common Patterns

### Error Handling
All contracts use strongly-typed error enums that conform to `LocalizedError`:
```swift
public enum WorkoutServiceError: Error, LocalizedError {
    case sessionNotFound(UUID)
    case invalidSessionState(current: WorkoutSessionState, required: WorkoutSessionState)
    // ... other cases

    public var errorDescription: String? {
        // Localized error messages
    }
}
```

### Reactive Programming
All services provide Combine publishers for real-time updates:
```swift
var currentSessionPublisher: AnyPublisher<WorkoutSession?, Never> { get }
var sessionsUpdatePublisher: AnyPublisher<[WorkoutSession], Never> { get }
```

### Async/Await Support
All operations use modern Swift concurrency:
```swift
func createSession(config: WorkoutSessionConfig) async throws -> WorkoutSession
func getSession(sessionId: UUID) async throws -> WorkoutSession
```

### Test Support
Each contract includes a companion `Mockable` protocol for testing:
```swift
public protocol MockableWorkoutService: WorkoutService {
    func setMockSessions(_ sessions: [WorkoutSession])
    func setMockError(_ error: WorkoutServiceError?)
    func setMockCurrentSession(_ session: WorkoutSession?)
}
```

### Configuration Objects
Complex operations use dedicated configuration objects:
```swift
public struct WorkoutSessionConfig {
    public let name: String?
    public let routineId: UUID?
    public let notes: String?
    public let startDate: Date
}
```

## Data Model Integration

All contracts are designed to work seamlessly with the Core Data model defined in `data-model.md`:

- **WorkoutSession**: Complete training sessions with metadata
- **WorkoutExercise**: Exercise instances within sessions
- **Exercise**: Master exercise library
- **ExerciseSet**: Individual sets with weight, reps, RPE
- **Routine**: Saved workout templates
- **PersonalRecord**: PR tracking with Epley formula calculations
- **WeeklyVolume**: Aggregated training metrics

## CloudKit Compatibility

All data operations are designed for CloudKit synchronization:
- UUID primary keys for CloudKit record names
- Proper relationship handling for CloudKit references
- Conflict resolution strategies
- Offline-first operation with sync reconciliation

## Usage Guidelines

1. **Dependency Injection**: Use protocol types for all dependencies
2. **Testing**: Leverage `Mockable` protocols for unit testing
3. **Error Handling**: Always handle strongly-typed errors appropriately
4. **Reactive Updates**: Subscribe to publishers for UI updates
5. **Background Operations**: Use repository background methods for heavy operations
6. **Validation**: Use built-in validation methods before operations

## Implementation Notes

These contracts define **interfaces only**. Concrete implementations will need to:

1. Handle Core Data context management
2. Implement CloudKit synchronization logic
3. Manage HealthKit permissions and data conversion
4. Handle notification scheduling and delivery
5. Implement plate calculation algorithms
6. Manage timer persistence across app lifecycle
7. Handle progress calculation formulas
8. Implement search and filtering logic

## Constitutional Compliance

All contracts support the project's constitutional requirements:

- **Test-Driven Development**: Protocols enable testing before implementation
- **Clean Architecture**: Clear separation between service, repository, and manager layers
- **Dependency Injection**: All dependencies are protocol-based
- **Single Responsibility**: Each contract has a focused, well-defined purpose
- **Open/Closed Principle**: Extensible through protocol conformance
- **Interface Segregation**: Focused, cohesive interfaces

This comprehensive contract system provides a solid foundation for implementing the Gigi Gains iOS app with confidence in its architecture, testability, and maintainability.