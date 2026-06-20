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

    /// 正規化画面座標 [0,1]（左上原点）→ ビューの point 座標へ変換する。
    ///
    /// `ARView.raycast(from:)` はビューの point 座標（0〜幅 / 0〜高さ）を期待するため、Vision 由来の
    /// 正規化座標をそのまま渡すとレイがビュー左上隅へ飛び盤面に当たらない（#59 の根因）。本変換で単位を合わせる。
    ///
    /// 注: これはアスペクトフィルのクロップを無視するビューサイズ乗算の近似。回転・アスペクト・クロップまで
    /// 厳密に扱うには `ARFrame.displayTransform(for:viewportSize:)` を適用する（精度向上の follow-up）。
    /// まずは単位の不一致（正規化↔point）を解消し、台パンが盤面へ作用するようにすることを優先する。
    static func viewPoint(fromNormalized normalized: CGPoint, viewportSize: CGSize) -> CGPoint {
        CGPoint(x: normalized.x * viewportSize.width, y: normalized.y * viewportSize.height)
    }

    /// カードのワールド上方向ベクトルから表/伏せを判定（worldUp.y > 0 で表）。
    static func isFaceUp(worldUp: SIMD3<Float>) -> Bool {
        worldUp.y > 0
    }
}
