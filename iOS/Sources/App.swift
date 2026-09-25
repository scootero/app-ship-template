// =============================================================================
// App.swift — iPhone/iPad entry point.                              [ios]
// =============================================================================
// Placeholder UI so the template builds on day one. Replace RootView with your
// real app, but KEEP the two hooks marked HOOK: screenshots depend on them.
// =============================================================================

import SwiftUI

@main
struct MainApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    // HOOK: start on the screen the screenshot script asked for (-route ...).
    @State private var route: AppRoute = LaunchOptions.route ?? .home

    var body: some View {
        TabView(selection: $route) {
            HomeScreen()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppRoute.home)
            DetailScreen()
                .tabItem { Label("Detail", systemImage: "chart.bar") }
                .tag(AppRoute.detail)
            SettingsScreen()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(AppRoute.settings)
        }
    }
}

// TODO(setup): delete these placeholder screens once your real ones exist.

struct HomeScreen: View {
    // HOOK: demo data when launched with -demo 1, real data otherwise.
    private var items: [SampleItem] { LaunchOptions.isDemo ? DemoData.items : [] }

    var body: some View {
        NavigationStack {
            List(items) { item in
                LabeledContent(item.title, value: item.value.formatted())
            }
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView("No data yet", systemImage: "tray",
                                           description: Text("Launch with -demo 1 to see sample data."))
                }
            }
            .navigationTitle("__DISPLAY_NAME__")
        }
    }
}

struct DetailScreen: View {
    var body: some View {
        NavigationStack {
            Text("Detail").navigationTitle("Detail")
        }
    }
}

struct SettingsScreen: View {
    var body: some View {
        NavigationStack {
            Form {
                LabeledContent("Version",
                               value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview { RootView() }
