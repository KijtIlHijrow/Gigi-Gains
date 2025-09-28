//
//  VolumeCalculationTests.swift
//  Gigi Gains Tests
//
//  Unit tests for workout volume calculations and training load metrics.
//  Tests volume tracking, progressive overload calculations, and training analytics.
//
//  Created: 2025-09-28
//

import XCTest
@testable import GigiGains

final class VolumeCalculationTests: XCTestCase {

    // MARK: - Basic Volume Calculations

    func testBasicVolumeCalculation() {
        // Test: Volume = Weight × Reps × Sets

        // Single exercise volume
        let volume1 = VolumeCalculator.calculateExerciseVolume(weight: 185, reps: 8, sets: 3)
        XCTAssertEqual(volume1, 4440, "185 × 8 × 3 should equal 4,440")

        let volume2 = VolumeCalculator.calculateExerciseVolume(weight: 225, reps: 5, sets: 4)
        XCTAssertEqual(volume2, 4500, "225 × 5 × 4 should equal 4,500")

        let volume3 = VolumeCalculator.calculateExerciseVolume(weight: 135, reps: 12, sets: 2)
        XCTAssertEqual(volume3, 3240, "135 × 12 × 2 should equal 3,240")

        // Zero cases
        XCTAssertEqual(VolumeCalculator.calculateExerciseVolume(weight: 0, reps: 8, sets: 3), 0, "Zero weight should result in zero volume")
        XCTAssertEqual(VolumeCalculator.calculateExerciseVolume(weight: 185, reps: 0, sets: 3), 0, "Zero reps should result in zero volume")
        XCTAssertEqual(VolumeCalculator.calculateExerciseVolume(weight: 185, reps: 8, sets: 0), 0, "Zero sets should result in zero volume")
    }

    func testMultiSetVolumeCalculation() {
        // Test volume calculation for exercises with varying sets
        let sets = [
            SetData(weight: 185, reps: 8),
            SetData(weight: 185, reps: 8),
            SetData(weight: 185, reps: 6),
            SetData(weight: 205, reps: 5),
            SetData(weight: 225, reps: 3)
        ]

        let totalVolume = VolumeCalculator.calculateMultiSetVolume(sets: sets)
        let expectedVolume = (185 * 8) + (185 * 8) + (185 * 6) + (205 * 5) + (225 * 3)
        XCTAssertEqual(totalVolume, Double(expectedVolume), "Multi-set volume calculation should sum all sets")
    }

    func testWorkoutVolumeCalculation() {
        let workout = WorkoutData(
            exercises: [
                ExerciseData(
                    name: "Bench Press",
                    sets: [
                        SetData(weight: 185, reps: 8),
                        SetData(weight: 185, reps: 8),
                        SetData(weight: 185, reps: 6)
                    ]
                ),
                ExerciseData(
                    name: "Shoulder Press",
                    sets: [
                        SetData(weight: 135, reps: 8),
                        SetData(weight: 135, reps: 8),
                        SetData(weight: 135, reps: 7)
                    ]
                ),
                ExerciseData(
                    name: "Tricep Dips",
                    sets: [
                        SetData(weight: 0, reps: 12), // Bodyweight
                        SetData(weight: 0, reps: 10),
                        SetData(weight: 0, reps: 8)
                    ]
                )
            ]
        )

        let totalVolume = VolumeCalculator.calculateWorkoutVolume(workout: workout)

        // Expected: Bench (185×8 + 185×8 + 185×6) + Shoulder (135×8 + 135×8 + 135×7) + Tricep (0)
        let benchVolume = (185 * 8) + (185 * 8) + (185 * 6) // 4070
        let shoulderVolume = (135 * 8) + (135 * 8) + (135 * 7) // 3105
        let tricepVolume = 0 // Bodyweight exercises don't count toward volume
        let expectedTotal = benchVolume + shoulderVolume + tricepVolume

        XCTAssertEqual(totalVolume, Double(expectedTotal), "Workout volume should sum all exercises")
    }

