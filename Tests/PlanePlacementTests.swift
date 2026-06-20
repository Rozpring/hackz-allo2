import XCTest
@testable import TableBangConcentration

final class PlanePlacementTests: XCTestCase {
    func testPlaneIsPlaceableWhenLargeEnough() {
        XCTAssertTrue(PlaneReadiness.isPlaceable(planeWidth: 0.5, planeDepth: 0.5, minSide: 0.3))
    }

    func testPlaneTooSmallIsNotPlaceable() {
        XCTAssertFalse(PlaneReadiness.isPlaceable(planeWidth: 0.2, planeDepth: 0.5, minSide: 0.3))
        XCTAssertFalse(PlaneReadiness.isPlaceable(planeWidth: 0.5, planeDepth: 0.1, minSide: 0.3))
    }

    func testBoundaryIsInclusive() {
        XCTAssertTrue(PlaneReadiness.isPlaceable(planeWidth: 0.3, planeDepth: 0.3, minSide: 0.3))
    }

    // 平面検出・トラッキング状態 → 配置ガイダンス
    func testGuidanceSearchingWhenNoPlane() {
        XCTAssertEqual(PlacementGuidance.evaluate(planeReady: false, trackingLimited: false), .searchingPlane)
    }

    func testGuidanceReadyWhenPlaneDetected() {
        XCTAssertEqual(PlacementGuidance.evaluate(planeReady: true, trackingLimited: false), .readyToPlace)
    }

    func testGuidanceTrackingLimitedTakesPriority() {
        XCTAssertEqual(PlacementGuidance.evaluate(planeReady: true, trackingLimited: true), .trackingLimited)
    }
}
