# Feature Specification: Gigi Gains iOS Workout Tracking App v1

**Feature Branch**: `001-app-name-gigi`
**Created**: 2025-09-27
**Status**: Draft
**Input**: User description: "App name: Gigi Gains. Platform: iOS + iPadOS. Future Apple Watch companion is out of scope for v1 but should be planned for. Scope v1: User can log workouts: exercises, sets, reps, weight, RPE. Superset and circuit support. Rest timer with background notifications. Exercise library with categories and muscle groups. Routines: create, save, and reuse. Progression tracking: PRs, weekly volume chart, export CSV. Plate calculator (kg/lb). HealthKit integration: write completed workouts, read exercises. Core Data storage with iCloud sync. History: browse past sessions, filter by exercise, show graphs. Non-goals v1: Social/community features. Subscriptions or monetisation. Advanced coaching marketplace. Constraints: Swift Package Manager only, no CocoaPods. Core Data + NSPersistentCloudKitContainer with lightweight migrations. GitHub Actions CI, Fastlane optional. SnapshotTesting package for UI verification. Strict privacy strings in Info.plist."

---

## ⚡ Quick Guidelines
- ✅ Focus on WHAT users need and WHY
- ❌ Avoid HOW to implement (no tech stack, APIs, code structure)
- 👥 Written for business stakeholders, not developers

---

## User Scenarios & Testing *(mandatory)*

### Primary User Story
A fitness enthusiast opens Gigi Gains to log their strength training workout. They create a new session, add exercises from the built-in library, log their sets with weight and reps, track their effort level (RPE), and use the rest timer between sets. After completing their workout, they review their progress compared to previous sessions and save the workout to their routine library for future use. The app automatically syncs their data across devices and integrates with Apple Health.

### Acceptance Scenarios
1. **Given** the user has opened the app for the first time, **When** they grant HealthKit permissions, **Then** the app can read exercise data and write completed workouts to Apple Health
2. **Given** the user is starting a new workout, **When** they select exercises from the library, **Then** they can log sets with weight, reps, and RPE values
3. **Given** the user completes a set, **When** they start the rest timer, **Then** they receive background notifications when rest time is complete
4. **Given** the user has previous workout data, **When** they view their exercise history, **Then** they can see progression charts and personal records
5. **Given** the user creates a routine, **When** they save it, **Then** they can reuse it for future workouts
6. **Given** the user performs supersets or circuits, **When** they group exercises, **Then** the timer and logging flows accommodate non-linear exercise sequences
7. **Given** the user wants to load plates, **When** they use the plate calculator, **Then** they can determine the correct weight distribution in kg or lb

### Edge Cases
- What happens when the user has no internet connection but wants to log a workout?
- How does the system handle syncing conflicts when the same workout is edited on multiple devices? (User prompted to manually resolve conflicts)
- What happens when HealthKit permissions are denied or revoked?
- How does the app behave when running in background during rest timer?
- What happens when the user attempts to log invalid data (negative weight, impossible rep counts)?

## Requirements *(mandatory)*

### Functional Requirements
- **FR-001**: System MUST allow users to create and log workout sessions with exercises, sets, reps, weight, and RPE (1-10 scale)
- **FR-002**: System MUST provide a comprehensive exercise library organized by categories and muscle groups
- **FR-003**: System MUST support superset and circuit training with grouped exercise logging
- **FR-004**: System MUST provide a rest timer with background notifications when time expires (default: 2 minutes, user configurable)
- **FR-005**: System MUST allow users to create, save, and reuse workout routines
- **FR-006**: System MUST track and display personal records (PRs) for each exercise
- **FR-007**: System MUST generate weekly volume charts showing training progression
- **FR-008**: System MUST allow users to export workout data in CSV format with columns: Session Date, Duration, Exercise, Set Number, Reps, Weight, RPE
- **FR-009**: System MUST provide a plate calculator supporting both kg and lb weight units
- **FR-010**: System MUST integrate with HealthKit to write completed workouts and read exercise data
- **FR-011**: System MUST store all data locally with iCloud synchronization across user devices
- **FR-012**: System MUST provide workout history with filtering by exercise and date ranges
- **FR-013**: System MUST display progression graphs for individual exercises and overall training metrics
- **FR-014**: System MUST work offline with full workout logging capabilities
- **FR-015**: System MUST be compatible with iOS and iPadOS with responsive design
- **FR-016**: System MUST preserve user privacy with no third-party analytics or data sharing
- **FR-017**: System MUST handle data migration when app structure changes
- **FR-018**: System MUST provide clear permission prompts for HealthKit access with privacy explanations

## Clarifications

### Session 2025-09-27
- Q: How should PRs be calculated? → A: 1RM estimated using Epley formula (weight × (1 + reps/30))
- Q: What columns should the CSV export include? → A: Session Date, Duration, Exercise, Set Number, Reps, Weight, RPE
- Q: What RPE scale should be used? → A: 1-10 scale (traditional Borg RPE)
- Q: How should sync conflicts be resolved? → A: User prompt for manual resolution
- Q: What should the default rest timer duration be? → A: 2 minutes

### Key Entities *(include if feature involves data)*
- **Workout Session**: A complete training session with date, duration, exercises performed, and notes
- **Exercise**: A specific movement with name, category, muscle groups, and historical performance data
- **Set**: Individual work unit within an exercise containing reps, weight, RPE (1-10 scale), and completion status
- **Routine**: A saved template of exercises and set schemes that can be reused for future workouts
- **Personal Record**: The best estimated 1RM for a specific exercise calculated using Epley formula (weight × (1 + reps/30))
- **Exercise Library Entry**: Predefined exercise with category, muscle groups, and optional instructions
- **Training Volume**: Aggregated weekly/monthly metrics for progression tracking
- **Rest Timer**: Configurable countdown timer with background notification capability (default: 2 minutes)

---

## Review & Acceptance Checklist
*GATE: Automated checks run during main() execution*

### Content Quality
- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

### Requirement Completeness
- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

---

## Execution Status
*Updated by main() during processing*

- [x] User description parsed
- [x] Key concepts extracted
- [x] Ambiguities marked
- [x] User scenarios defined
- [x] Requirements generated
- [x] Entities identified
- [x] Review checklist passed

---