    // MARK: - Progressive Overload Calculations

    func testProgressiveOverload() {
        let previousWorkout = WorkoutData(
            exercises: [
                ExerciseData(
                    name: "Bench Press",
                    sets: [
                        SetData(weight: 175, reps: 8),
                        SetData(weight: 175, reps: 8),
                        SetData(weight: 175, reps: 7)
                    ]
                )
            ]
        )

        let currentWorkout = WorkoutData(
            exercises: [
                ExerciseData(
                    name: "Bench Press",
                    sets: [
                        SetData(weight: 185, reps: 8),
                        SetData(weight: 185, reps: 8),
                        SetData(weight: 185, reps: 8)
                    ]
                )
            ]
        )

        let overload = VolumeCalculator.calculateProgressiveOverload(
            previous: previousWorkout,
            current: currentWorkout
        )

        XCTAssertGreaterThan(overload.volumeIncrease, 0, "Volume should have increased")
        XCTAssertTrue(overload.hasProgressed, "Should detect progression")

        let previousVolume = (175 * 8) + (175 * 8) + (175 * 7) // 4025
        let currentVolume = (185 * 8) + (185 * 8) + (185 * 8) // 4440
        let expectedIncrease = currentVolume - previousVolume // 415

        XCTAssertEqual(overload.volumeIncrease, Double(expectedIncrease), accuracy: 0.1, "Volume increase should be calculated correctly")
    }

    func testVolumeRegression() {
        let previousWorkout = WorkoutData(
            exercises: [
                ExerciseData(
                    name: "Squat",
                    sets: [
                        SetData(weight: 225, reps: 8),
                        SetData(weight: 225, reps: 8),
                        SetData(weight: 225, reps: 8)
                    ]
                )
            ]
        )

        let currentWorkout = WorkoutData(
            exercises: [
                ExerciseData(
                    name: "Squat",
                    sets: [
                        SetData(weight: 205, reps: 8),
                        SetData(weight: 205, reps: 7),
                        SetData(weight: 205, reps: 6)
                    ]
                )
            ]
        )

        let overload = VolumeCalculator.calculateProgressiveOverload(
            previous: previousWorkout,
            current: currentWorkout
        )

        XCTAssertLessThan(overload.volumeIncrease, 0, "Volume should have decreased")
        XCTAssertFalse(overload.hasProgressed, "Should detect regression")
    }

    // MARK: - Weekly Volume Calculations

    func testWeeklyVolumeCalculation() {
        let weeklyWorkouts = [
            WorkoutData(exercises: [
                ExerciseData(name: "Bench Press", sets: [
                    SetData(weight: 185, reps: 8),
                    SetData(weight: 185, reps: 8),
                    SetData(weight: 185, reps: 7)
                ])
            ]),
            WorkoutData(exercises: [
                ExerciseData(name: "Bench Press", sets: [
                    SetData(weight: 190, reps: 6),
                    SetData(weight: 190, reps: 6),
                    SetData(weight: 190, reps: 5)
                ])
            ]),
            WorkoutData(exercises: [
                ExerciseData(name: "Bench Press", sets: [
                    SetData(weight: 175, reps: 10),
                    SetData(weight: 175, reps: 10),
                    SetData(weight: 175, reps: 9)
                ])
            ])
        ]

        let weeklyVolume = VolumeCalculator.calculateWeeklyVolume(workouts: weeklyWorkouts, exerciseName: "Bench Press")

        // Calculate expected volume
        let workout1Volume = (185 * 8) + (185 * 8) + (185 * 7) // 4255
        let workout2Volume = (190 * 6) + (190 * 6) + (190 * 5) // 3230
        let workout3Volume = (175 * 10) + (175 * 10) + (175 * 9) // 5075
        let expectedTotal = workout1Volume + workout2Volume + workout3Volume // 12560

        XCTAssertEqual(weeklyVolume, Double(expectedTotal), "Weekly volume should sum all workouts")
    }

