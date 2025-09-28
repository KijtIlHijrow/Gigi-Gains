//
//  PlateCalculatorView.swift
//  Gigi Gains
//
//  Plate calculator view for weight loading calculations.
//  Helps users determine which plates to load for target weights.
//
//  Created: 2025-09-28
//

import SwiftUI

struct PlateCalculatorView: View {
    @StateObject private var calculator = PlateCalculator()
    @State private var targetWeight = ""
    @State private var selectedBarWeight: BarWeight = .standard45
    @State private var showingPlateSetup = false

    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            calculatorHeader
            weightInput
            barSelection
            plateCalculation
            quickWeightButtons
            Spacer()
        }
        .padding()
        .navigationTitle("Plate Calculator")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Setup") {
                    showingPlateSetup = true
                }
                .accessibilityLabel("Plate setup")
                .accessibilityHint("Configure available plates")
            }
        }
        .sheet(isPresented: $showingPlateSetup) {
            PlateSetupView(calculator: calculator)
        }
        .onChange(of: targetWeight) { _ in
            calculatePlates()
        }
        .onChange(of: selectedBarWeight) { _ in
            calculatePlates()
        }
    }

    private var calculatorHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "scalemass")
                .font(.system(size: 50))
                .foregroundColor(.blue)

            Text("Calculate Plate Loading")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Enter your target weight to see which plates to load")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var weightInput: some View {
        VStack(spacing: 12) {
            Text("Target Weight")
                .font(.headline)
                .fontWeight(.medium)

            HStack {
                TextField("0", text: $targetWeight)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .focused($isInputFocused)
                    .accessibilityLabel("Target weight")

                Text("lbs")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)

            Button("Clear") {
                targetWeight = ""
                isInputFocused = false
            }
            .font(.subheadline)
            .foregroundColor(.blue)
            .opacity(targetWeight.isEmpty ? 0 : 1)
        }
    }

    private var barSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Barbell Weight")
                .font(.headline)
                .fontWeight(.medium)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(BarWeight.allCases, id: \.self) { barWeight in
                        Button(action: {
                            selectedBarWeight = barWeight
                        }) {
                            VStack(spacing: 4) {
                                Text(barWeight.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("\(Int(barWeight.weight)) lbs")
                                    .font(.caption)
                            }
                            .foregroundColor(selectedBarWeight == barWeight ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                selectedBarWeight == barWeight
                                    ? Color.blue
                                    : Color(.systemGray5)
                            )
                            .cornerRadius(12)
                        }
                        .accessibilityLabel("\(barWeight.displayName), \(Int(barWeight.weight)) pounds")
                        .accessibilityAddTraits(selectedBarWeight == barWeight ? .isSelected : [])
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var plateCalculation: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let result = calculator.currentResult {
                HStack {
                    Text("Plate Loading")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Spacer()

                    if result.isExact {
                        Label("Exact", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Label("Closest: \(Int(result.actualWeight)) lbs", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                if result.plateConfiguration.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)

                        Text("No plates needed")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("Target weight equals bar weight")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    plateVisualization(for: result)
                    plateList(for: result)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)

                    Text("Enter a target weight")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private func plateVisualization(for result: PlateCalculationResult) -> some View {
        VStack(spacing: 12) {
            Text("Each Side")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                // Bar end
                Rectangle()
                    .frame(width: 20, height: 8)
                    .foregroundColor(.gray)

                // Plates
                ForEach(result.plateConfiguration.indices, id: \.self) { index in
                    let plate = result.plateConfiguration[index]
                    Rectangle()
                        .frame(width: plateWidth(for: plate.weight), height: plateHeight(for: plate.weight))
                        .foregroundColor(plateColor(for: plate.weight))
                        .overlay(
                            Text("\(Int(plate.weight))")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                }

                // Bar
                Rectangle()
                    .frame(width: 60, height: 12)
                    .foregroundColor(.black)

                // Plates (mirrored)
                ForEach(result.plateConfiguration.reversed().indices, id: \.self) { index in
                    let plate = result.plateConfiguration.reversed()[index]
                    Rectangle()
                        .frame(width: plateWidth(for: plate.weight), height: plateHeight(for: plate.weight))
                        .foregroundColor(plateColor(for: plate.weight))
                        .overlay(
                            Text("\(Int(plate.weight))")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                }

                // Bar end
                Rectangle()
                    .frame(width: 20, height: 8)
                    .foregroundColor(.gray)
            }
        }
    }

    private func plateList(for result: PlateCalculationResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Per Side:")
                .font(.subheadline)
                .fontWeight(.medium)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(result.plateConfiguration, id: \.weight) { plate in
                    HStack {
                        Circle()
                            .frame(width: 12, height: 12)
                            .foregroundColor(plateColor(for: plate.weight))

                        Text("\(plate.count)×\(Int(plate.weight))")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
                }
            }

            HStack {
                Text("Total Weight:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(Int(result.actualWeight)) lbs")
                    .font(.subheadline)
                    .fontWeight(.bold)
            }
            .padding(.top, 8)
        }
    }

    private var quickWeightButtons: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Weights")
                .font(.headline)
                .fontWeight(.medium)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(calculator.commonWeights, id: \.self) { weight in
                    Button(action: {
                        targetWeight = String(Int(weight))
                        isInputFocused = false
                    }) {
                        Text("\(Int(weight))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .accessibilityLabel("\(Int(weight)) pounds")
                }
            }
        }
    }

    private func plateWidth(for weight: Double) -> CGFloat {
        switch weight {
        case 45: return 20
        case 35: return 18
        case 25: return 16
        case 10: return 12
        case 5: return 10
        case 2.5: return 8
        default: return 14
        }
    }

    private func plateHeight(for weight: Double) -> CGFloat {
        switch weight {
        case 45: return 40
        case 35: return 36
        case 25: return 32
        case 10: return 24
        case 5: return 20
        case 2.5: return 16
        default: return 28
        }
    }

    private func plateColor(for weight: Double) -> Color {
        switch weight {
        case 45: return .blue
        case 35: return .yellow
        case 25: return .green
        case 10: return .white
        case 5: return .red
        case 2.5: return .black
        default: return .gray
        }
    }

    private func calculatePlates() {
        guard let target = Double(targetWeight), target > 0 else {
            calculator.currentResult = nil
            return
        }

        calculator.calculatePlates(targetWeight: target, barWeight: selectedBarWeight.weight)
    }
}

// MARK: - Plate Setup View

struct PlateSetupView: View {
    @ObservedObject var calculator: PlateCalculator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Available Plates")) {
                    ForEach(calculator.availablePlates.indices, id: \.self) { index in
                        HStack {
                            Circle()
                                .frame(width: 16, height: 16)
                                .foregroundColor(plateColor(for: calculator.availablePlates[index].weight))

                            Text("\(Int(calculator.availablePlates[index].weight)) lbs")
                                .font(.subheadline)

                            Spacer()

                            Stepper(
                                "Count: \(calculator.availablePlates[index].count)",
                                value: $calculator.availablePlates[index].count,
                                in: 0...20
                            )
                            .accessibilityLabel("Number of \(Int(calculator.availablePlates[index].weight)) pound plates")
                        }
                    }
                }

                Section(header: Text("Presets")) {
                    Button("Home Gym") {
                        calculator.setHomeGymPreset()
                    }

                    Button("Commercial Gym") {
                        calculator.setCommercialGymPreset()
                    }

                    Button("Powerlifting Gym") {
                        calculator.setPowerliftingPreset()
                    }
                }
            }
            .navigationTitle("Plate Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func plateColor(for weight: Double) -> Color {
        switch weight {
        case 45: return .blue
        case 35: return .yellow
        case 25: return .green
        case 10: return .white
        case 5: return .red
        case 2.5: return .black
        default: return .gray
        }
    }
}

// MARK: - Supporting Types

enum BarWeight: Double, CaseIterable {
    case standard45 = 45
    case women35 = 35
    case training15 = 15
    case safety20 = 20

    var displayName: String {
        switch self {
        case .standard45: return "Standard"
        case .women35: return "Women's"
        case .training15: return "Training"
        case .safety20: return "Safety"
        }
    }

    var weight: Double {
        return rawValue
    }
}

struct PlateInfo {
    let weight: Double
    var count: Int
}

struct PlateConfiguration {
    let weight: Double
    let count: Int
}

struct PlateCalculationResult {
    let targetWeight: Double
    let actualWeight: Double
    let plateConfiguration: [PlateConfiguration]
    let isExact: Bool
}

// MARK: - Plate Calculator

class PlateCalculator: ObservableObject {
    @Published var availablePlates: [PlateInfo] = [
        PlateInfo(weight: 45, count: 8),
        PlateInfo(weight: 35, count: 4),
        PlateInfo(weight: 25, count: 4),
        PlateInfo(weight: 10, count: 4),
        PlateInfo(weight: 5, count: 4),
        PlateInfo(weight: 2.5, count: 4)
    ]

    @Published var currentResult: PlateCalculationResult?

    let commonWeights: [Double] = [95, 135, 155, 185, 205, 225, 245, 275, 295, 315, 335, 365, 405, 455]

    func calculatePlates(targetWeight: Double, barWeight: Double) {
        let remainingWeight = targetWeight - barWeight

        guard remainingWeight > 0 else {
            currentResult = PlateCalculationResult(
                targetWeight: targetWeight,
                actualWeight: barWeight,
                plateConfiguration: [],
                isExact: true
            )
            return
        }

        let perSideWeight = remainingWeight / 2
        let configuration = findOptimalConfiguration(for: perSideWeight)

        let actualPerSideWeight = configuration.reduce(0) { total, plate in
            total + (plate.weight * Double(plate.count))
        }

        let actualTotalWeight = barWeight + (actualPerSideWeight * 2)
        let isExact = abs(actualTotalWeight - targetWeight) < 0.1

        currentResult = PlateCalculationResult(
            targetWeight: targetWeight,
            actualWeight: actualTotalWeight,
            plateConfiguration: configuration,
            isExact: isExact
        )
    }

    private func findOptimalConfiguration(for targetWeight: Double) -> [PlateConfiguration] {
        var remaining = targetWeight
        var configuration: [PlateConfiguration] = []

        // Sort plates by weight (heaviest first)
        let sortedPlates = availablePlates.sorted { $0.weight > $1.weight }

        for plate in sortedPlates {
            let maxUsable = min(plate.count, Int(remaining / plate.weight))
            if maxUsable > 0 {
                configuration.append(PlateConfiguration(weight: plate.weight, count: maxUsable))
                remaining -= Double(maxUsable) * plate.weight
            }
        }

        return configuration
    }

    func setHomeGymPreset() {
        availablePlates = [
            PlateInfo(weight: 45, count: 4),
            PlateInfo(weight: 25, count: 4),
            PlateInfo(weight: 10, count: 4),
            PlateInfo(weight: 5, count: 4),
            PlateInfo(weight: 2.5, count: 4)
        ]
    }

    func setCommercialGymPreset() {
        availablePlates = [
            PlateInfo(weight: 45, count: 12),
            PlateInfo(weight: 35, count: 8),
            PlateInfo(weight: 25, count: 8),
            PlateInfo(weight: 10, count: 8),
            PlateInfo(weight: 5, count: 8),
            PlateInfo(weight: 2.5, count: 8)
        ]
    }

    func setPowerliftingPreset() {
        availablePlates = [
            PlateInfo(weight: 55, count: 4), // 25kg
            PlateInfo(weight: 45, count: 8), // 20kg
            PlateInfo(weight: 35, count: 4), // 15kg
            PlateInfo(weight: 25, count: 8), // 10kg
            PlateInfo(weight: 11, count: 4), // 5kg
            PlateInfo(weight: 5.5, count: 4), // 2.5kg
            PlateInfo(weight: 2.75, count: 4), // 1.25kg
        ]
    }
}

// MARK: - Preview

#if DEBUG
struct PlateCalculatorView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PlateCalculatorView()
        }
        .preferredColorScheme(.light)
        .previewDisplayName("Light Mode")

        NavigationView {
            PlateCalculatorView()
        }
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")
    }
}

struct PlateSetupView_Previews: PreviewProvider {
    static var previews: some View {
        PlateSetupView(calculator: PlateCalculator())
    }
}
#endif