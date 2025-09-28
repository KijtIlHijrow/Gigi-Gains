//
//  PlateCalculationTests.swift
//  Gigi Gains Tests
//
//  Unit tests for plate calculator algorithms and weight loading logic.
//  Tests plate combination algorithms for accuracy and edge cases.
//
//  Created: 2025-09-28
//

import XCTest
@testable import GigiGains

final class PlateCalculationTests: XCTestCase {

    // MARK: - Standard Test Setup

    private let standardPlates = [
        PlateInfo(weight: 45, count: 8),
        PlateInfo(weight: 35, count: 4),
        PlateInfo(weight: 25, count: 4),
        PlateInfo(weight: 10, count: 4),
        PlateInfo(weight: 5, count: 4),
        PlateInfo(weight: 2.5, count: 4)
    ]

    private let standardBarWeight = 45.0

    // MARK: - Basic Calculation Tests

    func testSimplePlateCalculations() {
        let calculator = PlateCalculator()
        calculator.availablePlates = standardPlates

        // Test 135 lbs (45 lb bar + 45 lb plates on each side)
        calculator.calculatePlates(targetWeight: 135, barWeight: standardBarWeight)
        guard let result = calculator.currentResult else {
            XCTFail("Should have calculation result")
            return
        }

        XCTAssertTrue(result.isExact, "135 lbs should be exact")
        XCTAssertEqual(result.actualWeight, 135, "Total weight should be 135")
        XCTAssertEqual(result.plateConfiguration.count, 1, "Should only need 45 lb plates")
        XCTAssertEqual(result.plateConfiguration.first?.weight, 45, "Should use 45 lb plates")
        XCTAssertEqual(result.plateConfiguration.first?.count, 1, "Should use 1 plate per side")
    }

    func testComplexPlateCalculations() {
        let calculator = PlateCalculator()
        calculator.availablePlates = standardPlates

        // Test 225 lbs (45 + 45 + 35 on each side)
        calculator.calculatePlates(targetWeight: 225, barWeight: standardBarWeight)
        guard let result = calculator.currentResult else {
            XCTFail("Should have calculation result")
            return
        }

        XCTAssertTrue(result.isExact, "225 lbs should be exact")
        XCTAssertEqual(result.actualWeight, 225, "Total weight should be 225")

        // Should use 45 and 35 lb plates
        let plateWeights = result.plateConfiguration.map { $0.weight }.sorted(by: >)
        XCTAssertEqual(plateWeights, [45, 35], "Should use 45 and 35 lb plates")
    }

    func testExactWeightMatching() {
        let calculator = PlateCalculator()
        calculator.availablePlates = standardPlates

        let testWeights = [95, 135, 155, 185, 205, 225, 245, 275, 295, 315]

        for weight in testWeights {
            calculator.calculatePlates(targetWeight: Double(weight), barWeight: standardBarWeight)
            guard let result = calculator.currentResult else {
                XCTFail("Should have result for \(weight) lbs")
                continue
            }

            XCTAssertTrue(result.isExact, "\(weight) lbs should be exactly achievable")
            XCTAssertEqual(result.actualWeight, Double(weight), accuracy: 0.1, "Weight should match target: \(weight)")
        }
    }

    func testImpossibleWeights() {
        let calculator = PlateCalculator()
        calculator.availablePlates = standardPlates

        // Test weight that can't be made exactly (e.g., 137 lbs)
        calculator.calculatePlates(targetWeight: 137, barWeight: standardBarWeight)
        guard let result = calculator.currentResult else {
            XCTFail("Should have calculation result")
            return
        }

        XCTAssertFalse(result.isExact, "137 lbs should not be exact with standard plates")
        XCTAssertGreaterThanOrEqual(result.actualWeight, 135, "Should round down to closest achievable weight")
        XCTAssertLessThan(result.actualWeight, 140, "Should not exceed by too much")
    }

