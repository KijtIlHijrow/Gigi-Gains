# Gigi Gains iOS App - Quickstart Guide & Integration Test Scenarios

**Version**: 1.0
**Feature Branch**: `001-app-name-gigi`
**Created**: 2025-09-28
**Purpose**: Manual testing scenarios and automated integration test foundation

---

## Overview

This quickstart guide provides comprehensive test scenarios based on the acceptance criteria from the Gigi Gains feature specification. Each scenario includes step-by-step instructions, expected behaviors, validation checkpoints, and clear pass/fail criteria suitable for both manual testing and automated integration test development.

---

## Test Environment Setup

### Prerequisites
- iOS device/simulator running iOS 15+ or iPadOS 15+
- Xcode 14+ for simulator testing
- Test Apple ID with HealthKit permissions available
- iCloud account configured on test device
- Network connectivity for initial setup (offline scenarios tested separately)

### Test Data Requirements
- Clean app installation (no existing Core Data)
- HealthKit permissions reset (for first-time setup scenarios)
- Sample exercise data for history/progression testing

---

## Scenario 1: First-Time App Setup & HealthKit Integration

### **Acceptance Criteria**: FR-010, FR-018
*Given the user has opened the app for the first time, When they grant HealthKit permissions, Then the app can read exercise data and write completed workouts to Apple Health*

### Test Steps

#### 1.1 Initial App Launch
**Action**: Launch Gigi Gains app for the first time on a clean device
**Expected Behavior**:
- App displays welcome/onboarding screen
- No previous workout data visible
- HealthKit permission prompt appears automatically or via setup flow

**Validation Checkpoint**: Verify Core Data store is empty, no cached HealthKit permissions

#### 1.2 HealthKit Permission Grant
**Action**: Tap "Allow" on HealthKit permission dialog, select all workout-related permissions
**Expected Behavior**:
- Permission dialog shows specific data types (Workouts, Active Energy, Heart Rate)
- User can selectively enable/disable permission categories
- Privacy explanation clearly visible

**Integration Point**: HealthKit authorization status should be `.sharingAuthorized`

#### 1.3 Post-Permission Setup
**Action**: Complete HealthKit permission flow
**Expected Behavior**:
- App proceeds to main workout logging interface
- HealthKit permissions persisted in app settings
- No error states or permission re-prompts

**Success Criteria**:
- ✅ HealthKit read permissions granted for exercise data
- ✅ HealthKit write permissions granted for workout sessions
- ✅ App transitions to main interface
- ✅ Permission state persisted across app restarts

**Data Validation**:
```swift
// Verification points for automated tests
assert(HKHealthStore().authorizationStatus(for: HKWorkoutType.workoutType()) == .sharingAuthorized)
assert(CoreDataManager.shared.persistentContainer.viewContext.hasChanges == false)
```

#### 1.4 HealthKit Permission Denial Edge Case
**Action**: Deny HealthKit permissions during setup
**Expected Behavior**:
- App continues to function with reduced functionality
- Clear messaging about limited features without HealthKit
- Option to re-enable permissions in app settings

**Error Handling Verification**:
- ✅ No app crashes on permission denial
- ✅ Graceful degradation of HealthKit-dependent features
- ✅ Settings screen provides re-authorization option

---

## Scenario 2: Starting a New Workout & Exercise Logging

### **Acceptance Criteria**: FR-001, FR-002
*Given the user is starting a new workout, When they select exercises from the library, Then they can log sets with weight, reps, and RPE values*

### Test Steps

#### 2.1 New Workout Creation
**Action**: Tap "Start New Workout" on main screen
**Expected Behavior**:
- New workout session created with current timestamp
- Empty exercise list displayed
- "Add Exercise" button visible and functional

**Validation Checkpoint**: Verify workout session entity created in Core Data with status "in_progress"

