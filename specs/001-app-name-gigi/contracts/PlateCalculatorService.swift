//
//  PlateCalculatorService.swift
//  Gigi Gains - Internal API Contract
//
//  Defines the interface for weight plate calculation utilities supporting
//  both kg and lb weight systems with customizable plate configurations.
//
//  Created: 2025-09-28
//

import Foundation
import Combine

// MARK: - Supporting Types

/// Weight unit systems supported by the calculator
public enum WeightUnit: String, CaseIterable {
    case kilograms = "kg"
    case pounds = "lb"

    public var description: String {
        return rawValue
    }

    public var fullName: String {
        switch self {
        case .kilograms: return "Kilograms"
        case .pounds: return "Pounds"
        }
    }

    /// Conversion factor to kilograms
    public var toKilogramsMultiplier: Double {
        switch self {
        case .kilograms: return 1.0
        case .pounds: return 0.453592
        }
    }

    /// Conversion factor from kilograms
    public var fromKilogramsMultiplier: Double {
        switch self {
        case .kilograms: return 1.0
        case .pounds: return 2.20462
        }
    }
}

/// Individual weight plate specification
public struct WeightPlate {
    public let weight: Double
    public let unit: WeightUnit
    public let count: Int
    public let color: String?
    public let isOlympic: Bool
    public let isPowerlifting: Bool

    public init(weight: Double, unit: WeightUnit, count: Int, color: String? = nil, isOlympic: Bool = false, isPowerlifting: Bool = false) {
        self.weight = weight
        self.unit = unit
        self.count = count
        self.color = color
        self.isOlympic = isOlympic
        self.isPowerlifting = isPowerlifting
    }

    /// Weight converted to specified unit
    public func weight(in targetUnit: WeightUnit) -> Double {
        if unit == targetUnit {
            return weight
        }

        let weightInKg = weight * unit.toKilogramsMultiplier
        return weightInKg * targetUnit.fromKilogramsMultiplier
    }

    /// Formatted weight string with unit
    public var formattedWeight: String {
        return String(format: "%.1f%@", weight, unit.rawValue)
    }
}

/// Barbell specification
public struct Barbell {
    public let name: String
    public let weight: Double
    public let unit: WeightUnit
    public let length: Double? // in meters
    public let isOlympic: Bool
    public let isPowerlifting: Bool

    public init(name: String, weight: Double, unit: WeightUnit, length: Double? = nil, isOlympic: Bool = false, isPowerlifting: Bool = false) {
        self.name = name
        self.weight = weight
        self.unit = unit
        self.length = length
        self.isOlympic = isOlympic
        self.isPowerlifting = isPowerlifting
    }

    /// Weight converted to specified unit
    public func weight(in targetUnit: WeightUnit) -> Double {
        if unit == targetUnit {
            return weight
        }

        let weightInKg = weight * unit.toKilogramsMultiplier
        return weightInKg * targetUnit.fromKilogramsMultiplier
    }

    /// Formatted weight string with unit
    public var formattedWeight: String {
        return String(format: "%.1f%@", weight, unit.rawValue)
    }
}

/// Configuration for a complete plate set
public struct PlateSetConfiguration {
    public let name: String
    public let barbell: Barbell
    public let plates: [WeightPlate]
    public let unit: WeightUnit
    public let isDefault: Bool

    public init(name: String, barbell: Barbell, plates: [WeightPlate], unit: WeightUnit, isDefault: Bool = false) {
        self.name = name
        self.barbell = barbell
        self.plates = plates
        self.unit = unit
        self.isDefault = isDefault
    }

    /// Total number of plates available
    public var totalPlateCount: Int {
        return plates.reduce(0) { $0 + $1.count }
    }

    /// Maximum possible weight with this configuration
    public var maxWeight: Double {
        let plateWeight = plates.reduce(0.0) { total, plate in
            total + (plate.weight(in: unit) * Double(plate.count))
        }
        return barbell.weight(in: unit) + plateWeight
    }
}

/// Result of plate calculation showing how to load the barbell
public struct PlateCalculationResult {
    public let targetWeight: Double
    public let actualWeight: Double
    public let barbell: Barbell
    public let platesPerSide: [PlateUsage]
    public let unit: WeightUnit
    public let isExact: Bool
    public let errorMessage: String?

    public init(targetWeight: Double, actualWeight: Double, barbell: Barbell, platesPerSide: [PlateUsage], unit: WeightUnit, isExact: Bool, errorMessage: String? = nil) {
        self.targetWeight = targetWeight
        self.actualWeight = actualWeight
        self.barbell = barbell
        self.platesPerSide = platesPerSide
        self.unit = unit
        self.isExact = isExact
        self.errorMessage = errorMessage
    }

