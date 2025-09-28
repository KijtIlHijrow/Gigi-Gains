//
//  SetLoggingView.swift
//  Gigi Gains
//
//  Set logging view for entering reps, weight, and RPE.
//  Provides focused input interface for workout data entry.
//
//  Created: 2025-09-28
//

import SwiftUI

struct SetLoggingView: View {
    @Binding var weight: String
    @Binding var reps: String
    @Binding var rpe: String

    let exerciseName: String
    let setNumber: Int
    let onComplete: () -> Void
    let onCancel: () -> Void

    @FocusState private var focusedField: Field?
    @State private var showingRPEInfo = false

    enum Field: Hashable {
        case weight, reps, rpe
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                headerSection
                inputSection
                previousSetsSection
                actionButtons
                Spacer()
            }
            .padding()
            .navigationTitle("Log Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onComplete()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValidInput)
                }
            }
        }
        .onAppear {
            focusedField = .weight
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(exerciseName)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Text("Set \(setNumber)")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(exerciseName), set \(setNumber)")
    }

    private var inputSection: some View {
        VStack(spacing: 20) {
            // Weight Input
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Weight")
                        .font(.headline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("lbs")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                TextField("0", text: $weight)
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .weight)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .accessibilityLabel("Weight in pounds")
            }

            // Reps Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Reps")
                    .font(.headline)
                    .fontWeight(.medium)

                TextField("0", text: $reps)
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .reps)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .accessibilityLabel("Number of repetitions")
            }

            // RPE Input
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("RPE")
                        .font(.headline)
                        .fontWeight(.medium)

                    Button(action: {
                        showingRPEInfo = true
                    }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                    }
                    .accessibilityLabel("RPE information")

                    Spacer()

                    Text("1-10")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                TextField("0", text: $rpe)
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .rpe)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .accessibilityLabel("Rate of Perceived Exertion from 1 to 10")
            }
        }
    }

    private var previousSetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Previous Sets")
                .font(.headline)
                .fontWeight(.medium)

            // Placeholder for previous sets
            HStack {
                Text("Set 1:")
                    .foregroundColor(.secondary)
                Spacer()
                Text("135 lbs × 8 @ RPE 7")
                    .fontWeight(.medium)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)

            if setNumber > 2 {
                HStack {
                    Text("Set \(setNumber - 1):")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("135 lbs × 6 @ RPE 8")
                        .fontWeight(.medium)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                focusedField = nil
                onComplete()
            }) {
                Text("Complete Set")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValidInput ? Color.blue : Color.gray)
                    .cornerRadius(12)
            }
            .disabled(!isValidInput)
            .accessibilityLabel("Complete this set")

            HStack(spacing: 12) {
                Button(action: fillPreviousData) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Use Previous")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .accessibilityLabel("Use data from previous set")

                Spacer()

                Button(action: clearAllFields) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear")
                    }
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                .accessibilityLabel("Clear all fields")
            }
        }
    }

    private var isValidInput: Bool {
        !weight.isEmpty && !reps.isEmpty && !rpe.isEmpty &&
        Double(weight) != nil && Int(reps) != nil && Double(rpe) != nil &&
        (Double(rpe) ?? 0) >= 1 && (Double(rpe) ?? 0) <= 10
    }

    private func fillPreviousData() {
        // Simulate filling from previous set
        weight = "135"
        reps = "8"
        rpe = "7"
    }

    private func clearAllFields() {
        weight = ""
        reps = ""
        rpe = ""
        focusedField = .weight
    }
}

// MARK: - RPE Information View

struct RPEInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Rate of Perceived Exertion (RPE)")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("RPE is a scale from 1-10 that measures how hard an exercise feels. Use this to track the intensity of your sets.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    VStack(spacing: 12) {
                        RPEScaleRow(rpe: 10, description: "Maximum effort", detail: "Could not do another rep")
                        RPEScaleRow(rpe: 9, description: "Very hard", detail: "Could do 1 more rep")
                        RPEScaleRow(rpe: 8, description: "Hard", detail: "Could do 2-3 more reps")
                        RPEScaleRow(rpe: 7, description: "Somewhat hard", detail: "Could do 3-4 more reps")
                        RPEScaleRow(rpe: 6, description: "Moderate", detail: "Could do 4-6 more reps")
                        RPEScaleRow(rpe: 5, description: "Light", detail: "Could do many more reps")
                        RPEScaleRow(rpe: 1-4, description: "Very light", detail: "Warm-up intensity")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tips:")
                            .font(.headline)
                            .fontWeight(.semibold)

                        Text("• Most working sets should be RPE 6-9")
                        Text("• Use RPE 8-9 for strength training")
                        Text("• RPE 6-7 is good for volume work")
                        Text("• Be honest with your ratings")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle("RPE Scale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct RPEScaleRow: View {
    let rpe: Int
    let description: String
    let detail: String

    init(rpe: Int, description: String, detail: String) {
        self.rpe = rpe
        self.description = description
        self.detail = detail
    }

    init(rpe: ClosedRange<Int>, description: String, detail: String) {
        self.rpe = rpe.lowerBound
        self.description = description
        self.detail = detail
    }

    var body: some View {
        HStack {
            Text("\(rpe)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(colorForRPE(rpe))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(description)
                    .font(.headline)
                    .fontWeight(.medium)

                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func colorForRPE(_ rpe: Int) -> Color {
        switch rpe {
        case 9...10: return .red
        case 7...8: return .orange
        case 5...6: return .yellow
        default: return .green
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SetLoggingView_Previews: PreviewProvider {
    static var previews: some View {
        SetLoggingView(
            weight: .constant("135"),
            reps: .constant("8"),
            rpe: .constant("7"),
            exerciseName: "Bench Press",
            setNumber: 2,
            onComplete: {},
            onCancel: {}
        )
        .preferredColorScheme(.light)
        .previewDisplayName("Light Mode")

        SetLoggingView(
            weight: .constant(""),
            reps: .constant(""),
            rpe: .constant(""),
            exerciseName: "Squat",
            setNumber: 1,
            onComplete: {},
            onCancel: {}
        )
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode - Empty")
    }
}

struct RPEInfoView_Previews: PreviewProvider {
    static var previews: some View {
        RPEInfoView()
    }
}
#endif