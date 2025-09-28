//
//  PRCalculationTests.swift
//  Gigi Gains Tests
//
//  Unit tests for Epley formula personal record calculations.
//  Tests one-rep max estimation and volume calculations for accuracy.
//
//  Created: 2025-09-28
//

import XCTest
@testable import GigiGains

final class PRCalculationTests: XCTestCase {

    // MARK: - Test Cases

    func testEpleyFormulaCalculation() {
        // Test standard Epley formula: 1RM = weight × (1 + reps/30)

        // Test case 1: 225 lbs × 5 reps should equal ~254 lbs
        let oneRM1 = PRCalculator.calculateOneRepMax(weight: 225, reps: 5)
        XCTAssertEqual(oneRM1, 262.5, accuracy: 0.1, "Epley formula calculation incorrect for 225×5")

        // Test case 2: 185 lbs × 8 reps should equal ~234 lbs
        let oneRM2 = PRCalculator.calculateOneRepMax(weight: 185, reps: 8)
        XCTAssertEqual(oneRM2, 234.3, accuracy: 0.1, "Epley formula calculation incorrect for 185×8")

        // Test case 3: 135 lbs × 12 reps should equal ~189 lbs
        let oneRM3 = PRCalculator.calculateOneRepMax(weight: 135, reps: 12)
        XCTAssertEqual(oneRM3, 189.0, accuracy: 0.1, "Epley formula calculation incorrect for 135×12")

        // Test case 4: 315 lbs × 1 rep should equal 315 lbs (no calculation needed)
        let oneRM4 = PRCalculator.calculateOneRepMax(weight: 315, reps: 1)
        XCTAssertEqual(oneRM4, 315.0, accuracy: 0.1, "One rep max should equal input weight when reps = 1")
    }

    func testBrzckiFormulaCalculation() {
        // Test alternative Brzycki formula: 1RM = weight × (36 / (37 - reps))

        let oneRM1 = PRCalculator.calculateOneRepMaxBrzycki(weight: 225, reps: 5)
        XCTAssertEqual(oneRM1, 253.1, accuracy: 0.1, "Brzycki formula calculation incorrect for 225×5")

        let oneRM2 = PRCalculator.calculateOneRepMaxBrzycki(weight: 185, reps: 8)
        XCTAssertEqual(oneRM2, 229.3, accuracy: 0.1, "Brzycki formula calculation incorrect for 185×8")

        let oneRM3 = PRCalculator.calculateOneRepMaxBrzycki(weight: 135, reps: 12)
        XCTAssertEqual(oneRM3, 194.4, accuracy: 0.1, "Brzycki formula calculation incorrect for 135×12")
    }

    func testEdgeCases() {
        // Test zero and negative values
        XCTAssertEqual(PRCalculator.calculateOneRepMax(weight: 0, reps: 5), 0, "Zero weight should return zero")
        XCTAssertEqual(PRCalculator.calculateOneRepMax(weight: 100, reps: 0), 100, "Zero reps should return input weight")

        // Test very high rep counts (should handle gracefully)
        let highRepResult = PRCalculator.calculateOneRepMax(weight: 100, reps: 25)
        XCTAssertGreaterThan(highRepResult, 100, "High rep count should increase estimated 1RM")
        XCTAssertLessThan(highRepResult, 300, "High rep estimation should be reasonable")

        // Test very low weights
        let lowWeightResult = PRCalculator.calculateOneRepMax(weight: 5, reps: 10)
        XCTAssertGreaterThan(lowWeightResult, 5, "Low weight calculation should work")
    }

