# Data Model Design: Gigi Gains iOS Workout Tracking App v1

**Feature Branch**: `001-app-name-gigi`
**Created**: 2025-09-28
**Status**: Implementation Ready
**Version**: 1.0

## Overview

This document defines the Core Data entity model for Gigi Gains, designed for offline-first functionality with CloudKit synchronization via NSPersistentCloudKitContainer. The model supports comprehensive workout tracking, progression monitoring, and routine management while maintaining optimal performance and data integrity.

## Core Principles

- **Offline-First**: All entities work without internet connectivity
- **CloudKit Compatible**: Designed for automatic sync across devices
- **Performance Optimized**: Relationships and indexing for efficient queries
- **Migration Ready**: Structure supports future schema changes
- **Privacy Focused**: No external identifiers or tracking data

## Entity Definitions

### 1. WorkoutSession
Primary entity representing a complete training session.

```swift
@objc(WorkoutSession)
public class WorkoutSession: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var startDate: Date
    @NSManaged public var endDate: Date?
    @NSManaged public var duration: Double // seconds
    @NSManaged public var name: String?
    @NSManaged public var notes: String?
    @NSManaged public var isCompleted: Bool
    @NSManaged public var totalVolume: Double // kg or lbs
    @NSManaged public var averageRPE: Double
    @NSManaged public var createdAt: Date
    @NSManaged public var modifiedAt: Date

    // Relationships
    @NSManaged public var exercises: NSSet
    @NSManaged public var routine: Routine?
}
```

**Attributes:**
- `id`: UUID - Primary identifier, CloudKit compatible
- `startDate`: Date - When workout began (required)
- `endDate`: Date? - When workout completed (nil if in progress)
- `duration`: Double - Total workout time in seconds
- `name`: String? - User-defined session name
- `notes`: String? - Session-level notes
- `isCompleted`: Bool - Whether session is finished
- `totalVolume`: Double - Calculated total weight moved
- `averageRPE`: Double - Calculated average RPE across all sets
- `createdAt`: Date - Entity creation timestamp
- `modifiedAt`: Date - Last modification timestamp

**CloudKit Considerations:**
- Uses UUID for CloudKit record names
- Date attributes sync automatically
- String attributes have 1MB CloudKit limit (sufficient for notes)

### 2. WorkoutExercise
Junction entity linking exercises to workout sessions with session-specific data.

```swift
@objc(WorkoutExercise)
public class WorkoutExercise: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var orderIndex: Int32
    @NSManaged public var restTimerDuration: Double // seconds
    @NSManaged public var notes: String?
    @NSManaged public var superset: String? // identifier for grouping
    @NSManaged public var isCompleted: Bool
    @NSManaged public var createdAt: Date
    @NSManaged public var modifiedAt: Date

    // Relationships
    @NSManaged public var session: WorkoutSession
    @NSManaged public var exercise: Exercise
    @NSManaged public var sets: NSSet
}
```

**Attributes:**
- `id`: UUID - Primary identifier
- `orderIndex`: Int32 - Exercise order within session
- `restTimerDuration`: Double - Custom rest time for this exercise
- `notes`: String? - Exercise-specific notes for this session
- `superset`: String? - Groups exercises for supersets/circuits
- `isCompleted`: Bool - Whether all sets are completed

**Design Rationale:**
- Separates exercise template from session instance
- Enables custom rest times per exercise per session
- Supports superset grouping with string identifier

### 3. Exercise
Master exercise library containing all available movements.

```swift
@objc(Exercise)
public class Exercise: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var category: String
    @NSManaged public var primaryMuscleGroups: String // JSON array
    @NSManaged public var secondaryMuscleGroups: String // JSON array
    @NSManaged public var equipment: String
    @NSManaged public var instructions: String?
    @NSManaged public var isCustom: Bool
    @NSManaged public var isArchived: Bool
    @NSManaged public var defaultRestTime: Double // seconds
    @NSManaged public var createdAt: Date
    @NSManaged public var modifiedAt: Date

    // Relationships
    @NSManaged public var workoutExercises: NSSet
    @NSManaged public var personalRecords: NSSet
    @NSManaged public var routineExercises: NSSet
}
```

