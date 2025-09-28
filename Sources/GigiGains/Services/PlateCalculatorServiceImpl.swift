//
//  PlateCalculatorServiceImpl.swift
//  Gigi Gains
//
//  Implementation of PlateCalculatorService protocol providing comprehensive
//  weight plate calculation utilities with support for multiple weight systems.
//
//  Created: 2025-09-28
//

import Foundation
import Combine

public class PlateCalculatorServiceImpl: PlateCalculatorService {

    // MARK: - Properties

    private let plateSetConfigurationsSubject = CurrentValueSubject<[PlateSetConfiguration], Never>([])
    private let calculationPreferencesSubject = CurrentValueSubject<CalculationPreferences, Never>(CalculationPreferences())

    private var plateConfigurations: [String: PlateSetConfiguration] = [:]
    private var currentPreferences = CalculationPreferences()
    private var calculationHistory: [PlateCalculationResult] = []
    private var statistics = PlateCalculatorStatistics(
        totalCalculations: 0,
        exactMatches: 0,
        approximations: 0,
        failedCalculations: 0,
        mostUsedPlateWeight: nil,
        averageWeightCalculated: nil,
        preferredUnit: nil
    )

    // MARK: - Publishers

    public var plateSetConfigurationsPublisher: AnyPublisher<[PlateSetConfiguration], Never> {
        plateSetConfigurationsSubject.eraseToAnyPublisher()
    }

