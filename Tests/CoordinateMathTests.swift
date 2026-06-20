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
}
