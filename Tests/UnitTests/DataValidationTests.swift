//
//  DataValidationTests.swift
//  Gigi Gains Tests
//
//  Unit tests for data validation logic and business rule enforcement.
//  Tests input sanitization, boundary conditions, and constraint validation.
//
//  Created: 2025-09-28
//

import XCTest
@testable import GigiGains

final class DataValidationTests: XCTestCase {

    // MARK: - Exercise Data Validation

    func testExerciseNameValidation() {
        // Valid exercise names
        XCTAssertTrue(ExerciseValidator.isValidName("Bench Press"), "Standard exercise name should be valid")
        XCTAssertTrue(ExerciseValidator.isValidName("Barbell Back Squat"), "Multi-word exercise name should be valid")
        XCTAssertTrue(ExerciseValidator.isValidName("DB Chest Flyes"), "Exercise with abbreviation should be valid")
        XCTAssertTrue(ExerciseValidator.isValidName("21s Bicep Curls"), "Exercise with numbers should be valid")
        XCTAssertTrue(ExerciseValidator.isValidName("T-Bar Row"), "Exercise with hyphens should be valid")

        // Invalid exercise names
        XCTAssertFalse(ExerciseValidator.isValidName(""), "Empty name should be invalid")
        XCTAssertFalse(ExerciseValidator.isValidName("   "), "Whitespace-only name should be invalid")
        XCTAssertFalse(ExerciseValidator.isValidName("A"), "Single character name should be invalid")
        XCTAssertFalse(ExerciseValidator.isValidName("X".repeating(101)), "Name over 100 characters should be invalid")
        XCTAssertFalse(ExerciseValidator.isValidName("Test@Exercise"), "Name with special characters should be invalid")
        XCTAssertFalse(ExerciseValidator.isValidName("Exercise\nName"), "Name with newlines should be invalid")
        XCTAssertFalse(ExerciseValidator.isValidName("Exercise\tName"), "Name with tabs should be invalid")
    }

    func testMuscleGroupValidation() {
        let validMuscleGroups = ["Chest", "Back", "Shoulders", "Arms", "Legs", "Core", "Glutes", "Calves"]

        // Valid muscle groups
        for muscleGroup in validMuscleGroups {
            XCTAssertTrue(ExerciseValidator.isValidMuscleGroup(muscleGroup), "\(muscleGroup) should be valid")
        }

        // Case insensitive validation
        XCTAssertTrue(ExerciseValidator.isValidMuscleGroup("chest"), "Lowercase muscle group should be valid")
        XCTAssertTrue(ExerciseValidator.isValidMuscleGroup("SHOULDERS"), "Uppercase muscle group should be valid")
        XCTAssertTrue(ExerciseValidator.isValidMuscleGroup("ArMs"), "Mixed case muscle group should be valid")

        // Invalid muscle groups
        XCTAssertFalse(ExerciseValidator.isValidMuscleGroup(""), "Empty muscle group should be invalid")
        XCTAssertFalse(ExerciseValidator.isValidMuscleGroup("InvalidGroup"), "Non-standard muscle group should be invalid")
        XCTAssertFalse(ExerciseValidator.isValidMuscleGroup("123"), "Numeric muscle group should be invalid")
    }

    func testEquipmentValidation() {
        let validEquipment = ["Barbell", "Dumbbell", "Cable", "Machine", "Bodyweight", "Resistance Band", "Kettlebell"]

        // Valid equipment
        for equipment in validEquipment {
            XCTAssertTrue(ExerciseValidator.isValidEquipment(equipment), "\(equipment) should be valid")
        }

        // Empty equipment should be valid (bodyweight exercises)
        XCTAssertTrue(ExerciseValidator.isValidEquipment(nil), "Nil equipment should be valid for bodyweight")
        XCTAssertTrue(ExerciseValidator.isValidEquipment(""), "Empty equipment should be valid for bodyweight")

        // Invalid equipment
        XCTAssertFalse(ExerciseValidator.isValidEquipment("InvalidEquipment"), "Non-standard equipment should be invalid")
        XCTAssertFalse(ExerciseValidator.isValidEquipment("123"), "Numeric equipment should be invalid")
    }

    // MARK: - Workout Data Validation

