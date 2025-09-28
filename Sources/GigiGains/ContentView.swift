//
//  ContentView.swift
//  Gigi Gains
//
//  Root view with navigation setup and app-wide state management.
//  Handles onboarding, authentication, and main app navigation.
//
//  Created: 2025-09-28
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var dependencyContainer: DependencyContainer
    @StateObject private var appState = AppState()

    @State private var showingOnboarding = false
    @State private var showingPermissionPrompts = false

    var body: some View {
        Group {
            if appState.isFirstLaunch {
                onboardingView
            } else if appState.needsPermissionSetup {
                permissionSetupView
            } else {
                mainAppView
            }
        }
        .onAppear {
            checkAppState()
        }
        .onChange(of: appState.isFirstLaunch) { _ in
            updateAppState()
        }
    }

    private var onboardingView: some View {
        OnboardingView {
            appState.completeOnboarding()
        }
    }

    private var permissionSetupView: some View {
        PermissionSetupView {
            appState.completePermissionSetup()
        }
    }

    private var mainAppView: some View {
        MainTabView()
            .overlay(alignment: .topTrailing) {
                if appState.showSyncIndicator {
                    syncIndicator
                }
            }
            .alert("Sync Error", isPresented: $appState.showSyncError) {
                Button("Retry") {
                    retrySyncOperation()
                }
                Button("Dismiss", role: .cancel) {
                    appState.dismissSyncError()
                }
            } message: {
                Text(appState.syncErrorMessage)
            }
    }

    private var syncIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Syncing...")
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding()
    }

    private func checkAppState() {
        appState.isFirstLaunch = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") == false
        appState.needsPermissionSetup = !hasRequiredPermissions()
    }

    private func updateAppState() {
        if !appState.isFirstLaunch {
            checkPermissionState()
        }
    }

    private func checkPermissionState() {
        Task {
            let notificationStatus = await dependencyContainer.notificationService.getAuthorizationStatus()
            let healthKitStatus = await dependencyContainer.healthKitService.getAuthorizationStatus()

            await MainActor.run {
                appState.needsPermissionSetup = notificationStatus == .notDetermined ||
                    (dependencyContainer.healthKitService.isHealthKitAvailable &&
                     healthKitStatus.workoutWritePermission == .notDetermined)
            }
        }
    }

    private func hasRequiredPermissions() -> Bool {
        // Check if essential permissions have been requested
        return UserDefaults.standard.bool(forKey: "hasRequestedNotifications") &&
               UserDefaults.standard.bool(forKey: "hasRequestedHealthKit")
    }

    private func retrySyncOperation() {
        Task {
            do {
                try await dependencyContainer.cloudSyncService.performManualSync()
                appState.dismissSyncError()
            } catch {
                appState.showSyncError(with: error.localizedDescription)
            }
        }
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentPage = 0
    private let pages = OnboardingPage.allPages

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))

            VStack(spacing: 16) {
                if currentPage == pages.count - 1 {
                    Button("Get Started") {
                        completeOnboarding()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    HStack {
                        Button("Skip") {
                            completeOnboarding()
                        }
                        .foregroundColor(.secondary)

                        Spacer()

                        Button("Next") {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
            }
            .padding()
        }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        withAnimation {
            onComplete()
        }
    }
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: page.iconName)
                .font(.system(size: 100))
                .foregroundColor(.blue)

            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Permission Setup View

struct PermissionSetupView: View {
    let onComplete: () -> Void

    @EnvironmentObject private var dependencyContainer: DependencyContainer
    @State private var currentStep = 0
    @State private var isRequestingPermissions = false

    private let steps = ["Notifications", "Apple Health"]

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Text("Permission Setup")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Gigi Gains needs a few permissions to provide the best experience")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if currentStep == 0 {
                notificationPermissionStep
            } else {
                healthKitPermissionStep
            }

            Spacer()

            VStack(spacing: 12) {
                if isRequestingPermissions {
                    ProgressView("Requesting permissions...")
                } else {
                    Button(currentStep == 0 ? "Allow Notifications" : "Allow Health Access") {
                        requestCurrentPermission()
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button("Skip") {
                        skipCurrentStep()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }

    private var notificationPermissionStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "bell.fill")
                .font(.system(size: 80))
                .foregroundColor(.orange)

            VStack(spacing: 12) {
                Text("Stay Motivated")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Get notified when your rest timer completes and receive workout reminders to stay consistent with your training.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var healthKitPermissionStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "heart.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)

            VStack(spacing: 12) {
                Text("Track Your Progress")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Sync your workouts with Apple Health to see your fitness data in one place and track your long-term progress.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func requestCurrentPermission() {
        isRequestingPermissions = true

        Task {
            do {
                if currentStep == 0 {
                    let _ = try await dependencyContainer.notificationService.requestPermissions()
                    UserDefaults.standard.set(true, forKey: "hasRequestedNotifications")
                } else {
                    let _ = try await dependencyContainer.healthKitService.requestPermissions()
                    UserDefaults.standard.set(true, forKey: "hasRequestedHealthKit")
                }

                await MainActor.run {
                    isRequestingPermissions = false
                    nextStep()
                }
            } catch {
                await MainActor.run {
                    isRequestingPermissions = false
                    nextStep() // Continue even if permission denied
                }
            }
        }
    }

    private func skipCurrentStep() {
        if currentStep == 0 {
            UserDefaults.standard.set(true, forKey: "hasRequestedNotifications")
        } else {
            UserDefaults.standard.set(true, forKey: "hasRequestedHealthKit")
        }
        nextStep()
    }

    private func nextStep() {
        if currentStep < steps.count - 1 {
            withAnimation {
                currentStep += 1
            }
        } else {
            completePermissionSetup()
        }
    }

    private func completePermissionSetup() {
        withAnimation {
            onComplete()
        }
    }
}

// MARK: - App State

class AppState: ObservableObject {
    @Published var isFirstLaunch = false
    @Published var needsPermissionSetup = false
    @Published var showSyncIndicator = false
    @Published var showSyncError = false
    @Published var syncErrorMessage = ""

    func completeOnboarding() {
        isFirstLaunch = false
    }

    func completePermissionSetup() {
        needsPermissionSetup = false
    }

    func showSyncError(with message: String) {
        syncErrorMessage = message
        showSyncError = true
    }

    func dismissSyncError() {
        showSyncError = false
        syncErrorMessage = ""
    }
}

// MARK: - Supporting Types

struct OnboardingPage {
    let iconName: String
    let title: String
    let description: String

    static let allPages = [
        OnboardingPage(
            iconName: "dumbbell.fill",
            title: "Welcome to Gigi Gains",
            description: "Your personal strength training companion. Track workouts, monitor progress, and achieve your fitness goals."
        ),
        OnboardingPage(
            iconName: "timer",
            title: "Built-in Rest Timer",
            description: "Never lose track of your rest periods. Get notifications when it's time for your next set, even when the app is in the background."
        ),
        OnboardingPage(
            iconName: "chart.line.uptrend.xyaxis",
            title: "Track Your Progress",
            description: "See your strength gains over time with detailed analytics. Monitor personal records and weekly training volume."
        ),
        OnboardingPage(
            iconName: "icloud.fill",
            title: "Sync Across Devices",
            description: "Your workout data stays in sync across all your devices with secure iCloud integration."
        )
    ]
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(DependencyContainer())
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode")

        ContentView()
            .environmentObject(DependencyContainer())
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView {
            print("Onboarding completed")
        }
    }
}
#endif