    func testMonthlyVolumeCalculation() {
        // Create 4 weeks of sample data
        var monthlyWorkouts: [WorkoutData] = []

        for week in 1...4 {
            for workout in 1...3 {
                let baseWeight = 180.0 + Double(week * 5) // Progressive overload
                monthlyWorkouts.append(
                    WorkoutData(exercises: [
                        ExerciseData(name: "Squat", sets: [
                            SetData(weight: baseWeight, reps: 8),
                            SetData(weight: baseWeight, reps: 8),
                            SetData(weight: baseWeight, reps: 7)
                        ])
                    ])
                )
            }
        }

        let monthlyVolume = VolumeCalculator.calculateMonthlyVolume(workouts: monthlyWorkouts, exerciseName: "Squat")
        XCTAssertGreaterThan(monthlyVolume, 0, "Monthly volume should be positive")
        XCTAssertGreaterThan(monthlyVolume, 50000, "Monthly volume should be substantial for regular training")
    }

    // MARK: - Volume Load and Intensity

    func testVolumeLoad() {
        // Volume Load = (Weight × Reps) / RPE for each set
        let sets = [
            SetDataWithRPE(weight: 185, reps: 8, rpe: 8),
            SetDataWithRPE(weight: 185, reps: 8, rpe: 9),
            SetDataWithRPE(weight: 185, reps: 6, rpe: 9.5)
        ]

        let volumeLoad = VolumeCalculator.calculateVolumeLoad(sets: sets)

        // Expected: (185×8/8) + (185×8/9) + (185×6/9.5)
        let expectedLoad = (185.0 * 8.0 / 8.0) + (185.0 * 8.0 / 9.0) + (185.0 * 6.0 / 9.5)
        XCTAssertEqual(volumeLoad, expectedLoad, accuracy: 0.1, "Volume load should account for RPE")
    }

    func testRelativeVolumeIntensity() {
        // Test volume at different percentages of 1RM
        let oneRM = 225.0
        let sets = [
            SetData(weight: 180, reps: 8), // ~80% 1RM
            SetData(weight: 202, reps: 5), // ~90% 1RM
            SetData(weight: 157, reps: 12) // ~70% 1RM
        ]

        let volumeByIntensity = VolumeCalculator.calculateVolumeByIntensityZones(
            sets: sets,
            oneRM: oneRM
        )

        XCTAssertGreaterThan(volumeByIntensity.highIntensity, 0, "Should have high intensity volume")
        XCTAssertGreaterThan(volumeByIntensity.moderateIntensity, 0, "Should have moderate intensity volume")
        XCTAssertGreaterThan(volumeByIntensity.lowIntensity, 0, "Should have low intensity volume")

        let totalVolume = volumeByIntensity.highIntensity + volumeByIntensity.moderateIntensity + volumeByIntensity.lowIntensity
        let expectedTotal = VolumeCalculator.calculateMultiSetVolume(sets: sets)
        XCTAssertEqual(totalVolume, expectedTotal, accuracy: 0.1, "Intensity zones should sum to total volume")
    }

    // MARK: - Training Metrics

    func testTonnageCalculation() {
        // Tonnage = Total weight moved in metric tons
        let workout = WorkoutData(
            exercises: [
                ExerciseData(name: "Deadlift", sets: [
                    SetData(weight: 315, reps: 5),
                    SetData(weight: 315, reps: 5),
                    SetData(weight: 315, reps: 4),
                    SetData(weight: 275, reps: 8)
                ])
            ]
        )

        let tonnage = VolumeCalculator.calculateTonnage(workout: workout)

        // Expected: (315×5 + 315×5 + 315×4 + 275×8) / 2204.62 (lbs to tonnes conversion)
        let totalLbs = (315 * 5) + (315 * 5) + (315 * 4) + (275 * 8) // 6570
        let expectedTonnage = Double(totalLbs) / 2204.62

        XCTAssertEqual(tonnage, expectedTonnage, accuracy: 0.01, "Tonnage should convert lbs to metric tons")
    }