    func testVolumeCalculations() {
        // Test workout volume calculations (weight × reps × sets)

        let volume1 = PRCalculator.calculateVolume(weight: 185, reps: 8, sets: 3)
        XCTAssertEqual(volume1, 4440, "Volume calculation incorrect: 185×8×3 should equal 4440")

        let volume2 = PRCalculator.calculateVolume(weight: 225, reps: 5, sets: 4)
        XCTAssertEqual(volume2, 4500, "Volume calculation incorrect: 225×5×4 should equal 4500")

        let volume3 = PRCalculator.calculateVolume(weight: 135, reps: 12, sets: 2)
        XCTAssertEqual(volume3, 3240, "Volume calculation incorrect: 135×12×2 should equal 3240")

        // Test zero cases
        XCTAssertEqual(PRCalculator.calculateVolume(weight: 0, reps: 8, sets: 3), 0, "Zero weight should result in zero volume")
        XCTAssertEqual(PRCalculator.calculateVolume(weight: 185, reps: 0, sets: 3), 0, "Zero reps should result in zero volume")
        XCTAssertEqual(PRCalculator.calculateVolume(weight: 185, reps: 8, sets: 0), 0, "Zero sets should result in zero volume")
    }

    func testRelativeIntensityCalculations() {
        // Test percentage-based calculations for training loads

        let weight90Percent = PRCalculator.calculatePercentageWeight(oneRM: 300, percentage: 0.90)
        XCTAssertEqual(weight90Percent, 270, accuracy: 0.1, "90% of 300 should be 270")

        let weight85Percent = PRCalculator.calculatePercentageWeight(oneRM: 225, percentage: 0.85)
        XCTAssertEqual(weight85Percent, 191.25, accuracy: 0.1, "85% of 225 should be 191.25")

        let weight70Percent = PRCalculator.calculatePercentageWeight(oneRM: 185, percentage: 0.70)
        XCTAssertEqual(weight70Percent, 129.5, accuracy: 0.1, "70% of 185 should be 129.5")

        // Test percentage from weight
        let percentage1 = PRCalculator.calculatePercentageFromWeight(weight: 180, oneRM: 200)
        XCTAssertEqual(percentage1, 0.90, accuracy: 0.01, "180 should be 90% of 200")

        let percentage2 = PRCalculator.calculatePercentageFromWeight(weight: 135, oneRM: 225)
        XCTAssertEqual(percentage2, 0.60, accuracy: 0.01, "135 should be 60% of 225")
    }

    func testPersonalRecordDetection() {
        // Test PR detection logic

        let existingPRs = [
            PersonalRecord(exerciseId: UUID(), type: .oneRepMax, value: 225, date: Date()),
            PersonalRecord(exerciseId: UUID(), type: .maxVolume, value: 5000, date: Date()),
            PersonalRecord(exerciseId: UUID(), type: .maxReps, value: 15, date: Date())
        ]

        // Test new 1RM PR
        let newOneRM = PRCalculator.detectPersonalRecord(
            type: .oneRepMax,
            newValue: 235,
            existingRecords: existingPRs
        )
        XCTAssertTrue(newOneRM.isNewRecord, "235 should be a new 1RM PR over 225")
        XCTAssertEqual(newOneRM.improvement, 10, accuracy: 0.1, "Improvement should be 10 lbs")

        // Test non-PR
        let notPR = PRCalculator.detectPersonalRecord(
            type: .oneRepMax,
            newValue: 220,
            existingRecords: existingPRs
        )
        XCTAssertFalse(notPR.isNewRecord, "220 should not be a PR when existing is 225")

        // Test volume PR
        let volumePR = PRCalculator.detectPersonalRecord(
            type: .maxVolume,
            newValue: 5500,
            existingRecords: existingPRs
        )
        XCTAssertTrue(volumePR.isNewRecord, "5500 should be a new volume PR over 5000")
    }

