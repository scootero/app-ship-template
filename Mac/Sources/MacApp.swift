// =============================================================================
// MacApp.swift — Mac entry point.                                   [mac]
// =============================================================================
// Placeholder window app. For a menu-bar app like Blip, swap WindowGroup for
// MenuBarExtra and set INFOPLIST_KEY_LSUIElement: YES in project.yml.
// Uses the same Shared/ code (LaunchOptions, DemoData) as the iOS app.
// =============================================================================

import SwiftUI

@main
struct MacApp: App {
    var body: some Scene {
        WindowGroup {
            MacRootView()
                .frame(minWidth: 480, minHeight: 320)
        }
        // OPTIONAL menu bar version:
        // MenuBarExtra("__DISPLAY_NAME__", systemImage: "circle.fill") { MacRootView() }
        //     .menuBarExtraStyle(.window)
    }
}

struct MacRootView: View {
    // HOOK: demo data for screenshots (-demo 1).
    private var items: [SampleItem] { LaunchOptions.isDemo ? DemoData.items : [] }

    var body: some View {
        List(items) { item in
            LabeledContent(item.title, value: item.value.formatted())
        }
        .overlay {
            if items.isEmpty { Text("Launch with -demo 1 to see sample data.") }
        }
        .navigationTitle("__DISPLAY_NAME__")
    }
}