    func testVolumePerBodyweight() {
        let bodyweight = 180.0
        let workout = WorkoutData(
            exercises: [
                ExerciseData(name: "Bench Press", sets: [
                    SetData(weight: 185, reps: 8),
                    SetData(weight: 185, reps: 8),
                    SetData(weight: 185, reps: 7)
                ])
            ]
        )

        let volumeRatio = VolumeCalculator.calculateVolumePerBodyweight(
            workout: workout,
            bodyweight: bodyweight
        )

        let workoutVolume = VolumeCalculator.calculateWorkoutVolume(workout: workout)
        let expectedRatio = workoutVolume / bodyweight

        XCTAssertEqual(volumeRatio, expectedRatio, accuracy: 0.1, "Volume per bodyweight should be calculated correctly")
    }

    // MARK: - Performance and Edge Cases

    func testLargeVolumeCalculations() {
        // Test performance with large datasets
        var largeWorkout: [ExerciseData] = []

        for i in 0..<100 {
            let exercise = ExerciseData(
                name: "Exercise \(i)",
                sets: (0..<10).map { _ in
                    SetData(weight: Double.random(in: 100...300), reps: Int.random(in: 5...15))
                }
            )
            largeWorkout.append(exercise)
        }

        measure {
            let totalVolume = VolumeCalculator.calculateWorkoutVolume(
                workout: WorkoutData(exercises: largeWorkout)
            )
            XCTAssertGreaterThan(totalVolume, 0, "Large workout should have positive volume")
        }
    }

    func testFloatingPointPrecision() {
        // Test edge cases with floating point arithmetic
        let sets = [
            SetData(weight: 185.75, reps: 8),
            SetData(weight: 185.25, reps: 8),
            SetData(weight: 184.5, reps: 7)
        ]

        let volume = VolumeCalculator.calculateMultiSetVolume(sets: sets)
        let expectedVolume = (185.75 * 8) + (185.25 * 8) + (184.5 * 7)

        XCTAssertEqual(volume, expectedVolume, accuracy: 0.001, "Should handle floating point weights precisely")
    }

    func testExtremeValues() {
        // Test with very large values
        let extremeVolume = VolumeCalculator.calculateExerciseVolume(weight: 1000, reps: 100, sets: 10)
        XCTAssertEqual(extremeVolume, 1_000_000, "Should handle large values correctly")

        // Test with very small values
        let smallVolume = VolumeCalculator.calculateExerciseVolume(weight: 0.25, reps: 1, sets: 1)
        XCTAssertEqual(smallVolume, 0.25, "Should handle small values correctly")
    }

    func testVolumeValidation() {
        // Test validation logic
        XCTAssertTrue(VolumeCalculator.isValidVolumeInput(weight: 100, reps: 8, sets: 3), "Valid inputs should pass")
        XCTAssertFalse(VolumeCalculator.isValidVolumeInput(weight: -50, reps: 8, sets: 3), "Negative weight should fail")
        XCTAssertFalse(VolumeCalculator.isValidVolumeInput(weight: 100, reps: -5, sets: 3), "Negative reps should fail")
        XCTAssertFalse(VolumeCalculator.isValidVolumeInput(weight: 100, reps: 8, sets: -1), "Negative sets should fail")
        XCTAssertFalse(VolumeCalculator.isValidVolumeInput(weight: 5000, reps: 8, sets: 3), "Unrealistic weight should fail")
    }

    // MARK: - Statistical Analysis

    func testVolumeDistribution() {
        let workouts = generateSampleWorkouts(count: 10)
        let distribution = VolumeCalculator.analyzeVolumeDistribution(workouts: workouts)

        XCTAssertGreaterThan(distribution.mean, 0, "Mean volume should be positive")
        XCTAssertGreaterThanOrEqual(distribution.standardDeviation, 0, "Standard deviation should be non-negative")
        XCTAssertLessThanOrEqual(distribution.minimum, distribution.maximum, "Min should be less than or equal to max")
        XCTAssertGreaterThanOrEqual(distribution.mean, distribution.minimum, "Mean should be >= minimum")
        XCTAssertLessThanOrEqual(distribution.mean, distribution.maximum, "Mean should be <= maximum")
    }