    func testWorkoutDurationValidation() {
        // Valid durations
        XCTAssertTrue(WorkoutValidator.isValidDuration(60), "1 minute workout should be valid")
        XCTAssertTrue(WorkoutValidator.isValidDuration(3600), "1 hour workout should be valid")
        XCTAssertTrue(WorkoutValidator.isValidDuration(7200), "2 hour workout should be valid")
        XCTAssertTrue(WorkoutValidator.isValidDuration(10800), "3 hour workout should be valid")

        // Boundary cases
        XCTAssertTrue(WorkoutValidator.isValidDuration(30), "30 second workout should be valid")
        XCTAssertTrue(WorkoutValidator.isValidDuration(14400), "4 hour workout should be valid")

        // Invalid durations
        XCTAssertFalse(WorkoutValidator.isValidDuration(0), "Zero duration should be invalid")
        XCTAssertFalse(WorkoutValidator.isValidDuration(-100), "Negative duration should be invalid")
        XCTAssertFalse(WorkoutValidator.isValidDuration(29), "Under 30 seconds should be invalid")
        XCTAssertFalse(WorkoutValidator.isValidDuration(18000), "Over 5 hours should be invalid")
    }

    func testWorkoutNameValidation() {
        // Valid workout names
        XCTAssertTrue(WorkoutValidator.isValidName("Push Day"), "Standard workout name should be valid")
        XCTAssertTrue(WorkoutValidator.isValidName("Upper Body Strength"), "Multi-word workout name should be valid")
        XCTAssertTrue(WorkoutValidator.isValidName("Leg Day #1"), "Workout name with numbers should be valid")
        XCTAssertTrue(WorkoutValidator.isValidName("HIIT Session"), "Acronym workout name should be valid")

        // Invalid workout names
        XCTAssertFalse(WorkoutValidator.isValidName(""), "Empty workout name should be invalid")
        XCTAssertFalse(WorkoutValidator.isValidName("   "), "Whitespace-only workout name should be invalid")
        XCTAssertFalse(WorkoutValidator.isValidName("W"), "Single character workout name should be invalid")
        XCTAssertFalse(WorkoutValidator.isValidName("X".repeating(51)), "Workout name over 50 characters should be invalid")
    }

    func testSetValidation() {
        // Valid sets
        XCTAssertTrue(SetValidator.isValidSet(weight: 135, reps: 8), "Standard set should be valid")
        XCTAssertTrue(SetValidator.isValidSet(weight: 0, reps: 15), "Bodyweight set should be valid")
        XCTAssertTrue(SetValidator.isValidSet(weight: 2.5, reps: 1), "Light weight single rep should be valid")
        XCTAssertTrue(SetValidator.isValidSet(weight: 500, reps: 1), "Heavy single should be valid")
        XCTAssertTrue(SetValidator.isValidSet(weight: 45, reps: 50), "High rep set should be valid")

        // Invalid sets
        XCTAssertFalse(SetValidator.isValidSet(weight: -10, reps: 8), "Negative weight should be invalid")
        XCTAssertFalse(SetValidator.isValidSet(weight: 135, reps: 0), "Zero reps should be invalid")
        XCTAssertFalse(SetValidator.isValidSet(weight: 135, reps: -5), "Negative reps should be invalid")
        XCTAssertFalse(SetValidator.isValidSet(weight: 1500, reps: 8), "Unrealistic weight should be invalid")
        XCTAssertFalse(SetValidator.isValidSet(weight: 135, reps: 101), "Over 100 reps should be invalid")
    }

    func testRestTimeValidation() {
        // Valid rest times
        XCTAssertTrue(WorkoutValidator.isValidRestTime(30), "30 second rest should be valid")
        XCTAssertTrue(WorkoutValidator.isValidRestTime(120), "2 minute rest should be valid")
        XCTAssertTrue(WorkoutValidator.isValidRestTime(300), "5 minute rest should be valid")
        XCTAssertTrue(WorkoutValidator.isValidRestTime(600), "10 minute rest should be valid")

        // Invalid rest times
        XCTAssertFalse(WorkoutValidator.isValidRestTime(0), "Zero rest time should be invalid")
        XCTAssertFalse(WorkoutValidator.isValidRestTime(-30), "Negative rest time should be invalid")
        XCTAssertFalse(WorkoutValidator.isValidRestTime(14), "Under 15 seconds should be invalid")
        XCTAssertFalse(WorkoutValidator.isValidRestTime(1800), "Over 30 minutes should be invalid")
    }

    // MARK: - Plate Calculator Validation