    public var calculationPreferencesPublisher: AnyPublisher<CalculationPreferences, Never> {
        calculationPreferencesSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    public init() {
        Task {
            await initializeDefaultPlateConfigurations()
        }
    }

    // MARK: - Plate Calculation

    public func calculatePlates(targetWeight: Double, unit: WeightUnit, plateSetName: String?) async throws -> PlateCalculationResult {
        let configuration = await getPlateSetConfiguration(name: plateSetName) ?? await getDefaultPlateSetConfiguration()
        return try await calculatePlates(targetWeight: targetWeight, unit: unit, configuration: configuration)
    }

    public func calculatePlates(targetWeight: Double, unit: WeightUnit, configuration: PlateSetConfiguration) async throws -> PlateCalculationResult {
        return try await calculatePlates(targetWeight: targetWeight, unit: unit, plateSetName: configuration.name, preferences: currentPreferences)
    }

    public func calculatePlates(targetWeight: Double, unit: WeightUnit, plateSetName: String?, preferences: CalculationPreferences) async throws -> PlateCalculationResult {
        let configuration = await getPlateSetConfiguration(name: plateSetName) ?? await getDefaultPlateSetConfiguration()

        guard targetWeight > 0 else {
            throw PlateCalculatorError.invalidTargetWeight(targetWeight)
        }

        let targetWeightInConfigUnit = try await convertWeight(targetWeight, from: unit, to: configuration.unit)
        let barbellWeight = configuration.barbell.weight(in: configuration.unit)

        // Check if target weight is too light (less than barbell weight)
        if targetWeightInConfigUnit < barbellWeight {
            throw PlateCalculatorError.weightTooLight(minimumWeight: barbellWeight)
        }

        // Weight needed from plates (both sides combined)
        let plateWeight = targetWeightInConfigUnit - barbellWeight

        // Weight needed per side
        let weightPerSide = plateWeight / 2.0

        // Sort plates by weight (heaviest first for greedy algorithm)
        let sortedPlates = configuration.plates.sorted { $0.weight > $1.weight }

        var bestResult: PlateCalculationResult?
        var remainingWeight = weightPerSide

        // Try to find exact match first
        if let exactResult = try calculateExactMatch(
            weightPerSide: weightPerSide,
            plates: sortedPlates,
            configuration: configuration,
            targetWeight: targetWeight,
            originalUnit: unit,
            preferences: preferences
        ) {
            bestResult = exactResult
        }

        // If no exact match and approximation is allowed
        if bestResult == nil && preferences.allowApproximation {
            bestResult = try calculateApproximateMatch(
                weightPerSide: weightPerSide,
                plates: sortedPlates,
                configuration: configuration,
                targetWeight: targetWeight,
                originalUnit: unit,
                preferences: preferences
            )
        }

        guard let result = bestResult else {
            let maxWeight = try await convertWeight(configuration.maxWeight, from: configuration.unit, to: unit)
            throw PlateCalculatorError.insufficientPlates(targetWeight: targetWeight, maxPossible: maxWeight)
        }

        // Record calculation for statistics
        await recordCalculation(result)

        return result
    }

    public func findClosestWeight(targetWeight: Double, unit: WeightUnit, plateSetName: String?, tolerance: Double) async throws -> PlateCalculationResult {
        var modifiedPreferences = currentPreferences
        modifiedPreferences = CalculationPreferences(
            preferFewerPlates: modifiedPreferences.preferFewerPlates,
            allowApproximation: true,
            approximationTolerance: tolerance,
            roundingRule: modifiedPreferences.roundingRule,
            prioritizeOlympicPlates: modifiedPreferences.prioritizeOlympicPlates,
            prioritizePowerliftingPlates: modifiedPreferences.prioritizePowerliftingPlates
        )

        return try await calculatePlates(targetWeight: targetWeight, unit: unit, plateSetName: plateSetName, preferences: modifiedPreferences)
    }

    public func canAchieveWeight(targetWeight: Double, unit: WeightUnit, plateSetName: String?) async -> Bool {
        do {
            let result = try await calculatePlates(targetWeight: targetWeight, unit: unit, plateSetName: plateSetName)
            return result.isExact
        } catch {
            return false
        }
    }

    public func getWeightRange(plateSetName: String?, unit: WeightUnit) async throws -> (min: Double, max: Double) {
        let configuration = await getPlateSetConfiguration(name: plateSetName) ?? await getDefaultPlateSetConfiguration()

        let minWeight = try await convertWeight(configuration.barbell.weight(in: configuration.unit), from: configuration.unit, to: unit)
        let maxWeight = try await convertWeight(configuration.maxWeight, from: configuration.unit, to: unit)

        return (minWeight, maxWeight)
    }

    // MARK: - Weight Conversion

    public func convertWeight(_ weight: Double, from fromUnit: WeightUnit, to toUnit: WeightUnit) async throws -> Double {
        guard weight >= 0 else {
            throw PlateCalculatorError.conversionError(from: fromUnit, to: toUnit)
        }

        if fromUnit == toUnit {
            return weight
        }

        let weightInKg = weight * fromUnit.toKilogramsMultiplier
        return weightInKg * toUnit.fromKilogramsMultiplier
    }

    public func convertWeights(_ weights: [Double], from fromUnit: WeightUnit, to toUnit: WeightUnit) async throws -> [Double] {
        return try await withThrowingTaskGroup(of: Double.self) { group in
            for weight in weights {
                group.addTask {
                    try await self.convertWeight(weight, from: fromUnit, to: toUnit)
                }
            }

            var convertedWeights: [Double] = []
            for try await convertedWeight in group {
                convertedWeights.append(convertedWeight)
            }
            return convertedWeights
        }
    }

    public func roundWeight(_ weight: Double, unit: WeightUnit, plateSetName: String?, rule: RoundingRule) async throws -> Double {
        let configuration = await getPlateSetConfiguration(name: plateSetName) ?? await getDefaultPlateSetConfiguration()

        // Find the smallest plate weight to determine rounding increment
        let smallestPlate = configuration.plates.min { $0.weight < $1.weight }
        guard let increment = smallestPlate?.weight(in: unit) else {
            return weight
        }

        let barbellWeight = try await convertWeight(configuration.barbell.weight(in: configuration.unit), from: configuration.unit, to: unit)

        // Calculate the weight that needs to come from plates
        let plateWeight = max(0, weight - barbellWeight)

        // Round to nearest increment that can be achieved with two sides
        let incrementPerSide = increment
        let targetPerSide = plateWeight / 2.0

        let roundedPerSide: Double
        switch rule {
        case .down:
            roundedPerSide = floor(targetPerSide / incrementPerSide) * incrementPerSide
        case .up:
            roundedPerSide = ceil(targetPerSide / incrementPerSide) * incrementPerSide
        case .nearest:
            roundedPerSide = round(targetPerSide / incrementPerSide) * incrementPerSide
        }

        return barbellWeight + (roundedPerSide * 2.0)
    }

    // MARK: - Plate Set Configuration Management

    public func getPlateSetConfigurations() async -> [PlateSetConfiguration] {
        return Array(plateConfigurations.values).sorted { $0.name < $1.name }
    }

    public func getPlateSetConfiguration(name: String?) async -> PlateSetConfiguration? {
        guard let name = name else { return nil }
        return plateConfigurations[name]
    }

    public func getDefaultPlateSetConfiguration() async -> PlateSetConfiguration {
        return plateConfigurations.values.first { $0.isDefault } ?? await getOlympicPlateSet(unit: .kilograms)
    }

    public func createPlateSetConfiguration(_ configuration: PlateSetConfiguration) async throws {
        let validationErrors = validatePlateSetConfiguration(configuration)
        guard validationErrors.isEmpty else {
            throw PlateCalculatorError.invalidPlateConfiguration
        }

        plateConfigurations[configuration.name] = configuration
        plateSetConfigurationsSubject.send(await getPlateSetConfigurations())
    }

    public func updatePlateSetConfiguration(name: String, configuration: PlateSetConfiguration) async throws {
        guard plateConfigurations[name] != nil else {
            throw PlateCalculatorError.invalidPlateConfiguration
        }

        let validationErrors = validatePlateSetConfiguration(configuration)
        guard validationErrors.isEmpty else {
            throw PlateCalculatorError.invalidPlateConfiguration
        }

        plateConfigurations[name] = configuration
        plateSetConfigurationsSubject.send(await getPlateSetConfigurations())
    }

    public func deletePlateSetConfiguration(name: String) async throws {
        guard let configuration = plateConfigurations[name] else {
            throw PlateCalculatorError.invalidPlateConfiguration
        }

        guard !configuration.isDefault else {
            throw PlateCalculatorError.invalidPlateConfiguration
        }

        plateConfigurations.removeValue(forKey: name)
        plateSetConfigurationsSubject.send(await getPlateSetConfigurations())
    }

    public func setDefaultPlateSetConfiguration(name: String) async throws {
        guard var configuration = plateConfigurations[name] else {
            throw PlateCalculatorError.invalidPlateConfiguration
        }

        // Remove default from all configurations
        for (key, var config) in plateConfigurations {
            config = PlateSetConfiguration(
                name: config.name,
                barbell: config.barbell,
                plates: config.plates,
                unit: config.unit,
                isDefault: false
            )
            plateConfigurations[key] = config
        }

        // Set new default
        configuration = PlateSetConfiguration(
            name: configuration.name,
            barbell: configuration.barbell,
            plates: configuration.plates,
            unit: configuration.unit,
            isDefault: true
        )
        plateConfigurations[name] = configuration

        plateSetConfigurationsSubject.send(await getPlateSetConfigurations())
    }

    public func duplicatePlateSetConfiguration(sourceName: String, newName: String) async throws -> PlateSetConfiguration {
        guard let sourceConfig = plateConfigurations[sourceName] else {
            throw PlateCalculatorError.invalidPlateConfiguration
        }

        let newConfig = PlateSetConfiguration(
            name: newName,
            barbell: sourceConfig.barbell,
            plates: sourceConfig.plates,
            unit: sourceConfig.unit,
            isDefault: false
        )

        try await createPlateSetConfiguration(newConfig)
        return newConfig
    }

    // MARK: - Predefined Plate Sets

    public func getOlympicPlateSet(unit: WeightUnit) async -> PlateSetConfiguration {
        let barbell: Barbell
        let plates: [WeightPlate]

        switch unit {
        case .kilograms:
            barbell = Barbell(name: "Olympic Barbell", weight: 20.0, unit: .kilograms, length: 2.2, isOlympic: true)
            plates = [
                WeightPlate(weight: 25.0, unit: .kilograms, count: 4, color: "Red", isOlympic: true),
                WeightPlate(weight: 20.0, unit: .kilograms, count: 4, color: "Blue", isOlympic: true),
                WeightPlate(weight: 15.0, unit: .kilograms, count: 4, color: "Yellow", isOlympic: true),
                WeightPlate(weight: 10.0, unit: .kilograms, count: 4, color: "Green", isOlympic: true),
                WeightPlate(weight: 5.0, unit: .kilograms, count: 4, color: "White", isOlympic: true),
                WeightPlate(weight: 2.5, unit: .kilograms, count: 4, color: "Black", isOlympic: true),
                WeightPlate(weight: 1.25, unit: .kilograms, count: 4, color: "Chrome", isOlympic: true)
            ]
        case .pounds:
            barbell = Barbell(name: "Olympic Barbell", weight: 45.0, unit: .pounds, length: 2.2, isOlympic: true)
            plates = [
                WeightPlate(weight: 55.0, unit: .pounds, count: 4, color: "Red", isOlympic: true),
                WeightPlate(weight: 45.0, unit: .pounds, count: 4, color: "Blue", isOlympic: true),
                WeightPlate(weight: 35.0, unit: .pounds, count: 4, color: "Yellow", isOlympic: true),
                WeightPlate(weight: 25.0, unit: .pounds, count: 4, color: "Green", isOlympic: true),
                WeightPlate(weight: 10.0, unit: .pounds, count: 4, color: "White", isOlympic: true),
                WeightPlate(weight: 5.0, unit: .pounds, count: 4, color: "Black", isOlympic: true),
                WeightPlate(weight: 2.5, unit: .pounds, count: 4, color: "Chrome", isOlympic: true)
            ]
        }

        return PlateSetConfiguration(
            name: "Olympic \(unit.description)",
            barbell: barbell,
            plates: plates,
            unit: unit,
            isDefault: true
        )
    }

    public func getPowerliftingPlateSet(unit: WeightUnit) async -> PlateSetConfiguration {
        let barbell: Barbell
        let plates: [WeightPlate]

        switch unit {
        case .kilograms:
            barbell = Barbell(name: "Powerlifting Barbell", weight: 20.0, unit: .kilograms, length: 2.2, isPowerlifting: true)
            plates = [
                WeightPlate(weight: 25.0, unit: .kilograms, count: 6, color: "Red", isPowerlifting: true),
                WeightPlate(weight: 20.0, unit: .kilograms, count: 6, color: "Blue", isPowerlifting: true),
                WeightPlate(weight: 15.0, unit: .kilograms, count: 4, color: "Yellow", isPowerlifting: true),
                WeightPlate(weight: 10.0, unit: .kilograms, count: 4, color: "Green", isPowerlifting: true),
                WeightPlate(weight: 5.0, unit: .kilograms, count: 4, color: "White", isPowerlifting: true),
                WeightPlate(weight: 2.5, unit: .kilograms, count: 4, color: "Red", isPowerlifting: true),
                WeightPlate(weight: 1.25, unit: .kilograms, count: 4, color: "Silver", isPowerlifting: true),
                WeightPlate(weight: 0.5, unit: .kilograms, count: 4, color: "Green", isPowerlifting: true)
            ]
        case .pounds:
            barbell = Barbell(name: "Powerlifting Barbell", weight: 45.0, unit: .pounds, length: 2.2, isPowerlifting: true)
            plates = [
                WeightPlate(weight: 55.0, unit: .pounds, count: 6, color: "Red", isPowerlifting: true),
                WeightPlate(weight: 45.0, unit: .pounds, count: 6, color: "Blue", isPowerlifting: true),
                WeightPlate(weight: 35.0, unit: .pounds, count: 4, color: "Yellow", isPowerlifting: true),
                WeightPlate(weight: 25.0, unit: .pounds, count: 4, color: "Green", isPowerlifting: true),
                WeightPlate(weight: 10.0, unit: .pounds, count: 4, color: "White", isPowerlifting: true),
                WeightPlate(weight: 5.0, unit: .pounds, count: 4, color: "Red", isPowerlifting: true),
                WeightPlate(weight: 2.5, unit: .pounds, count: 4, color: "Silver", isPowerlifting: true),
                WeightPlate(weight: 1.0, unit: .pounds, count: 4, color: "Green", isPowerlifting: true)
            ]
        }

        return PlateSetConfiguration(
            name: "Powerlifting \(unit.description)",
            barbell: barbell,
            plates: plates,
            unit: unit
        )
    }

    public func getHomeGymPlateSet(unit: WeightUnit) async -> PlateSetConfiguration {
        let barbell: Barbell
        let plates: [WeightPlate]

        switch unit {
        case .kilograms:
            barbell = Barbell(name: "Standard Barbell", weight: 15.0, unit: .kilograms, length: 1.8)
            plates = [
                WeightPlate(weight: 20.0, unit: .kilograms, count: 4, color: "Black"),
                WeightPlate(weight: 10.0, unit: .kilograms, count: 4, color: "Gray"),
                WeightPlate(weight: 5.0, unit: .kilograms, count: 4, color: "Blue"),
                WeightPlate(weight: 2.5, unit: .kilograms, count: 4, color: "Red"),
                WeightPlate(weight: 1.25, unit: .kilograms, count: 4, color: "Silver")
            ]
        case .pounds:
            barbell = Barbell(name: "Standard Barbell", weight: 35.0, unit: .pounds, length: 1.8)
            plates = [
                WeightPlate(weight: 45.0, unit: .pounds, count: 4, color: "Black"),
                WeightPlate(weight: 25.0, unit: .pounds, count: 4, color: "Gray"),
                WeightPlate(weight: 10.0, unit: .pounds, count: 4, color: "Blue"),
                WeightPlate(weight: 5.0, unit: .pounds, count: 4, color: "Red"),
                WeightPlate(weight: 2.5, unit: .pounds, count: 4, color: "Silver")
            ]
        }

        return PlateSetConfiguration(
            name: "Home Gym \(unit.description)",
            barbell: barbell,
            plates: plates,
            unit: unit
        )
    }

    public func getCommercialGymPlateSet(unit: WeightUnit) async -> PlateSetConfiguration {
        let barbell: Barbell
        let plates: [WeightPlate]

        switch unit {
        case .kilograms:
            barbell = Barbell(name: "Commercial Barbell", weight: 20.0, unit: .kilograms, length: 2.2)
            plates = [
                WeightPlate(weight: 25.0, unit: .kilograms, count: 8, color: "Red"),
                WeightPlate(weight: 20.0, unit: .kilograms, count: 8, color: "Blue"),
                WeightPlate(weight: 15.0, unit: .kilograms, count: 6, color: "Yellow"),
                WeightPlate(weight: 10.0, unit: .kilograms, count: 6, color: "Green"),
                WeightPlate(weight: 5.0, unit: .kilograms, count: 6, color: "White"),
                WeightPlate(weight: 2.5, unit: .kilograms, count: 6, color: "Black"),
                WeightPlate(weight: 1.25, unit: .kilograms, count: 6, color: "Chrome")
            ]
        case .pounds:
            barbell = Barbell(name: "Commercial Barbell", weight: 45.0, unit: .pounds, length: 2.2)
            plates = [
                WeightPlate(weight: 45.0, unit: .pounds, count: 8, color: "Black"),
                WeightPlate(weight: 35.0, unit: .pounds, count: 6, color: "Gray"),
                WeightPlate(weight: 25.0, unit: .pounds, count: 6, color: "Green"),
                WeightPlate(weight: 10.0, unit: .pounds, count: 6, color: "Blue"),
                WeightPlate(weight: 5.0, unit: .pounds, count: 6, color: "Red"),
                WeightPlate(weight: 2.5, unit: .pounds, count: 6, color: "Silver")
            ]
        }

        return PlateSetConfiguration(
            name: "Commercial Gym \(unit.description)",
            barbell: barbell,
            plates: plates,
            unit: unit
        )
    }

    @discardableResult
    public func initializeDefaultPlateConfigurations() async -> Int {
        var createdCount = 0

        let defaultConfigurations = [
            await getOlympicPlateSet(unit: .kilograms),
            await getOlympicPlateSet(unit: .pounds),
            await getPowerliftingPlateSet(unit: .kilograms),
            await getPowerliftingPlateSet(unit: .pounds),
            await getHomeGymPlateSet(unit: .kilograms),
            await getHomeGymPlateSet(unit: .pounds),
            await getCommercialGymPlateSet(unit: .kilograms),
            await getCommercialGymPlateSet(unit: .pounds)
        ]

        for configuration in defaultConfigurations {
            if plateConfigurations[configuration.name] == nil {
                plateConfigurations[configuration.name] = configuration
                createdCount += 1
            }
        }

        plateSetConfigurationsSubject.send(await getPlateSetConfigurations())
        return createdCount
    }

    // MARK: - Calculation Preferences

    public func getCalculationPreferences() async -> CalculationPreferences {
        return currentPreferences
    }

    public func updateCalculationPreferences(_ preferences: CalculationPreferences) async {
        currentPreferences = preferences
        calculationPreferencesSubject.send(preferences)
    }

    public func resetCalculationPreferences() async {
        currentPreferences = CalculationPreferences()
        calculationPreferencesSubject.send(currentPreferences)
    }

    // MARK: - History and Statistics

    public func recordCalculation(_ result: PlateCalculationResult) async {
        calculationHistory.append(result)

        // Keep only last 100 calculations
        if calculationHistory.count > 100 {
            calculationHistory.removeFirst(calculationHistory.count - 100)
        }

        // Update statistics
        updateStatistics()
    }

    public func getCalculatorStatistics() async -> PlateCalculatorStatistics {
        return statistics
    }

    public func getCalculationHistory(limit: Int) async -> [PlateCalculationResult] {
        return Array(calculationHistory.suffix(limit))
    }

    public func clearCalculationHistory(olderThan: Date?) async {
        if let cutoffDate = olderThan {
            calculationHistory.removeAll { result in
                // For this implementation, we don't have timestamps on results
                // In a real implementation, we'd add timestamps to PlateCalculationResult
                return false
            }
        } else {
            calculationHistory.removeAll()
        }
        updateStatistics()
    }

    public func getMostCalculatedWeights(unit: WeightUnit, limit: Int) async -> [Double] {
        let weights = calculationHistory.compactMap { result in
            do {
                return try await convertWeight(result.targetWeight, from: result.unit, to: unit)
            } catch {
                return nil
            }
        }

        let weightCounts = Dictionary(grouping: weights) { $0 }
            .mapValues { $0.count }

        return Array(weightCounts.sorted { $0.value > $1.value }.prefix(limit).map { $0.key })
    }

    // MARK: - Utility Functions

    public func validatePlateSetConfiguration(_ configuration: PlateSetConfiguration) -> [String] {
        var errors: [String] = []

        if configuration.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Configuration name cannot be empty")
        }

        if configuration.barbell.weight <= 0 {
            errors.append("Barbell weight must be positive")
        }

        if configuration.plates.isEmpty {
            errors.append("At least one plate is required")
        }

        for plate in configuration.plates {
            if plate.weight <= 0 {
                errors.append("Plate weight must be positive")
            }
            if plate.count < 0 {
                errors.append("Plate count must be non-negative")
            }
        }

        return errors
    }

