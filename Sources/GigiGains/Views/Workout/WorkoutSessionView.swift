//
//  WorkoutSessionView.swift
//  Gigi Gains
//
//  Active workout logging view for tracking exercises, sets, and progress.
//  Central view for recording workout sessions with real-time timer.
//
//  Created: 2025-09-28
//

import SwiftUI
import Combine

struct WorkoutSessionView: View {
    @StateObject private var viewModel = WorkoutSessionViewModel()
    @State private var showingExerciseSelection = false
    @State private var showingRestTimer = false
    @State private var showingRoutineSelection = false
    @State private var showingEndWorkoutAlert = false

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isWorkoutActive {
                activeWorkoutContent
            } else {
                startWorkoutContent
            }
        }
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if viewModel.isWorkoutActive {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("End") {
                        showingEndWorkoutAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .sheet(isPresented: $showingExerciseSelection) {
            ExerciseSelectionView { exercise in
                viewModel.addExercise(exercise)
                showingExerciseSelection = false
            }
        }
        .sheet(isPresented: $showingRestTimer) {
            RestTimerView(duration: viewModel.restDuration) {
                showingRestTimer = false
            }
        }
        .sheet(isPresented: $showingRoutineSelection) {
            RoutineSelectionView { routine in
                viewModel.startWorkoutFromRoutine(routine)
                showingRoutineSelection = false
            }
        }
        .alert("End Workout", isPresented: $showingEndWorkoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("End Workout", role: .destructive) {
                viewModel.endWorkout()
            }
        } message: {
            Text("Are you sure you want to end this workout? Your progress will be saved.")
        }
    }

    private var startWorkoutContent: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                Text("Ready to Train?")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Start a new workout or choose a routine")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Ready to train? Start a new workout or choose a routine")

            VStack(spacing: 16) {
                Button(action: {
                    viewModel.startQuickWorkout()
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Quick Workout")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .accessibilityLabel("Start quick workout")
                .accessibilityHint("Begin a new workout session")

                Button(action: {
                    showingRoutineSelection = true
                }) {
                    HStack {
                        Image(systemName: "list.bullet.clipboard")
                        Text("Choose Routine")
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                .accessibilityLabel("Choose routine")
                .accessibilityHint("Select from saved workout routines")
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private var activeWorkoutContent: some View {
        VStack(spacing: 0) {
            workoutHeader

            if viewModel.exercises.isEmpty {
                emptyWorkoutState
            } else {
                exerciseList
            }
        }
    }

    private var workoutHeader: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Workout Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(viewModel.workoutDurationText)
                        .font(.title2)
                        .fontWeight(.medium)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Exercises")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(viewModel.exercises.count)")
                        .font(.title2)
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal)

            Divider()
        }
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }

    private var emptyWorkoutState: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("Add Your First Exercise")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Tap the button below to select an exercise and start logging sets")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button(action: {
                showingExerciseSelection = true
            }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Exercise")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .accessibilityLabel("Add exercise")
            .accessibilityHint("Select an exercise to add to your workout")

            Spacer()
        }
    }

    private var exerciseList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.exercises.indices, id: \.self) { index in
                    ExerciseRowView(
                        exercise: viewModel.exercises[index],
                        onAddSet: {
                            viewModel.addSet(to: index)
                        },
                        onStartRest: { duration in
                            viewModel.restDuration = duration
                            showingRestTimer = true
                        }
                    )
                }

                Button(action: {
                    showingExerciseSelection = true
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add Exercise")
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .accessibilityLabel("Add another exercise")
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Exercise Row View

struct ExerciseRowView: View {
    let exercise: WorkoutExercise
    let onAddSet: () -> Void
    let onStartRest: (TimeInterval) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(exercise.name)
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Menu {
                    Button("Exercise Info") {
                        // Show exercise information
                    }
                    Button("Replace Exercise") {
                        // Replace with different exercise
                    }
                    Button("Remove", role: .destructive) {
                        // Remove exercise
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.blue)
                }
                .accessibilityLabel("Exercise options")
            }

            if exercise.sets.isEmpty {
                Button(action: onAddSet) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add First Set")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.vertical, 8)
                }
                .accessibilityLabel("Add first set for \(exercise.name)")
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(exercise.sets.indices, id: \.self) { setIndex in
                        SetRowView(
                            setNumber: setIndex + 1,
                            set: exercise.sets[setIndex],
                            onStartRest: onStartRest
                        )
                    }
                }

                Button(action: onAddSet) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add Set")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.vertical, 8)
                }
                .accessibilityLabel("Add another set for \(exercise.name)")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
}

// MARK: - Set Row View

struct SetRowView: View {
    let setNumber: Int
    let set: WorkoutSet
    let onStartRest: (TimeInterval) -> Void

    @State private var weight = ""
    @State private var reps = ""
    @State private var rpe = ""
    @State private var isCompleted = false

    var body: some View {
        HStack(spacing: 12) {
            Text("\(setNumber)")
                .font(.headline)
                .fontWeight(.medium)
                .frame(width: 30)
                .foregroundColor(.secondary)

            Group {
                TextField("Weight", text: $weight)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .accessibilityLabel("Weight for set \(setNumber)")

                TextField("Reps", text: $reps)
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .accessibilityLabel("Reps for set \(setNumber)")

                TextField("RPE", text: $rpe)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .accessibilityLabel("RPE for set \(setNumber)")
            }

            Button(action: {
                isCompleted.toggle()
                if isCompleted {
                    // Start rest timer after completing set
                    onStartRest(120) // Default 2 minute rest
                }
            }) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isCompleted ? .green : .gray)
                    .font(.title2)
            }
            .accessibilityLabel(isCompleted ? "Set completed" : "Mark set complete")
        }
    }
}

// MARK: - Routine Selection View

struct RoutineSelectionView: View {
    let onRoutineSelected: (WorkoutRoutine) -> Void

    var body: some View {
        NavigationView {
            VStack {
                Text("Select a routine to start your workout")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()

                // Placeholder for routine list
                List {
                    Text("Push Day")
                    Text("Pull Day")
                    Text("Leg Day")
                }

                Spacer()
            }
            .navigationTitle("Choose Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        // Close sheet
                    }
                }
            }
        }
    }
}

// MARK: - Placeholder Types

struct WorkoutExercise {
    let name: String
    var sets: [WorkoutSet]
}

struct WorkoutSet {
    var weight: Double?
    var reps: Int?
    var rpe: Double?
    var isCompleted: Bool
}

struct WorkoutRoutine {
    let name: String
    let exercises: [String]
}

// MARK: - Preview

#if DEBUG
struct WorkoutSessionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            WorkoutSessionView()
        }
        .preferredColorScheme(.light)
        .previewDisplayName("Light Mode")

        NavigationView {
            WorkoutSessionView()
        }
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")
    }
}
#endif