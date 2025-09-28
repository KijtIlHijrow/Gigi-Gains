# Tasks: Gigi Gains iOS Workout Tracking App v1

**Input**: Design documents from `/specs/001-app-name-gigi/`
**Prerequisites**: plan.md (required), research.md, data-model.md, contracts/, quickstart.md

## Execution Flow (main)
```
1. Load plan.md from feature directory
   → Tech stack: Swift 5.10+, SwiftUI, Combine, XCTest, HealthKit, CloudKit, Core Data
   → Structure: iOS app with offline-first architecture
2. Load design documents:
   → data-model.md: 8 Core Data entities
   → contracts/: 11 Swift protocol contracts
   → quickstart.md: 7 core scenarios + edge cases
3. Generate tasks by category:
   → Setup: project init, dependencies, Core Data stack
   → Tests: 11 contract tests, 12 integration tests
   → Core: 8 models, 11 services, 15+ SwiftUI views
   → Integration: HealthKit, CloudKit, notifications
   → Polish: unit tests, performance, accessibility
4. Apply TDD ordering: Tests before implementation
5. Mark [P] for parallel execution (different files)
```

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Path Conventions
- **iOS Project Structure**: `GigiGains/Sources/`, `GigiGains/Tests/`
- Based on Swift Package Manager layout from plan.md

## Phase 3.1: Setup & Foundation
- [ ] T001 Create iOS project structure per implementation plan with Swift Package Manager
- [ ] T002 Initialize Swift 5.10+ project with SwiftUI, Combine, XCTest, HealthKit, CloudKit dependencies in Package.swift
- [ ] T003 [P] Configure SwiftLint and SwiftFormat tools for code quality
- [ ] T004 [P] Setup Core Data stack with NSPersistentCloudKitContainer in GigiGains/Sources/Managers/CoreDataStack.swift
- [ ] T005 [P] Configure HealthKit and CloudKit capabilities in project settings

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3
**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**

### Contract Tests [P] - Can run in parallel
- [ ] T006 [P] Contract test WorkoutServiceProtocol in GigiGains/Tests/UnitTests/WorkoutServiceTests.swift
- [ ] T007 [P] Contract test RoutineServiceProtocol in GigiGains/Tests/UnitTests/RoutineServiceTests.swift
- [ ] T008 [P] Contract test ExerciseLibraryServiceProtocol in GigiGains/Tests/UnitTests/ExerciseLibraryServiceTests.swift
- [ ] T009 [P] Contract test ProgressTrackingServiceProtocol in GigiGains/Tests/UnitTests/ProgressTrackingServiceTests.swift
- [ ] T010 [P] Contract test HealthKitServiceProtocol in GigiGains/Tests/UnitTests/HealthKitServiceTests.swift
- [ ] T011 [P] Contract test CloudSyncServiceProtocol in GigiGains/Tests/UnitTests/CloudSyncServiceTests.swift
- [ ] T012 [P] Contract test NotificationServiceProtocol in GigiGains/Tests/UnitTests/NotificationServiceTests.swift
- [ ] T013 [P] Contract test TimerManagerProtocol in GigiGains/Tests/UnitTests/TimerManagerTests.swift
- [ ] T014 [P] Contract test PlateCalculatorServiceProtocol in GigiGains/Tests/UnitTests/PlateCalculatorServiceTests.swift
- [ ] T015 [P] Contract test WorkoutRepositoryProtocol in GigiGains/Tests/UnitTests/WorkoutRepositoryTests.swift
- [ ] T016 [P] Contract test ExerciseRepositoryProtocol in GigiGains/Tests/UnitTests/ExerciseRepositoryTests.swift

