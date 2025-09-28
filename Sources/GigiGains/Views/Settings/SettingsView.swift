//
//  SettingsView.swift
//  Gigi Gains
//
//  Settings view for app configuration and preferences.
//  Provides access to all user preferences, integrations, and app settings.
//
//  Created: 2025-09-28
//

import SwiftUI

struct SettingsView: View {
    @State private var showingHealthKitSettings = false
    @State private var showingNotificationSettings = false
    @State private var showingCloudSyncSettings = false
    @State private var showingDataExport = false
    @State private var showingAbout = false

    var body: some View {
        List {
            profileSection
            workoutPreferencesSection
            integrationsSection
            notificationsSection
            dataAndPrivacySection
            supportSection
            aboutSection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingHealthKitSettings) {
            HealthKitSettingsView()
        }
        .sheet(isPresented: $showingNotificationSettings) {
            NotificationSettingsView()
        }
        .sheet(isPresented: $showingCloudSyncSettings) {
            CloudSyncSettingsView()
        }
        .sheet(isPresented: $showingDataExport) {
            DataExportView()
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
    }

    private var profileSection: some View {
        Section {
            HStack {
                Circle()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.blue)
                    .overlay(
                        Text("GG")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Gigi Gains User")
                        .font(.headline)
                        .fontWeight(.medium)

                    Text("Member since January 2025")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("User profile")
            .accessibilityHint("Tap to edit profile")
        }
    }

    private var workoutPreferencesSection: some View {
        Section(header: Text("Workout Preferences")) {
            SettingsRow(
                icon: "timer",
                title: "Default Rest Timer",
                value: "2 minutes",
                color: .orange
            ) {
                // Navigate to rest timer settings
            }

            SettingsRow(
                icon: "scalemass",
                title: "Weight Unit",
                value: "Pounds (lbs)",
                color: .purple
            ) {
                // Navigate to unit settings
            }

            SettingsRow(
                icon: "target",
                title: "RPE Scale",
                value: "1-10 Scale",
                color: .red
            ) {
                // Navigate to RPE settings
            }

            SettingsRow(
                icon: "list.bullet.clipboard",
                title: "Routine Templates",
                value: "3 saved",
                color: .green
            ) {
                // Navigate to routine templates
            }
        }
    }

    private var integrationsSection: some View {
        Section(header: Text("Integrations")) {
            SettingsRow(
                icon: "heart.fill",
                title: "Apple Health",
                value: "Connected",
                color: .red,
                isConnected: true
            ) {
                showingHealthKitSettings = true
            }

            SettingsRow(
                icon: "icloud.fill",
                title: "iCloud Sync",
                value: "Enabled",
                color: .blue,
                isConnected: true
            ) {
                showingCloudSyncSettings = true
            }

            SettingsRow(
                icon: "applewatch",
                title: "Apple Watch",
                value: "Coming Soon",
                color: .black,
                isConnected: false
            ) {
                // Future Apple Watch integration
            }
        }
    }

    private var notificationsSection: some View {
        Section(header: Text("Notifications")) {
            SettingsRow(
                icon: "bell.fill",
                title: "Rest Timer Alerts",
                value: "Enabled",
                color: .orange,
                isConnected: true
            ) {
                showingNotificationSettings = true
            }

            SettingsRow(
                icon: "calendar.badge.clock",
                title: "Workout Reminders",
                value: "Daily at 6:00 PM",
                color: .indigo
            ) {
                showingNotificationSettings = true
            }

            SettingsRow(
                icon: "trophy.fill",
                title: "Achievement Alerts",
                value: "Enabled",
                color: .yellow,
                isConnected: true
            ) {
                showingNotificationSettings = true
            }
        }
    }

    private var dataAndPrivacySection: some View {
        Section(header: Text("Data & Privacy")) {
            SettingsRow(
                icon: "square.and.arrow.up",
                title: "Export Data",
                value: "CSV, JSON",
                color: .blue
            ) {
                showingDataExport = true
            }

            SettingsRow(
                icon: "trash",
                title: "Clear All Data",
                value: "Reset app",
                color: .red
            ) {
                // Show confirmation dialog
            }

            SettingsRow(
                icon: "lock.fill",
                title: "Privacy Policy",
                value: "View policy",
                color: .green
            ) {
                // Open privacy policy
            }

            SettingsRow(
                icon: "shield.checkered",
                title: "Data Security",
                value: "Local & iCloud only",
                color: .blue
            ) {
                // Show data security info
            }
        }
    }

    private var supportSection: some View {
        Section(header: Text("Support")) {
            SettingsRow(
                icon: "questionmark.circle.fill",
                title: "Help & FAQ",
                value: "Get answers",
                color: .blue
            ) {
                // Open help
            }

            SettingsRow(
                icon: "envelope.fill",
                title: "Contact Support",
                value: "Send feedback",
                color: .green
            ) {
                // Open email composer
            }

            SettingsRow(
                icon: "star.fill",
                title: "Rate App",
                value: "App Store",
                color: .yellow
            ) {
                // Open App Store rating
            }

            SettingsRow(
                icon: "square.and.arrow.up",
                title: "Share App",
                value: "Tell friends",
                color: .indigo
            ) {
                // Open share sheet
            }
        }
    }

    private var aboutSection: some View {
        Section(header: Text("About")) {
            SettingsRow(
                icon: "info.circle.fill",
                title: "App Version",
                value: "1.0.0 (1)",
                color: .gray
            ) {
                showingAbout = true
            }

            SettingsRow(
                icon: "doc.text.fill",
                title: "Terms of Service",
                value: "Legal terms",
                color: .blue
            ) {
                // Open terms of service
            }

            SettingsRow(
                icon: "heart.circle.fill",
                title: "Acknowledgments",
                value: "Open source libraries",
                color: .pink
            ) {
                // Show acknowledgments
            }
        }
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    let isConnected: Bool?
    let action: () -> Void

    init(icon: String, title: String, value: String, color: Color, isConnected: Bool? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.value = value
        self.color = color
        self.isConnected = isConnected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.primary)

                    HStack(spacing: 4) {
                        Text(value)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let isConnected = isConnected {
                            Circle()
                                .frame(width: 6, height: 6)
                                .foregroundColor(isConnected ? .green : .gray)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(title), \(value)")
    }
}

// MARK: - HealthKit Settings View

struct HealthKitSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var workoutExportEnabled = true
    @State private var heartRateImportEnabled = true
    @State private var activeEnergyImportEnabled = true
    @State private var autoSyncEnabled = true

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Apple Health Integration")) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text("Connection Status")
                        Spacer()
                        Text("Connected")
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    }
                }

                Section(header: Text("Data Export")) {
                    Toggle("Export Workouts", isOn: $workoutExportEnabled)
                        .accessibilityLabel("Export completed workouts to Apple Health")

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Workout data including exercises, sets, reps, and duration will be saved to Apple Health")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Data Import")) {
                    Toggle("Import Heart Rate", isOn: $heartRateImportEnabled)
                        .accessibilityLabel("Import heart rate data from Apple Health")

                    Toggle("Import Active Energy", isOn: $activeEnergyImportEnabled)
                        .accessibilityLabel("Import active energy data from Apple Health")

                    Toggle("Auto Sync", isOn: $autoSyncEnabled)
                        .accessibilityLabel("Automatically sync data with Apple Health")
                }