    /// Difference between target and actual weight
    public var weightDifference: Double {
        return actualWeight - targetWeight
    }

    /// Total number of plates used
    public var totalPlatesUsed: Int {
        return platesPerSide.reduce(0) { $0 + $1.count } * 2 // Both sides
    }

    /// Whether the calculation was successful
    public var isSuccessful: Bool {
        return errorMessage == nil
    }

    /// Formatted loading instructions
    public var loadingInstructions: String {
        guard isSuccessful else {
            return errorMessage ?? "Calculation failed"
        }

        if platesPerSide.isEmpty {
            return "Use only the \(barbell.name) (\(barbell.formattedWeight))"
        }

        let plateList = platesPerSide.map { plateUsage in
            if plateUsage.count == 1 {
                return plateUsage.plate.formattedWeight
            } else {
                return "\(plateUsage.count)×\(plateUsage.plate.formattedWeight)"
            }
        }.joined(separator: " + ")

        return "Load each side: \(plateList)"
    }
}

/// Usage of a specific plate in the calculation
public struct PlateUsage {
    public let plate: WeightPlate
    public let count: Int

    public init(plate: WeightPlate, count: Int) {
        self.plate = plate
        self.count = count
    }

    /// Total weight contribution from this plate usage
    public var totalWeight: Double {
        return plate.weight * Double(count)
    }
}

/// Errors that can occur during plate calculations
public enum PlateCalculatorError: Error, LocalizedError {
    case invalidTargetWeight(Double)
    case insufficientPlates(targetWeight: Double, maxPossible: Double)
    case noPlatesAvailable
    case invalidPlateConfiguration
    case weightTooLight(minimumWeight: Double)
    case conversionError(from: WeightUnit, to: WeightUnit)

    public var errorDescription: String? {
        switch self {
        case .invalidTargetWeight(let weight):
            return "Invalid target weight: \(weight)"
        case .insufficientPlates(let target, let max):
            return "Insufficient plates. Target: \(target), Maximum possible: \(max)"
        case .noPlatesAvailable:
            return "No plates available in the current configuration"
        case .invalidPlateConfiguration:
            return "Invalid plate configuration"
        case .weightTooLight(let minimum):
            return "Weight too light. Minimum weight with current barbell: \(minimum)"
        case .conversionError(let from, let to):
            return "Unable to convert weight from \(from.rawValue) to \(to.rawValue)"
        }
    }
}

/// Algorithm preferences for plate calculation
public struct CalculationPreferences {
    public let preferFewerPlates: Bool
    public let allowApproximation: Bool
    public let approximationTolerance: Double
    public let roundingRule: RoundingRule
    public let prioritizeOlympicPlates: Bool
    public let prioritizePowerliftingPlates: Bool

    public init(preferFewerPlates: Bool = true, allowApproximation: Bool = true, approximationTolerance: Double = 0.5, roundingRule: RoundingRule = .nearest, prioritizeOlympicPlates: Bool = false, prioritizePowerliftingPlates: Bool = false) {
        self.preferFewerPlates = preferFewerPlates
        self.allowApproximation = allowApproximation
        self.approximationTolerance = approximationTolerance
        self.roundingRule = roundingRule
        self.prioritizeOlympicPlates = prioritizeOlympicPlates
        self.prioritizePowerliftingPlates = prioritizePowerliftingPlates
    }
}

/// Rounding rules for weight approximation
public enum RoundingRule: String, CaseIterable {
    case down = "down"
    case up = "up"
    case nearest = "nearest"

    public var description: String {
        switch self {
        case .down: return "Round Down"
        case .up: return "Round Up"
        case .nearest: return "Round to Nearest"
        }
    }
}

/// Statistics about plate usage and calculations
public struct PlateCalculatorStatistics {
    public let totalCalculations: Int
    public let exactMatches: Int
    public let approximations: Int
    public let failedCalculations: Int
    public let mostUsedPlateWeight: Double?
    public let averageWeightCalculated: Double?
    public let preferredUnit: WeightUnit?

    public init(totalCalculations: Int, exactMatches: Int, approximations: Int, failedCalculations: Int, mostUsedPlateWeight: Double?, averageWeightCalculated: Double?, preferredUnit: WeightUnit?) {
        self.totalCalculations = totalCalculations
        self.exactMatches = exactMatches
        self.approximations = approximations
        self.failedCalculations = failedCalculations
        self.mostUsedPlateWeight = mostUsedPlateWeight
        self.averageWeightCalculated = averageWeightCalculated
        self.preferredUnit = preferredUnit
    }

