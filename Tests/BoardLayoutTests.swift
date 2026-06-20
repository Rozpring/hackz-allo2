import XCTest
import simd
@testable import TableBangConcentration

final class BoardLayoutTests: XCTestCase {
    func testPositionCountMatchesCardCount() {
        let positions = BoardLayout.gridPositions(count: 16, columns: 4, spacing: 0.08)
        XCTAssertEqual(positions.count, 16)
    }

    func testGridIsCenteredAroundOrigin() {
        // 2x2 格子・間隔 1.0 は原点対称に並ぶ（XZ平面、y=0）
        let positions = BoardLayout.gridPositions(count: 4, columns: 2, spacing: 1.0)
        let xs = positions.map { $0.x }.sorted()
        let zs = positions.map { $0.z }.sorted()
        XCTAssertEqual(xs, [-0.5, -0.5, 0.5, 0.5])
        XCTAssertEqual(zs, [-0.5, -0.5, 0.5, 0.5])
        XCTAssertTrue(positions.allSatisfy { $0.y == 0 }, "格子はテーブル平面(y=0)に並ぶ")
    }

    func testCellsAreSpacedByConfiguredSpacing() {
        // 1行に並ぶ隣接セルの間隔が spacing と一致
        let positions = BoardLayout.gridPositions(count: 2, columns: 2, spacing: 0.08)
        let dx = abs(positions[1].x - positions[0].x)
        XCTAssertEqual(dx, 0.08, accuracy: 1e-6)
    }

    func testEmptyCountReturnsNoPositions() {
        XCTAssertTrue(BoardLayout.gridPositions(count: 0, columns: 4, spacing: 0.1).isEmpty)
    }

    func testColumnsExceedingCountStaysSingleRow() {
        let positions = BoardLayout.gridPositions(count: 3, columns: 5, spacing: 1.0)
        XCTAssertEqual(positions.count, 3)
        XCTAssertTrue(positions.allSatisfy { $0.z == 0 }, "全カードが1行に収まる")
    }

    func testPartialLastRow() {
        // 端数のある最終行でも全カード分の座標を返す
        let positions = BoardLayout.gridPositions(count: 5, columns: 4, spacing: 0.1)
        XCTAssertEqual(positions.count, 5)
        // 2行(rows=2)になり、z方向は2段
        let distinctZ = Set(positions.map { ($0.z * 1000).rounded() })
        XCTAssertEqual(distinctZ.count, 2)
    }
}
