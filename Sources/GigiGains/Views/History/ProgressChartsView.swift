//
//  ProgressChartsView.swift
//  Gigi Gains
//
//  Progress charts view for PR tracking and workout analytics.
//  Displays visual representations of strength progress and workout data.
//
//  Created: 2025-09-28
//

import SwiftUI
import Charts

struct ProgressChartsView: View {
    @StateObject private var viewModel = ProgressChartsViewModel()
    @State private var selectedTimeRange: TimeRange = .threeMonths
    @State private var selectedMetric: ProgressMetric = .strength
    @State private var selectedExercise: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                metricsSelector
                timeRangeSelector
                mainChart
                summaryCards
                exerciseBreakdown
            }
            .padding()
        }
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            viewModel.loadProgressData()
        }
        .onChange(of: selectedTimeRange) { _ in
            viewModel.updateTimeRange(selectedTimeRange)
        }
        .onChange(of: selectedMetric) { _ in
            viewModel.updateMetric(selectedMetric)
        }
    }

    private var metricsSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress Metrics")
                .font(.headline)
                .fontWeight(.semibold)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ProgressMetric.allCases, id: \.self) { metric in
                        Button(action: {
                            selectedMetric = metric
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: metric.iconName)
                                    .font(.title2)
                                Text(metric.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(selectedMetric == metric ? .white : .blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                selectedMetric == metric
                                    ? Color.blue
                                    : Color.blue.opacity(0.1)
                            )
                            .cornerRadius(12)
                        }
                        .accessibilityLabel("View \(metric.displayName) progress")
                        .accessibilityAddTraits(selectedMetric == metric ? .isSelected : [])
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var timeRangeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Time Range")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.displayName).tag(range)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }

    private var mainChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(selectedMetric.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                if let trend = viewModel.currentTrend {
                    HStack(spacing: 4) {
                        Image(systemName: trend.isPositive ? "arrow.up.right" : "arrow.down.right")
                            .foregroundColor(trend.isPositive ? .green : .red)
                        Text(trend.displayValue)
                            .fontWeight(.medium)
                            .foregroundColor(trend.isPositive ? .green : .red)
                    }
                    .font(.subheadline)
                }
            }

            chartView
                .frame(height: 250)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private var chartView: some View {
        switch selectedMetric {
        case .strength:
            strengthChart
        case .volume:
            volumeChart
        case .frequency:
            frequencyChart
        case .bodyweight:
            bodyweightChart
        }
    }

    private var strengthChart: some View {
        Chart(viewModel.strengthData) { dataPoint in
            LineMark(
                x: .value("Date", dataPoint.date),
                y: .value("Weight", dataPoint.value)
            )
            .foregroundStyle(.blue)
            .symbol(Circle().strokeBorder(lineWidth: 2))

            PointMark(
                x: .value("Date", dataPoint.date),
                y: .value("Weight", dataPoint.value)
            )
            .foregroundStyle(.blue)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated))
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
    }

    private var volumeChart: some View {
        Chart(viewModel.volumeData) { dataPoint in
            BarMark(
                x: .value("Date", dataPoint.date),
                y: .value("Volume", dataPoint.value)
            )
            .foregroundStyle(.green)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
    }

    private var frequencyChart: some View {
        Chart(viewModel.frequencyData) { dataPoint in
            LineMark(
                x: .value("Date", dataPoint.date),
                y: .value("Frequency", dataPoint.value)
            )
            .foregroundStyle(.orange)

            AreaMark(
                x: .value("Date", dataPoint.date),
                y: .value("Frequency", dataPoint.value)
            )
            .foregroundStyle(.orange.opacity(0.3))
        }
    }

    private var bodyweightChart: some View {
        Chart(viewModel.bodyweightData) { dataPoint in
            LineMark(
                x: .value("Date", dataPoint.date),
                y: .value("Weight", dataPoint.value)
            )
            .foregroundStyle(.purple)
            .symbol(Circle().strokeBorder(lineWidth: 2))
        }
        .chartYScale(domain: .automatic(includesZero: false))
    }

    private var summaryCards: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ForEach(viewModel.summaryStats, id: \.title) { stat in
                SummaryCard(
                    title: stat.title,
                    value: stat.value,
                    subtitle: stat.subtitle,
                    trend: stat.trend,
                    color: stat.color
                )
            }
        }
    }

    private var exerciseBreakdown: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Exercise Progress")
                .font(.title2)
                .fontWeight(.semibold)

            ForEach(viewModel.exerciseProgress, id: \.exerciseName) { exercise in
                ExerciseProgressRow(
                    exerciseName: exercise.exerciseName,
                    currentMax: exercise.currentMax,
                    previousMax: exercise.previousMax,
                    improvement: exercise.improvement,
                    lastImprovement: exercise.lastImprovement
                ) {
                    selectedExercise = exercise.exerciseName
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let title: String
    let value: String
    let subtitle: String
    let trend: TrendIndicator?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if let trend = trend {
                    HStack(spacing: 2) {
                        Image(systemName: trend.isPositive ? "arrow.up" : "arrow.down")
                        Text(trend.displayValue)
                    }
                    .font(.caption2)
                    .foregroundColor(trend.isPositive ? .green : .red)
                }
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Exercise Progress Row

struct ExerciseProgressRow: View {
    let exerciseName: String
    let currentMax: Double
    let previousMax: Double?
    let improvement: Double?
    let lastImprovement: Date?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exerciseName)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    if let lastImprovement = lastImprovement {
                        Text("Last PR: \(lastImprovement, style: .relative)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(currentMax)) lbs")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    if let improvement = improvement, improvement != 0 {
                        HStack(spacing: 2) {
                            Image(systemName: improvement > 0 ? "arrow.up" : "arrow.down")
                            Text("\(Int(abs(improvement))) lbs")
                        }
                        .font(.caption)
                        .foregroundColor(improvement > 0 ? .green : .red)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(exerciseName), current max \(Int(currentMax)) pounds")
    }
}

// MARK: - Supporting Types

enum ProgressMetric: String, CaseIterable {
    case strength = "strength"
    case volume = "volume"
    case frequency = "frequency"
    case bodyweight = "bodyweight"

    var displayName: String {
        switch self {
        case .strength: return "Strength"
        case .volume: return "Volume"
        case .frequency: return "Frequency"
        case .bodyweight: return "Body Weight"
        }
    }

    var iconName: String {
        switch self {
        case .strength: return "dumbbell"
        case .volume: return "chart.bar.fill"
        case .frequency: return "calendar"
        case .bodyweight: return "scalemass"
        }
    }
}

enum TimeRange: String, CaseIterable {
    case oneMonth = "1m"
    case threeMonths = "3m"
    case sixMonths = "6m"
    case oneYear = "1y"

    var displayName: String {
        switch self {
        case .oneMonth: return "1M"
        case .threeMonths: return "3M"
        case .sixMonths: return "6M"
        case .oneYear: return "1Y"
        }
    }

    var dateRange: (start: Date, end: Date) {
        let end = Date()
        let calendar = Calendar.current

        let start: Date
        switch self {
        case .oneMonth:
            start = calendar.date(byAdding: .month, value: -1, to: end) ?? end
        case .threeMonths:
            start = calendar.date(byAdding: .month, value: -3, to: end) ?? end
        case .sixMonths:
            start = calendar.date(byAdding: .month, value: -6, to: end) ?? end
        case .oneYear:
            start = calendar.date(byAdding: .year, value: -1, to: end) ?? end
        }

        return (start, end)
    }
}

struct ProgressDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct TrendIndicator {
    let value: Double
    let isPositive: Bool

    var displayValue: String {
        let absValue = abs(value)
        if absValue >= 1000 {
            return String(format: "%.1fk", absValue / 1000)
        } else {
            return String(format: "%.0f", absValue)
        }
    }
}

struct SummaryStatistic {
    let title: String
    let value: String
    let subtitle: String
    let trend: TrendIndicator?
    let color: Color
}

struct ExerciseProgress {
    let exerciseName: String
    let currentMax: Double
    let previousMax: Double?
    let improvement: Double?
    let lastImprovement: Date?
}

// MARK: - View Model

class ProgressChartsViewModel: ObservableObject {
    @Published var strengthData: [ProgressDataPoint] = []
    @Published var volumeData: [ProgressDataPoint] = []
    @Published var frequencyData: [ProgressDataPoint] = []
    @Published var bodyweightData: [ProgressDataPoint] = []
    @Published var summaryStats: [SummaryStatistic] = []
    @Published var exerciseProgress: [ExerciseProgress] = []
    @Published var currentTrend: TrendIndicator?

    private var currentTimeRange: TimeRange = .threeMonths
    private var currentMetric: ProgressMetric = .strength

    func loadProgressData() {
        generateSampleData()
        updateCurrentTrend()
        updateSummaryStats()
        updateExerciseProgress()
    }

    func updateTimeRange(_ timeRange: TimeRange) {
        currentTimeRange = timeRange
        generateSampleData()
        updateCurrentTrend()
    }

    func updateMetric(_ metric: ProgressMetric) {
        currentMetric = metric
        updateCurrentTrend()
    }

    private func generateSampleData() {
        let (startDate, endDate) = currentTimeRange.dateRange
        let dayCount = Int(endDate.timeIntervalSince(startDate) / 86400)

        strengthData = generateDataPoints(
            startDate: startDate,
            endDate: endDate,
            count: min(dayCount / 7, 20), // Weekly data points
            baseValue: 135,
            variation: 50
        )

        volumeData = generateDataPoints(
            startDate: startDate,
            endDate: endDate,
            count: min(dayCount / 7, 20),
            baseValue: 8000,
            variation: 3000
        )

        frequencyData = generateDataPoints(
            startDate: startDate,
            endDate: endDate,
            count: min(dayCount / 7, 20),
            baseValue: 3.5,
            variation: 1.5
        )

        bodyweightData = generateDataPoints(
            startDate: startDate,
            endDate: endDate,
            count: min(dayCount / 7, 20),
            baseValue: 180,
            variation: 10
        )
    }

    private func generateDataPoints(startDate: Date, endDate: Date, count: Int, baseValue: Double, variation: Double) -> [ProgressDataPoint] {
        let timeInterval = endDate.timeIntervalSince(startDate)
        let stepInterval = timeInterval / Double(count - 1)

        return (0..<count).map { index in
            let date = startDate.addingTimeInterval(Double(index) * stepInterval)
            let trend = sin(Double(index) * 0.3) * 0.5 + 0.5 // Gradual upward trend
            let noise = Double.random(in: -0.2...0.2)
            let value = baseValue + (trend + noise) * variation

            return ProgressDataPoint(date: date, value: value)
        }
    }

    private func updateCurrentTrend() {
        let data: [ProgressDataPoint]
        switch currentMetric {
        case .strength: data = strengthData
        case .volume: data = volumeData
        case .frequency: data = frequencyData
        case .bodyweight: data = bodyweightData
        }

        guard data.count >= 2 else {
            currentTrend = nil
            return
        }

        let recent = Array(data.suffix(5))
        let earlier = Array(data.prefix(5))

        let recentAvg = recent.map { $0.value }.reduce(0, +) / Double(recent.count)
        let earlierAvg = earlier.map { $0.value }.reduce(0, +) / Double(earlier.count)

        let change = recentAvg - earlierAvg
        currentTrend = TrendIndicator(value: change, isPositive: change >= 0)
    }

    private func updateSummaryStats() {
        summaryStats = [
            SummaryStatistic(
                title: "Max Bench",
                value: "225 lbs",
                subtitle: "Personal Record",
                trend: TrendIndicator(value: 15, isPositive: true),
                color: .blue
            ),
            SummaryStatistic(
                title: "Weekly Volume",
                value: "45K lbs",
                subtitle: "This week",
                trend: TrendIndicator(value: 5.2, isPositive: true),
                color: .green
            ),
            SummaryStatistic(
                title: "Workout Frequency",
                value: "4.2/week",
                subtitle: "Average",
                trend: TrendIndicator(value: 0.8, isPositive: true),
                color: .orange
            ),
            SummaryStatistic(
                title: "Body Weight",
                value: "182 lbs",
                subtitle: "Current",
                trend: TrendIndicator(value: 2.1, isPositive: true),
                color: .purple
            )
        ]
    }

    private func updateExerciseProgress() {
        exerciseProgress = [
            ExerciseProgress(
                exerciseName: "Bench Press",
                currentMax: 225,
                previousMax: 215,
                improvement: 10,
                lastImprovement: Calendar.current.date(byAdding: .day, value: -5, to: Date())
            ),
            ExerciseProgress(
                exerciseName: "Squat",
                currentMax: 315,
                previousMax: 305,
                improvement: 10,
                lastImprovement: Calendar.current.date(byAdding: .day, value: -12, to: Date())
            ),
            ExerciseProgress(
                exerciseName: "Deadlift",
                currentMax: 385,
                previousMax: 375,
                improvement: 10,
                lastImprovement: Calendar.current.date(byAdding: .day, value: -8, to: Date())
            ),
            ExerciseProgress(
                exerciseName: "Shoulder Press",
                currentMax: 135,
                previousMax: 130,
                improvement: 5,
                lastImprovement: Calendar.current.date(byAdding: .day, value: -15, to: Date())
            )
        ]
    }
}

// MARK: - Preview

#if DEBUG
struct ProgressChartsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ProgressChartsView()
        }
        .preferredColorScheme(.light)
        .previewDisplayName("Light Mode")

        NavigationView {
            ProgressChartsView()
        }
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")
    }
}
#endif