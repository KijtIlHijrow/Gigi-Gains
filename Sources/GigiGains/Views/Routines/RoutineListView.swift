//
//  RoutineListView.swift
//  Gigi Gains
//
//  Routine list view for displaying and managing saved workout routines.
//  Allows users to view, edit, delete, and start workouts from routines.
//
//  Created: 2025-09-28
//

import SwiftUI

struct RoutineListView: View {
    @StateObject private var viewModel = RoutineListViewModel()
    @State private var showingCreateRoutine = false
    @State private var selectedRoutine: WorkoutRoutine?
    @State private var showingEditRoutine = false

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.routines.isEmpty {
                emptyStateView
            } else {
                routineListContent
            }
        }
        .navigationTitle("Routines")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingCreateRoutine = true
                }) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Create new routine")
            }
        }
        .sheet(isPresented: $showingCreateRoutine) {
            RoutineCreationView { routine in
                viewModel.addRoutine(routine)
                showingCreateRoutine = false
            }
        }
        .sheet(item: $selectedRoutine) { routine in
            RoutineDetailView(routine: routine) { action in
                handleRoutineAction(action, for: routine)
            }
        }
        .onAppear {
            viewModel.loadRoutines()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                Text("No Routines Yet")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Create your first routine to save time planning workouts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button(action: {
                showingCreateRoutine = true
            }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Create Routine")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .accessibilityLabel("Create your first routine")

            Spacer()
        }
    }

    private var routineListContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.routines, id: \.id) { routine in
                    RoutineRowView(routine: routine) { action in
                        handleRoutineAction(action, for: routine)
                    }
                }
            }
            .padding()
        }
    }

    private func handleRoutineAction(_ action: RoutineAction, for routine: WorkoutRoutine) {
        switch action {
        case .start:
            // Start workout from routine
            viewModel.startWorkout(from: routine)
        case .view:
            selectedRoutine = routine
        case .edit:
            selectedRoutine = routine
            showingEditRoutine = true
        case .duplicate:
            viewModel.duplicateRoutine(routine)
        case .delete:
            viewModel.deleteRoutine(routine)
        }
    }
}

// MARK: - Routine Row View