    func testPlateWeightValidation() {
        // Standard plate weights
        let standardPlates = [2.5, 5.0, 10.0, 25.0, 35.0, 45.0]
        for weight in standardPlates {
            XCTAssertTrue(PlateValidator.isValidPlateWeight(weight), "\(weight) lb plate should be valid")
        }

        // Metric plate weights
        let metricPlates = [1.25, 2.5, 5.0, 10.0, 15.0, 20.0, 25.0]
        for weight in metricPlates {
            XCTAssertTrue(PlateValidator.isValidPlateWeight(weight), "\(weight) kg plate should be valid")
        }

        // Invalid plate weights
        XCTAssertFalse(PlateValidator.isValidPlateWeight(0), "Zero weight plate should be invalid")
        XCTAssertFalse(PlateValidator.isValidPlateWeight(-5), "Negative weight plate should be invalid")
        XCTAssertFalse(PlateValidator.isValidPlateWeight(0.5), "Under 1 lb plate should be invalid")
        XCTAssertFalse(PlateValidator.isValidPlateWeight(100), "Over 50 lb plate should be invalid")
        XCTAssertFalse(PlateValidator.isValidPlateWeight(37.3), "Non-standard weight should be invalid")
    }

    func testBarWeightValidation() {
        // Standard bar weights
        XCTAssertTrue(PlateValidator.isValidBarWeight(45), "Olympic barbell should be valid")
        XCTAssertTrue(PlateValidator.isValidBarWeight(35), "Women's barbell should be valid")
        XCTAssertTrue(PlateValidator.isValidBarWeight(15), "Training bar should be valid")
        XCTAssertTrue(PlateValidator.isValidBarWeight(20), "20kg barbell should be valid")

        // Invalid bar weights
        XCTAssertFalse(PlateValidator.isValidBarWeight(0), "Zero weight bar should be invalid")
        XCTAssertFalse(PlateValidator.isValidBarWeight(-10), "Negative bar weight should be invalid")
        XCTAssertFalse(PlateValidator.isValidBarWeight(5), "Too light bar should be invalid")
        XCTAssertFalse(PlateValidator.isValidBarWeight(100), "Too heavy bar should be invalid")
    }

    func testTargetWeightValidation() {
        // Valid target weights
        XCTAssertTrue(PlateValidator.isValidTargetWeight(45), "Bar weight only should be valid")
        XCTAssertTrue(PlateValidator.isValidTargetWeight(135), "Standard target weight should be valid")
        XCTAssertTrue(PlateValidator.isValidTargetWeight(500), "Heavy target weight should be valid")
        XCTAssertTrue(PlateValidator.isValidTargetWeight(67.5), "Fractional weight should be valid")

        // Invalid target weights
        XCTAssertFalse(PlateValidator.isValidTargetWeight(0), "Zero target weight should be invalid")
        XCTAssertFalse(PlateValidator.isValidTargetWeight(-100), "Negative target weight should be invalid")
        XCTAssertFalse(PlateValidator.isValidTargetWeight(30), "Below minimum bar weight should be invalid")
        XCTAssertFalse(PlateValidator.isValidTargetWeight(2000), "Unrealistic target weight should be invalid")
    }

    // MARK: - User Input Sanitization

    func testStringInputSanitization() {
        // Test trimming whitespace
        XCTAssertEqual(InputSanitizer.sanitizeName("  Bench Press  "), "Bench Press", "Should trim whitespace")
        XCTAssertEqual(InputSanitizer.sanitizeName("\t\nSquat\n\t"), "Squat", "Should trim tabs and newlines")

        // Test removing multiple spaces
        XCTAssertEqual(InputSanitizer.sanitizeName("Barbell  Back   Squat"), "Barbell Back Squat", "Should normalize spaces")

        // Test removing special characters
        XCTAssertEqual(InputSanitizer.sanitizeName("Bench@Press#1"), "Bench Press 1", "Should remove special characters")

        // Test handling empty/whitespace input
        XCTAssertEqual(InputSanitizer.sanitizeName(""), "", "Should handle empty string")
        XCTAssertEqual(InputSanitizer.sanitizeName("   "), "", "Should handle whitespace-only string")

        // Test preserving valid characters
        XCTAssertEqual(InputSanitizer.sanitizeName("T-Bar Row"), "T-Bar Row", "Should preserve hyphens")
        XCTAssertEqual(InputSanitizer.sanitizeName("21s Bicep Curls"), "21s Bicep Curls", "Should preserve numbers")
    }

    func testNumericInputValidation() {
        // Valid numeric inputs
        XCTAssertTrue(InputValidator.isValidNumericInput("135"), "Integer string should be valid")
        XCTAssertTrue(InputValidator.isValidNumericInput("135.5"), "Decimal string should be valid")
        XCTAssertTrue(InputValidator.isValidNumericInput("0"), "Zero string should be valid")
        XCTAssertTrue(InputValidator.isValidNumericInput("2.5"), "Small decimal should be valid")

        // Invalid numeric inputs
        XCTAssertFalse(InputValidator.isValidNumericInput(""), "Empty string should be invalid")
        XCTAssertFalse(InputValidator.isValidNumericInput("abc"), "Letter string should be invalid")
        XCTAssertFalse(InputValidator.isValidNumericInput("12.34.56"), "Multiple decimals should be invalid")
        XCTAssertFalse(InputValidator.isValidNumericInput("-50"), "Negative should be invalid for weights")
        XCTAssertFalse(InputValidator.isValidNumericInput("1,234"), "Comma separator should be invalid")
        XCTAssertFalse(InputValidator.isValidNumericInput("1 2 3"), "Spaces should be invalid")
    }

