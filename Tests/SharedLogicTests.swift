// =============================================================================
// SharedLogicTests.swift — unit tests.                             [core] PHASE 1
// =============================================================================
// These run on every push (ci.yml) and gate releases (coverage-check.sh).
// Keep them HERMETIC: no network, no HealthKit, no real accounts, no clocks.
// Test logic (scoring, formatting, models), not SwiftUI view layout.
//
// The same Tests/ folder is compiled into both the iOS and Mac test targets,
// so tests here should only touch Shared/ code.
//
// TODO(phase-1): replace these with tests for your real logic. For FitUp the
// first tests to write are the Balanced Battle scoring math.
// =============================================================================

import XCTest
@testable import __APP_NAME__   // both app targets use PRODUCT_NAME __APP_NAME__, so one import works for both

final class SharedLogicTests: XCTestCase {

    func testDemoDataIsStable() {
        // Screenshots rely on demo data never changing between runs.
        XCTAssertEqual(DemoData.items.count, 3)
        XCTAssertEqual(DemoData.items.first?.title, "Morning Walk")
    }

    func testEveryRouteRoundTrips() {
        // Every route the screenshot script uses must parse back.
        for route in AppRoute.allCases {
            XCTAssertEqual(AppRoute(rawValue: route.rawValue), route)
        }
    }

    func testDetectsTestHost() {
        XCTAssertTrue(LaunchOptions.isRunningTests)
    }
}