    func testEdgeCases() {
        let calculator = PlateCalculator()
        calculator.availablePlates = standardPlates

        // Test bar weight only
        calculator.calculatePlates(targetWeight: standardBarWeight, barWeight: standardBarWeight)
        guard let result1 = calculator.currentResult else {
            XCTFail("Should handle bar weight only")
            return
        }

        XCTAssertTrue(result1.plateConfiguration.isEmpty, "Should need no plates for bar weight")
        XCTAssertEqual(result1.actualWeight, standardBarWeight, "Should equal bar weight")
        XCTAssertTrue(result1.isExact, "Bar weight should be exact")

        // Test weight less than bar weight
        calculator.calculatePlates(targetWeight: 30, barWeight: standardBarWeight)
        guard let result2 = calculator.currentResult else {
            XCTFail("Should handle weight less than bar")
            return
        }

        XCTAssertTrue(result2.plateConfiguration.isEmpty, "Should need no plates when target < bar")
        XCTAssertEqual(result2.actualWeight, standardBarWeight, "Should equal bar weight")

        // Test very high weight
        calculator.calculatePlates(targetWeight: 1000, barWeight: standardBarWeight)
        guard let result3 = calculator.currentResult else {
            XCTFail("Should handle very high weights")
            return
        }

        XCTAssertLessThan(result3.actualWeight, 1000, "Should not exceed available plates")
    }

    func testDifferentBarWeights() {
        let calculator = PlateCalculator()
        calculator.availablePlates = standardPlates

        // Test with women's bar (35 lbs)
        calculator.calculatePlates(targetWeight: 135, barWeight: 35)
        guard let result1 = calculator.currentResult else {
            XCTFail("Should work with different bar weights")
            return
        }

        XCTAssertEqual(result1.actualWeight, 135, "Should achieve target with different bar")

        // Test with training bar (15 lbs)
        calculator.calculatePlates(targetWeight: 95, barWeight: 15)
        guard let result2 = calculator.currentResult else {
            XCTFail("Should work with training bar")
            return
        }

        XCTAssertEqual(result2.actualWeight, 95, accuracy: 2.5, "Should achieve close to target with training bar")
    }

    func testLimitedPlateAvailability() {
        let calculator = PlateCalculator()

        // Test with limited plates (home gym scenario)
        calculator.availablePlates = [
            PlateInfo(weight: 45, count: 2),
            PlateInfo(weight: 25, count: 2),
            PlateInfo(weight: 10, count: 2),
            PlateInfo(weight: 5, count: 2),
            PlateInfo(weight: 2.5, count: 2)
        ]

        // Try to make 315 lbs (would need many 45s)
        calculator.calculatePlates(targetWeight: 315, barWeight: standardBarWeight)
        guard let result = calculator.currentResult else {
            XCTFail("Should handle limited plates")
            return
        }

        XCTAssertLessThan(result.actualWeight, 315, "Should not exceed available plates")
        XCTAssertGreaterThan(result.actualWeight, standardBarWeight, "Should add some weight")

        // Verify we don't use more plates than available
        for plateConfig in result.plateConfiguration {
            let availablePlate = calculator.availablePlates.first { $0.weight == plateConfig.weight }
            XCTAssertNotNil(availablePlate, "Should only use available plates")
            XCTAssertLessThanOrEqual(plateConfig.count, availablePlate!.count, "Should not exceed available count")
        }
    }

    func testPlateOptimization() {
        let calculator = PlateCalculator()
        calculator.availablePlates = standardPlates

        // Test that algorithm prefers larger plates (more efficient)
        calculator.calculatePlates(targetWeight: 225, barWeight: standardBarWeight)
        guard let result = calculator.currentResult else {
            XCTFail("Should have result")
            return
        }

        // Should prefer 45+35 over many smaller plates
        let hasLargePlates = result.plateConfiguration.contains { $0.weight >= 35 }
        XCTAssertTrue(hasLargePlates, "Should prefer larger plates for efficiency")

        // Total plate count should be reasonable
        let totalPlateCount = result.plateConfiguration.reduce(0) { $0 + $1.count }
        XCTAssertLessThan(totalPlateCount, 6, "Should use efficient plate combination")
    }