struct RoutineRowView: View {
    let routine: WorkoutRoutine
    let onAction: (RoutineAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(routine.name)
                        .font(.headline)
                        .fontWeight(.semibold)

                    if let description = routine.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Menu {
                    Button("View Details") {
                        onAction(.view)
                    }

                    Button("Edit") {
                        onAction(.edit)
                    }

                    Button("Duplicate") {
                        onAction(.duplicate)
                    }

                    Divider()

                    Button("Delete", role: .destructive) {
                        onAction(.delete)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
                .accessibilityLabel("Routine options")
            }

            HStack {
                Label("\(routine.exercises.count) exercises", systemImage: "list.bullet")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if let lastUsed = routine.lastUsed {
                    Text("Last used \(lastUsed, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Button(action: {
                onAction(.start)
            }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Workout")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.blue)
                .cornerRadius(8)
            }
            .accessibilityLabel("Start workout from \(routine.name)")
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Routine Detail View

struct RoutineDetailView: View {
    let routine: WorkoutRoutine
    let onAction: (RoutineAction) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    routineHeader
                    exercisesList
                    actionButtons
                }
                .padding()
            }
            .navigationTitle(routine.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Edit") {
                            onAction(.edit)
                            dismiss()
                        }

                        Button("Duplicate") {
                            onAction(.duplicate)
                            dismiss()
                        }

                        Divider()

                        Button("Delete", role: .destructive) {
                            onAction(.delete)
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    private var routineHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let description = routine.description {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            HStack {
                Label("\(routine.exercises.count) exercises", systemImage: "list.bullet")

                Spacer()

                if let lastUsed = routine.lastUsed {
                    Text("Last used \(lastUsed, style: .relative)")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }

    private var exercisesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercises")
                .font(.headline)
                .fontWeight(.semibold)

            ForEach(routine.exercises.indices, id: \.self) { index in
                HStack {
                    Text("\(index + 1).")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 25, alignment: .leading)

                    Text(routine.exercises[index].name)
                        .font(.subheadline)

                    Spacer()

                    if let sets = routine.exercises[index].plannedSets {
                        Text("\(sets) sets")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                onAction(.start)
                dismiss()
            }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Workout")
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .accessibilityLabel("Start workout from this routine")

            Button(action: {
                onAction(.edit)
                dismiss()
            }) {
                HStack {
                    Image(systemName: "pencil")
                    Text("Edit Routine")
                }
                .font(.subheadline)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
            .accessibilityLabel("Edit this routine")
        }
    }
}

// MARK: - Supporting Types

enum RoutineAction {
    case start
    case view
    case edit
    case duplicate
    case delete
}

struct WorkoutRoutine {
    let id = UUID()
    let name: String
    let description: String?
    let exercises: [RoutineExercise]
    let lastUsed: Date?
    let createdDate: Date

    init(name: String, description: String? = nil, exercises: [RoutineExercise], lastUsed: Date? = nil, createdDate: Date = Date()) {
        self.name = name
        self.description = description
        self.exercises = exercises
        self.lastUsed = lastUsed
        self.createdDate = createdDate
    }
}

struct RoutineExercise {
    let name: String
    let plannedSets: Int?
    let restTime: TimeInterval?
    let notes: String?

    init(name: String, plannedSets: Int? = nil, restTime: TimeInterval? = nil, notes: String? = nil) {
        self.name = name
        self.plannedSets = plannedSets
        self.restTime = restTime
        self.notes = notes
    }
}

// MARK: - View Model

class RoutineListViewModel: ObservableObject {
    @Published var routines: [WorkoutRoutine] = []

    func loadRoutines() {
        // Load from Core Data or other persistence
        routines = sampleRoutines
    }

    func addRoutine(_ routine: WorkoutRoutine) {
        routines.append(routine)
        // Save to Core Data
    }

    func deleteRoutine(_ routine: WorkoutRoutine) {
        routines.removeAll { $0.id == routine.id }
        // Delete from Core Data
    }

    func duplicateRoutine(_ routine: WorkoutRoutine) {
        let duplicated = WorkoutRoutine(
            name: "\(routine.name) Copy",
            description: routine.description,
            exercises: routine.exercises
        )
        routines.append(duplicated)
        // Save to Core Data
    }

    func startWorkout(from routine: WorkoutRoutine) {
        // Navigate to workout session with routine
        print("Starting workout from routine: \(routine.name)")
    }

    private var sampleRoutines: [WorkoutRoutine] {
        [
            WorkoutRoutine(
                name: "Push Day",
                description: "Chest, shoulders, and triceps workout",
                exercises: [
                    RoutineExercise(name: "Bench Press", plannedSets: 4, restTime: 180),
                    RoutineExercise(name: "Shoulder Press", plannedSets: 3, restTime: 120),
                    RoutineExercise(name: "Tricep Dips", plannedSets: 3, restTime: 90)
                ],
                lastUsed: Calendar.current.date(byAdding: .day, value: -2, to: Date())
            ),
            WorkoutRoutine(
                name: "Pull Day",
                description: "Back and biceps focused session",
                exercises: [
                    RoutineExercise(name: "Pull-ups", plannedSets: 4, restTime: 120),
                    RoutineExercise(name: "Dumbbell Row", plannedSets: 4, restTime: 90),
                    RoutineExercise(name: "Bicep Curl", plannedSets: 3, restTime: 60)
                ],
                lastUsed: Calendar.current.date(byAdding: .day, value: -5, to: Date())
            ),
            WorkoutRoutine(
                name: "Leg Day",
                description: "Complete lower body workout",
                exercises: [
                    RoutineExercise(name: "Squat", plannedSets: 4, restTime: 180),
                    RoutineExercise(name: "Deadlift", plannedSets: 3, restTime: 240),
                    RoutineExercise(name: "Calf Raises", plannedSets: 4, restTime: 60)
                ],
                lastUsed: Calendar.current.date(byAdding: .day, value: -7, to: Date())
            )
        ]
    }
}

// MARK: - Preview

#if DEBUG
struct RoutineListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            RoutineListView()
        }
        .preferredColorScheme(.light)
        .previewDisplayName("Light Mode")

        NavigationView {
            RoutineListView()
        }
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")
    }
}
#endif