                Section(header: Text("Privacy")) {
                    Button("Review Permissions") {
                        // Open Health app permissions
                    }

                    Button("Privacy Settings") {
                        // Show privacy information
                    }
                }
            }
            .navigationTitle("Apple Health")
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

// MARK: - Notification Settings View

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var restTimerEnabled = true
    @State private var workoutRemindersEnabled = true
    @State private var achievementAlertsEnabled = true
    @State private var soundEnabled = true
    @State private var badgeEnabled = true

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Notification Types")) {
                    Toggle("Rest Timer Alerts", isOn: $restTimerEnabled)
                        .accessibilityLabel("Enable rest timer completion notifications")

                    Toggle("Workout Reminders", isOn: $workoutRemindersEnabled)
                        .accessibilityLabel("Enable scheduled workout reminder notifications")

                    Toggle("Achievement Alerts", isOn: $achievementAlertsEnabled)
                        .accessibilityLabel("Enable personal record and achievement notifications")
                }

                Section(header: Text("Notification Style")) {
                    Toggle("Sound", isOn: $soundEnabled)
                        .accessibilityLabel("Play sound with notifications")

                    Toggle("Badge App Icon", isOn: $badgeEnabled)
                        .accessibilityLabel("Show notification count on app icon")
                }

                Section(header: Text("Workout Reminders")) {
                    HStack {
                        Text("Daily Reminder")
                        Spacer()
                        Text("6:00 PM")
                            .foregroundColor(.secondary)
                    }

                    Button("Customize Schedule") {
                        // Open reminder schedule settings
                    }
                }

                Section(footer: Text("Notification permissions can be managed in iOS Settings > Notifications > Gigi Gains")) {
                    Button("Open System Settings") {
                        // Open iOS notification settings
                    }
                }
            }
            .navigationTitle("Notifications")
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

