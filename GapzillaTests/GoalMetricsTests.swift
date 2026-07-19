import XCTest
@testable import Gapzilla

final class GoalMetricsTests: XCTestCase {
    func testGapMetricsAreDerivedFromSlips() throws {
        let today = try date("2026-07-15")
        let events = [
            event("slip-1", "2026-06-01", .slip),
            event("slip-2", "2026-06-11", .slip),
            event("slip-3", "2026-07-01", .slip)
        ]

        let metrics = GoalMetrics(events: events, today: today)

        XCTAssertEqual(metrics.currentGap, 14)
        XCTAssertEqual(metrics.completedGaps, [10, 20])
        XCTAssertEqual(metrics.bestGap, 20)
        XCTAssertEqual(metrics.averageGap, 15)
        XCTAssertEqual(metrics.previousGap, 20)
        XCTAssertEqual(metrics.trend.map(\.days), [10, 20, 14])
    }

    func testUrgeDoesNotResetCurrentGap() throws {
        let today = try date("2026-07-15")
        let slip = event("slip", "2026-07-01", .slip)
        let urge = event("urge", "2026-07-14", .urge)

        let metrics = GoalMetrics(events: [slip, urge], today: today)

        XCTAssertEqual(metrics.currentGap, 14)
        XCTAssertEqual(metrics.urgesLastSevenDays, 1)
        XCTAssertNil(metrics.impactDays(for: urge))
    }

    func testSlipOverridesUrgeForSameDayInterpretation() throws {
        let today = try date("2026-07-15")
        let earlierSlip = event("slip-1", "2026-07-01", .slip)
        let urge = event("urge", "2026-07-14", .urge)
        let sameDaySlip = event("slip-2", "2026-07-14", .slip)

        let metrics = GoalMetrics(events: [urge, sameDaySlip, earlierSlip], today: today)

        XCTAssertEqual(metrics.dayKind(on: try date("2026-07-14")), .slip)
        XCTAssertTrue(metrics.controlledUrges.isEmpty)
        XCTAssertEqual(metrics.urgesLastSevenDays, 0)
    }

    func testUrgeOnlyDayIsDerivedAsControlled() throws {
        let today = try date("2026-07-15")
        let urge = event("urge", "2026-07-14", .urge)

        let metrics = GoalMetrics(events: [urge], today: today)

        XCTAssertEqual(metrics.dayKind(on: try date("2026-07-14")), .urge)
        XCTAssertEqual(metrics.controlledUrges, [urge])
        XCTAssertEqual(metrics.urgesLastSevenDays, 1)
    }

    func testImpactUsesNextSlipAndCurrentDay() throws {
        let today = try date("2026-07-15")
        let first = event("slip-1", "2026-06-01", .slip)
        let latest = event("slip-2", "2026-06-11", .slip)
        let metrics = GoalMetrics(events: [latest, first], today: today)

        XCTAssertEqual(metrics.impactDays(for: first), 10)
        XCTAssertEqual(metrics.impactDays(for: latest), 34)
    }

    private func event(_ id: String, _ occurredOn: String, _ kind: EventKind) -> GoalEvent {
        GoalEvent(
            id: id,
            goalId: "goal",
            eventType: kind.rawValue,
            occurredOn: occurredOn,
            note: "",
            createdAt: ""
        )
    }

    private func date(_ value: String) throws -> Date {
        try XCTUnwrap(AppDate.api.date(from: value))
    }
}