    func testIncrementalWeights() {
        let calculator = PlateCalculator()
        calculator.availablePlates = standardPlates

        // Test 2.5 lb increments work correctly
        let baseWeight = 135.0
        let increments = [2.5, 5.0, 7.5, 10.0, 12.5, 15.0]

        for increment in increments {
            let targetWeight = baseWeight + increment * 2 // Both sides
            calculator.calculatePlates(targetWeight: targetWeight, barWeight: standardBarWeight)

            guard let result = calculator.currentResult else {
                XCTFail("Should calculate \(targetWeight) lbs")
                continue
            }

            XCTAssertTrue(result.isExact, "\(targetWeight) lbs should be exact with 2.5 lb plates")
            XCTAssertEqual(result.actualWeight, targetWeight, accuracy: 0.1, "Should match target exactly")
        }
    }

    func testPerformanceWithManyPlates() {
        let calculator = PlateCalculator()

        // Create scenario with many different plate weights
        calculator.availablePlates = [
            PlateInfo(weight: 55, count: 4),   // 25kg
            PlateInfo(weight: 45, count: 8),   // 20kg
            PlateInfo(weight: 35, count: 4),   // 15kg
            PlateInfo(weight: 25, count: 8),   // 10kg
            PlateInfo(weight: 15, count: 4),   // 6.8kg
            PlateInfo(weight: 11, count: 4),   // 5kg
            PlateInfo(weight: 5.5, count: 4),  // 2.5kg
            PlateInfo(weight: 2.75, count: 4), // 1.25kg
            PlateInfo(weight: 1.25, count: 4)  // 0.5kg
        ]

        measure {
            for weight in stride(from: 60, to: 500, by: 2.5) {
                calculator.calculatePlates(targetWeight: weight, barWeight: standardBarWeight)
            }
        }
    }

    func testAlgorithmStability() {
        let calculator = PlateCalculator()
        calculator.availablePlates = standardPlates

        // Test that same inputs produce same outputs
        let targetWeight = 185.0

        var results: [PlateCalculationResult] = []
        for _ in 0..<5 {
            calculator.calculatePlates(targetWeight: targetWeight, barWeight: standardBarWeight)
            if let result = calculator.currentResult {
                results.append(result)
            }
        }

        XCTAssertEqual(results.count, 5, "Should have 5 results")

        // All results should be identical
        let firstResult = results[0]
        for result in results.dropFirst() {
            XCTAssertEqual(result.actualWeight, firstResult.actualWeight, "Results should be consistent")
            XCTAssertEqual(result.isExact, firstResult.isExact, "Exactness should be consistent")
            XCTAssertEqual(result.plateConfiguration.count, firstResult.plateConfiguration.count, "Plate count should be consistent")
        }
    }

    func testKilogramConversions() {
        let calculator = PlateCalculator()

        // Set up kilogram plates
        calculator.availablePlates = [
            PlateInfo(weight: 25, count: 4),  // 25kg ≈ 55 lbs
            PlateInfo(weight: 20, count: 8),  // 20kg ≈ 44 lbs
            PlateInfo(weight: 15, count: 4),  // 15kg ≈ 33 lbs
            PlateInfo(weight: 10, count: 8),  // 10kg ≈ 22 lbs
            PlateInfo(weight: 5, count: 4),   // 5kg ≈ 11 lbs
            PlateInfo(weight: 2.5, count: 4), // 2.5kg ≈ 5.5 lbs
            PlateInfo(weight: 1.25, count: 4) // 1.25kg ≈ 2.75 lbs
        ]

        let kgBarWeight = 20.0 // 20kg bar

        // Test common kilogram weights
        let kgWeights = [60, 80, 100, 120, 140, 160, 180, 200]

        for weight in kgWeights {
            calculator.calculatePlates(targetWeight: Double(weight), barWeight: kgBarWeight)
            guard let result = calculator.currentResult else {
                XCTFail("Should calculate \(weight)kg")
                continue
            }

            XCTAssertLessThanOrEqual(abs(result.actualWeight - Double(weight)), 2.5, "Should be within 2.5kg of target")
        }
    }

