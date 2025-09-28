//
//  RoutineCreationView.swift
//  Gigi Gains
//
//  Routine creation view for building and editing workout routines.
//  Allows users to create custom routines with exercises, sets, and rest times.
//
//  Created: 2025-09-28
//

import SwiftUI

struct RoutineCreationView: View {
    let onRoutineCreated: (WorkoutRoutine) -> Void

    @State private var routineName = ""
    @State private var routineDescription = ""
    @State private var exercises: [RoutineExercise] = []
    @State private var showingExerciseSelection = false
    @State private var editingExerciseIndex: Int?

    @Environment(\.dismiss) private var dismiss

    private var isValidRoutine: Bool {
        !routineName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !exercises.isEmpty
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Form {
                    routineDetailsSection
                    exercisesSection
                }

                if !exercises.isEmpty {
                    createRoutineButton
                }
            }
            .navigationTitle("Create Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        createRoutine()
                    }
                    .disabled(!isValidRoutine)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingExerciseSelection) {
                ExerciseSelectionView { exercise in
                    addExercise(exercise)
                    showingExerciseSelection = false
                }
            }
            .sheet(item: $editingExerciseIndex) { index in
                ExerciseConfigurationView(
                    exercise: exercises[index.value],
                    onSave: { updatedExercise in
                        exercises[index.value] = updatedExercise
                        editingExerciseIndex = nil
                    },
                    onCancel: {
                        editingExerciseIndex = nil
                    }
                )
            }
        }
    }

    private var routineDetailsSection: some View {
        Section(header: Text("Routine Details")) {
            TextField("Routine Name", text: $routineName)
                .accessibilityLabel("Routine name")

            TextField("Description (optional)", text: $routineDescription, axis: .vertical)
                .lineLimit(2...4)
                .accessibilityLabel("Routine description")
        }
    }

    private var exercisesSection: some View {
        Section(header: HStack {
            Text("Exercises (\(exercises.count))")
            Spacer()
            Button("Add Exercise") {
                showingExerciseSelection = true
            }
            .font(.subheadline)
            .foregroundColor(.blue)
        }) {
            if exercises.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "plus.circle.dashed")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)

                    Text("No exercises added yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button("Add First Exercise") {
                        showingExerciseSelection = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .accessibilityLabel("Add first exercise to routine")
            } else {
                ForEach(exercises.indices, id: \.self) { index in
                    ExerciseRowView(
                        exercise: exercises[index],
                        index: index,
                        onEdit: {
                            editingExerciseIndex = EditingIndex(value: index)
                        },
                        onDelete: {
                            exercises.remove(at: index)
                        },
                        onMoveUp: index > 0 ? {
                            moveExercise(from: index, to: index - 1)
                        } : nil,
                        onMoveDown: index < exercises.count - 1 ? {
                            moveExercise(from: index, to: index + 1)
                        } : nil
                    )
                }
                .onMove(perform: moveExercises)
            }
        }
    }

    private var createRoutineButton: some View {
        VStack {
            Divider()

            Button(action: createRoutine) {
                Text("Create Routine")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValidRoutine ? Color.blue : Color.gray)
                    .cornerRadius(12)
            }
            .disabled(!isValidRoutine)
            .padding()
            .accessibilityLabel("Create routine with \(exercises.count) exercises")
        }
        .background(Color(.systemGroupedBackground))
    }

    private func addExercise(_ exercise: Exercise) {
        let routineExercise = RoutineExercise(
            name: exercise.name,
            plannedSets: 3, // Default
            restTime: 120,  // Default 2 minutes
            notes: nil
        )
        exercises.append(routineExercise)
    }

    private func moveExercise(from source: Int, to destination: Int) {
        exercises.swapAt(source, destination)
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        exercises.move(fromOffsets: source, toOffset: destination)
    }

    private func createRoutine() {
        let routine = WorkoutRoutine(
            name: routineName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: routineDescription.isEmpty ? nil : routineDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            exercises: exercises
        )

        onRoutineCreated(routine)
    }
}

// MARK: - Exercise Row View

private struct ExerciseRowView: View {
    let exercise: RoutineExercise
    let index: Int
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onMoveUp: (() -> Void)?
    let onMoveDown: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(index + 1). \(exercise.name)")
                        .font(.headline)
                        .fontWeight(.medium)

                    HStack {
                        if let sets = exercise.plannedSets {
                            Text("\(sets) sets")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if let restTime = exercise.restTime {
                            Text("• \(Int(restTime))s rest")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                Menu {
                    Button("Edit") {
                        onEdit()
                    }

                    if let onMoveUp = onMoveUp {
                        Button("Move Up") {
                            onMoveUp()
                        }
                    }

                    if let onMoveDown = onMoveDown {
                        Button("Move Down") {
                            onMoveDown()
                        }
                    }

                    Divider()

                    Button("Remove", role: .destructive) {
                        onDelete()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.blue)
                }
                .accessibilityLabel("Exercise options")
            }

            if let notes = exercise.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Exercise Configuration View

struct ExerciseConfigurationView: View {
    let exercise: RoutineExercise
    let onSave: (RoutineExercise) -> Void
    let onCancel: () -> Void

    @State private var plannedSets: String
    @State private var restTime: String
    @State private var notes: String

    init(exercise: RoutineExercise, onSave: @escaping (RoutineExercise) -> Void, onCancel: @escaping () -> Void) {
        self.exercise = exercise
        self.onSave = onSave
        self.onCancel = onCancel

        _plannedSets = State(initialValue: exercise.plannedSets?.description ?? "3")
        _restTime = State(initialValue: exercise.restTime != nil ? String(Int(exercise.restTime!)) : "120")
        _notes = State(initialValue: exercise.notes ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Exercise Details")) {
                    HStack {
                        Text("Exercise")
                        Spacer()
                        Text(exercise.name)
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Configuration")) {
                    HStack {
                        Text("Planned Sets")
                        Spacer()
                        TextField("Sets", text: $plannedSets)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .accessibilityLabel("Number of planned sets")
                    }

                    HStack {
                        Text("Rest Time")
                        Spacer()
                        TextField("Seconds", text: $restTime)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("sec")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("Rest time between sets in seconds")
                }

                Section(header: Text("Notes (Optional)")) {
                    TextField("Exercise notes...", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                        .accessibilityLabel("Exercise notes")
                }
            }
            .navigationTitle("Configure Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveExercise()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveExercise() {
        let updatedExercise = RoutineExercise(
            name: exercise.name,
            plannedSets: Int(plannedSets),
            restTime: TimeInterval(Int(restTime) ?? 120),
            notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        onSave(updatedExercise)
    }
}

// MARK: - Supporting Types

private struct EditingIndex: Identifiable {
    let id = UUID()
    let value: Int
}

// MARK: - Preview

#if DEBUG
struct RoutineCreationView_Previews: PreviewProvider {
    static var previews: some View {
        RoutineCreationView { routine in
            print("Created routine: \(routine.name)")
        }
        .preferredColorScheme(.light)
        .previewDisplayName("Light Mode")

        RoutineCreationView { routine in
            print("Created routine: \(routine.name)")
        }
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")
    }
}

struct ExerciseConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        ExerciseConfigurationView(
            exercise: RoutineExercise(name: "Bench Press", plannedSets: 4, restTime: 180),
            onSave: { _ in },
            onCancel: { }
        )
    }
}
#endif