    func testRPEBasedCalculations() {
        // Test RPE-based load calculations

        // RPE 8 should be approximately 92% of 1RM
        let rpe8Weight = PRCalculator.calculateRPEWeight(oneRM: 200, targetRPE: 8)
        XCTAssertEqual(rpe8Weight, 184, accuracy: 2, "RPE 8 should be ~92% of 1RM")

        // RPE 9 should be approximately 96% of 1RM
        let rpe9Weight = PRCalculator.calculateRPEWeight(oneRM: 200, targetRPE: 9)
        XCTAssertEqual(rpe9Weight, 192, accuracy: 2, "RPE 9 should be ~96% of 1RM")

        // RPE 7 should be approximately 88% of 1RM
        let rpe7Weight = PRCalculator.calculateRPEWeight(oneRM: 200, targetRPE: 7)
        XCTAssertEqual(rpe7Weight, 176, accuracy: 2, "RPE 7 should be ~88% of 1RM")

        // Test RPE estimation from performance
        let estimatedRPE = PRCalculator.estimateRPE(weight: 180, reps: 5, oneRM: 200)
        XCTAssertGreaterThan(estimatedRPE, 7, "RPE should be reasonable for the given parameters")
        XCTAssertLessThan(estimatedRPE, 10, "RPE should not exceed 10")
    }

    func testProgressCalculations() {
        // Test progress tracking calculations

        let oldData = [
            WorkoutData(date: Date().addingTimeInterval(-86400 * 30), weight: 185, reps: 8),
            WorkoutData(date: Date().addingTimeInterval(-86400 * 20), weight: 190, reps: 8),
            WorkoutData(date: Date().addingTimeInterval(-86400 * 10), weight: 195, reps: 8)
        ]

        let newData = WorkoutData(date: Date(), weight: 200, reps: 8)

        let progressRate = PRCalculator.calculateProgressRate(historicalData: oldData, newData: newData)
        XCTAssertGreaterThan(progressRate, 0, "Progress rate should be positive for improving performance")

        let strength1RM = PRCalculator.calculateOneRepMax(weight: newData.weight, reps: newData.reps)
        XCTAssertGreaterThan(strength1RM, 200, "Calculated 1RM should be greater than working weight")
    }

    func testValidationLogic() {
        // Test input validation

        XCTAssertFalse(PRCalculator.isValidInput(weight: -10, reps: 5), "Negative weight should be invalid")
        XCTAssertFalse(PRCalculator.isValidInput(weight: 100, reps: -1), "Negative reps should be invalid")
        XCTAssertFalse(PRCalculator.isValidInput(weight: 0, reps: 5), "Zero weight should be invalid")
        XCTAssertTrue(PRCalculator.isValidInput(weight: 100, reps: 5), "Valid inputs should pass validation")

        // Test reasonable limits
        XCTAssertFalse(PRCalculator.isValidInput(weight: 2000, reps: 5), "Unreasonably high weight should be invalid")
        XCTAssertFalse(PRCalculator.isValidInput(weight: 100, reps: 100), "Unreasonably high reps should be invalid")
        XCTAssertTrue(PRCalculator.isValidInput(weight: 500, reps: 20), "High but reasonable values should be valid")
    }

    // MARK: - Performance Tests

    func testCalculationPerformance() {
        // Test that calculations are fast enough for real-time use

        measure {
            for _ in 0..<1000 {
                let _ = PRCalculator.calculateOneRepMax(weight: Double.random(in: 50...500), reps: Int.random(in: 1...20))
            }
        }
    }

    func testBulkVolumeCalculation() {
        // Test performance for calculating volume for entire workouts

        let workoutData = (0..<100).map { _ in
            (weight: Double.random(in: 50...300), reps: Int.random(in: 5...15), sets: Int.random(in: 2...5))
        }

        measure {
            let totalVolume = workoutData.reduce(0.0) { total, data in
                total + PRCalculator.calculateVolume(weight: data.weight, reps: data.reps, sets: data.sets)
            }
            XCTAssertGreaterThan(totalVolume, 0, "Total volume should be calculated")
        }
    }
}

// MARK: - Supporting Types

struct WorkoutData {
    let date: Date
    let weight: Double
    let reps: Int
}

struct PersonalRecord {
    let exerciseId: UUID
    let type: PRType
    let value: Double
    let date: Date
}

enum PRType {
    case oneRepMax
    case maxVolume
    case maxReps
}

struct PRDetectionResult {
    let isNewRecord: Bool
    let improvement: Double
    let previousValue: Double?
}