### Integration Tests [P] - Can run in parallel
- [ ] T017 [P] Integration test first-time app setup & HealthKit permissions in GigiGains/Tests/IntegrationTests/FirstTimeSetupTests.swift
- [ ] T018 [P] Integration test starting new workout & exercise logging in GigiGains/Tests/IntegrationTests/WorkoutLoggingTests.swift
- [ ] T019 [P] Integration test rest timer usage & background notifications in GigiGains/Tests/IntegrationTests/RestTimerTests.swift
- [ ] T020 [P] Integration test exercise history & progression tracking in GigiGains/Tests/IntegrationTests/ProgressionTrackingTests.swift
- [ ] T021 [P] Integration test routine creation & reuse in GigiGains/Tests/IntegrationTests/RoutineManagementTests.swift
- [ ] T022 [P] Integration test superset & circuit training in GigiGains/Tests/IntegrationTests/SupersetCircuitTests.swift
- [ ] T023 [P] Integration test plate calculator usage in GigiGains/Tests/IntegrationTests/PlateCalculatorTests.swift
- [ ] T024 [P] Integration test offline functionality without internet in GigiGains/Tests/IntegrationTests/OfflineFunctionalityTests.swift
- [ ] T025 [P] Integration test sync conflict resolution in GigiGains/Tests/IntegrationTests/SyncConflictTests.swift
- [ ] T026 [P] Integration test HealthKit permission denial handling in GigiGains/Tests/IntegrationTests/HealthKitPermissionTests.swift
- [ ] T027 [P] Integration test background app behavior during rest timer in GigiGains/Tests/IntegrationTests/BackgroundBehaviorTests.swift
- [ ] T028 [P] Integration test invalid data entry handling in GigiGains/Tests/IntegrationTests/DataValidationTests.swift

## Phase 3.3: Core Data Models (ONLY after tests are failing)
### Core Data Entities [P] - Can run in parallel (independent schemas)
- [ ] T029 [P] WorkoutSession Core Data entity in GigiGains/Sources/Models/WorkoutSession.swift
- [ ] T030 [P] WorkoutExercise Core Data entity in GigiGains/Sources/Models/WorkoutExercise.swift
- [ ] T031 [P] Exercise Core Data entity in GigiGains/Sources/Models/Exercise.swift
- [ ] T032 [P] ExerciseSet Core Data entity in GigiGains/Sources/Models/ExerciseSet.swift
- [ ] T033 [P] Routine Core Data entity in GigiGains/Sources/Models/Routine.swift
- [ ] T034 [P] RoutineExercise Core Data entity in GigiGains/Sources/Models/RoutineExercise.swift
- [ ] T035 [P] PersonalRecord Core Data entity in GigiGains/Sources/Models/PersonalRecord.swift
- [ ] T036 [P] WeeklyVolume Core Data entity in GigiGains/Sources/Models/WeeklyVolume.swift

### Core Data Model Configuration
- [ ] T037 Create GigiGains.xcdatamodeld with all entities and CloudKit configuration
- [ ] T038 Configure entity relationships and delete rules in Core Data model
- [ ] T039 Setup Core Data migration policies for future schema changes

## Phase 3.4: Repository Layer
### Repositories [P] - Can run in parallel (different entities)
- [ ] T040 [P] WorkoutRepository implementation in GigiGains/Sources/Services/WorkoutRepository.swift
- [ ] T041 [P] ExerciseRepository implementation in GigiGains/Sources/Services/ExerciseRepository.swift

## Phase 3.5: Service Layer (Sequential - dependencies between services)
- [ ] T042 ExerciseLibraryService implementation in GigiGains/Sources/Services/ExerciseLibraryService.swift
- [ ] T043 WorkoutService implementation in GigiGains/Sources/Services/WorkoutService.swift
- [ ] T044 RoutineService implementation in GigiGains/Sources/Services/RoutineService.swift
- [ ] T045 ProgressTrackingService implementation in GigiGains/Sources/Services/ProgressTrackingService.swift
- [ ] T046 PlateCalculatorService implementation in GigiGains/Sources/Services/PlateCalculatorService.swift

