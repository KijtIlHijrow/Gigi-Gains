//
//  MainTabView.swift
//  Gigi Gains
//
//  Main tab view with workout, routines, history, settings tabs.
//  Serves as the primary navigation structure for the app.
//
//  Created: 2025-09-28
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            WorkoutTabView()
                .tabItem {
                    Image(systemName: "dumbbell.fill")
                    Text("Workout")
                }
                .tag(0)
                .accessibilityLabel("Workout tab")
                .accessibilityHint("Start or continue your workout session")

            RoutinesTabView()
                .tabItem {
                    Image(systemName: "list.bullet.clipboard")
                    Text("Routines")
                }
                .tag(1)
                .accessibilityLabel("Routines tab")
                .accessibilityHint("View and manage your workout routines")

            HistoryTabView()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("History")
                }
                .tag(2)
                .accessibilityLabel("History tab")
                .accessibilityHint("View workout history and progress charts")

            SettingsTabView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(3)
                .accessibilityLabel("Settings tab")
                .accessibilityHint("Configure app settings and preferences")
        }
        .accentColor(.blue)
        .onAppear {
            setupTabBarAppearance()
        }
    }

    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Tab Content Views

struct WorkoutTabView: View {
    var body: some View {
        NavigationView {
            WorkoutSessionView()
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct RoutinesTabView: View {
    var body: some View {
        NavigationView {
            RoutineListView()
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct HistoryTabView: View {
    var body: some View {
        NavigationView {
            WorkoutHistoryView()
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct SettingsTabView: View {
    var body: some View {
        NavigationView {
            SettingsView()
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Preview

#if DEBUG
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode")

        MainTabView()
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")

        MainTabView()
            .previewDevice("iPad Pro (11-inch) (4th generation)")
            .previewDisplayName("iPad")
    }
}
#endif