#### 2.2 Exercise Library Access
**Action**: Tap "Add Exercise" button
**Expected Behavior**:
- Exercise library opens with categories (Chest, Back, Legs, Shoulders, Arms, Core)
- Search functionality available
- Muscle group filters functional
- Minimum 50 common exercises available

**Integration Point**: Exercise library loaded from Core Data presets

#### 2.3 Exercise Selection & Set Logging
**Action**: Select "Bench Press" from Chest category
**Expected Behavior**:
- Exercise added to current workout
- Set logging interface appears
- Default values: Weight (empty), Reps (empty), RPE (7)

#### 2.4 Set Data Entry
**Action**: Log first set - Weight: 135 lbs, Reps: 8, RPE: 6
**Expected Behavior**:
- All values accepted and displayed
- Set marked as completed
- "Add Set" button enabled for next set
- Previous set data pre-populated for next set

**Data Validation**:
```swift
// Test data constraints
assert(weight > 0 && weight <= 1000) // Reasonable weight limits
assert(reps > 0 && reps <= 50) // Reasonable rep limits
assert(rpe >= 1 && rpe <= 10) // Valid RPE scale
```

#### 2.5 Multiple Set Logging
**Action**: Add 2 more sets with varying weights and reps
**Expected Behavior**:
- Each set stored independently
- Set numbers auto-increment (1, 2, 3)
- Previous set data suggested but editable

**Success Criteria**:
- ✅ Exercise successfully added to workout
- ✅ All set data persisted to Core Data
- ✅ Input validation prevents invalid entries
- ✅ Set progression tracked chronologically

**Performance Benchmark**: Set logging should complete within 500ms

---

## Scenario 3: Rest Timer Usage & Background Notifications

### **Acceptance Criteria**: FR-004
*Given the user completes a set, When they start the rest timer, Then they receive background notifications when rest time is complete*

### Test Steps

#### 3.1 Rest Timer Activation
**Action**: Complete a set and tap "Start Rest Timer" (default 2 minutes)
**Expected Behavior**:
- Timer starts countdown from 2:00
- Visual timer display updates every second
- App UI shows timer is active

**Validation Checkpoint**: Verify timer state persisted in case of app backgrounding

#### 3.2 Timer Customization
**Action**: Before starting timer, change duration to 90 seconds
**Expected Behavior**:
- Custom duration accepted and saved as new default
- Timer countdown reflects custom duration
- Duration preference persisted for future use

#### 3.3 Background App Behavior
**Action**: Start rest timer, then background the app (home button/app switcher)
**Expected Behavior**:
- Timer continues running in background
- Local notification scheduled for timer completion
- App badge or lock screen notification appears when timer expires

**Integration Point**: iOS background processing and local notifications

#### 3.4 Notification Delivery
**Action**: Wait for rest timer to complete while app is backgrounded
**Expected Behavior**:
- Push notification delivered with message "Rest period complete - Ready for next set"
- Notification includes action to return to workout
- Timer state resets when app is reopened

#### 3.5 Timer Interruption Handling
**Action**: Start timer, background app, then restart/force-quit app before timer completes
**Expected Behavior**:
- Timer state recovered on app restart
- Remaining time calculated correctly
- Option to continue or reset timer

**Success Criteria**:
- ✅ Timer runs accurately in foreground and background
- ✅ Notifications delivered reliably when app backgrounded
- ✅ Timer state persists through app lifecycle events
- ✅ Custom durations saved and reused

**Error Handling Verification**:
- ✅ No duplicate notifications if timer restarted
- ✅ Graceful handling of notification permission denial
- ✅ Timer state cleanup on workout completion

---

## Scenario 4: Exercise History & Progression Tracking

### **Acceptance Criteria**: FR-006, FR-007, FR-012, FR-013
*Given the user has previous workout data, When they view their exercise history, Then they can see progression charts and personal records*

### Test Steps

