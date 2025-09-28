//
//  WorkoutHistoryView.swift
//  Gigi Gains
//
//  Workout history view for displaying past workout sessions.
//  Shows chronological list of workouts with filtering and search capabilities.
//
//  Created: 2025-09-28
//

import SwiftUI

struct WorkoutHistoryView: View {
    @StateObject private var viewModel = WorkoutHistoryViewModel()
    @State private var searchText = ""
    @State private var selectedTimeFilter: TimeFilter = .all
    @State private var showingFilterOptions = false
    @State private var selectedWorkout: WorkoutSession?

    private let timeFilters = TimeFilter.allCases

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.workouts.isEmpty && !viewModel.isLoading {
                emptyStateView
            } else {
                workoutHistoryContent
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingFilterOptions = true
                }) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel("Filter options")
            }
        }
        .searchable(text: $searchText, prompt: "Search workouts...")
        .refreshable {
            await viewModel.refreshWorkouts()
        }
        .sheet(item: $selectedWorkout) { workout in
            WorkoutDetailView(workout: workout)
        }
        .sheet(isPresented: $showingFilterOptions) {
            filterOptionsSheet
        }
        .onAppear {
            viewModel.loadWorkouts()
        }
        .onChange(of: searchText) { _ in
            viewModel.applyFilters(searchText: searchText, timeFilter: selectedTimeFilter)
        }
        .onChange(of: selectedTimeFilter) { _ in
            viewModel.applyFilters(searchText: searchText, timeFilter: selectedTimeFilter)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                Text("No Workout History")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Complete your first workout to see your progress here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
    }

    private var workoutHistoryContent: some View {
        VStack(spacing: 0) {
            if selectedTimeFilter != .all {
                filterIndicator
            }

            if viewModel.isLoading {
                ProgressView("Loading workouts...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                workoutsList
            }
        }
    }

    private var filterIndicator: some View {
        HStack {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.caption)
            Text("Filtered by: \(selectedTimeFilter.displayName)")
                .font(.caption)

            Spacer()

            Button("Clear") {
                selectedTimeFilter = .all
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    private var workoutsList: some View {
        List {
            if viewModel.filteredWorkouts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)

                    Text("No workouts found")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("Try adjusting your search or filter")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowSeparator(.hidden)
            } else {
                ForEach(groupedWorkouts, id: \.key) { group in
                    Section(header: Text(group.key)) {
                        ForEach(group.value, id: \.id) { workout in
                            WorkoutRowView(workout: workout) {
                                selectedWorkout = workout
                            }
                        }
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
    }

    private var groupedWorkouts: [(key: String, value: [WorkoutSession])] {
        let grouped = Dictionary(grouping: viewModel.filteredWorkouts) { workout in
            DateFormatter.sectionDateFormatter.string(from: workout.date)
        }

        return grouped.sorted { first, second in
            DateFormatter.sectionDateFormatter.date(from: first.key) ?? Date() >
            DateFormatter.sectionDateFormatter.date(from: second.key) ?? Date()
        }
    }

    private var filterOptionsSheet: some View {
        NavigationView {
            List {
                Section(header: Text("Time Period")) {
                    ForEach(timeFilters, id: \.self) { filter in
                        Button(action: {
                            selectedTimeFilter = filter
                            showingFilterOptions = false
                        }) {
                            HStack {
                                Text(filter.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedTimeFilter == filter {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }

                Section(header: Text("Statistics")) {
                    StatisticRow(
                        title: "Total Workouts",
                        value: "\(viewModel.statistics.totalWorkouts)"
                    )

                    StatisticRow(
                        title: "This Month",
                        value: "\(viewModel.statistics.thisMonth)"
                    )

                    StatisticRow(
                        title: "Average Duration",
                        value: viewModel.statistics.averageDurationText
                    )

                    StatisticRow(
                        title: "Total Volume",
                        value: viewModel.statistics.totalVolumeText
                    )
                }
            }
            .navigationTitle("Filter & Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingFilterOptions = false
                    }
                }
            }
        }
    }
}

// MARK: - Workout Row View

struct WorkoutRowView: View {
    let workout: WorkoutSession
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workout.name)
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text(workout.date, style: .time)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(workout.durationText)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        if let volume = workout.totalVolume {
                            Text("\(Int(volume)) lbs")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                HStack {
                    Label("\(workout.exercises.count) exercises", systemImage: "list.bullet")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if workout.isPersonalRecord {
                        Label("PR", systemImage: "trophy.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(workout.name) workout on \(workout.date, style: .date)")
        .accessibilityHint("View workout details")
    }
}

// MARK: - Statistic Row

struct StatisticRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Supporting Types

enum TimeFilter: String, CaseIterable {
    case all = "all"
    case thisWeek = "thisWeek"
    case thisMonth = "thisMonth"
    case last30Days = "last30Days"
    case last3Months = "last3Months"
    case thisYear = "thisYear"

    var displayName: String {
        switch self {
        case .all: return "All Time"
        case .thisWeek: return "This Week"
        case .thisMonth: return "This Month"
        case .last30Days: return "Last 30 Days"
        case .last3Months: return "Last 3 Months"
        case .thisYear: return "This Year"
        }
    }

    func dateRange(from referenceDate: Date = Date()) -> (start: Date, end: Date)? {
        let calendar = Calendar.current

        switch self {
        case .all:
            return nil
        case .thisWeek:
            let start = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start ?? referenceDate
            return (start, referenceDate)
        case .thisMonth:
            let start = calendar.dateInterval(of: .month, for: referenceDate)?.start ?? referenceDate
            return (start, referenceDate)
        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -30, to: referenceDate) ?? referenceDate
            return (start, referenceDate)
        case .last3Months:
            let start = calendar.date(byAdding: .month, value: -3, to: referenceDate) ?? referenceDate
            return (start, referenceDate)
        case .thisYear:
            let start = calendar.dateInterval(of: .year, for: referenceDate)?.start ?? referenceDate
            return (start, referenceDate)
        }
    }
}

struct WorkoutSession {
    let id = UUID()
    let name: String
    let date: Date
    let duration: TimeInterval
    let exercises: [ExerciseSession]
    let totalVolume: Double?
    let isPersonalRecord: Bool

    var durationText: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct ExerciseSession {
    let name: String
    let sets: [SetData]
    let personalRecords: [String] // PR types achieved
}

struct SetData {
    let weight: Double?
    let reps: Int
    let rpe: Double?
}

struct WorkoutStatistics {
    let totalWorkouts: Int
    let thisMonth: Int
    let averageDuration: TimeInterval
    let totalVolume: Double

    var averageDurationText: String {
        let minutes = Int(averageDuration) / 60
        return "\(minutes)m"
    }

    var totalVolumeText: String {
        if totalVolume >= 1000000 {
            return String(format: "%.1fM lbs", totalVolume / 1000000)
        } else if totalVolume >= 1000 {
            return String(format: "%.0fK lbs", totalVolume / 1000)
        } else {
            return "\(Int(totalVolume)) lbs"
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let sectionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

// MARK: - View Model

class WorkoutHistoryViewModel: ObservableObject {
    @Published var workouts: [WorkoutSession] = []
    @Published var filteredWorkouts: [WorkoutSession] = []
    @Published var isLoading = false
    @Published var statistics = WorkoutStatistics(totalWorkouts: 0, thisMonth: 0, averageDuration: 0, totalVolume: 0)

    func loadWorkouts() {
        isLoading = true

        // Simulate loading from Core Data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.workouts = self.sampleWorkouts
            self.filteredWorkouts = self.workouts
            self.updateStatistics()
            self.isLoading = false
        }
    }

    func refreshWorkouts() async {
        await MainActor.run {
            isLoading = true
        }

        // Simulate network refresh
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        await MainActor.run {
            self.workouts = self.sampleWorkouts
            self.filteredWorkouts = self.workouts
            self.updateStatistics()
            self.isLoading = false
        }
    }

    func applyFilters(searchText: String, timeFilter: TimeFilter) {
        var filtered = workouts

        // Apply time filter
        if let dateRange = timeFilter.dateRange() {
            filtered = filtered.filter { workout in
                workout.date >= dateRange.start && workout.date <= dateRange.end
            }
        }

        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { workout in
                workout.name.localizedCaseInsensitiveContains(searchText) ||
                workout.exercises.contains { exercise in
                    exercise.name.localizedCaseInsensitiveContains(searchText)
                }
            }
        }

        filteredWorkouts = filtered
    }

    private func updateStatistics() {
        let totalWorkouts = workouts.count
        let currentMonth = Calendar.current.dateInterval(of: .month, for: Date())
        let thisMonth = workouts.filter { workout in
            guard let currentMonth = currentMonth else { return false }
            return currentMonth.contains(workout.date)
        }.count

        let totalDuration = workouts.reduce(0) { $0 + $1.duration }
        let averageDuration = totalWorkouts > 0 ? totalDuration / Double(totalWorkouts) : 0

        let totalVolume = workouts.reduce(0.0) { total, workout in
            total + (workout.totalVolume ?? 0)
        }

        statistics = WorkoutStatistics(
            totalWorkouts: totalWorkouts,
            thisMonth: thisMonth,
            averageDuration: averageDuration,
            totalVolume: totalVolume
        )
    }

    private var sampleWorkouts: [WorkoutSession] {
        [
            WorkoutSession(
                name: "Push Day",
                date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                duration: 3600, // 1 hour
                exercises: [
                    ExerciseSession(name: "Bench Press", sets: [], personalRecords: ["1RM"]),
                    ExerciseSession(name: "Shoulder Press", sets: [], personalRecords: []),
                    ExerciseSession(name: "Tricep Dips", sets: [], personalRecords: [])
                ],
                totalVolume: 8500,
                isPersonalRecord: true
            ),
            WorkoutSession(
                name: "Pull Day",
                date: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
                duration: 3300, // 55 minutes
                exercises: [
                    ExerciseSession(name: "Pull-ups", sets: [], personalRecords: []),
                    ExerciseSession(name: "Dumbbell Row", sets: [], personalRecords: []),
                    ExerciseSession(name: "Bicep Curl", sets: [], personalRecords: [])
                ],
                totalVolume: 6200,
                isPersonalRecord: false
            ),
            WorkoutSession(
                name: "Leg Day",
                date: Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date(),
                duration: 4200, // 70 minutes
                exercises: [
                    ExerciseSession(name: "Squat", sets: [], personalRecords: ["Volume"]),
                    ExerciseSession(name: "Deadlift", sets: [], personalRecords: []),
                    ExerciseSession(name: "Calf Raises", sets: [], personalRecords: [])
                ],
                totalVolume: 12500,
                isPersonalRecord: true
            )
        ]
    }
}

// MARK: - Preview

#if DEBUG
struct WorkoutHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            WorkoutHistoryView()
        }
        .preferredColorScheme(.light)
        .previewDisplayName("Light Mode")

        NavigationView {
            WorkoutHistoryView()
        }
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")
    }
}
#endif