    func testDateValidation() {
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let tomorrow = now.addingTimeInterval(86400)
        let nextWeek = now.addingTimeInterval(86400 * 7)

        // Valid dates
        XCTAssertTrue(DateValidator.isValidWorkoutDate(yesterday), "Yesterday should be valid workout date")
        XCTAssertTrue(DateValidator.isValidWorkoutDate(now), "Today should be valid workout date")

        // Invalid dates
        XCTAssertFalse(DateValidator.isValidWorkoutDate(tomorrow), "Future date should be invalid")
        XCTAssertFalse(DateValidator.isValidWorkoutDate(nextWeek), "Future date should be invalid")

        let twoYearsAgo = now.addingTimeInterval(-86400 * 365 * 2)
        XCTAssertFalse(DateValidator.isValidWorkoutDate(twoYearsAgo), "Very old date should be invalid")
    }

    // MARK: - Business Rule Validation

    func testProgressiveOverloadValidation() {
        let previousSet = WorkoutSet(weight: 135, reps: 8, date: Date().addingTimeInterval(-86400))

        // Valid progressive overload
        XCTAssertTrue(ProgressValidator.isProgressiveOverload(
            current: WorkoutSet(weight: 140, reps: 8, date: Date()),
            previous: previousSet
        ), "Weight increase should be progressive overload")

        XCTAssertTrue(ProgressValidator.isProgressiveOverload(
            current: WorkoutSet(weight: 135, reps: 9, date: Date()),
            previous: previousSet
        ), "Rep increase should be progressive overload")

        // Invalid progressive overload
        XCTAssertFalse(ProgressValidator.isProgressiveOverload(
            current: WorkoutSet(weight: 130, reps: 8, date: Date()),
            previous: previousSet
        ), "Weight decrease should not be progressive overload")

        XCTAssertFalse(ProgressValidator.isProgressiveOverload(
            current: WorkoutSet(weight: 135, reps: 7, date: Date()),
            previous: previousSet
        ), "Rep decrease should not be progressive overload")
    }

    func testWorkoutFrequencyValidation() {
        let dayAgo = Date().addingTimeInterval(-86400)
        let twoDaysAgo = Date().addingTimeInterval(-86400 * 2)
        let weekAgo = Date().addingTimeInterval(-86400 * 7)

        // Valid workout frequency
        XCTAssertTrue(WorkoutValidator.isValidFrequency(
            lastWorkout: twoDaysAgo,
            currentWorkout: Date()
        ), "2 days rest should be valid frequency")

        XCTAssertTrue(WorkoutValidator.isValidFrequency(
            lastWorkout: weekAgo,
            currentWorkout: Date()
        ), "1 week rest should be valid frequency")

        // Warning frequency (not invalid, but flagged)
        XCTAssertFalse(WorkoutValidator.isValidFrequency(
            lastWorkout: dayAgo,
            currentWorkout: Date()
        ), "1 day rest should be flagged for same muscle group")

        let hourAgo = Date().addingTimeInterval(-3600)
        XCTAssertFalse(WorkoutValidator.isValidFrequency(
            lastWorkout: hourAgo,
            currentWorkout: Date()
        ), "Same day workout should be flagged")
    }

    func testVolumeValidation() {
        // Valid volume ranges
        XCTAssertTrue(VolumeValidator.isValidWorkoutVolume(5000), "5000 lbs volume should be valid")
        XCTAssertTrue(VolumeValidator.isValidWorkoutVolume(15000), "15000 lbs volume should be valid")
        XCTAssertTrue(VolumeValidator.isValidWorkoutVolume(25000), "25000 lbs volume should be valid")

        // Invalid volume ranges
        XCTAssertFalse(VolumeValidator.isValidWorkoutVolume(0), "Zero volume should be invalid")
        XCTAssertFalse(VolumeValidator.isValidWorkoutVolume(-1000), "Negative volume should be invalid")
        XCTAssertFalse(VolumeValidator.isValidWorkoutVolume(100000), "Excessive volume should be invalid")

        // Edge cases
        XCTAssertTrue(VolumeValidator.isValidWorkoutVolume(500), "Low volume should be valid for light sessions")
        XCTAssertFalse(VolumeValidator.isValidWorkoutVolume(75000), "Unrealistic volume should be invalid")
    }

