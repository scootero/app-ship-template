// =============================================================================
// DemoData.swift — fake data for screenshots, previews and demos.  [core] PHASE 4
// =============================================================================
// WHY: App Store screenshots must look full and alive, and must NEVER show
// real names, emails, IPs or health data. Blip seeds curated fake data behind a
// launch flag; this is the same idea.
//
// Pattern: your data layer asks `LaunchOptions.isDemo` once at startup and, if
// true, returns these values instead of calling real services.
//
// TODO(phase-4): replace the sample model with your real models. FitUp would
// seed: one live battle mid-race, a finished best-of-5, a leaderboard of ~8
// made-up players. Pick values that make each screenshot tell a story.
// =============================================================================

import Foundation

public struct SampleItem: Identifiable, Hashable, Sendable {
    public let id: Int
    public let title: String
    public let value: Int

    public init(id: Int, title: String, value: Int) {
        self.id = id
        self.title = title
        self.value = value
    }
}

public enum DemoData {
    /// Fixed values (no randomness) so every screenshot run looks identical.
    public static let items: [SampleItem] = [
        SampleItem(id: 1, title: "Morning Walk", value: 8_412),
        SampleItem(id: 2, title: "Lunch Loop", value: 3_207),
        SampleItem(id: 3, title: "Evening Run", value: 11_965),
    ]
}