    /// Success rate for exact calculations (0.0 to 1.0)
    public var exactMatchRate: Double {
        guard totalCalculations > 0 else { return 0.0 }
        return Double(exactMatches) / Double(totalCalculations)
    }

    /// Overall success rate including approximations (0.0 to 1.0)
    public var successRate: Double {
        guard totalCalculations > 0 else { return 0.0 }
        return Double(totalCalculations - failedCalculations) / Double(totalCalculations)
    }
}

// MARK: - Main Protocol

/// Service protocol for weight plate calculation utilities
///
/// This protocol defines the complete interface for plate calculation in the Gigi Gains app.
/// It supports both kg and lb weight systems, customizable plate configurations, and intelligent
/// algorithms for determining the optimal plate loading for any target weight.
///
/// Key responsibilities:
/// - Weight plate calculations for target weights
/// - Support for multiple weight units (kg/lb)
/// - Customizable plate set configurations
/// - Barbell weight consideration
/// - Optimal plate loading algorithms
/// - Weight conversion utilities
/// - Plate set management and persistence
/// - Calculation history and statistics
///
/// ## Usage Example:
/// ```swift
/// let calculator: PlateCalculatorService = PlateCalculatorServiceImpl()
///
/// // Calculate plates needed for 100kg
/// let result = try await calculator.calculatePlates(
///     targetWeight: 100.0,
///     unit: .kilograms,
///     plateSetName: "Olympic"
/// )
///
/// print(result.loadingInstructions)
/// // Output: "Load each side: 2×20kg + 1×5kg"
///
/// // Convert weight between units
/// let poundsWeight = try await calculator.convertWeight(
///     100.0,
///     from: .kilograms,
///     to: .pounds
/// )
/// ```
public protocol PlateCalculatorService: AnyObject {

    // MARK: - Publishers for Reactive Updates

    /// Publishes updates to plate set configurations
    /// Emits when plate sets are added, modified, or removed
    var plateSetConfigurationsPublisher: AnyPublisher<[PlateSetConfiguration], Never> { get }

    /// Publishes calculation preference changes
    /// Useful for updating UI based on user preferences
    var calculationPreferencesPublisher: AnyPublisher<CalculationPreferences, Never> { get }

    // MARK: - Plate Calculation

    /// Calculates the optimal plate loading for a target weight
    /// - Parameters:
    ///   - targetWeight: The desired total weight
    ///   - unit: The weight unit for the target weight
    ///   - plateSetName: Name of the plate set configuration to use (nil for default)
    /// - Returns: Calculation result with plate loading instructions
    /// - Throws: `PlateCalculatorError` if calculation fails
    func calculatePlates(targetWeight: Double, unit: WeightUnit, plateSetName: String?) async throws -> PlateCalculationResult

    /// Calculates plates using a specific plate set configuration
    /// - Parameters:
    ///   - targetWeight: The desired total weight
    ///   - unit: The weight unit for the target weight
    ///   - configuration: The plate set configuration to use
    /// - Returns: Calculation result with plate loading instructions
    /// - Throws: `PlateCalculatorError` if calculation fails
    func calculatePlates(targetWeight: Double, unit: WeightUnit, configuration: PlateSetConfiguration) async throws -> PlateCalculationResult

    /// Calculates plates with custom preferences
    /// - Parameters:
    ///   - targetWeight: The desired total weight
    ///   - unit: The weight unit for the target weight
    ///   - plateSetName: Name of the plate set configuration to use
    ///   - preferences: Custom calculation preferences
    /// - Returns: Calculation result with plate loading instructions
    /// - Throws: `PlateCalculatorError` if calculation fails
    func calculatePlates(targetWeight: Double, unit: WeightUnit, plateSetName: String?, preferences: CalculationPreferences) async throws -> PlateCalculationResult

    /// Finds the closest achievable weight to the target
    /// - Parameters:
    ///   - targetWeight: The desired total weight
    ///   - unit: The weight unit for the target weight
    ///   - plateSetName: Name of the plate set configuration to use
    ///   - tolerance: Maximum acceptable difference from target
    /// - Returns: Calculation result for the closest achievable weight
    /// - Throws: `PlateCalculatorError` if no weight within tolerance can be achieved
    func findClosestWeight(targetWeight: Double, unit: WeightUnit, plateSetName: String?, tolerance: Double) async throws -> PlateCalculationResult