    // MARK: - Performance Tests

    func testValidationPerformance() {
        let exerciseNames = (0..<1000).map { "Exercise \($0)" }

        measure {
            for name in exerciseNames {
                _ = ExerciseValidator.isValidName(name)
            }
        }
    }

    func testBulkSetValidation() {
        let sets = (0..<1000).map { index in
            WorkoutSet(weight: Double(100 + index % 200), reps: 5 + index % 15, date: Date())
        }

        measure {
            for set in sets {
                _ = SetValidator.isValidSet(weight: set.weight, reps: set.reps)
            }
        }
    }
}

// MARK: - Validator Implementations

struct ExerciseValidator {
    static func isValidName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 && trimmed.count <= 100 else { return false }

        let allowedCharacters = CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: "-'"))
        return trimmed.rangeOfCharacter(from: allowedCharacters.inverted) == nil
    }

    static func isValidMuscleGroup(_ muscleGroup: String) -> Bool {
        let validGroups = ["chest", "back", "shoulders", "arms", "legs", "core", "glutes", "calves"]
        return validGroups.contains(muscleGroup.lowercased())
    }

    static func isValidEquipment(_ equipment: String?) -> Bool {
        guard let equipment = equipment, !equipment.isEmpty else { return true }

        let validEquipment = ["barbell", "dumbbell", "cable", "machine", "bodyweight", "resistance band", "kettlebell"]
        return validEquipment.contains(equipment.lowercased())
    }
}

struct WorkoutValidator {
    static func isValidDuration(_ duration: TimeInterval) -> Bool {
        return duration >= 30 && duration <= 14400 // 30 seconds to 4 hours
    }

    static func isValidName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 2 && trimmed.count <= 50
    }

    static func isValidRestTime(_ restTime: TimeInterval) -> Bool {
        return restTime >= 15 && restTime <= 1800 // 15 seconds to 30 minutes
    }

    static func isValidFrequency(lastWorkout: Date, currentWorkout: Date) -> Bool {
        let timeDifference = currentWorkout.timeIntervalSince(lastWorkout)
        return timeDifference >= 86400 // At least 24 hours between workouts
    }
}

struct SetValidator {
    static func isValidSet(weight: Double, reps: Int) -> Bool {
        return weight >= 0 && weight <= 1000 && reps >= 1 && reps <= 100
    }
}

struct PlateValidator {
    static func isValidPlateWeight(_ weight: Double) -> Bool {
        let standardWeights = [1.25, 2.5, 5.0, 10.0, 15.0, 20.0, 25.0, 35.0, 45.0]
        return standardWeights.contains(weight)
    }

    static func isValidBarWeight(_ weight: Double) -> Bool {
        let standardBars = [15.0, 20.0, 35.0, 45.0]
        return standardBars.contains(weight)
    }

    static func isValidTargetWeight(_ weight: Double) -> Bool {
        return weight >= 15 && weight <= 1500
    }
}

struct InputSanitizer {
    static func sanitizeName(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowedCharacters = CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: "-'"))
        let filtered = trimmed.components(separatedBy: allowedCharacters.inverted).joined()

        // Normalize multiple spaces to single space
        let normalized = filtered.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        return normalized.trimmingCharacters(in: .whitespaces)
    }
}

struct InputValidator {
    static func isValidNumericInput(_ input: String) -> Bool {
        guard !input.isEmpty else { return false }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.allowsFloats = true

        guard let number = formatter.number(from: input) else { return false }
        return number.doubleValue >= 0
    }
}

struct DateValidator {
    static func isValidWorkoutDate(_ date: Date) -> Bool {
        let now = Date()
        let oneYearAgo = now.addingTimeInterval(-365 * 24 * 60 * 60)

        return date >= oneYearAgo && date <= now
    }
}

struct ProgressValidator {
    static func isProgressiveOverload(current: WorkoutSet, previous: WorkoutSet) -> Bool {
        let currentVolume = current.weight * Double(current.reps)
        let previousVolume = previous.weight * Double(previous.reps)

        return currentVolume > previousVolume
    }
}

struct VolumeValidator {
    static func isValidWorkoutVolume(_ volume: Double) -> Bool {
        return volume > 0 && volume <= 50000 // Up to 50,000 lbs total volume
    }
}

// MARK: - Supporting Types

struct WorkoutSet {
    let weight: Double
    let reps: Int
    let date: Date
}