// MARK: - Cloud Sync Settings View

struct CloudSyncSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var iCloudSyncEnabled = true
    @State private var autoSyncEnabled = true
    @State private var syncOnCellularEnabled = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("iCloud Sync")) {
                    HStack {
                        Image(systemName: "icloud.fill")
                            .foregroundColor(.blue)
                        Text("Status")
                        Spacer()
                        Text("Synced")
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    }

                    Toggle("Enable iCloud Sync", isOn: $iCloudSyncEnabled)
                        .accessibilityLabel("Enable automatic iCloud synchronization")

                    if iCloudSyncEnabled {
                        Toggle("Auto Sync", isOn: $autoSyncEnabled)
                            .accessibilityLabel("Automatically sync changes")

                        Toggle("Sync on Cellular", isOn: $syncOnCellularEnabled)
                            .accessibilityLabel("Allow syncing over cellular data")
                    }
                }

                Section(header: Text("Sync Statistics")) {
                    HStack {
                        Text("Last Sync")
                        Spacer()
                        Text("2 minutes ago")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Data Usage")
                        Spacer()
                        Text("2.3 MB")
                            .foregroundColor(.secondary)
                    }

                    Button("Force Sync Now") {
                        // Trigger manual sync
                    }
                }

                Section(header: Text("Troubleshooting")) {
                    Button("Reset Sync Data") {
                        // Reset sync metadata
                    }

                    Button("View Sync Log") {
                        // Show detailed sync information
                    }
                }
            }
            .navigationTitle("iCloud Sync")
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

// MARK: - Data Export View

struct DataExportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: ExportFormat = .csv
    @State private var includePersonalRecords = true
    @State private var includeWorkoutHistory = true
    @State private var includeRoutines = true

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Export Format")) {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section(header: Text("Include Data")) {
                    Toggle("Workout History", isOn: $includeWorkoutHistory)
                        .accessibilityLabel("Include all completed workouts")

                    Toggle("Personal Records", isOn: $includePersonalRecords)
                        .accessibilityLabel("Include personal record achievements")

                    Toggle("Routines", isOn: $includeRoutines)
                        .accessibilityLabel("Include saved workout routines")
                }

                Section(header: Text("Privacy Notice")) {
                    Text("Exported data contains only your workout information. No personal identifiers or sensitive data is included.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section {
                    Button("Export Data") {
                        // Perform data export
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)

                        Text("Gigi Gains")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Version 1.0.0 (1)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("About Gigi Gains")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Gigi Gains is a privacy-focused workout tracking app designed for strength training enthusiasts. Track your progress, log workouts, and achieve your fitness goals.")
                            .font(.body)
                            .foregroundColor(.secondary)

                        Text("Key Features:")
                            .font(.headline)
                            .fontWeight(.medium)

                        VStack(alignment: .leading, spacing: 8) {
                            FeatureRow(icon: "dumbbell", text: "Comprehensive exercise library")
                            FeatureRow(icon: "timer", text: "Built-in rest timer with notifications")
                            FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Progress tracking and analytics")
                            FeatureRow(icon: "heart.fill", text: "Apple Health integration")
                            FeatureRow(icon: "icloud.fill", text: "iCloud sync across devices")
                            FeatureRow(icon: "lock.fill", text: "Privacy-first design")
                        }
                    }

                    VStack(spacing: 12) {
                        Text("Made with ❤️ for fitness enthusiasts")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("© 2025 Gigi Gains. All rights reserved.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("About")
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

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.blue)
                .frame(width: 20)

            Text(text)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Supporting Types

enum ExportFormat: String, CaseIterable {
    case csv = "csv"
    case json = "json"

    var displayName: String {
        switch self {
        case .csv: return "CSV"
        case .json: return "JSON"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
        }
        .preferredColorScheme(.light)
        .previewDisplayName("Light Mode")

        NavigationView {
            SettingsView()
        }
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")
    }
}

struct HealthKitSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        HealthKitSettingsView()
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}
#endif