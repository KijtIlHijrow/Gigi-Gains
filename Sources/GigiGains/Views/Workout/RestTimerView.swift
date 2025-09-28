//
//  RestTimerView.swift
//  Gigi Gains
//
//  Rest timer view with countdown and background notifications.
//  Provides visual and audio feedback for rest periods between sets.
//
//  Created: 2025-09-28
//

import SwiftUI

struct RestTimerView: View {
    let duration: TimeInterval
    let onComplete: () -> Void

    @StateObject private var timerManager = RestTimerManager()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var showingCustomTimer = false
    @State private var customMinutes = 2
    @State private var customSeconds = 0

    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()

                timerDisplay

                progressRing

                timerControls

                quickTimerButtons

                Spacer()
            }
            .padding()
            .navigationTitle("Rest Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Skip") {
                        timerManager.stop()
                        onComplete()
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Custom") {
                        showingCustomTimer = true
                    }
                    .foregroundColor(.blue)
                }
            }
            .onAppear {
                timerManager.start(duration: duration)
            }
            .onDisappear {
                if timerManager.isActive {
                    // Timer continues in background
                }
            }
            .onChange(of: scenePhase) { phase in
                handleScenePhaseChange(phase)
            }
            .onChange(of: timerManager.isComplete) { isComplete in
                if isComplete {
                    handleTimerComplete()
                }
            }
            .sheet(isPresented: $showingCustomTimer) {
                customTimerSheet
            }
        }
    }

    private var timerDisplay: some View {
        VStack(spacing: 8) {
            Text("Rest Time")
                .font(.headline)
                .foregroundColor(.secondary)

            Text(timerManager.timeDisplayText)
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundColor(timerManager.timeRemaining <= 10 ? .red : .primary)
                .monospacedDigit()
                .accessibilityLabel("Time remaining: \(timerManager.timeDisplayText)")

            if timerManager.timeRemaining <= 10 && timerManager.timeRemaining > 0 {
                Text("Almost done!")
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .fontWeight(.medium)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 12)
                .frame(width: 200, height: 200)

            Circle()
                .trim(from: 0, to: timerManager.progress)
                .stroke(
                    timerManager.timeRemaining <= 10 ? .red : .blue,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: timerManager.progress)

            VStack {
                Image(systemName: "timer")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)

                Text("\(Int(timerManager.progress * 100))%")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityLabel("Timer progress: \(Int(timerManager.progress * 100)) percent complete")
    }

    private var timerControls: some View {
        HStack(spacing: 24) {
            Button(action: {
                if timerManager.isActive {
                    timerManager.pause()
                } else {
                    timerManager.resume()
                }
                hapticFeedback.impactOccurred()
            }) {
                Image(systemName: timerManager.isActive ? "pause.fill" : "play.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(timerManager.isActive ? Color.orange : Color.green)
                    .clipShape(Circle())
            }
            .accessibilityLabel(timerManager.isActive ? "Pause timer" : "Resume timer")

            Button(action: {
                timerManager.stop()
                hapticFeedback.impactOccurred()
                onComplete()
                dismiss()
            }) {
                Image(systemName: "stop.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.red)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Stop timer")

            Button(action: {
                timerManager.addTime(30)
                hapticFeedback.impactOccurred()
            }) {
                VStack(spacing: 2) {
                    Image(systemName: "plus")
                        .font(.title2)
                    Text("30s")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Color.blue)
                .clipShape(Circle())
            }
            .accessibilityLabel("Add 30 seconds")
        }
    }

    private var quickTimerButtons: some View {
        VStack(spacing: 16) {
            Text("Quick Restart")
                .font(.headline)
                .fontWeight(.medium)

            HStack(spacing: 16) {
                ForEach([60, 90, 120, 180], id: \.self) { seconds in
                    Button(action: {
                        timerManager.restart(duration: TimeInterval(seconds))
                        hapticFeedback.impactOccurred()
                    }) {
                        Text(formatQuickTime(seconds))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(20)
                    }
                    .accessibilityLabel("Restart timer for \(formatQuickTime(seconds))")
                }
            }
        }
    }

    private var customTimerSheet: some View {
        NavigationView {
            VStack(spacing: 32) {
                Text("Set Custom Timer")
                    .font(.title2)
                    .fontWeight(.semibold)

                HStack {
                    VStack {
                        Text("Minutes")
                            .font(.headline)
                        Picker("Minutes", selection: $customMinutes) {
                            ForEach(0..<10) { minute in
                                Text("\(minute)").tag(minute)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(width: 100, height: 120)
                    }

                    VStack {
                        Text("Seconds")
                            .font(.headline)
                        Picker("Seconds", selection: $customSeconds) {
                            ForEach([0, 15, 30, 45], id: \.self) { second in
                                Text("\(second)").tag(second)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(width: 100, height: 120)
                    }
                }

                Button(action: {
                    let totalSeconds = customMinutes * 60 + customSeconds
                    if totalSeconds > 0 {
                        timerManager.restart(duration: TimeInterval(totalSeconds))
                        showingCustomTimer = false
                    }
                }) {
                    Text("Start Timer")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .disabled(customMinutes == 0 && customSeconds == 0)

                Spacer()
            }
            .padding()
            .navigationTitle("Custom Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showingCustomTimer = false
                    }
                }
            }
        }
    }

    private func formatQuickTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60

        if minutes > 0 && remainingSeconds > 0 {
            return "\(minutes):\(String(format: "%02d", remainingSeconds))"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(remainingSeconds)s"
        }
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .background:
            timerManager.enableBackgroundMode()
        case .active:
            timerManager.disableBackgroundMode()
        default:
            break
        }
    }

    private func handleTimerComplete() {
        hapticFeedback.impactOccurred()

        // Schedule completion after a brief delay for user feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            onComplete()
            dismiss()
        }
    }
}

// MARK: - Rest Timer Manager

class RestTimerManager: ObservableObject {
    @Published var timeRemaining: TimeInterval = 0
    @Published var totalDuration: TimeInterval = 0
    @Published var isActive = false
    @Published var isComplete = false

    private var timer: Timer?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return max(0, min(1, (totalDuration - timeRemaining) / totalDuration))
    }

    var timeDisplayText: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    func start(duration: TimeInterval) {
        stop() // Stop any existing timer

        totalDuration = duration
        timeRemaining = duration
        isActive = true
        isComplete = false

        startTimer()
    }

    func pause() {
        isActive = false
        stopTimer()
    }

    func resume() {
        guard timeRemaining > 0 else { return }
        isActive = true
        startTimer()
    }

    func stop() {
        isActive = false
        isComplete = false
        stopTimer()
        endBackgroundTask()
    }

    func restart(duration: TimeInterval) {
        start(duration: duration)
    }

    func addTime(_ seconds: TimeInterval) {
        timeRemaining += seconds
        totalDuration += seconds
    }

    func enableBackgroundMode() {
        guard isActive else { return }

        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }

    func disableBackgroundMode() {
        endBackgroundTask()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateTimer() {
        guard timeRemaining > 0 else {
            completeTimer()
            return
        }

        timeRemaining -= 1.0

        // Haptic feedback for last 3 seconds
        if timeRemaining <= 3 && timeRemaining > 0 {
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
        }
    }

    private func completeTimer() {
        isActive = false
        isComplete = true
        timeRemaining = 0
        stopTimer()
        endBackgroundTask()

        // Trigger completion notification and haptic
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }

    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    deinit {
        stop()
    }
}

// MARK: - Preview

#if DEBUG
struct RestTimerView_Previews: PreviewProvider {
    static var previews: some View {
        RestTimerView(duration: 120) {
            print("Timer completed")
        }
        .preferredColorScheme(.light)
        .previewDisplayName("Light Mode")

        RestTimerView(duration: 60) {
            print("Timer completed")
        }
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")
    }
}
#endif