    func testSpecialPlateConfigurations() {
        let calculator = PlateCalculator()

        // Test bumper plate set (limited smaller plates)
        calculator.availablePlates = [
            PlateInfo(weight: 45, count: 6),   // Red bumpers
            PlateInfo(weight: 35, count: 4),   // Blue bumpers
            PlateInfo(weight: 25, count: 4),   // Yellow bumpers
            PlateInfo(weight: 15, count: 2),   // Green bumpers
            PlateInfo(weight: 10, count: 6),   // White bumpers
            PlateInfo(weight: 5, count: 2),    // Change plates
            PlateInfo(weight: 2.5, count: 2)   // Change plates
        ]

        // Test powerlifting competition weights
        let competitionWeights = [182.5, 187.5, 192.5, 197.5] // Common attempt progressions

        for weight in competitionWeights {
            calculator.calculatePlates(targetWeight: weight, barWeight: standardBarWeight)
            guard let result = calculator.currentResult else {
                XCTFail("Should calculate competition weight \(weight)")
                continue
            }

            XCTAssertEqual(result.actualWeight, weight, accuracy: 0.1, "Competition weights should be exact")
        }
    }

    func testValidationLogic() {
        let calculator = PlateCalculator()
        calculator.availablePlates = standardPlates

        // Test validation helper methods
        XCTAssertTrue(calculator.isValidConfiguration(), "Standard configuration should be valid")

        // Test with negative plate weights
        calculator.availablePlates.append(PlateInfo(weight: -5, count: 2))
        XCTAssertFalse(calculator.isValidConfiguration(), "Negative weights should be invalid")

        // Reset to valid configuration
        calculator.availablePlates = standardPlates

        // Test weight validation
        XCTAssertTrue(PlateCalculator.isValidWeight(100), "Normal weight should be valid")
        XCTAssertFalse(PlateCalculator.isValidWeight(-50), "Negative weight should be invalid")
        XCTAssertFalse(PlateCalculator.isValidWeight(0), "Zero weight should be invalid")
        XCTAssertFalse(PlateCalculator.isValidWeight(10000), "Extremely high weight should be invalid")
    }

    func testMemoryUsage() {
        // Test that algorithm doesn't consume excessive memory for complex calculations
        let calculator = PlateCalculator()

        // Create large plate set
        var largePlateSet: [PlateInfo] = []
        for weight in stride(from: 2.5, to: 100, by: 2.5) {
            largePlateSet.append(PlateInfo(weight: weight, count: 4))
        }

        calculator.availablePlates = largePlateSet

        measureMemoryUsage {
            for weight in stride(from: 100, to: 600, by: 5) {
                calculator.calculatePlates(targetWeight: weight, barWeight: 45)
            }
        }
    }

    // MARK: - Helper Methods

    private func measureMemoryUsage(_ block: () -> Void) {
        // Simple memory usage measurement
        let startMemory = mach_task_basic_info()
        block()
        let endMemory = mach_task_basic_info()

        let memoryUsed = endMemory.resident_size - startMemory.resident_size
        XCTAssertLessThan(memoryUsed, 10_000_000, "Memory usage should be reasonable (< 10MB)")
    }

    private func mach_task_basic_info() -> mach_task_basic_info {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return kerr == KERN_SUCCESS ? info : mach_task_basic_info()
    }
}

// MARK: - PlateCalculator Extensions for Testing

extension PlateCalculator {
    func isValidConfiguration() -> Bool {
        return availablePlates.allSatisfy { plate in
            plate.weight > 0 && plate.count >= 0
        }
    }

    static func isValidWeight(_ weight: Double) -> Bool {
        return weight > 0 && weight <= 2000 // Reasonable upper limit
    }
}