    /// Validates if a target weight is achievable with the current plate set
    /// - Parameters:
    ///   - targetWeight: The weight to validate
    ///   - unit: The weight unit
    ///   - plateSetName: Name of the plate set configuration to check
    /// - Returns: True if the weight is exactly achievable
    func canAchieveWeight(targetWeight: Double, unit: WeightUnit, plateSetName: String?) async -> Bool

    /// Gets the minimum and maximum weights possible with a plate set
    /// - Parameters:
    ///   - plateSetName: Name of the plate set configuration to analyze
    ///   - unit: The weight unit for the result
    /// - Returns: Tuple of (minimum weight, maximum weight)
    /// - Throws: `PlateCalculatorError` if plate set is invalid
    func getWeightRange(plateSetName: String?, unit: WeightUnit) async throws -> (min: Double, max: Double)

    // MARK: - Weight Conversion

    /// Converts weight between different units
    /// - Parameters:
    ///   - weight: The weight value to convert
    ///   - fromUnit: The source unit
    ///   - toUnit: The target unit
    /// - Returns: The converted weight value
    /// - Throws: `PlateCalculatorError.conversionError` if conversion fails
    func convertWeight(_ weight: Double, from fromUnit: WeightUnit, to toUnit: WeightUnit) async throws -> Double

    /// Converts multiple weights between units
    /// - Parameters:
    ///   - weights: Array of weight values to convert
    ///   - fromUnit: The source unit
    ///   - toUnit: The target unit
    /// - Returns: Array of converted weight values
    func convertWeights(_ weights: [Double], from fromUnit: WeightUnit, to toUnit: WeightUnit) async throws -> [Double]

    /// Rounds weight to the nearest achievable value
    /// - Parameters:
    ///   - weight: The weight to round
    ///   - unit: The weight unit
    ///   - plateSetName: Name of the plate set to use for rounding
    ///   - rule: Rounding rule to apply
    /// - Returns: The rounded weight value
    func roundWeight(_ weight: Double, unit: WeightUnit, plateSetName: String?, rule: RoundingRule) async throws -> Double

    // MARK: - Plate Set Configuration Management

    /// Gets all available plate set configurations
    /// - Returns: Array of all plate set configurations
    func getPlateSetConfigurations() async -> [PlateSetConfiguration]

    /// Gets a specific plate set configuration by name
    /// - Parameter name: Name of the plate set configuration
    /// - Returns: The plate set configuration, or nil if not found
    func getPlateSetConfiguration(name: String) async -> PlateSetConfiguration?

    /// Gets the default plate set configuration
    /// - Returns: The default plate set configuration
    func getDefaultPlateSetConfiguration() async -> PlateSetConfiguration

    /// Creates a new plate set configuration
    /// - Parameter configuration: The plate set configuration to create
    /// - Throws: `PlateCalculatorError.invalidPlateConfiguration` if configuration is invalid
    func createPlateSetConfiguration(_ configuration: PlateSetConfiguration) async throws

    /// Updates an existing plate set configuration
    /// - Parameters:
    ///   - name: Name of the configuration to update
    ///   - configuration: The updated configuration
    /// - Throws: `PlateCalculatorError.invalidPlateConfiguration` if configuration is invalid
    func updatePlateSetConfiguration(name: String, configuration: PlateSetConfiguration) async throws

    /// Deletes a plate set configuration
    /// - Parameter name: Name of the configuration to delete
    /// - Note: Cannot delete the default configuration
    func deletePlateSetConfiguration(name: String) async throws

    /// Sets the default plate set configuration
    /// - Parameter name: Name of the configuration to set as default
    /// - Throws: `PlateCalculatorError` if configuration doesn't exist
    func setDefaultPlateSetConfiguration(name: String) async throws

    /// Duplicates a plate set configuration with a new name
    /// - Parameters:
    ///   - sourceName: Name of the configuration to duplicate
    ///   - newName: Name for the new configuration
    /// - Returns: The duplicated configuration
    /// - Throws: `PlateCalculatorError` if source configuration doesn't exist
    func duplicatePlateSetConfiguration(sourceName: String, newName: String) async throws -> PlateSetConfiguration

    // MARK: - Predefined Plate Sets

    /// Gets standard Olympic plate set configuration
    /// - Parameter unit: The weight unit for the plate set
    /// - Returns: Standard Olympic plate set configuration
    func getOlympicPlateSet(unit: WeightUnit) async -> PlateSetConfiguration

    /// Gets standard powerlifting plate set configuration
    /// - Parameter unit: The weight unit for the plate set
    /// - Returns: Standard powerlifting plate set configuration
    func getPowerliftingPlateSet(unit: WeightUnit) async -> PlateSetConfiguration