**Attributes:**
- `id`: UUID - Primary identifier
- `name`: String - Exercise name (indexed)
- `category`: String - Exercise category (compound, isolation, etc.)
- `primaryMuscleGroups`: String - JSON array of primary muscles
- `secondaryMuscleGroups`: String - JSON array of secondary muscles
- `equipment`: String - Required equipment
- `instructions`: String? - Exercise instructions or form cues
- `isCustom`: Bool - User-created vs. predefined
- `isArchived`: Bool - Hidden from active library
- `defaultRestTime`: Double - Default rest time in seconds

**CloudKit Considerations:**
- Muscle groups stored as JSON strings (CloudKit doesn't support arrays)
- Instructions limited to 1MB CloudKit text limit

### 4. ExerciseSet
Individual set within a workout exercise.

```swift
@objc(ExerciseSet)
public class ExerciseSet: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var setNumber: Int32
    @NSManaged public var weight: Double
    @NSManaged public var reps: Int32
    @NSManaged public var rpe: Double // 1-10 scale
    @NSManaged public var isCompleted: Bool
    @NSManaged public var notes: String?
    @NSManaged public var restDuration: Double // actual rest taken
    @NSManaged public var estimatedOneRM: Double // calculated
    @NSManaged public var createdAt: Date
    @NSManaged public var modifiedAt: Date

    // Relationships
    @NSManaged public var workoutExercise: WorkoutExercise
}
```

**Attributes:**
- `id`: UUID - Primary identifier
- `setNumber`: Int32 - Set order within exercise
- `weight`: Double - Weight used (stored in user's preferred unit)
- `reps`: Int32 - Repetitions completed
- `rpe`: Double - Rate of Perceived Exertion (1-10)
- `isCompleted`: Bool - Whether set was finished
- `notes`: String? - Set-specific notes
- `restDuration`: Double - Actual rest time taken
- `estimatedOneRM`: Double - Calculated using Epley formula

**Validation Rules:**
- `weight` >= 0
- `reps` >= 0 and <= 1000 (reasonable upper limit)
- `rpe` >= 1.0 and <= 10.0
- `setNumber` >= 1

### 5. Routine
Saved workout templates for reuse.

```swift
@objc(Routine)
public class Routine: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var notes: String?
    @NSManaged public var isArchived: Bool
    @NSManaged public var lastUsed: Date?
    @NSManaged public var useCount: Int32
    @NSManaged public var estimatedDuration: Double // minutes
    @NSManaged public var createdAt: Date
    @NSManaged public var modifiedAt: Date

    // Relationships
    @NSManaged public var exercises: NSSet
    @NSManaged public var workoutSessions: NSSet
}
```

**Attributes:**
- `id`: UUID - Primary identifier
- `name`: String - Routine name (indexed)
- `notes`: String? - Routine description or goals
- `isArchived`: Bool - Hidden from active routines
- `lastUsed`: Date? - When routine was last used
- `useCount`: Int32 - Number of times routine has been used
- `estimatedDuration`: Double - Estimated completion time in minutes

### 6. RoutineExercise
Template exercise within a routine.

```swift
@objc(RoutineExercise)
public class RoutineExercise: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var orderIndex: Int32
    @NSManaged public var targetSets: Int32
    @NSManaged public var targetReps: String? // JSON for set schemes
    @NSManaged public var targetWeight: Double?
    @NSManaged public var targetRPE: Double?
    @NSManaged public var restTime: Double // seconds
    @NSManaged public var superset: String?
    @NSManaged public var notes: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var modifiedAt: Date

    // Relationships
    @NSManaged public var routine: Routine
    @NSManaged public var exercise: Exercise
}
```

**Attributes:**
- `id`: UUID - Primary identifier
- `orderIndex`: Int32 - Exercise order in routine
- `targetSets`: Int32 - Planned number of sets
- `targetReps`: String? - JSON array for varied rep schemes (e.g., [5,5,5] or [10,8,6])
- `targetWeight`: Double? - Suggested weight
- `targetRPE`: Double? - Target RPE
- `restTime`: Double - Rest time between sets
- `superset`: String? - Superset grouping identifier

### 7. PersonalRecord
Tracks best performances for each exercise.

```swift
@objc(PersonalRecord)
public class PersonalRecord: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var recordType: String // "1RM", "volume", "endurance"
    @NSManaged public var value: Double
    @NSManaged public var weight: Double?
    @NSManaged public var reps: Int32?
    @NSManaged public var date: Date
    @NSManaged public var notes: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var modifiedAt: Date

    // Relationships
    @NSManaged public var exercise: Exercise
    @NSManaged public var sourceSet: ExerciseSet?
}
```

**Attributes:**
- `id`: UUID - Primary identifier
- `recordType`: String - Type of record ("1RM", "maxVolume", "maxReps")
- `value`: Double - Record value (1RM weight, total volume, etc.)
- `weight`: Double? - Weight used for this record
- `reps`: Int32? - Reps performed for this record
- `date`: Date - When record was achieved
- `sourceSet`: ExerciseSet? - Link to the set that achieved this PR

### 8. WeeklyVolume
Aggregated training metrics for progression tracking.

```swift
@objc(WeeklyVolume)
public class WeeklyVolume: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var weekStartDate: Date
    @NSManaged public var totalVolume: Double // total weight moved
    @NSManaged public var totalSets: Int32
    @NSManaged public var totalWorkouts: Int32
    @NSManaged public var averageRPE: Double
    @NSManaged public var totalDuration: Double // minutes
    @NSManaged public var muscleGroupVolumes: String // JSON
    @NSManaged public var createdAt: Date
    @NSManaged public var modifiedAt: Date
}
```

**Attributes:**
- `id`: UUID - Primary identifier
- `weekStartDate`: Date - Monday of the week (indexed)
- `totalVolume`: Double - Total weight moved this week
- `totalSets`: Int32 - Total sets completed
- `totalWorkouts`: Int32 - Number of workouts
- `averageRPE`: Double - Average RPE across all sets
- `totalDuration`: Double - Total workout time in minutes
- `muscleGroupVolumes`: String - JSON mapping muscle groups to volumes

## Relationships

### Cardinality and Delete Rules

```
WorkoutSession (1) ←→ (N) WorkoutExercise
- Delete Rule: Cascade (deleting session deletes all exercises)

WorkoutExercise (1) ←→ (N) ExerciseSet
- Delete Rule: Cascade (deleting exercise deletes all sets)

Exercise (1) ←→ (N) WorkoutExercise
- Delete Rule: Nullify (deleting exercise keeps workout data with null reference)

Exercise (1) ←→ (N) PersonalRecord
- Delete Rule: Cascade (deleting exercise deletes PRs)

Routine (1) ←→ (N) RoutineExercise
- Delete Rule: Cascade (deleting routine deletes template exercises)

Exercise (1) ←→ (N) RoutineExercise
- Delete Rule: Nullify (deleting exercise keeps routine structure)

WorkoutSession (N) ←→ (1) Routine
- Delete Rule: Nullify (deleting routine keeps workout history)

ExerciseSet (1) ←→ (1) PersonalRecord
- Delete Rule: Nullify (deleting set keeps PR record)
```

## Validation Rules

### Data Constraints

1. **WorkoutSession**
   - `startDate` cannot be in the future
   - `endDate` must be after `startDate` if present
   - `duration` must be positive
   - `averageRPE` between 1.0-10.0 if present

2. **ExerciseSet**
   - `weight` >= 0
   - `reps` >= 0 and <= 1000
   - `rpe` between 1.0-10.0
   - `setNumber` >= 1
   - `restDuration` >= 0

3. **Exercise**
   - `name` cannot be empty
   - `category` must be from predefined list
   - `defaultRestTime` >= 0

4. **Routine**
   - `name` cannot be empty
   - `estimatedDuration` >= 0

### Business Rules

1. **Unique Constraints**
   - Exercise names must be unique per user
   - Routine names must be unique per user
   - Set numbers must be unique within WorkoutExercise

2. **State Transitions**
   - WorkoutSession can only be marked complete if all exercises are complete
   - WorkoutExercise can only be marked complete if all sets are complete
   - Cannot modify completed sets (create new sets instead)

## State Transitions

### Workout Session States

```
Draft → In Progress → Completed
  ↓         ↓            ↓
  └── Can be deleted ────┘
          └── Cannot modify sets ──┘
```

**State Rules:**
- **Draft**: Session created but not started
- **In Progress**: Session started (`startDate` set, no `endDate`)
- **Completed**: Session finished (`endDate` set, `isCompleted` = true)

### Set States

```
Planned → In Progress → Completed
   ↓          ↓           ↓
   └── Can modify ───────┘
           └── Creates PR if applicable ──┘
```

## Indexing Strategy

### Primary Indexes (for performance)

```swift
// WorkoutSession
@Index(["startDate"], name: "workout_session_start_date")
@Index(["isCompleted"], name: "workout_session_completed")

// Exercise
@Index(["name"], name: "exercise_name")
@Index(["category"], name: "exercise_category")
@Index(["isArchived"], name: "exercise_archived")

// ExerciseSet
@Index(["createdAt"], name: "exercise_set_created")
@Index(["isCompleted"], name: "exercise_set_completed")

// Routine
@Index(["name"], name: "routine_name")
@Index(["lastUsed"], name: "routine_last_used")

// PersonalRecord
@Index(["date"], name: "personal_record_date")
@Index(["recordType"], name: "personal_record_type")

// WeeklyVolume
@Index(["weekStartDate"], name: "weekly_volume_date")
```

### Composite Indexes

```swift
// For exercise filtering
@Index(["category", "isArchived"], name: "exercise_category_archived")

// For workout history queries
@Index(["startDate", "isCompleted"], name: "workout_date_completed")

// For PR tracking
@Index(["exercise", "recordType"], name: "pr_exercise_type")
```

## CloudKit Mapping

### Record Types

```
CKRecord Types:
- CD_WorkoutSession
- CD_WorkoutExercise
- CD_Exercise
- CD_ExerciseSet
- CD_Routine
- CD_RoutineExercise
- CD_PersonalRecord
- CD_WeeklyVolume
```

### CloudKit Compatibility Notes

1. **UUID Attributes**: Automatically mapped to CloudKit recordName
2. **Date Attributes**: Native CloudKit Date type
3. **String Attributes**: CloudKit String type (1MB limit)
4. **JSON Attributes**: Stored as CloudKit String, parsed client-side
5. **Relationships**: CloudKit CKReference with delete actions
6. **Large Text**: Consider CKAsset for exercise instructions >1MB

### Sync Considerations

1. **Conflict Resolution**: Last-writer-wins for CloudKit
2. **Incremental Sync**: NSPersistentCloudKitContainer handles automatically
3. **Schema Evolution**: CloudKit schema updated automatically from Core Data
4. **Privacy**: All data in private CloudKit database
5. **Quotas**: CloudKit free tier: 1GB storage, 10GB monthly transfer

## Migration Considerations

### Version 1.0 → 1.1 (Lightweight Migration)

**Planned Changes:**
- Add `difficulty` attribute to Exercise
- Add `bodyWeight` tracking to ExerciseSet
- Add `template` flag to WorkoutSession

**Migration Strategy:**
```swift
// Core Data model versioning
// GigiGains.xcdatamodeld
//   ├── GigiGains 1.0.xcdatamodel (current)
//   └── GigiGains 1.1.xcdatamodel (future)

// Migration mapping model
// GigiGains 1.0 to 1.1.xcmappingmodel
```

### Version 1.1 → 2.0 (Custom Migration)

**Major Changes:**
- Split Exercise into ExerciseTemplate and ExerciseVariation
- Add Equipment entity
- Normalize muscle group data

**Migration Strategy:**
```swift
// Custom NSEntityMigrationPolicy subclasses
class ExerciseMigrationPolicy: NSEntityMigrationPolicy {
    override func createDestinationInstances(
        forSource sInstance: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        // Custom migration logic
    }
}
```

### CloudKit Schema Versioning

1. **Additive Changes**: New attributes sync automatically
2. **Breaking Changes**: Require app version coordination
3. **Schema Rollback**: Not supported - plan changes carefully
4. **Testing**: Use CloudKit development environment for schema changes

## Performance Optimization

### Fetch Request Optimization

```swift
// Efficient workout loading with relationships
let request: NSFetchRequest<WorkoutSession> = WorkoutSession.fetchRequest()
request.predicate = NSPredicate(format: "startDate >= %@", thirtyDaysAgo)
request.relationshipKeyPathsForPrefetching = ["exercises", "exercises.sets"]
request.returnsObjectsAsFaults = false
```

### Memory Management

1. **Batch Size**: Limit fetch requests to 50-100 objects
2. **Faulting**: Use faults for distant relationships
3. **Background Context**: Use for data processing
4. **Cache Invalidation**: Clear unused objects from memory

### CloudKit Performance

1. **Batch Operations**: Group saves into batches
2. **Predicate Optimization**: Use indexed fields in predicates
3. **Asset Handling**: Use CKAsset for large binary data
4. **Subscription Filters**: Minimize unnecessary sync operations

## Implementation Notes

### Core Data Stack Setup

```swift
lazy var persistentContainer: NSPersistentCloudKitContainer = {
    let container = NSPersistentCloudKitContainer(name: "GigiGains")

    // Configure for CloudKit
    guard let description = container.persistentStoreDescriptions.first else {
        fatalError("Failed to retrieve persistent store description")
    }

    // Enable CloudKit
    description.setOption(true as NSNumber,
                         forKey: NSPersistentCloudKitContainerOptionsKey)

    // Enable history tracking for CloudKit
    description.setOption(true as NSNumber,
                         forKey: NSPersistentHistoryTrackingKey)

    // Enable remote change notifications
    description.setOption(true as NSNumber,
                         forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

    container.loadPersistentStores { _, error in
        if let error = error {
            fatalError("Core Data error: \(error)")
        }
    }

    // Configure view context
    container.viewContext.automaticallyMergesChangesFromParent = true
    container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

    return container
}()
```

### Calculated Properties

```swift
extension ExerciseSet {
    var estimatedOneRM: Double {
        guard weight > 0, reps > 0 else { return 0 }
        // Modified Epley formula with RPE adjustment
        let repsInReserve = rpe > 0 ? (10 - rpe) : 0
        let totalReps = Double(reps) + repsInReserve
        return weight * (1 + totalReps / 30)
    }
}

extension WorkoutSession {
    var totalVolume: Double {
        exercises.compactMap { exercise in
            (exercise as? WorkoutExercise)?.sets.compactMap { set in
                (set as? ExerciseSet)?.weight * Double((set as? ExerciseSet)?.reps ?? 0)
            }.reduce(0, +)
        }.reduce(0, +)
    }
}
```

This comprehensive data model provides a robust foundation for the Gigi Gains iOS workout tracking app, supporting all specified features while maintaining optimal performance and CloudKit compatibility.