#### 4.1 Historical Data Setup
**Prerequisite**: Complete 5 workouts over different dates with Bench Press exercise, varying weights and reps
**Data Pattern**:
- Workout 1: 3 sets × 8 reps @ 135 lbs
- Workout 2: 3 sets × 6 reps @ 145 lbs
- Workout 3: 3 sets × 5 reps @ 155 lbs
- Workout 4: 3 sets × 8 reps @ 140 lbs
- Workout 5: 3 sets × 3 reps @ 165 lbs

#### 4.2 Personal Records Display
**Action**: Navigate to Bench Press exercise history
**Expected Behavior**:
- Current PR displayed prominently: 169.5 lbs (calculated using Epley formula: 165 × (1 + 3/30))
- PR calculation visible and explainable
- Date of PR achievement shown

**Data Validation**:
```swift
// PR Calculation verification (Epley formula)
let expectedPR = 165 * (1 + 3.0/30.0) // = 169.5 lbs
assert(abs(calculatedPR - expectedPR) < 0.1)
```

#### 4.3 Progression Charts
**Action**: View progression chart for Bench Press
**Expected Behavior**:
- Line graph showing 1RM progression over time
- Data points for each workout session
- Trend line indicating overall progression
- Axis labels with dates and weight values

#### 4.4 Weekly Volume Tracking
**Action**: Navigate to weekly volume chart
**Expected Behavior**:
- Bar chart showing total weekly training volume
- Volume calculation: Σ(sets × reps × weight) for each week
- Multiple exercise types aggregated
- Selectable date ranges (4 weeks, 12 weeks, 1 year)

#### 4.5 Exercise History Filtering
**Action**: Apply date range filter to show last 30 days only
**Expected Behavior**:
- Chart updates to show filtered data range
- Performance metrics recalculated for selected period
- Filter state persisted across app sessions

**Success Criteria**:
- ✅ PRs calculated correctly using Epley formula
- ✅ Progression charts display accurate historical data
- ✅ Weekly volume calculations match manual verification
- ✅ Date filtering functions properly across all views

**Performance Benchmark**: Chart rendering should complete within 1 second for 6 months of data

---

## Scenario 5: Routine Creation & Reuse

### **Acceptance Criteria**: FR-005
*Given the user creates a routine, When they save it, Then they can reuse it for future workouts*

### Test Steps

#### 5.1 Routine Creation from Active Workout
**Action**: During an active workout with 4 exercises, tap "Save as Routine"
**Expected Behavior**:
- Routine name input dialog appears
- Current workout exercises and set schemes captured
- Default name suggested based on exercise selection

#### 5.2 Routine Customization
**Action**: Name routine "Push Day A" and save
**Expected Behavior**:
- Routine saved with custom name
- Template includes all exercises with target sets/reps
- RPE and weight values saved as suggestions, not requirements

**Validation Checkpoint**: Verify routine entity created in Core Data with relationships to exercise templates

#### 5.3 Routine Library Access
**Action**: Navigate to "My Routines" section
**Expected Behavior**:
- All saved routines displayed in list
- Last used date and exercise count shown
- Options to edit, duplicate, or delete routines

#### 5.4 Starting Workout from Routine
**Action**: Select "Push Day A" routine and start new workout
**Expected Behavior**:
- New workout session created with routine exercises pre-loaded
- Previous weight/rep values suggested but editable
- Routine metadata preserved (name, creation date)

#### 5.5 Routine Modification
**Action**: Add new exercise to active routine-based workout, save changes back to routine
**Expected Behavior**:
- Option to update original routine or save as new routine
- Clear versioning/modification tracking
- No impact on previous workouts using this routine

**Success Criteria**:
- ✅ Routines save complete exercise and set configurations
- ✅ Routine-based workouts start with appropriate defaults
- ✅ Routine modifications handled without data corruption
- ✅ Routine library supports standard CRUD operations

**Integration Point**: Core Data relationships between Routine, Exercise, and WorkoutSession entities

---

## Scenario 6: Superset & Circuit Training

### **Acceptance Criteria**: FR-003
*Given the user performs supersets or circuits, When they group exercises, Then the timer and logging flows accommodate non-linear exercise sequences*