    public func estimatePlatesNeeded(minWeight: Double, maxWeight: Double, unit: WeightUnit, plateSetName: String?) async throws -> Int {
        let configuration = await getPlateSetConfiguration(name: plateSetName) ?? await getDefaultPlateSetConfiguration()

        let maxWeightInConfigUnit = try await convertWeight(maxWeight, from: unit, to: configuration.unit)
        let barbellWeight = configuration.barbell.weight(in: configuration.unit)
        let plateWeight = maxWeightInConfigUnit - barbellWeight

        // Simple estimation: assume we need enough plates to achieve max weight
        let heaviestPlate = configuration.plates.max { $0.weight < $1.weight }
        guard let heaviest = heaviestPlate else { return 0 }

        let estimatedPairs = Int(ceil(plateWeight / (2.0 * heaviest.weight)))
        return estimatedPairs * 2
    }

    public func suggestOptimalPlateSet(minWeight: Double, maxWeight: Double, unit: WeightUnit) async -> PlateSetConfiguration {
        // For this implementation, return the commercial gym set as it has the most plates
        return await getCommercialGymPlateSet(unit: unit)
    }

    public func formatWeight(_ weight: Double, unit: WeightUnit, includeUnit: Bool) async -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = weight.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1

        let formattedNumber = formatter.string(from: NSNumber(value: weight)) ?? String(weight)

