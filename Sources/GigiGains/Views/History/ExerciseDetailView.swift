//
//  ExerciseDetailView.swift
//  Gigi Gains
//
//  Exercise detail view showing history and personal records.
//  Displays comprehensive exercise analytics and performance tracking.
//
//  Created: 2025-09-28
//

import SwiftUI
import Charts

struct ExerciseDetailView: View {
    let exerciseName: String

    @StateObject private var viewModel = ExerciseDetailViewModel()
    @State private var selectedTimeRange: TimeRange = .threeMonths
    @State private var selectedMetric: ExerciseMetric = .oneRM
    @State private var showingWorkoutDetail = false
    @State private var selectedWorkout: ExerciseWorkout?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                exerciseHeader
                metricsChart
                personalRecords
                recentWorkouts
                exerciseNotes
            }
            .padding()
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Add to Routine") {
                        // Add exercise to routine
                    }

                    Button("View Exercise Library") {
                        // Show exercise information
                    }

                    Button("Export Data") {
                        // Export exercise data
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $selectedWorkout) { workout in
            WorkoutDetailView(workout: workout)
        }
        .onAppear {
            viewModel.loadExerciseData(for: exerciseName)
        }
        .onChange(of: selectedTimeRange) { _ in
            viewModel.updateTimeRange(selectedTimeRange)
        }
        .onChange(of: selectedMetric) { _ in
            viewModel.updateMetric(selectedMetric)
        }
    }

    private var exerciseHeader: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current 1RM")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(viewModel.currentOneRM)) lbs")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Last Workout")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let lastWorkout = viewModel.lastWorkoutDate {
                        Text(lastWorkout, style: .relative)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    } else {
                        Text("Never")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if let improvement = viewModel.recentImprovement {
                HStack {
                    Image(systemName: improvement.isPositive ? "arrow.up.right" : "arrow.down.right")
                        .foregroundColor(improvement.isPositive ? .green : .red)

                    Text("\(improvement.displayValue) from last month")
                        .font(.subheadline)
                        .foregroundColor(improvement.isPositive ? .green : .red)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private var metricsChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Progress")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Picker("Metric", selection: $selectedMetric) {
                        ForEach(ExerciseMetric.allCases, id: \.self) { metric in
                            Text(metric.displayName).tag(metric)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Spacer()
            }

            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.displayName).tag(range)
                }
            }
            .pickerStyle(SegmentedPickerStyle())

            chartView
                .frame(height: 200)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private var chartView: some View {
        if viewModel.chartData.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)

                Text("No data available")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text("Complete some workouts to see your progress")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart(viewModel.chartData) { dataPoint in
                LineMark(
                    x: .value("Date", dataPoint.date),
                    y: .value(selectedMetric.displayName, dataPoint.value)
                )
                .foregroundStyle(.blue)
                .symbol(Circle().strokeBorder(lineWidth: 2))

                if dataPoint.isPersonalRecord {
                    PointMark(
                        x: .value("Date", dataPoint.date),
                        y: .value(selectedMetric.displayName, dataPoint.value)
                    )
                    .foregroundStyle(.orange)
                    .symbol(Triangle().strokeBorder(lineWidth: 2))
                }
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
    }

    private var personalRecords: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Personal Records")
                .font(.title2)
                .fontWeight(.semibold)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(viewModel.personalRecords, id: \.type) { record in
                    PersonalRecordCard(record: record)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private var recentWorkouts: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Workouts")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button("View All") {
                    // Navigate to full workout history for this exercise
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }

            if viewModel.recentWorkouts.isEmpty {
                VStack(spacing: 8) {
                    Text("No recent workouts")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("This exercise hasn't been performed recently")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(viewModel.recentWorkouts, id: \.id) { workout in
                    ExerciseWorkoutRow(workout: workout) {
                        selectedWorkout = workout
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private var exerciseNotes: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercise Notes")
                .font(.headline)
                .fontWeight(.semibold)

            if let notes = viewModel.exerciseNotes, !notes.isEmpty {
                Text(notes)
                    .font(.body)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 8) {
                    Text("No notes yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button("Add Notes") {
                        // Add exercise notes
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Personal Record Card

struct PersonalRecordCard: View {
    let record: PersonalRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(record.type)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            Text(record.displayValue)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            if let date = record.date {
                Text(date, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Exercise Workout Row

struct ExerciseWorkoutRow: View {
    let workout: ExerciseWorkout
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.workoutName)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(workout.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(workout.bestSetDisplay)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    HStack(spacing: 4) {
                        Text("\(workout.totalSets) sets")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if workout.hasPersonalRecord {
                            Image(systemName: "trophy.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Supporting Types

enum ExerciseMetric: String, CaseIterable {
    case oneRM = "1rm"
    case volume = "volume"
    case maxReps = "maxReps"
    case totalSets = "totalSets"

    var displayName: String {
        switch self {
        case .oneRM: return "1RM"
        case .volume: return "Volume"
        case .maxReps: return "Max Reps"
        case .totalSets: return "Total Sets"
        }
    }
}

struct ExerciseDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let isPersonalRecord: Bool
}

struct PersonalRecord {
    let type: String
    let value: Double
    let unit: String
    let date: Date?

    var displayValue: String {
        switch type.lowercased() {
        case "1rm", "max weight":
            return "\(Int(value)) \(unit)"
        case "max reps":
            return "\(Int(value)) reps"
        case "max volume":
            if value >= 1000 {
                return String(format: "%.1fK \(unit)", value / 1000)
            } else {
                return "\(Int(value)) \(unit)"
            }
        default:
            return "\(Int(value)) \(unit)"
        }
    }
}

struct ExerciseWorkout: Identifiable {
    let id = UUID()
    let workoutName: String
    let date: Date
    let sets: [ExerciseSet]
    let hasPersonalRecord: Bool

    var totalSets: Int {
        sets.count
    }

    var bestSetDisplay: String {
        guard let bestSet = sets.max(by: { ($0.weight ?? 0) < ($1.weight ?? 0) }) else {
            return "No sets"
        }

        if let weight = bestSet.weight {
            return "\(Int(weight)) lbs × \(bestSet.reps)"
        } else {
            return "\(bestSet.reps) reps"
        }
    }
}

struct ExerciseSet {
    let weight: Double?
    let reps: Int
    let rpe: Double?
    let isPersonalRecord: Bool
}

// MARK: - Triangle Symbol

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - View Model

class ExerciseDetailViewModel: ObservableObject {
    @Published var chartData: [ExerciseDataPoint] = []
    @Published var personalRecords: [PersonalRecord] = []
    @Published var recentWorkouts: [ExerciseWorkout] = []
    @Published var currentOneRM: Double = 0
    @Published var lastWorkoutDate: Date?
    @Published var recentImprovement: TrendIndicator?
    @Published var exerciseNotes: String?

    private var currentTimeRange: TimeRange = .threeMonths
    private var currentMetric: ExerciseMetric = .oneRM
    private var currentExercise: String = ""

    func loadExerciseData(for exerciseName: String) {
        currentExercise = exerciseName
        generateSampleData()
        loadPersonalRecords()
        loadRecentWorkouts()
        calculateCurrentStats()
    }

    func updateTimeRange(_ timeRange: TimeRange) {
        currentTimeRange = timeRange
        generateSampleData()
    }

    func updateMetric(_ metric: ExerciseMetric) {
        currentMetric = metric
        generateSampleData()
    }

    private func generateSampleData() {
        let (startDate, endDate) = currentTimeRange.dateRange
        let dayCount = Int(endDate.timeIntervalSince(startDate) / 86400)
        let dataPointCount = min(dayCount / 14, 15) // Bi-weekly data points

        chartData = (0..<dataPointCount).compactMap { index in
            // Simulate some workouts being skipped
            guard Bool.random() else { return nil }

            let date = startDate.addingTimeInterval(Double(index) * 14 * 86400)
            let progress = Double(index) / Double(dataPointCount - 1)
            let baseValue = getBaseValue(for: currentMetric)
            let improvement = progress * getImprovementRange(for: currentMetric)
            let noise = Double.random(in: -0.1...0.1) * baseValue
            let value = baseValue + improvement + noise

            let isPersonalRecord = index > 0 && index % 4 == 0 && Bool.random()

            return ExerciseDataPoint(
                date: date,
                value: max(0, value),
                isPersonalRecord: isPersonalRecord
            )
        }
    }

    private func loadPersonalRecords() {
        personalRecords = [
            PersonalRecord(
                type: "1RM",
                value: 225,
                unit: "lbs",
                date: Calendar.current.date(byAdding: .day, value: -5, to: Date())
            ),
            PersonalRecord(
                type: "Max Reps",
                value: 12,
                unit: "reps",
                date: Calendar.current.date(byAdding: .day, value: -12, to: Date())
            ),
            PersonalRecord(
                type: "Max Volume",
                value: 4500,
                unit: "lbs",
                date: Calendar.current.date(byAdding: .day, value: -3, to: Date())
            ),
            PersonalRecord(
                type: "Best RPE 8",
                value: 205,
                unit: "lbs",
                date: Calendar.current.date(byAdding: .day, value: -8, to: Date())
            )
        ]
    }

    private func loadRecentWorkouts() {
        recentWorkouts = [
            ExerciseWorkout(
                workoutName: "Push Day",
                date: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
                sets: [
                    ExerciseSet(weight: 185, reps: 8, rpe: 7, isPersonalRecord: false),
                    ExerciseSet(weight: 185, reps: 8, rpe: 8, isPersonalRecord: false),
                    ExerciseSet(weight: 185, reps: 6, rpe: 9, isPersonalRecord: false)
                ],
                hasPersonalRecord: false
            ),
            ExerciseWorkout(
                workoutName: "Chest Focus",
                date: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
                sets: [
                    ExerciseSet(weight: 225, reps: 1, rpe: 10, isPersonalRecord: true),
                    ExerciseSet(weight: 205, reps: 3, rpe: 9, isPersonalRecord: false),
                    ExerciseSet(weight: 185, reps: 8, rpe: 8, isPersonalRecord: false)
                ],
                hasPersonalRecord: true
            ),
            ExerciseWorkout(
                workoutName: "Upper Body",
                date: Calendar.current.date(byAdding: .day, value: -9, to: Date()) ?? Date(),
                sets: [
                    ExerciseSet(weight: 185, reps: 10, rpe: 7, isPersonalRecord: false),
                    ExerciseSet(weight: 185, reps: 8, rpe: 8, isPersonalRecord: false),
                    ExerciseSet(weight: 185, reps: 6, rpe: 9, isPersonalRecord: false)
                ],
                hasPersonalRecord: false
            )
        ]
    }

    private func calculateCurrentStats() {
        currentOneRM = 225
        lastWorkoutDate = recentWorkouts.first?.date
        recentImprovement = TrendIndicator(value: 15, isPositive: true)
        exerciseNotes = "Focus on controlled tempo. 3-second negative, 1-second pause at chest."
    }

    private func getBaseValue(for metric: ExerciseMetric) -> Double {
        switch metric {
        case .oneRM: return 185
        case .volume: return 3500
        case .maxReps: return 8
        case .totalSets: return 12
        }
    }

    private func getImprovementRange(for metric: ExerciseMetric) -> Double {
        switch metric {
        case .oneRM: return 40
        case .volume: return 2000
        case .maxReps: return 4
        case .totalSets: return 8
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ExerciseDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ExerciseDetailView(exerciseName: "Bench Press")
        }
        .preferredColorScheme(.light)
        .previewDisplayName("Light Mode")

        NavigationView {
            ExerciseDetailView(exerciseName: "Squat")
        }
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")
    }
}
#endif