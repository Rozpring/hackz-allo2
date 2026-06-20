import XCTest
@testable import TableBangConcentration

final class FrameRouterTests: XCTestCase {
    func testRoutesToAllConsumers() {
        var a: [Int] = []
        var b: [Int] = []
        let router = FrameRouter<Int>(consumers: [{ a.append($0) }, { b.append($0) }])

        router.route(1)
        router.route(2)

        XCTAssertEqual(a, [1, 2])
        XCTAssertEqual(b, [1, 2], "1フィードが全消費者へ分配される（AR描画と手検出の二系統, #30）")
    }

    func testNoConsumersIsSafe() {
        let router = FrameRouter<Int>(consumers: [])
        router.route(42) // クラッシュしない
    }
}
