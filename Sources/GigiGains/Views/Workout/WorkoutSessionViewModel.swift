//
//  WorkoutSessionViewModel.swift
//  Gigi Gains
//
//  View model for WorkoutSessionView managing workout state and logic.
//  Handles workout lifecycle, exercise management, and timer coordination.
//
//  Created: 2025-09-28
//

import Foundation
import Combine

@MainActor
class WorkoutSessionViewModel: ObservableObject {
    @Published var isWorkoutActive = false
    @Published var exercises: [WorkoutExercise] = []
    @Published var workoutStartTime: Date?
    @Published var workoutDuration: TimeInterval = 0
    @Published var restDuration: TimeInterval = 120

    private var workoutTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    var workoutDurationText: String {
        let hours = Int(workoutDuration) / 3600
        let minutes = Int(workoutDuration) % 3600 / 60
        let seconds = Int(workoutDuration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    func startQuickWorkout() {
        isWorkoutActive = true
        workoutStartTime = Date()
        exercises = []
        startWorkoutTimer()
    }

    func startWorkoutFromRoutine(_ routine: WorkoutRoutine) {
        isWorkoutActive = true
        workoutStartTime = Date()
        exercises = routine.exercises.map { routineExercise in
            WorkoutExercise(name: routineExercise.name, sets: [])
        }
        startWorkoutTimer()
    }

    func addExercise(_ exercise: Exercise) {
        let workoutExercise = WorkoutExercise(name: exercise.name, sets: [])
        exercises.append(workoutExercise)
    }

    func addSet(to exerciseIndex: Int) {
        guard exerciseIndex < exercises.count else { return }
        let newSet = WorkoutSet(weight: nil, reps: nil, rpe: nil, isCompleted: false)
        exercises[exerciseIndex].sets.append(newSet)
    }

    func endWorkout() {
        isWorkoutActive = false
        workoutTimer?.invalidate()
        workoutTimer = nil

        // Save workout to Core Data
        saveWorkout()

        // Reset state
        workoutStartTime = nil
        workoutDuration = 0
        exercises = []
    }

    private func startWorkoutTimer() {
        workoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.workoutStartTime else { return }
            self.workoutDuration = Date().timeIntervalSince(startTime)
        }
    }

    private func saveWorkout() {
        // Implementation would save to Core Data via repository
        print("Saving workout with \(exercises.count) exercises")
    }

    deinit {
        workoutTimer?.invalidate()
    }
}