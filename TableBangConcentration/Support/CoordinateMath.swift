import Foundation
import CoreGraphics
import ImageIO
import UIKit
import simd

/// 座標変換の純関数ヘルパ。
///
/// 注意: Vision の正規化座標→ARView 画面座標の本変換は、回転・アスペクト・クロップを含む
/// `ARFrame.displayTransform(for:viewportSize:)` を用いる（単純な y 反転では不可）。
/// 本ファイルにはテスト可能な純関数のみを置き、displayTransform 適用は結線層（#8）で行う。
enum CoordinateMath {
    /// 端末向きから背面カメラ `capturedImage` 用の `CGImagePropertyOrientation` を算出。
    static func imageOrientation(for interfaceOrientation: UIInterfaceOrientation) -> CGImagePropertyOrientation {
        switch interfaceOrientation {
        case .portrait: return .right
        case .portraitUpsideDown: return .left
        case .landscapeLeft: return .down
        case .landscapeRight: return .up
        default: return .right
        }
    }

    /// Vision 正規化座標（左下原点）→ 画面正規化座標（左上原点）への y 反転。
    static func flipY(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: 1 - point.y)
    }

    /// カードのワールド上方向ベクトルから表/伏せを判定（worldUp.y > 0 で表）。
    static func isFaceUp(worldUp: SIMD3<Float>) -> Bool {
        worldUp.y > 0
    }
}