    /// Gets basic home gym plate set configuration
    /// - Parameter unit: The weight unit for the plate set
    /// - Returns: Basic home gym plate set configuration
    func getHomeGymPlateSet(unit: WeightUnit) async -> PlateSetConfiguration

    /// Gets commercial gym standard plate set configuration
    /// - Parameter unit: The weight unit for the plate set
    /// - Returns: Commercial gym standard plate set configuration
    func getCommercialGymPlateSet(unit: WeightUnit) async -> PlateSetConfiguration

    /// Initializes default plate set configurations
    /// - Note: Creates standard plate sets if none exist
    /// - Returns: Number of configurations created
    func initializeDefaultPlateConfigurations() async -> Int

    // MARK: - Calculation Preferences

    /// Gets the current calculation preferences
    /// - Returns: Current calculation preferences
    func getCalculationPreferences() async -> CalculationPreferences

    /// Updates calculation preferences
    /// - Parameter preferences: New calculation preferences
    func updateCalculationPreferences(_ preferences: CalculationPreferences) async

    /// Resets calculation preferences to defaults
    func resetCalculationPreferences() async

    // MARK: - History and Statistics

    /// Records a plate calculation for statistics
    /// - Parameter result: The calculation result to record
    /// - Note: Called automatically after successful calculations
    func recordCalculation(_ result: PlateCalculationResult) async

    /// Gets plate calculator usage statistics
    /// - Returns: Usage statistics and analytics
    func getCalculatorStatistics() async -> PlateCalculatorStatistics

    /// Gets calculation history
    /// - Parameter limit: Maximum number of recent calculations to return
    /// - Returns: Array of recent calculation results
    func getCalculationHistory(limit: Int) async -> [PlateCalculationResult]

    /// Clears calculation history
    /// - Parameter olderThan: Clear entries older than this date (nil for all)
    func clearCalculationHistory(olderThan: Date?) async

    /// Gets the most frequently calculated weights
    /// - Parameters:
    ///   - unit: Weight unit for the results
    ///   - limit: Maximum number of weights to return
    /// - Returns: Array of frequently calculated weights
    func getMostCalculatedWeights(unit: WeightUnit, limit: Int) async -> [Double]

    // MARK: - Utility Functions

    /// Validates a plate set configuration
    /// - Parameter configuration: Configuration to validate
    /// - Returns: Array of validation errors, empty if valid
    func validatePlateSetConfiguration(_ configuration: PlateSetConfiguration) -> [String]

    /// Estimates the number of plates needed for a weight range
    /// - Parameters:
    ///   - minWeight: Minimum weight in the range
    ///   - maxWeight: Maximum weight in the range
    ///   - unit: Weight unit
    ///   - plateSetName: Plate set to use for estimation
    /// - Returns: Estimated plate count needed
    func estimatePlatesNeeded(minWeight: Double, maxWeight: Double, unit: WeightUnit, plateSetName: String?) async throws -> Int

    /// Suggests optimal plate set for a given weight range
    /// - Parameters:
    ///   - minWeight: Minimum weight to accommodate
    ///   - maxWeight: Maximum weight to accommodate
    ///   - unit: Weight unit
    /// - Returns: Suggested plate set configuration
    func suggestOptimalPlateSet(minWeight: Double, maxWeight: Double, unit: WeightUnit) async -> PlateSetConfiguration

    /// Formats weight value according to user preferences
    /// - Parameters:
    ///   - weight: Weight value to format
    ///   - unit: Weight unit
    ///   - includeUnit: Whether to include unit suffix
    /// - Returns: Formatted weight string
    func formatWeight(_ weight: Double, unit: WeightUnit, includeUnit: Bool) async -> String
}

// MARK: - Test Helper Protocol

/// Protocol for test implementations and mocking
/// Enables dependency injection and unit testing of components that depend on PlateCalculatorService
public protocol MockablePlateCalculatorService: PlateCalculatorService {
    /// Allows tests to inject mock plate configurations
    func setMockPlateConfigurations(_ configurations: [PlateSetConfiguration])

    /// Allows tests to simulate calculation results
    func setMockCalculationResult(_ result: PlateCalculationResult)

    /// Allows tests to simulate errors
    func setMockError(_ error: PlateCalculatorError?)

    /// Allows tests to control preferences
    func setMockPreferences(_ preferences: CalculationPreferences)

    /// Allows tests to inject mock statistics
    func setMockStatistics(_ statistics: PlateCalculatorStatistics)
}