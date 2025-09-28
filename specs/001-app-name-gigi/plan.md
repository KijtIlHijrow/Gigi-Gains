
# Implementation Plan: Gigi Gains iOS Workout Tracking App v1

**Branch**: `001-app-name-gigi` | **Date**: 2025-09-28 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-app-name-gigi/spec.md`

## Execution Flow (/plan command scope)
```
1. Load feature spec from Input path
   → If not found: ERROR "No feature spec at {path}"
2. Fill Technical Context (scan for NEEDS CLARIFICATION)
   → Detect Project Type from file system structure or context (web=frontend+backend, mobile=app+api)
   → Set Structure Decision based on project type
3. Fill the Constitution Check section based on the content of the constitution document.
4. Evaluate Constitution Check section below
   → If violations exist: Document in Complexity Tracking
   → If no justification possible: ERROR "Simplify approach first"
   → Update Progress Tracking: Initial Constitution Check
5. Execute Phase 0 → research.md
   → If NEEDS CLARIFICATION remain: ERROR "Resolve unknowns"
6. Execute Phase 1 → contracts, data-model.md, quickstart.md, agent-specific template file (e.g., `CLAUDE.md` for Claude Code, `.github/copilot-instructions.md` for GitHub Copilot, `GEMINI.md` for Gemini CLI, `QWEN.md` for Qwen Code or `AGENTS.md` for opencode).
7. Re-evaluate Constitution Check section
   → If new violations: Refactor design, return to Phase 1
   → Update Progress Tracking: Post-Design Constitution Check