## Phase 3.6: System Integration Layer
- [ ] T047 HealthKitService implementation in GigiGains/Sources/Managers/HealthKitService.swift
- [ ] T048 CloudSyncService implementation in GigiGains/Sources/Managers/CloudSyncService.swift
- [ ] T049 NotificationService implementation in GigiGains/Sources/Managers/NotificationService.swift
- [ ] T050 TimerManager implementation in GigiGains/Sources/Managers/TimerManager.swift

## Phase 3.7: SwiftUI Views & Navigation
### Core Views [P] - Can run in parallel (independent components)
- [ ] T051 [P] MainTabView with workout, routines, history, settings tabs in GigiGains/Sources/Views/MainTabView.swift
- [ ] T052 [P] WorkoutSessionView for active workout logging in GigiGains/Sources/Views/Workout/WorkoutSessionView.swift
- [ ] T053 [P] ExerciseSelectionView for choosing exercises in GigiGains/Sources/Views/Workout/ExerciseSelectionView.swift
- [ ] T054 [P] SetLoggingView for reps, weight, RPE input in GigiGains/Sources/Views/Workout/SetLoggingView.swift
- [ ] T055 [P] RestTimerView with countdown and notifications in GigiGains/Sources/Views/Workout/RestTimerView.swift
- [ ] T056 [P] RoutineListView for saved routines in GigiGains/Sources/Views/Routines/RoutineListView.swift
- [ ] T057 [P] RoutineCreationView for building routines in GigiGains/Sources/Views/Routines/RoutineCreationView.swift
- [ ] T058 [P] WorkoutHistoryView for past sessions in GigiGains/Sources/Views/History/WorkoutHistoryView.swift
- [ ] T059 [P] ProgressChartsView for PR tracking in GigiGains/Sources/Views/History/ProgressChartsView.swift
- [ ] T060 [P] ExerciseDetailView with history and PRs in GigiGains/Sources/Views/History/ExerciseDetailView.swift
- [ ] T061 [P] PlateCalculatorView for weight loading in GigiGains/Sources/Views/Tools/PlateCalculatorView.swift
- [ ] T062 [P] SettingsView for app configuration in GigiGains/Sources/Views/Settings/SettingsView.swift

### View Models (Sequential - depend on services)
- [ ] T063 WorkoutSessionViewModel in GigiGains/Sources/Views/Workout/WorkoutSessionViewModel.swift
- [ ] T064 RoutineListViewModel in GigiGains/Sources/Views/Routines/RoutineListViewModel.swift
- [ ] T065 WorkoutHistoryViewModel in GigiGains/Sources/Views/History/WorkoutHistoryViewModel.swift
- [ ] T066 ProgressChartsViewModel in GigiGains/Sources/Views/History/ProgressChartsViewModel.swift

## Phase 3.8: App Structure & Configuration
- [ ] T067 GigiGainsApp.swift main app entry point with Core Data and service injection
- [ ] T068 ContentView.swift root view with navigation setup
- [ ] T069 DependencyContainer for service injection and mocking support
- [ ] T070 Configure Info.plist with HealthKit usage descriptions and privacy strings

## Phase 3.9: Polish & Quality
### Unit Tests for Complex Logic [P] - Can run in parallel
- [ ] T071 [P] Unit tests for Epley formula PR calculations in GigiGains/Tests/UnitTests/PRCalculationTests.swift
- [ ] T072 [P] Unit tests for plate calculator algorithms in GigiGains/Tests/UnitTests/PlateCalculationTests.swift
- [ ] T073 [P] Unit tests for workout volume calculations in GigiGains/Tests/UnitTests/VolumeCalculationTests.swift
- [ ] T074 [P] Unit tests for data validation logic in GigiGains/Tests/UnitTests/DataValidationTests.swift

### Snapshot Tests [P] - Can run in parallel
- [ ] T075 [P] Snapshot tests for WorkoutSessionView in GigiGains/Tests/SnapshotTests/WorkoutSessionSnapshotTests.swift
- [ ] T076 [P] Snapshot tests for RoutineListView in GigiGains/Tests/SnapshotTests/RoutineListSnapshotTests.swift
- [ ] T077 [P] Snapshot tests for ProgressChartsView in GigiGains/Tests/SnapshotTests/ProgressChartsSnapshotTests.swift