### Test Steps

#### 6.1 Superset Creation
**Action**: Add Bench Press and Bent-over Row to workout, tap "Create Superset"
**Expected Behavior**:
- Exercises grouped visually with connecting indicator
- Combined set counter (1A, 1B, 2A, 2B, etc.)
- Single rest timer for the superset pair

#### 6.2 Superset Exercise Flow
**Action**: Complete Bench Press set (1A), then immediately log Bent-over Row set (1B)
**Expected Behavior**:
- No automatic rest timer between 1A and 1B
- Rest timer starts only after completing both exercises in the pair
- Clear visual indication of which exercise is next

#### 6.3 Circuit Training Setup
**Action**: Add 4 exercises and group as circuit
**Expected Behavior**:
- All 4 exercises grouped with circuit indicator
- Round-based progression (Round 1: A→B→C→D, Round 2: A→B→C→D)
- Single rest timer between rounds

#### 6.4 Circuit Exercise Navigation
**Action**: Complete one full round of circuit
**Expected Behavior**:
- App guides user through exercise sequence (A→B→C→D)
- Automatic progression to next exercise after set logging
- Rest timer activates only after completing full round

#### 6.5 Mixed Workout Structure
**Action**: Create workout with individual exercise, superset, and circuit
**Expected Behavior**:
- Each grouping type handled appropriately
- Timer behavior adapts to exercise context
- Clear visual distinction between grouping types

**Success Criteria**:
- ✅ Superset exercises linked with appropriate timer behavior
- ✅ Circuit training supports multi-exercise rounds
- ✅ Mixed workout structures handled correctly
- ✅ Exercise progression follows logical sequence

**Timing Expectations**:
- Individual exercise: Rest timer after each set
- Superset: Rest timer after completing both exercises
- Circuit: Rest timer after completing full round

---

## Scenario 7: Plate Calculator Usage

### **Acceptance Criteria**: FR-009
*Given the user wants to load plates, When they use the plate calculator, Then they can determine the correct weight distribution in kg or lb*

### Test Steps

#### 7.1 Plate Calculator Access
**Action**: During set logging, tap weight field and select "Plate Calculator"
**Expected Behavior**:
- Calculator interface opens with unit selection (kg/lb)
- Standard plate sizes displayed (45, 35, 25, 10, 5, 2.5 lbs or 20, 15, 10, 5, 2.5, 1.25 kg)
- Target weight input field available

#### 7.2 Weight Calculation - Pounds
**Action**: Enter target weight of 225 lbs, select pound plates
**Expected Behavior**:
- Calculator shows: Bar (45 lbs) + 2×45 lb plates + 2×25 lb plates + 2×5 lb plates
- Visual representation of bar with plates
- Exact weight calculation: 225 lbs

#### 7.3 Weight Calculation - Kilograms
**Action**: Switch to kg mode, enter target weight of 100 kg
**Expected Behavior**:
- Calculator shows: Bar (20 kg) + 2×20 kg plates + 2×15 kg plates + 2×5 kg plates
- Metric plate sizes used
- Exact weight calculation: 100 kg

#### 7.4 Impossible Weight Handling
**Action**: Enter target weight that cannot be achieved with available plates (e.g., 37 lbs)
**Expected Behavior**:
- Calculator shows closest possible weight below target
- Alternative options displayed (e.g., "Closest: 35 lbs" or "Add micro-plates for exact weight")
- Clear indication that exact weight is not achievable

#### 7.5 Plate Calculator Integration
**Action**: Accept calculated plate configuration and return to set logging
**Expected Behavior**:
- Calculated weight automatically filled into weight field
- Set logging continues normally
- Calculator preferences (unit, available plates) persist

**Success Criteria**:
- ✅ Accurate plate calculations for both kg and lb systems
- ✅ Visual representation helps user understand plate loading
- ✅ Graceful handling of impossible weight combinations
- ✅ Unit preferences persist across calculator uses

