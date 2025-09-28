//
//  ExerciseSelectionView.swift
//  Gigi Gains
//
//  Exercise selection view for choosing exercises from the library.
//  Supports search, filtering by muscle group, and custom exercise creation.
//
//  Created: 2025-09-28
//

import SwiftUI

struct ExerciseSelectionView: View {
    let onExerciseSelected: (Exercise) -> Void

    @State private var searchText = ""
    @State private var selectedMuscleGroup: MuscleGroup = .all
    @State private var showingCustomExerciseSheet = false
    @Environment(\.dismiss) private var dismiss

    private let exercises = Exercise.sampleExercises
    private let muscleGroups = MuscleGroup.allCases

    private var filteredExercises: [Exercise] {
        let filtered = exercises.filter { exercise in
            let matchesSearch = searchText.isEmpty ||
                exercise.name.localizedCaseInsensitiveContains(searchText) ||
                exercise.muscleGroups.contains { $0.rawValue.localizedCaseInsensitiveContains(searchText) }

            let matchesMuscleGroup = selectedMuscleGroup == .all ||
                exercise.muscleGroups.contains(selectedMuscleGroup)

            return matchesSearch && matchesMuscleGroup
        }

        return filtered.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchAndFilterSection
                exerciseListSection
            }
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Custom") {
                        showingCustomExerciseSheet = true
                    }
                    .accessibilityLabel("Create custom exercise")
                    .accessibilityHint("Create a new exercise not in the library")
                }
            }
            .sheet(isPresented: $showingCustomExerciseSheet) {
                CustomExerciseCreationView { exercise in
                    onExerciseSelected(exercise)
                    dismiss()
                }
            }
        }
    }

    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search exercises...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .accessibilityLabel("Search exercises")

                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)

            // Muscle Group Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(muscleGroups, id: \.self) { muscleGroup in
                        Button(action: {
                            selectedMuscleGroup = muscleGroup
                        }) {
                            Text(muscleGroup.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    selectedMuscleGroup == muscleGroup
                                        ? Color.blue
                                        : Color(.systemGray5)
                                )
                                .foregroundColor(
                                    selectedMuscleGroup == muscleGroup
                                        ? .white
                                        : .primary
                                )
                                .cornerRadius(20)
                        }
                        .accessibilityLabel("Filter by \(muscleGroup.displayName)")
                        .accessibilityAddTraits(selectedMuscleGroup == muscleGroup ? .isSelected : [])
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }

    private var exerciseListSection: some View {
        List {
            if filteredExercises.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)

                    Text("No exercises found")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("Try adjusting your search or muscle group filter")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowSeparator(.hidden)
            } else {
                ForEach(filteredExercises, id: \.id) { exercise in
                    ExerciseRowView(exercise: exercise) {
                        onExerciseSelected(exercise)
                        dismiss()
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
    }
}

// MARK: - Exercise Row View

private struct ExerciseRowView: View {
    let exercise: Exercise
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)

                    Text(exercise.muscleGroupsText)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let equipment = exercise.equipment {
                        HStack(spacing: 4) {
                            Image(systemName: "wrench.and.screwdriver")
                                .font(.caption2)
                            Text(equipment.displayName)
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if exercise.isCompound {
                        Text("Compound")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(6)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(exercise.name), \(exercise.muscleGroupsText)")
        .accessibilityHint("Select this exercise for your workout")
    }
}

// MARK: - Custom Exercise Creation View

struct CustomExerciseCreationView: View {
    let onExerciseCreated: (Exercise) -> Void

    @State private var exerciseName = ""
    @State private var selectedMuscleGroups: Set<MuscleGroup> = []
    @State private var selectedEquipment: Equipment?
    @State private var isCompound = false
    @State private var instructions = ""

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Exercise Details")) {
                    TextField("Exercise Name", text: $exerciseName)
                        .accessibilityLabel("Exercise name")

                    Toggle("Compound Exercise", isOn: $isCompound)
                        .accessibilityLabel("Mark as compound exercise")
                }

                Section(header: Text("Muscle Groups")) {
                    ForEach(MuscleGroup.allCases.filter { $0 != .all }, id: \.self) { muscleGroup in
                        Button(action: {
                            if selectedMuscleGroups.contains(muscleGroup) {
                                selectedMuscleGroups.remove(muscleGroup)
                            } else {
                                selectedMuscleGroups.insert(muscleGroup)
                            }
                        }) {
                            HStack {
                                Text(muscleGroup.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedMuscleGroups.contains(muscleGroup) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .accessibilityLabel("Toggle \(muscleGroup.displayName)")
                        .accessibilityAddTraits(selectedMuscleGroups.contains(muscleGroup) ? .isSelected : [])
                    }
                }

                Section(header: Text("Equipment (Optional)")) {
                    Picker("Equipment", selection: $selectedEquipment) {
                        Text("None").tag(Equipment?.none)
                        ForEach(Equipment.allCases, id: \.self) { equipment in
                            Text(equipment.displayName).tag(Equipment?.some(equipment))
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                Section(header: Text("Instructions (Optional)")) {
                    TextField("Exercise instructions...", text: $instructions, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityLabel("Exercise instructions")
                }
            }
            .navigationTitle("Create Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createExercise()
                    }
                    .disabled(exerciseName.isEmpty || selectedMuscleGroups.isEmpty)
                }
            }
        }
    }

    private func createExercise() {
        let exercise = Exercise(
            id: UUID(),
            name: exerciseName.trimmingCharacters(in: .whitespacesAndNewlines),
            muscleGroups: Array(selectedMuscleGroups),
            equipment: selectedEquipment,
            isCompound: isCompound,
            instructions: instructions.isEmpty ? nil : instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        onExerciseCreated(exercise)
    }
}

// MARK: - Supporting Types

enum MuscleGroup: String, CaseIterable {
    case all = "all"
    case chest = "chest"
    case back = "back"
    case shoulders = "shoulders"
    case arms = "arms"
    case legs = "legs"
    case glutes = "glutes"
    case core = "core"
    case fullBody = "fullBody"

    var displayName: String {
        switch self {
        case .all: return "All"
        case .chest: return "Chest"
        case .back: return "Back"
        case .shoulders: return "Shoulders"
        case .arms: return "Arms"
        case .legs: return "Legs"
        case .glutes: return "Glutes"
        case .core: return "Core"
        case .fullBody: return "Full Body"
        }
    }
}

enum Equipment: String, CaseIterable {
    case barbell = "barbell"
    case dumbbell = "dumbbell"
    case machine = "machine"
    case cable = "cable"
    case bodyweight = "bodyweight"
    case kettlebell = "kettlebell"
    case resistance = "resistance"

    var displayName: String {
        switch self {
        case .barbell: return "Barbell"
        case .dumbbell: return "Dumbbell"
        case .machine: return "Machine"
        case .cable: return "Cable"
        case .bodyweight: return "Bodyweight"
        case .kettlebell: return "Kettlebell"
        case .resistance: return "Resistance Band"
        }
    }
}

struct Exercise {
    let id: UUID
    let name: String
    let muscleGroups: [MuscleGroup]
    let equipment: Equipment?
    let isCompound: Bool
    let instructions: String?

    var muscleGroupsText: String {
        muscleGroups.map { $0.displayName }.joined(separator: ", ")
    }

    static let sampleExercises: [Exercise] = [
        Exercise(id: UUID(), name: "Bench Press", muscleGroups: [.chest, .shoulders, .arms], equipment: .barbell, isCompound: true, instructions: nil),
        Exercise(id: UUID(), name: "Squat", muscleGroups: [.legs, .glutes], equipment: .barbell, isCompound: true, instructions: nil),
        Exercise(id: UUID(), name: "Deadlift", muscleGroups: [.back, .legs, .glutes], equipment: .barbell, isCompound: true, instructions: nil),
        Exercise(id: UUID(), name: "Pull-ups", muscleGroups: [.back, .arms], equipment: .bodyweight, isCompound: true, instructions: nil),
        Exercise(id: UUID(), name: "Push-ups", muscleGroups: [.chest, .shoulders, .arms], equipment: .bodyweight, isCompound: true, instructions: nil),
        Exercise(id: UUID(), name: "Dumbbell Row", muscleGroups: [.back, .arms], equipment: .dumbbell, isCompound: false, instructions: nil),
        Exercise(id: UUID(), name: "Shoulder Press", muscleGroups: [.shoulders, .arms], equipment: .dumbbell, isCompound: false, instructions: nil),
        Exercise(id: UUID(), name: "Bicep Curl", muscleGroups: [.arms], equipment: .dumbbell, isCompound: false, instructions: nil),
        Exercise(id: UUID(), name: "Tricep Dips", muscleGroups: [.arms], equipment: .bodyweight, isCompound: false, instructions: nil),
        Exercise(id: UUID(), name: "Plank", muscleGroups: [.core], equipment: .bodyweight, isCompound: false, instructions: nil)
    ]
}

// MARK: - Preview

#if DEBUG
struct ExerciseSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        ExerciseSelectionView { exercise in
            print("Selected: \(exercise.name)")
        }
        .preferredColorScheme(.light)
        .previewDisplayName("Light Mode")

        ExerciseSelectionView { exercise in
            print("Selected: \(exercise.name)")
        }
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")
    }
}
#endif