### Performance & Accessibility
- [ ] T078 Performance tests for Core Data queries (<100ms) in GigiGains/Tests/PerformanceTests/CoreDataPerformanceTests.swift
- [ ] T079 Accessibility tests for VoiceOver support in GigiGains/Tests/UITests/AccessibilityTests.swift
- [ ] T080 UI tests for critical user flows in GigiGains/Tests/UITests/CriticalFlowTests.swift

### Documentation & Configuration
- [ ] T081 [P] Create DocC documentation for public APIs
- [ ] T082 [P] Update Package.swift with final dependencies and metadata
- [ ] T083 [P] Create sample exercise data for testing and demo
- [ ] T084 [P] Setup GitHub Actions CI workflow for testing
- [ ] T085 Manual testing using quickstart.md scenarios

## Dependencies
**Critical TDD Dependencies:**
- All contract tests (T006-T016) and integration tests (T017-T028) MUST complete before any implementation
- Core Data models (T029-T036) before repositories (T040-T041)
- Repositories before services (T042-T046)
- Services before managers (T047-T050)
- Services before view models (T063-T066)
- View models before views (T051-T062)
- App structure (T067-T070) requires all services and views
- Polish tasks (T071-T085) after all implementation

## Parallel Execution Examples

### Contract Tests (can launch together):
```
Task: "Contract test WorkoutServiceProtocol in GigiGains/Tests/UnitTests/WorkoutServiceTests.swift"
Task: "Contract test RoutineServiceProtocol in GigiGains/Tests/UnitTests/RoutineServiceTests.swift"
Task: "Contract test ExerciseLibraryServiceProtocol in GigiGains/Tests/UnitTests/ExerciseLibraryServiceTests.swift"
Task: "Contract test ProgressTrackingServiceProtocol in GigiGains/Tests/UnitTests/ProgressTrackingServiceTests.swift"
# ... all T006-T016
```

### Core Data Models (can launch together):
```
Task: "WorkoutSession Core Data entity in GigiGains/Sources/Models/WorkoutSession.swift"
Task: "WorkoutExercise Core Data entity in GigiGains/Sources/Models/WorkoutExercise.swift"
Task: "Exercise Core Data entity in GigiGains/Sources/Models/Exercise.swift"
Task: "ExerciseSet Core Data entity in GigiGains/Sources/Models/ExerciseSet.swift"
# ... all T029-T036
```

### SwiftUI Views (can launch together):
```
Task: "MainTabView with workout, routines, history, settings tabs in GigiGains/Sources/Views/MainTabView.swift"
Task: "WorkoutSessionView for active workout logging in GigiGains/Sources/Views/Workout/WorkoutSessionView.swift"
Task: "ExerciseSelectionView for choosing exercises in GigiGains/Sources/Views/Workout/ExerciseSelectionView.swift"
# ... all T051-T062
```

## Notes
- **[P] tasks** = different files, no dependencies - can run in parallel
- **Verify tests fail** before implementing (TDD requirement)
- **Constitutional compliance**: 80%+ test coverage, accessibility, privacy-first
- **Offline-first**: All core functionality works without internet
- Each task specifies exact file path for clarity
- Follow SwiftUI best practices and iOS design guidelines

## Validation Checklist
*GATE: Checked before task execution*

- [x] All 11 contracts have corresponding test tasks (T006-T016)
- [x] All 8 entities have model creation tasks (T029-T036)
- [x] All tests come before implementation (T006-T028 before T029+)
- [x] Parallel tasks [P] are truly independent (different files)
- [x] Each task specifies exact file path
- [x] No task modifies same file as another [P] task
- [x] TDD workflow: Tests → Models → Services → Views → Polish
- [x] Constitutional compliance: accessibility, privacy, test coverage
- [x] iOS-specific requirements: HealthKit, CloudKit, background processing