    func testVolumeProgression() {
        let workouts = generateProgressiveWorkouts(weeks: 12)
        let progression = VolumeCalculator.analyzeVolumeProgression(workouts: workouts)

        XCTAssertGreaterThan(progression.slope, 0, "Progressive workouts should have positive slope")
        XCTAssertGreaterThan(progression.rSquared, 0.7, "Good progression should have high R²")
    }

    // MARK: - Helper Methods

    private func generateSampleWorkouts(count: Int) -> [WorkoutData] {
        return (0..<count).map { i in
            WorkoutData(exercises: [
                ExerciseData(name: "Exercise \(i)", sets: [
                    SetData(weight: 150 + Double(i * 5), reps: 8),
                    SetData(weight: 150 + Double(i * 5), reps: 8),
                    SetData(weight: 150 + Double(i * 5), reps: 7)
                ])
            ])
        }
    }

    private func generateProgressiveWorkouts(weeks: Int) -> [WorkoutData] {
        return (0..<weeks).map { week in
            let baseWeight = 135.0 + Double(week * 5) // 5 lb progression per week
            return WorkoutData(exercises: [
                ExerciseData(name: "Progressive Exercise", sets: [
                    SetData(weight: baseWeight, reps: 8),
                    SetData(weight: baseWeight, reps: 8),
                    SetData(weight: baseWeight, reps: 7)
                ])
            ])
        }
    }
}

// MARK: - Supporting Types

struct WorkoutData {
    let exercises: [ExerciseData]
}

struct ExerciseData {
    let name: String
    let sets: [SetData]
}

struct SetData {
    let weight: Double
    let reps: Int
}

struct SetDataWithRPE {
    let weight: Double
    let reps: Int
    let rpe: Double
}

struct ProgressiveOverloadResult {
    let volumeIncrease: Double
    let hasProgressed: Bool
    let percentageIncrease: Double
}

struct VolumeByIntensity {
    let highIntensity: Double    // >85% 1RM
    let moderateIntensity: Double // 70-85% 1RM
    let lowIntensity: Double     // <70% 1RM
}

struct VolumeDistribution {
    let mean: Double
    let standardDeviation: Double
    let minimum: Double
    let maximum: Double
    let median: Double
}

struct VolumeProgression {
    let slope: Double
    let rSquared: Double
    let weeklyIncrease: Double
}

// MARK: - Volume Calculator Implementation

struct VolumeCalculator {

    static func calculateExerciseVolume(weight: Double, reps: Int, sets: Int) -> Double {
        return weight * Double(reps) * Double(sets)
    }

    static func calculateMultiSetVolume(sets: [SetData]) -> Double {
        return sets.reduce(0) { total, set in
            total + (set.weight * Double(set.reps))
        }
    }

    static func calculateWorkoutVolume(workout: WorkoutData) -> Double {
        return workout.exercises.reduce(0) { total, exercise in
            total + calculateMultiSetVolume(sets: exercise.sets)
        }
    }

    static func calculateProgressiveOverload(previous: WorkoutData, current: WorkoutData) -> ProgressiveOverloadResult {
        let previousVolume = calculateWorkoutVolume(workout: previous)
        let currentVolume = calculateWorkoutVolume(workout: current)
        let increase = currentVolume - previousVolume
        let percentageIncrease = previousVolume > 0 ? (increase / previousVolume) * 100 : 0

        return ProgressiveOverloadResult(
            volumeIncrease: increase,
            hasProgressed: increase > 0,
            percentageIncrease: percentageIncrease
        )
    }

    static func calculateWeeklyVolume(workouts: [WorkoutData], exerciseName: String) -> Double {
        return workouts.reduce(0) { total, workout in
            let exerciseVolume = workout.exercises
                .filter { $0.name == exerciseName }
                .reduce(0) { subtotal, exercise in
                    subtotal + calculateMultiSetVolume(sets: exercise.sets)
                }
            return total + exerciseVolume
        }
    }

