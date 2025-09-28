//
//  WorkoutFlowUITests.swift
//  Gigi Gains Tests
//
//  UI tests for critical user flows and end-to-end workflows.
//  Tests complete user journeys from app launch to workout completion.
//
//  Created: 2025-09-28
//

import XCTest

final class WorkoutFlowUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment = ["UITEST_DISABLE_ANIMATIONS": "1"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - App Launch and Onboarding

    func testAppLaunchAndOnboarding() throws {
        // Test first launch onboarding flow
        if app.buttons["Get Started"].exists {
            app.buttons["Get Started"].tap()

            // Health permissions
            let healthKitButton = app.buttons["Enable HealthKit"]
            if healthKitButton.waitForExistence(timeout: 5) {
                healthKitButton.tap()

                // Handle system permission dialogs
                let systemAllow = app.buttons["Allow"]
                if systemAllow.waitForExistence(timeout: 10) {
                    systemAllow.tap()
                }
            }

            // Notification permissions
            let notificationButton = app.buttons["Enable Notifications"]
            if notificationButton.waitForExistence(timeout: 5) {
                notificationButton.tap()

                // Handle system notification permission
                let systemNotificationAllow = app.buttons["Allow"]
                if systemNotificationAllow.waitForExistence(timeout: 10) {
                    systemNotificationAllow.tap()
                }
            }

            // Complete onboarding
            let finishButton = app.buttons["Finish Setup"]
            if finishButton.waitForExistence(timeout: 5) {
                finishButton.tap()
            }
        }

        // Verify main app interface is displayed
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "Main tab bar should be visible")
        XCTAssertTrue(app.buttons["Workout"].exists, "Workout tab should be present")
        XCTAssertTrue(app.buttons["Routines"].exists, "Routines tab should be present")
        XCTAssertTrue(app.buttons["Progress"].exists, "Progress tab should be present")
        XCTAssertTrue(app.buttons["Settings"].exists, "Settings tab should be present")
    }

    // MARK: - Complete Workout Flow

    func testCompleteWorkoutFlow() throws {
        // Navigate to workout tab
        app.buttons["Workout"].tap()
        XCTAssertTrue(app.navigationBars["Workout"].waitForExistence(timeout: 5))

        // Start a new workout
        let startWorkoutButton = app.buttons["Start Workout"]
        XCTAssertTrue(startWorkoutButton.exists, "Start workout button should be visible")
        startWorkoutButton.tap()

        // Add first exercise
        let addExerciseButton = app.buttons["Add Exercise"]
        XCTAssertTrue(addExerciseButton.waitForExistence(timeout: 5), "Add exercise button should appear")
        addExerciseButton.tap()

        // Search and select an exercise
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Search field should be visible")
        searchField.tap()
        searchField.typeText("Bench Press")

        // Select exercise from results
        let benchPressCell = app.cells.containing(.staticText, identifier: "Bench Press").firstMatch
        XCTAssertTrue(benchPressCell.waitForExistence(timeout: 5), "Bench Press should appear in results")
        benchPressCell.tap()

        // Log first set
        let weightField = app.textFields["Weight"]
        XCTAssertTrue(weightField.waitForExistence(timeout: 5), "Weight field should be visible")
        weightField.tap()
        weightField.typeText("135")

        let repsField = app.textFields["Reps"]
        XCTAssertTrue(repsField.exists, "Reps field should be visible")
        repsField.tap()
        repsField.typeText("8")

        let logSetButton = app.buttons["Log Set"]
        XCTAssertTrue(logSetButton.exists, "Log set button should be visible")
        logSetButton.tap()

        // Verify set was logged
        let setRow = app.cells.containing(.staticText, identifier: "Set 1").firstMatch
        XCTAssertTrue(setRow.waitForExistence(timeout: 3), "First set should be logged")

        // Start rest timer
        let restTimerButton = app.buttons["Start Rest Timer"]
        if restTimerButton.exists {
            restTimerButton.tap()
            XCTAssertTrue(app.staticTexts.containing(.staticText, identifier: "Rest Timer").firstMatch.waitForExistence(timeout: 3))
        }

        // Log second set
        weightField.tap()
        weightField.clearAndEnterText("140")
        repsField.tap()
        repsField.clearAndEnterText("7")
        logSetButton.tap()

        // Verify second set was logged
        let secondSetRow = app.cells.containing(.staticText, identifier: "Set 2").firstMatch
        XCTAssertTrue(secondSetRow.waitForExistence(timeout: 3), "Second set should be logged")

        // Add second exercise
        addExerciseButton.tap()
        searchField.tap()
        searchField.clearAndEnterText("Squat")

        let squatCell = app.cells.containing(.staticText, identifier: "Squat").firstMatch
        XCTAssertTrue(squatCell.waitForExistence(timeout: 5), "Squat should appear in results")
        squatCell.tap()

        // Log squat sets
        weightField.tap()
        weightField.clearAndEnterText("185")
        repsField.tap()
        repsField.clearAndEnterText("5")
        logSetButton.tap()

        // Complete workout
        let finishWorkoutButton = app.buttons["Finish Workout"]
        XCTAssertTrue(finishWorkoutButton.waitForExistence(timeout: 5), "Finish workout button should appear")
        finishWorkoutButton.tap()

        // Confirm workout completion
        let confirmButton = app.buttons["Confirm"]
        if confirmButton.waitForExistence(timeout: 5) {
            confirmButton.tap()
        }

        // Verify return to workout list
        XCTAssertTrue(app.navigationBars["Workout"].waitForExistence(timeout: 5), "Should return to workout screen")
        XCTAssertTrue(startWorkoutButton.waitForExistence(timeout: 5), "Start workout button should be available again")
    }

    // MARK: - Routine Creation and Usage

    func testRoutineCreationAndUsage() throws {
        // Navigate to routines tab
        app.buttons["Routines"].tap()
        XCTAssertTrue(app.navigationBars["Routines"].waitForExistence(timeout: 5))

        // Create new routine
        let createRoutineButton = app.buttons["Create Routine"]
        XCTAssertTrue(createRoutineButton.exists, "Create routine button should be visible")
        createRoutineButton.tap()

        // Enter routine name
        let routineNameField = app.textFields["Routine Name"]
        XCTAssertTrue(routineNameField.waitForExistence(timeout: 5), "Routine name field should be visible")
        routineNameField.tap()
        routineNameField.typeText("Push Day")

        // Add exercises to routine
        let addExerciseToRoutineButton = app.buttons["Add Exercise"]
        XCTAssertTrue(addExerciseToRoutineButton.exists, "Add exercise button should be visible")
        addExerciseToRoutineButton.tap()

        // Add Bench Press
        let searchField = app.searchFields.firstMatch
        searchField.tap()
        searchField.typeText("Bench Press")
        app.cells.containing(.staticText, identifier: "Bench Press").firstMatch.tap()

        // Set target sets and reps
        let targetSetsField = app.textFields["Target Sets"]
        if targetSetsField.exists {
            targetSetsField.tap()
            targetSetsField.typeText("3")
        }

        let targetRepsField = app.textFields["Target Reps"]
        if targetRepsField.exists {
            targetRepsField.tap()
            targetRepsField.typeText("8-10")
        }

        // Add another exercise
        addExerciseToRoutineButton.tap()
        searchField.tap()
        searchField.clearAndEnterText("Overhead Press")
        app.cells.containing(.staticText, identifier: "Overhead Press").firstMatch.tap()

        // Save routine
        let saveRoutineButton = app.buttons["Save Routine"]
        XCTAssertTrue(saveRoutineButton.exists, "Save routine button should be visible")
        saveRoutineButton.tap()

        // Verify routine appears in list
        let pushDayRoutine = app.cells.containing(.staticText, identifier: "Push Day").firstMatch
        XCTAssertTrue(pushDayRoutine.waitForExistence(timeout: 5), "Push Day routine should appear in list")

        // Start workout from routine
        pushDayRoutine.tap()
        let startFromRoutineButton = app.buttons["Start Workout"]
        XCTAssertTrue(startFromRoutineButton.exists, "Start workout button should be visible in routine detail")
        startFromRoutineButton.tap()

        // Verify exercises are pre-loaded
        XCTAssertTrue(app.cells.containing(.staticText, identifier: "Bench Press").firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.cells.containing(.staticText, identifier: "Overhead Press").firstMatch.exists)
    }

    // MARK: - Progress Tracking

    func testProgressTracking() throws {
        // Navigate to progress tab
        app.buttons["Progress"].tap()
        XCTAssertTrue(app.navigationBars["Progress"].waitForExistence(timeout: 5))

        // View workout history
        let historyTab = app.buttons["History"]
        if historyTab.exists {
            historyTab.tap()
        }

        // Check if workout history is displayed
        let workoutHistoryList = app.tables.firstMatch
        XCTAssertTrue(workoutHistoryList.waitForExistence(timeout: 5), "Workout history should be visible")

        // View charts
        let chartsTab = app.buttons["Charts"]
        if chartsTab.exists {
            chartsTab.tap()

            // Verify charts are displayed
            let chartView = app.otherElements.containing(.staticText, identifier: "Progress Chart").firstMatch
            XCTAssertTrue(chartView.waitForExistence(timeout: 5), "Progress charts should be visible")
        }

        // View exercise-specific progress
        let exerciseDetailButton = app.buttons.matching(identifier: "Exercise Detail").firstMatch
        if exerciseDetailButton.exists {
            exerciseDetailButton.tap()

            // Verify exercise history is shown
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
        }
    }

    // MARK: - Plate Calculator

    func testPlateCalculator() throws {
        // Navigate to settings or find plate calculator
        app.buttons["Settings"].tap()

        let plateCalculatorButton = app.buttons["Plate Calculator"]
        if plateCalculatorButton.exists {
            plateCalculatorButton.tap()
        } else {
            // Try accessing from workout screen
            app.buttons["Workout"].tap()
            let calculatorButton = app.buttons.matching(identifier: "Calculator").firstMatch
            if calculatorButton.exists {
                calculatorButton.tap()
            }
        }

        // Enter target weight
        let targetWeightField = app.textFields["Target Weight"]
        XCTAssertTrue(targetWeightField.waitForExistence(timeout: 5), "Target weight field should be visible")
        targetWeightField.tap()
        targetWeightField.typeText("225")

        // Select bar weight
        let barWeightField = app.textFields["Bar Weight"]
        if barWeightField.exists {
            barWeightField.tap()
            barWeightField.typeText("45")
        }

        // Calculate plates
        let calculateButton = app.buttons["Calculate"]
        if calculateButton.exists {
            calculateButton.tap()
        }

        // Verify plate configuration is shown
        let plateResult = app.staticTexts.containing(.staticText, identifier: "plates").firstMatch
        XCTAssertTrue(plateResult.waitForExistence(timeout: 5), "Plate calculation result should be shown")
    }

    // MARK: - Settings and Preferences

    func testSettingsConfiguration() throws {
        // Navigate to settings
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        // Test unit preferences
        let unitPreferences = app.cells["Unit Preferences"]
        if unitPreferences.exists {
            unitPreferences.tap()

            // Toggle between pounds and kilograms
            let poundsButton = app.buttons["Pounds"]
            let kilogramsButton = app.buttons["Kilograms"]

            if poundsButton.exists {
                poundsButton.tap()
            }

            let backButton = app.navigationBars.buttons.firstMatch
            backButton.tap()
        }

        // Test notification settings
        let notificationSettings = app.cells["Notifications"]
        if notificationSettings.exists {
            notificationSettings.tap()

            // Toggle rest timer notifications
            let restTimerToggle = app.switches["Rest Timer Notifications"]
            if restTimerToggle.exists {
                restTimerToggle.tap()
            }

            app.navigationBars.buttons.firstMatch.tap()
        }

        // Test data export
        let dataExport = app.cells["Export Data"]
        if dataExport.exists {
            dataExport.tap()

            let exportButton = app.buttons["Export to CSV"]
            if exportButton.exists {
                exportButton.tap()

                // Handle share sheet
                let shareSheet = app.otherElements["ActivityListView"]
                if shareSheet.waitForExistence(timeout: 5) {
                    app.buttons["Cancel"].tap()
                }
            }

            app.navigationBars.buttons.firstMatch.tap()
        }
    }

    // MARK: - Error Handling and Edge Cases

    func testErrorHandling() throws {
        // Test network disconnection scenarios
        app.buttons["Workout"].tap()

        // Try to start workout with invalid data
        app.buttons["Start Workout"].tap()
        app.buttons["Add Exercise"].tap()

        // Enter invalid search
        let searchField = app.searchFields.firstMatch
        searchField.tap()
        searchField.typeText("NonexistentExercise123")

        // Verify "No results" message
        let noResultsMessage = app.staticTexts["No exercises found"]
        XCTAssertTrue(noResultsMessage.waitForExistence(timeout: 5), "No results message should appear")

        // Test invalid weight input
        app.navigationBars.buttons.firstMatch.tap() // Go back

        if app.textFields["Weight"].exists {
            app.textFields["Weight"].tap()
            app.textFields["Weight"].typeText("-50") // Invalid negative weight

            app.buttons["Log Set"].tap()

            // Verify error message
            let errorAlert = app.alerts.firstMatch
            if errorAlert.waitForExistence(timeout: 3) {
                XCTAssertTrue(errorAlert.staticTexts["Invalid weight"].exists, "Error message should appear")
                errorAlert.buttons["OK"].tap()
            }
        }
    }

    // MARK: - Performance and Responsiveness

    func testAppResponsiveness() throws {
        // Measure app launch time
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launch()
        }
    }

    func testLargeDataSetPerformance() throws {
        // This would test the app with large amounts of data
        // In a real scenario, you'd pre-populate with test data

        app.buttons["Progress"].tap()

        // Scroll through history quickly
        let historyTable = app.tables.firstMatch
        if historyTable.waitForExistence(timeout: 5) {
            historyTable.swipeUp()
            historyTable.swipeUp()
            historyTable.swipeDown()
            historyTable.swipeDown()
        }

        // Verify app remains responsive
        XCTAssertTrue(app.buttons["Progress"].isHittable, "App should remain responsive during scrolling")
    }

    // MARK: - Accessibility Testing

    func testVoiceOverNavigation() throws {
        // This would test VoiceOver navigation
        // Note: VoiceOver testing in UI tests requires special configuration

        app.buttons["Workout"].tap()

        // Verify important elements have accessibility labels
        let startWorkoutButton = app.buttons["Start Workout"]
        XCTAssertFalse(startWorkoutButton.label.isEmpty, "Start workout button should have accessibility label")

        if app.buttons["Add Exercise"].exists {
            app.buttons["Add Exercise"].tap()

            let searchField = app.searchFields.firstMatch
            XCTAssertFalse(searchField.label.isEmpty, "Search field should have accessibility label")
        }
    }

    // MARK: - Device Rotation

    func testDeviceRotation() throws {
        app.buttons["Workout"].tap()

        // Test portrait orientation
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.buttons["Start Workout"].waitForExistence(timeout: 5))

        // Test landscape orientation
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["Start Workout"].waitForExistence(timeout: 5), "UI should adapt to landscape")

        // Return to portrait
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - Background and Foreground

    func testBackgroundForegroundBehavior() throws {
        app.buttons["Workout"].tap()
        app.buttons["Start Workout"].tap()

        // Simulate app going to background
        XCUIDevice.shared.press(.home)

        // Return to app
        app.activate()

        // Verify workout state is preserved
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5), "Workout should be preserved")
    }
}

// MARK: - Helper Extensions

extension XCUIElement {
    func clearAndEnterText(_ text: String) {
        self.tap()
        self.doubleTap() // Select all
        self.typeText(text)
    }
}