// MARK: - PR Calculator Implementation

struct PRCalculator {

    /// Calculate one-rep max using Epley formula: 1RM = weight × (1 + reps/30)
    static func calculateOneRepMax(weight: Double, reps: Int) -> Double {
        guard weight > 0 && reps >= 1 else { return weight }
        return weight * (1 + Double(reps) / 30.0)
    }

    /// Calculate one-rep max using Brzycki formula: 1RM = weight × (36 / (37 - reps))
    static func calculateOneRepMaxBrzycki(weight: Double, reps: Int) -> Double {
        guard weight > 0 && reps >= 1 && reps < 37 else { return weight }
        return weight * (36.0 / (37.0 - Double(reps)))
    }

    /// Calculate training volume: weight × reps × sets
    static func calculateVolume(weight: Double, reps: Int, sets: Int) -> Double {
        return weight * Double(reps) * Double(sets)
    }

    /// Calculate weight for a given percentage of 1RM
    static func calculatePercentageWeight(oneRM: Double, percentage: Double) -> Double {
        return oneRM * percentage
    }

    /// Calculate percentage of 1RM for a given weight
    static func calculatePercentageFromWeight(weight: Double, oneRM: Double) -> Double {
        guard oneRM > 0 else { return 0 }
        return weight / oneRM
    }

    /// Detect if a new value represents a personal record
    static func detectPersonalRecord(type: PRType, newValue: Double, existingRecords: [PersonalRecord]) -> PRDetectionResult {
        let existingRecord = existingRecords.first { $0.type == type }

        guard let existing = existingRecord else {
            return PRDetectionResult(isNewRecord: true, improvement: newValue, previousValue: nil)
        }

        let isNewRecord = newValue > existing.value
        let improvement = isNewRecord ? newValue - existing.value : 0

        return PRDetectionResult(isNewRecord: isNewRecord, improvement: improvement, previousValue: existing.value)
    }

    /// Calculate target weight for specific RPE
    static func calculateRPEWeight(oneRM: Double, targetRPE: Double) -> Double {
        // RPE to percentage mapping (approximate)
        let rpePercentages: [Double: Double] = [
            10: 1.00,
            9.5: 0.98,
            9: 0.96,
            8.5: 0.94,
            8: 0.92,
            7.5: 0.90,
            7: 0.88,
            6.5: 0.86,
            6: 0.84
        ]

        let percentage = rpePercentages[targetRPE] ?? 0.85
        return oneRM * percentage
    }

    /// Estimate RPE from performance data
    static func estimateRPE(weight: Double, reps: Int, oneRM: Double) -> Double {
        let percentage = calculatePercentageFromWeight(weight: weight, oneRM: oneRM)

        // Adjust for reps performed (more reps = higher RPE)
        let repAdjustment = Double(reps - 1) * 0.25
        let baseRPE = percentage * 10

        return min(10.0, baseRPE + repAdjustment)
    }

    /// Calculate progress rate from historical data
    static func calculateProgressRate(historicalData: [WorkoutData], newData: WorkoutData) -> Double {
        guard !historicalData.isEmpty else { return 0 }

        let sortedData = historicalData.sorted { $0.date < $1.date }
        guard let firstData = sortedData.first, let lastData = sortedData.last else { return 0 }

        let timeSpan = newData.date.timeIntervalSince(firstData.date)
        guard timeSpan > 0 else { return 0 }

        let firstOneRM = calculateOneRepMax(weight: firstData.weight, reps: firstData.reps)
        let newOneRM = calculateOneRepMax(weight: newData.weight, reps: newData.reps)

        let improvement = newOneRM - firstOneRM
        return improvement / (timeSpan / (86400 * 30)) // Per month
    }

    /// Validate input parameters
    static func isValidInput(weight: Double, reps: Int) -> Bool {
        return weight > 0 &&
               weight <= 1500 && // Reasonable upper limit
               reps > 0 &&
               reps <= 50 // Reasonable upper limit for strength training
    }
}