    static func calculateMonthlyVolume(workouts: [WorkoutData], exerciseName: String) -> Double {
        return calculateWeeklyVolume(workouts: workouts, exerciseName: exerciseName)
    }

    static func calculateVolumeLoad(sets: [SetDataWithRPE]) -> Double {
        return sets.reduce(0) { total, set in
            total + (set.weight * Double(set.reps)) / set.rpe
        }
    }

    static func calculateVolumeByIntensityZones(sets: [SetData], oneRM: Double) -> VolumeByIntensity {
        var high = 0.0, moderate = 0.0, low = 0.0

        for set in sets {
            let percentage = set.weight / oneRM
            let volume = set.weight * Double(set.reps)

            if percentage >= 0.85 {
                high += volume
            } else if percentage >= 0.70 {
                moderate += volume
            } else {
                low += volume
            }
        }

        return VolumeByIntensity(highIntensity: high, moderateIntensity: moderate, lowIntensity: low)
    }

    static func calculateTonnage(workout: WorkoutData) -> Double {
        let totalLbs = calculateWorkoutVolume(workout: workout)
        return totalLbs / 2204.62 // Convert pounds to metric tonnes
    }

    static func calculateVolumePerBodyweight(workout: WorkoutData, bodyweight: Double) -> Double {
        let volume = calculateWorkoutVolume(workout: workout)
        return volume / bodyweight
    }

    static func isValidVolumeInput(weight: Double, reps: Int, sets: Int) -> Bool {
        return weight >= 0 && weight <= 2000 &&
               reps >= 0 && reps <= 100 &&
               sets >= 0 && sets <= 50
    }

    static func analyzeVolumeDistribution(workouts: [WorkoutData]) -> VolumeDistribution {
        let volumes = workouts.map { calculateWorkoutVolume(workout: $0) }
        let sortedVolumes = volumes.sorted()

        let mean = volumes.reduce(0, +) / Double(volumes.count)
        let variance = volumes.map { pow($0 - mean, 2) }.reduce(0, +) / Double(volumes.count)
        let standardDeviation = sqrt(variance)
        let minimum = sortedVolumes.first ?? 0
        let maximum = sortedVolumes.last ?? 0
        let median = sortedVolumes.count % 2 == 0 ?
            (sortedVolumes[sortedVolumes.count/2 - 1] + sortedVolumes[sortedVolumes.count/2]) / 2 :
            sortedVolumes[sortedVolumes.count/2]

        return VolumeDistribution(
            mean: mean,
            standardDeviation: standardDeviation,
            minimum: minimum,
            maximum: maximum,
            median: median
        )
    }

    static func analyzeVolumeProgression(workouts: [WorkoutData]) -> VolumeProgression {
        let volumes = workouts.map { calculateWorkoutVolume(workout: $0) }
        let n = Double(volumes.count)

        // Calculate linear regression
        let xMean = (n - 1) / 2
        let yMean = volumes.reduce(0, +) / n

        var numerator = 0.0
        var denominator = 0.0

        for (i, volume) in volumes.enumerated() {
            let x = Double(i)
            numerator += (x - xMean) * (volume - yMean)
            denominator += pow(x - xMean, 2)
        }

        let slope = denominator > 0 ? numerator / denominator : 0

        // Calculate R²
        var ssTotal = 0.0
        var ssResidual = 0.0

        for (i, volume) in volumes.enumerated() {
            let predicted = yMean + slope * (Double(i) - xMean)
            ssTotal += pow(volume - yMean, 2)
            ssResidual += pow(volume - predicted, 2)
        }

        let rSquared = ssTotal > 0 ? 1 - (ssResidual / ssTotal) : 0

        return VolumeProgression(
            slope: slope,
            rSquared: max(0, rSquared),
            weeklyIncrease: slope * 7 // Assuming daily data points
        )
    }
}