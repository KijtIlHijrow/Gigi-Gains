//
//  WorkoutDetailView.swift
//  Gigi Gains
//
//  Detailed view of a completed workout session.
//  Shows comprehensive workout information and exercise breakdown.
//
//  Created: 2025-09-28
//

import SwiftUI

struct WorkoutDetailView: View {
    let workout: WorkoutSession

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    workoutHeader
                    exerciseBreakdown
                    workoutStats
                }
                .padding()
            }
            .navigationTitle(workout.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Share Workout") {
                            // Share workout details
                        }

                        Button("Repeat Workout") {
                            // Start new workout based on this one
                        }

                        Button("Export Data") {
                            // Export this workout
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    private var workoutHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.date, style: .date)
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text(workout.date, style: .time)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(workout.durationText)
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let volume = workout.totalVolume {
                HStack {
                    Label("Total Volume", systemImage: "scalemass")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(Int(volume)) lbs")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }

            if workout.isPersonalRecord {
                Label("Personal Records Achieved", systemImage: "trophy.fill")
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private var exerciseBreakdown: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Exercises (\(workout.exercises.count))")
                .font(.title2)
                .fontWeight(.semibold)

            ForEach(workout.exercises.indices, id: \.self) { index in
                ExerciseDetailRow(exercise: workout.exercises[index])
            }
        }
    }

    private var workoutStats: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Workout Statistics")
                .font(.title2)
                .fontWeight(.semibold)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(title: "Exercises", value: "\(workout.exercises.count)")
                StatCard(title: "Total Sets", value: "\(workout.exercises.reduce(0) { $0 + $1.sets.count })")
                StatCard(title: "Average Rest", value: "2:15")
                StatCard(title: "Max Weight", value: "225 lbs")
            }
        }
    }
}

// MARK: - Exercise Detail Row

struct ExerciseDetailRow: View {
    let exercise: ExerciseSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(exercise.name)
                    .font(.headline)
                    .fontWeight(.medium)

                Spacer()

                if !exercise.personalRecords.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.orange)
                        Text("PR")
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                    .font(.caption)
                }
            }

            if !exercise.sets.isEmpty {
                VStack(spacing: 6) {
                    ForEach(exercise.sets.indices, id: \.self) { index in
                        HStack {
                            Text("\(index + 1)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(width: 25, alignment: .leading)

                            if let weight = exercise.sets[index].weight {
                                Text("\(Int(weight)) lbs")
                                    .font(.subheadline)
                                    .frame(width: 60, alignment: .leading)
                            } else {
                                Text("--")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(width: 60, alignment: .leading)
                            }

                            Text("× \(exercise.sets[index].reps)")
                                .font(.subheadline)
                                .frame(width: 40, alignment: .leading)

                            if let rpe = exercise.sets[index].rpe {
                                Text("@ \(Int(rpe))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.blue)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#if DEBUG
struct WorkoutDetailView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutDetailView(
            workout: WorkoutSession(
                name: "Push Day",
                date: Date(),
                duration: 3600,
                exercises: [
                    ExerciseSession(
                        name: "Bench Press",
                        sets: [
                            SetData(weight: 185, reps: 8, rpe: 8),
                            SetData(weight: 185, reps: 8, rpe: 8),
                            SetData(weight: 185, reps: 6, rpe: 9)
                        ],
                        personalRecords: ["1RM"]
                    )
                ],
                totalVolume: 8500,
                isPersonalRecord: true
            )
        )
    }
}
#endif