**Data Validation**:
```swift
// Standard plate sets for validation
let standardLbPlates = [45, 35, 25, 10, 5, 2.5]
let standardKgPlates = [20, 15, 10, 5, 2.5, 1.25]
let barWeight = unitSystem == .lb ? 45 : 20
```

---

## Edge Case Validation Scenarios

### Edge Case 1: Offline Functionality

#### EC1.1 Complete Offline Workout
**Setup**: Disable internet connection, airplane mode with WiFi/cellular off
**Action**: Start new workout, add exercises, log sets, complete workout
**Expected Behavior**:
- All workout logging functions work normally
- Data stored in local Core Data
- No error messages about connectivity
- Sync pending indicator visible

**Success Criteria**:
- ✅ Full workout logging capability without internet
- ✅ Data integrity maintained in offline mode
- ✅ User experience unchanged from online mode

#### EC1.2 Offline to Online Sync
**Action**: Re-enable internet connection after offline workout
**Expected Behavior**:
- Automatic sync to iCloud initiated
- Sync status indicator shows progress
- All offline data successfully uploaded
- No data loss or corruption

---

### Edge Case 2: Sync Conflict Resolution

#### EC2.1 Simultaneous Device Editing
**Setup**: Edit same workout on iPhone and iPad simultaneously
**Action**: Make conflicting changes, then sync both devices
**Expected Behavior**:
- Conflict detection triggered
- User prompted to resolve conflicts manually
- Clear comparison view of conflicting data
- Option to choose device A, device B, or merge manually

#### EC2.2 Conflict Resolution Interface
**Action**: Choose to keep iPhone version during conflict resolution
**Expected Behavior**:
- Selected version preserved across all devices
- Conflicting version archived or discarded as chosen
- Sync status updated to "resolved"
- No duplicate data created

**Success Criteria**:
- ✅ Conflicts detected reliably
- ✅ Resolution interface is user-friendly
- ✅ Data integrity maintained post-resolution
- ✅ No silent data loss

---

### Edge Case 3: HealthKit Permission Denial Handling

#### EC3.1 Workout Without HealthKit
**Setup**: Deny HealthKit permissions completely
**Action**: Complete full workout with multiple exercises
**Expected Behavior**:
- Workout logs normally within app
- No HealthKit data written
- Clear messaging about missing HealthKit integration
- Option to enable HealthKit in settings

#### EC3.2 Partial HealthKit Permissions
**Setup**: Grant read permissions but deny write permissions
**Action**: Complete workout and attempt HealthKit sync
**Expected Behavior**:
- App can read existing HealthKit exercise data
- Workout data not written to HealthKit
- User notified about partial integration
- Settings allow enabling write permissions

**Success Criteria**:
- ✅ App functions normally with no HealthKit permissions
- ✅ Partial permissions handled gracefully
- ✅ User can modify permissions without app restart

---

### Edge Case 4: Background App Behavior During Rest Timer

#### EC4.1 Extended Background Time
**Setup**: Start 5-minute rest timer
**Action**: Background app for 10 minutes (exceeding iOS background limits)
**Expected Behavior**:
- Timer state preserved when app returns to foreground
- Correct time calculation despite background suspension
- Notification delivered if timer completed while backgrounded
- No timer corruption or incorrect state

#### EC4.2 System Resource Pressure
**Setup**: Start rest timer, then launch multiple memory-intensive apps
**Action**: Return to Gigi Gains after potential memory pressure termination
**Expected Behavior**:
- App restores timer state correctly
- Workout data preserved
- Timer calculations account for suspension time
- Graceful recovery from process termination

**Success Criteria**:
- ✅ Timer reliability across background/foreground transitions
- ✅ Accurate time calculations despite iOS background limitations
- ✅ Workout data never lost due to backgrounding

---

### Edge Case 5: Invalid Data Entry Handling

