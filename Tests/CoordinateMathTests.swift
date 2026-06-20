import XCTest
import CoreGraphics
import ImageIO
import UIKit
import simd
@testable import TableBangConcentration

final class CoordinateMathTests: XCTestCase {
    func testImageOrientationForInterface() {
        XCTAssertEqual(CoordinateMath.imageOrientation(for: .portrait), .right)
        XCTAssertEqual(CoordinateMath.imageOrientation(for: .portraitUpsideDown), .left)
        XCTAssertEqual(CoordinateMath.imageOrientation(for: .landscapeLeft), .down)
        XCTAssertEqual(CoordinateMath.imageOrientation(for: .landscapeRight), .up)
    }

    func testFlipY() {
        let p = CoordinateMath.flipY(CGPoint(x: 0.3, y: 0.2))
        XCTAssertEqual(p.x, 0.3, accuracy: 1e-6)
        XCTAssertEqual(p.y, 0.8, accuracy: 1e-6)
    }

    func testFaceUpDetection() {
        XCTAssertTrue(CoordinateMath.isFaceUp(worldUp: SIMD3<Float>(0, 1, 0)))
        XCTAssertTrue(CoordinateMath.isFaceUp(worldUp: SIMD3<Float>(0.1, 0.9, 0.1)))
        XCTAssertFalse(CoordinateMath.isFaceUp(worldUp: SIMD3<Float>(0, -1, 0)))
    }

    // #59: 正規化座標 → ビュー point 座標への変換（単位不一致の解消）。
    func testViewPointFromNormalized() {
        let size = CGSize(width: 390, height: 844)

        let center = CoordinateMath.viewPoint(fromNormalized: CGPoint(x: 0.5, y: 0.5), viewportSize: size)
        XCTAssertEqual(center.x, 195, accuracy: 1e-6, "中央(0.5,0.5)はビュー中央")
        XCTAssertEqual(center.y, 422, accuracy: 1e-6)

        let origin = CoordinateMath.viewPoint(fromNormalized: CGPoint(x: 0, y: 0), viewportSize: size)
        XCTAssertEqual(origin.x, 0, accuracy: 1e-6)
        XCTAssertEqual(origin.y, 0, accuracy: 1e-6)

        let corner = CoordinateMath.viewPoint(fromNormalized: CGPoint(x: 1, y: 1), viewportSize: size)
        XCTAssertEqual(corner.x, 390, accuracy: 1e-6, "(1,1)はビュー右下")
        XCTAssertEqual(corner.y, 844, accuracy: 1e-6)
    }
}
