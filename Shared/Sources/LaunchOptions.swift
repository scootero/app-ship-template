// =============================================================================
// LaunchOptions.swift — the hooks that make automation possible.  [core] PHASE 1
// =============================================================================
// Scripts can't tap buttons. Instead they launch the app with flags:
//
//   -demo 1            fill the app with fake, good-looking data (no login,
//                      no HealthKit, no network). Used by screenshots + previews.
//   -route <name>      open straight to one screen. Used by screenshots.
//
// Example (what Tools/capture-screenshots.sh runs):
//   xcrun simctl launch booted com.example.MyApp -demo 1 -route detail
//
// How it works: iOS/macOS put launch arguments like "-demo 1" into
// UserDefaults automatically, so reading them is one line each.
//
// Also detects "running under unit tests" so the app skips real startup
// (network, HealthKit, onboarding) and tests stay fast and repeatable.
// =============================================================================

import Foundation

/// Every screen a script can jump to.
/// TODO(phase-4): replace these with your real screens. The raw values must
/// match SCREENSHOT_ROUTES in ship.config.
public enum AppRoute: String, CaseIterable, Sendable {
    case home
    case detail
    case settings
}

public enum LaunchOptions {
    /// `-demo 1` → use DemoData instead of real services.
    public static var isDemo: Bool {
        UserDefaults.standard.bool(forKey: "demo")
    }

    /// `-route detail` → start on that screen. nil = normal launch.
    public static var route: AppRoute? {
        UserDefaults.standard.string(forKey: "route").flatMap(AppRoute.init(rawValue:))
    }

    /// True when XCTest is hosting the app. Check this before starting
    /// anything slow or stateful (network, HealthKit, analytics, onboarding).
    public static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