#### EC5.1 Extreme Value Validation
**Action**: Attempt to enter weight of 10,000 lbs, reps of 1000, RPE of 15
**Expected Behavior**:
- Input validation prevents extreme values
- Clear error messages explain limits
- Suggested reasonable alternatives provided
- Form state preserved for valid fields

#### EC5.2 Data Type Validation
**Action**: Attempt to enter non-numeric characters in weight/reps fields
**Expected Behavior**:
- Numeric keyboard enforced on mobile
- Non-numeric input filtered out
- Decimal precision limited appropriately (weight: 1 decimal, reps: whole numbers)

#### EC5.3 Required Field Validation
**Action**: Attempt to save set with empty weight or reps
**Expected Behavior**:
- Save operation prevented
- Clear indication of required fields
- User guided to complete missing information
- No partial/corrupted data saved

**Success Criteria**:
- ✅ All input validation prevents data corruption
- ✅ Error messages are helpful and specific
- ✅ User experience remains smooth despite validation
- ✅ Edge cases don't cause app crashes

---

## Performance Benchmarks

### Database Operations
- **Workout Creation**: < 100ms
- **Set Logging**: < 500ms
- **Exercise History Loading**: < 1s for 6 months of data
- **Chart Rendering**: < 1s for 100 workouts
- **iCloud Sync**: < 5s for typical workout data

### Memory Usage
- **Baseline App**: < 50MB RAM
- **With Charts**: < 75MB RAM
- **During Image Loading**: < 100MB RAM
- **Background Mode**: < 10MB RAM

### Battery Impact
- **Active Workout (1 hour)**: < 5% battery drain
- **Background Timer**: < 1% additional drain
- **iCloud Sync**: < 1% per sync operation

---

## Automated Testing Integration Points

### Unit Test Coverage Areas
- Exercise 1RM calculations (Epley formula)
- Plate calculator algorithms
- RPE validation ranges
- Date/time handling for workout sessions
- Core Data relationship integrity

### Integration Test Hooks
- HealthKit authorization status monitoring
- iCloud sync completion callbacks
- Background task completion handlers
- Local notification delivery verification
- Core Data migration testing

### UI Test Automation Targets
- Complete workout flow automation
- Exercise library navigation
- Rest timer functionality
- Routine creation and reuse
- Settings and preferences

### Performance Test Scenarios
- Large dataset rendering (1000+ workouts)
- Concurrent user data modifications
- Background/foreground transition stress testing
- Memory pressure simulation
- Network connectivity variations

---

## Success Criteria Summary

### Functional Requirements Validation
- ✅ **FR-001**: Exercise logging with weight, reps, RPE
- ✅ **FR-002**: Comprehensive exercise library
- ✅ **FR-003**: Superset and circuit support
- ✅ **FR-004**: Rest timer with background notifications
- ✅ **FR-005**: Routine creation and reuse
- ✅ **FR-006**: Personal record tracking
- ✅ **FR-007**: Weekly volume charts
- ✅ **FR-008**: CSV export functionality
- ✅ **FR-009**: Plate calculator (kg/lb)
- ✅ **FR-010**: HealthKit integration
- ✅ **FR-011**: Core Data with iCloud sync
- ✅ **FR-012**: Workout history and filtering
- ✅ **FR-013**: Progression graphs
- ✅ **FR-014**: Offline functionality
- ✅ **FR-015**: iOS/iPadOS compatibility
- ✅ **FR-016**: Privacy compliance
- ✅ **FR-017**: Data migration support
- ✅ **FR-018**: Clear permission prompts

### Constitutional Compliance (TDD Validation)
- ✅ All acceptance scenarios have clear test steps
- ✅ Success criteria are measurable and objective
- ✅ Edge cases identified and tested
- ✅ Integration points validated
- ✅ Performance benchmarks established
- ✅ Error handling verified
- ✅ Data integrity confirmed across all scenarios

---

*This quickstart guide serves as the definitive testing specification for Gigi Gains v1. All scenarios should pass before considering the feature complete and ready for production deployment.*