        if includeUnit {
            return "\(formattedNumber)\(unit.rawValue)"
        } else {
            return formattedNumber
        }
    }

    // MARK: - Private Helper Methods

    private func calculateExactMatch(
        weightPerSide: Double,
        plates: [WeightPlate],
        configuration: PlateSetConfiguration,
        targetWeight: Double,
        originalUnit: WeightUnit,
        preferences: CalculationPreferences
    ) throws -> PlateCalculationResult? {
        var bestPlateUsage: [PlateUsage] = []
        var remainingWeight = weightPerSide

        // Greedy algorithm: use largest plates first
        for plate in plates {
            let availableCount = plate.count / 2 // Each side gets half the total plates
            if availableCount > 0 && plate.weight <= remainingWeight {
                let neededCount = min(availableCount, Int(remainingWeight / plate.weight))
                if neededCount > 0 {
                    bestPlateUsage.append(PlateUsage(plate: plate, count: neededCount))
                    remainingWeight -= Double(neededCount) * plate.weight
                }
            }
        }

        // Check if we achieved exact match
        if abs(remainingWeight) < 0.001 { // Account for floating point precision
            let totalPlateWeight = bestPlateUsage.reduce(0) { $0 + $1.totalWeight } * 2.0
            let actualWeight = configuration.barbell.weight(in: configuration.unit) + totalPlateWeight

            let convertedWeight = try convertWeightSync(actualWeight, from: configuration.unit, to: originalUnit)

            return PlateCalculationResult(
                targetWeight: targetWeight,
                actualWeight: convertedWeight,
                barbell: configuration.barbell,
                platesPerSide: bestPlateUsage,
                unit: originalUnit,
                isExact: true
            )
        }

        return nil
    }

    private func calculateApproximateMatch(
        weightPerSide: Double,
        plates: [WeightPlate],
        configuration: PlateSetConfiguration,
        targetWeight: Double,
        originalUnit: WeightUnit,
        preferences: CalculationPreferences
    ) throws -> PlateCalculationResult? {
        // Try rounding down and up to see which is closer
        let roundedDownWeight = calculateRoundedWeight(weightPerSide: weightPerSide, plates: plates, roundUp: false)
        let roundedUpWeight = calculateRoundedWeight(weightPerSide: weightPerSide, plates: plates, roundUp: true)

        let targetWeightInConfigUnit = try convertWeightSync(targetWeight, from: originalUnit, to: configuration.unit)

        let downDifference = abs(targetWeightInConfigUnit - (configuration.barbell.weight(in: configuration.unit) + roundedDownWeight * 2.0))
        let upDifference = abs(targetWeightInConfigUnit - (configuration.barbell.weight(in: configuration.unit) + roundedUpWeight * 2.0))

        let bestWeight: Double
        switch preferences.roundingRule {
        case .down:
            bestWeight = roundedDownWeight
        case .up:
            bestWeight = roundedUpWeight
        case .nearest:
            bestWeight = downDifference <= upDifference ? roundedDownWeight : roundedUpWeight
        }

        // Calculate plate usage for the chosen weight
        let plateUsage = calculatePlateUsageForWeight(bestWeight, plates: plates)
        let actualTotalWeight = configuration.barbell.weight(in: configuration.unit) + bestWeight * 2.0
        let convertedWeight = try convertWeightSync(actualTotalWeight, from: configuration.unit, to: originalUnit)

        let difference = abs(convertedWeight - targetWeight)
        if difference <= preferences.approximationTolerance {
            return PlateCalculationResult(
                targetWeight: targetWeight,
                actualWeight: convertedWeight,
                barbell: configuration.barbell,
                platesPerSide: plateUsage,
                unit: originalUnit,
                isExact: false
            )
        }

        return nil
    }

    private func calculateRoundedWeight(weightPerSide: Double, plates: [WeightPlate], roundUp: Bool) -> Double {
        var plateUsage: [PlateUsage] = []
        var remainingWeight = weightPerSide

        for plate in plates {
            let availableCount = plate.count / 2
            if availableCount > 0 && plate.weight <= remainingWeight + (roundUp ? plate.weight : 0) {
                let neededCount = min(availableCount, Int(remainingWeight / plate.weight))
                if neededCount > 0 {
                    plateUsage.append(PlateUsage(plate: plate, count: neededCount))
                    remainingWeight -= Double(neededCount) * plate.weight
                }
            }
        }

        return plateUsage.reduce(0) { $0 + $1.totalWeight }
    }

    private func calculatePlateUsageForWeight(_ targetWeight: Double, plates: [WeightPlate]) -> [PlateUsage] {
        var plateUsage: [PlateUsage] = []
        var remainingWeight = targetWeight

        for plate in plates {
            let availableCount = plate.count / 2
            if availableCount > 0 && plate.weight <= remainingWeight {
                let neededCount = min(availableCount, Int(remainingWeight / plate.weight))
                if neededCount > 0 {
                    plateUsage.append(PlateUsage(plate: plate, count: neededCount))
                    remainingWeight -= Double(neededCount) * plate.weight
                }
            }
        }

        return plateUsage
    }

    private func convertWeightSync(_ weight: Double, from fromUnit: WeightUnit, to toUnit: WeightUnit) throws -> Double {
        if fromUnit == toUnit {
            return weight
        }

        let weightInKg = weight * fromUnit.toKilogramsMultiplier
        return weightInKg * toUnit.fromKilogramsMultiplier
    }

    private func updateStatistics() {
        let total = calculationHistory.count
        let exact = calculationHistory.filter { $0.isExact }.count
        let approximations = total - exact
        let failed = calculationHistory.filter { !$0.isSuccessful }.count

        // Calculate most used plate weight
        var plateWeightCounts: [Double: Int] = [:]
        for result in calculationHistory {
            for plateUsage in result.platesPerSide {
                plateWeightCounts[plateUsage.plate.weight, default: 0] += plateUsage.count
            }
        }
        let mostUsedPlateWeight = plateWeightCounts.max { $0.value < $1.value }?.key

        // Calculate average weight
        let totalWeight = calculationHistory.reduce(0) { $0 + $1.targetWeight }
        let averageWeight = total > 0 ? totalWeight / Double(total) : nil

        // Determine preferred unit
        let unitCounts = Dictionary(grouping: calculationHistory) { $0.unit }.mapValues { $0.count }
        let preferredUnit = unitCounts.max { $0.value < $1.value }?.key

        statistics = PlateCalculatorStatistics(
            totalCalculations: total,
            exactMatches: exact,
            approximations: approximations,
            failedCalculations: failed,
            mostUsedPlateWeight: mostUsedPlateWeight,
            averageWeightCalculated: averageWeight,
            preferredUnit: preferredUnit
        )
    }
}