8. Plan Phase 2 → Describe task generation approach (DO NOT create tasks.md)
9. STOP - Ready for /tasks command
```

**IMPORTANT**: The /plan command STOPS at step 7. Phases 2-4 are executed by other commands:
- Phase 2: /tasks command creates tasks.md
- Phase 3-4: Implementation execution (manual or via tools)

## Summary
Gigi Gains is an iOS/iPadOS workout tracking app that enables users to log strength training sessions with exercises, sets, reps, weight, and RPE tracking. Key features include a comprehensive exercise library, superset/circuit support, rest timers with background notifications, routine creation and reuse, progression tracking with PR calculations and weekly volume charts, CSV export capabilities, plate calculator, HealthKit integration, Core Data storage with iCloud sync, and offline-first functionality. The app prioritizes user privacy with no third-party analytics and uses modern Swift/SwiftUI architecture following TDD principles.

## Technical Context
**Language/Version**: Swift 5.10+ with Xcode 16
**Primary Dependencies**: SwiftUI, Combine, XCTest, HealthKit, CloudKit, Core Data
**Storage**: Core Data with NSPersistentCloudKitContainer for iCloud sync
**Testing**: XCTest framework with snapshot testing for SwiftUI views, UI tests for critical flows
**Target Platform**: iOS 15+ and iPadOS 15+ (future Apple Watch compatibility planned)
**Project Type**: mobile - iOS app with offline-first architecture
**Performance Goals**: 60 fps UI, smooth workout logging, responsive rest timer notifications
**Constraints**: Offline-capable core functionality, privacy-first (no third-party analytics), Swift Package Manager only
**Scale/Scope**: Single-user personal fitness tracking, ~15-20 core screens, comprehensive exercise library

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Constitutional Compliance Evaluation**:

✅ **Swift-First Development**: Feature spec aligns with Swift 5.10+, SwiftUI, and Combine requirements
✅ **Test-Driven Development**: Plan includes XCTest framework with unit, snapshot, and UI testing approach
✅ **Code Quality & Architecture**: SOLID principles and dependency injection will be followed in implementation
✅ **Accessibility Excellence**: VoiceOver support and WCAG AA+ compliance planned for all UI components
✅ **Privacy by Design**: No third-party analytics, HealthKit permissions with clear prompts, local/iCloud storage only
✅ **Technology Standards**: All dependencies (SwiftUI, Combine, XCTest, HealthKit, CloudKit) are pre-approved
✅ **Development Workflow**: Offline-first architecture specified, DocC documentation planned
✅ **Governance**: All requirements align with constitutional principles

**Gate Status**: PASS - No constitutional violations detected

## Project Structure

### Documentation (this feature)
```
specs/[###-feature]/
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── data-model.md        # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
├── contracts/           # Phase 1 output (/plan command)
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (repository root)
```
GigiGains/
├── Sources/
│   ├── Models/           # Core Data entities, domain models
│   ├── Services/         # Business logic, data services
│   ├── Views/           # SwiftUI views and components
│   ├── Extensions/      # Swift extensions and utilities
│   ├── Managers/        # HealthKit, iCloud, notification managers
│   └── Resources/       # Assets, Core Data models, exercise library
├── Tests/
│   ├── UnitTests/       # Model and service unit tests
│   ├── IntegrationTests/ # HealthKit, Core Data integration tests
│   ├── UITests/         # SwiftUI user interface tests
│   └── SnapshotTests/   # SwiftUI snapshot tests
├── Package.swift        # Swift Package Manager configuration
└── Documentation/       # DocC documentation
```

**Structure Decision**: Selected mobile iOS app structure using Swift Package Manager. This structure separates concerns into clear modules: Models for data layer, Services for business logic, Views for SwiftUI UI components, Managers for system integrations, and comprehensive test coverage across all layers. The structure supports the constitutional requirements for TDD, clean architecture, and offline-first design.

## Phase 0: Outline & Research
1. **Extract unknowns from Technical Context** above:
   - For each NEEDS CLARIFICATION → research task
   - For each dependency → best practices task
   - For each integration → patterns task

2. **Generate and dispatch research agents**:
   ```
   For each unknown in Technical Context:
     Task: "Research {unknown} for {feature context}"
   For each technology choice:
     Task: "Find best practices for {tech} in {domain}"
   ```

3. **Consolidate findings** in `research.md` using format:
   - Decision: [what was chosen]
   - Rationale: [why chosen]
   - Alternatives considered: [what else evaluated]

**Output**: research.md with all NEEDS CLARIFICATION resolved

## Phase 1: Design & Contracts
*Prerequisites: research.md complete*

1. **Extract entities from feature spec** → `data-model.md`:
   - Entity name, fields, relationships
   - Validation rules from requirements
   - State transitions if applicable

2. **Generate API contracts** from functional requirements:
   - For each user action → endpoint
   - Use standard REST/GraphQL patterns
   - Output OpenAPI/GraphQL schema to `/contracts/`

3. **Generate contract tests** from contracts:
   - One test file per endpoint
   - Assert request/response schemas
   - Tests must fail (no implementation yet)

4. **Extract test scenarios** from user stories:
   - Each story → integration test scenario
   - Quickstart test = story validation steps

5. **Update agent file incrementally** (O(1) operation):
   - Run `.specify/scripts/bash/update-agent-context.sh claude`
     **IMPORTANT**: Execute it exactly as specified above. Do not add or remove any arguments.
   - If exists: Add only NEW tech from current plan
   - Preserve manual additions between markers
   - Update recent changes (keep last 3)
   - Keep under 150 lines for token efficiency
   - Output to repository root

**Output**: data-model.md, /contracts/*, failing tests, quickstart.md, agent-specific file

## Phase 2: Task Planning Approach
*This section describes what the /tasks command will do - DO NOT execute during /plan*

**Task Generation Strategy**:
- Load `.specify/templates/tasks-template.md` as base template structure
- Generate comprehensive tasks from Phase 1 design artifacts:
  * 11 contract protocols → 11 contract test tasks [P] (unit tests for each protocol interface)
  * 8 Core Data entities → 8 model creation tasks [P] (entity definitions with CloudKit compatibility)
  * 12 quickstart scenarios → 12 integration test tasks (validating end-to-end user flows)
  * 11 service implementations → 11 implementation tasks (making contract tests pass)
  * 15+ SwiftUI views → UI implementation and snapshot test tasks
  * 7 manager implementations → system integration tasks (HealthKit, CloudKit, notifications)

**Ordering Strategy (TDD-First)**:
1. **Foundation Layer [P]**: Core Data model creation (8 tasks) - parallel execution since entities are independent
2. **Contract Testing [P]**: Protocol test suites (11 tasks) - parallel execution using mock dependencies
3. **Service Implementation**: Business logic layer (11 tasks) - sequential based on dependencies
4. **Manager Integration**: System service integration (7 tasks) - depends on services
5. **UI Layer**: SwiftUI views and navigation (15+ tasks) - depends on services and managers
6. **Integration Validation**: Quickstart scenario implementation (12 tasks) - final validation
7. **Performance & Polish**: Optimization, accessibility, error handling refinements

**Dependency Mapping**:
- Models must complete before service implementation
- Contract tests enable parallel service development
- Services required before UI layer
- Managers bridge between services and system frameworks
- Integration tests validate complete user journeys

**Parallel Execution Markers [P]**:
- All Core Data entity tasks (independent schemas)
- All contract test tasks (mock-based, no dependencies)
- UI view tasks within same layer (independent components)
- Repository implementation tasks (separated by entity)

**Estimated Output**: 35-40 numbered, dependency-ordered tasks in tasks.md with TDD workflow

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation
*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)  
**Phase 4**: Implementation (execute tasks.md following constitutional principles)  
**Phase 5**: Validation (run tests, execute quickstart.md, performance validation)

## Complexity Tracking
*Fill ONLY if Constitution Check has violations that must be justified*

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |


## Progress Tracking
*This checklist is updated during execution flow*

**Phase Status**:
- [x] Phase 0: Research complete (/plan command)
- [x] Phase 1: Design complete (/plan command)
- [x] Phase 2: Task planning complete (/plan command - describe approach only)
- [ ] Phase 3: Tasks generated (/tasks command)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:
- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved
- [x] Complexity deviations documented (N/A - no violations)

---
*Based on Constitution v1.0.0 - See `/memory/constitution.md`*
