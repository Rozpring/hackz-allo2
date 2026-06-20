#if canImport(UIKit)
import UIKit
import ImageIO

/// 端末の `UIInterfaceOrientation` から、`ARFrame.capturedImage`（常にセンサ向き＝ランドスケープ固定）を
/// Vision に正しい向きで渡すための `CGImagePropertyOrientation` を算出する。
///
/// research.md「向きの罠」: ポートレート＋背面カメラは概ね `.right`。
///
/// - Note: 本ヘルパは tasks 1.3（#12, kyiku 担当 `CoordinateMath`）と責務が重複する見込み。
///   #12 が入ったらそちらへ集約し、本ファイルは削除して差し替える想定。暫定でここに置く。
enum CameraOrientation {
    /// 背面カメラ + `ARFrame.capturedImage` を Vision に渡す際の画像向き。
    static func forCapturedImage(interfaceOrientation: UIInterfaceOrientation) -> CGImagePropertyOrientation {
        switch interfaceOrientation {
        case .portrait:            return .right
        case .portraitUpsideDown:  return .left
        case .landscapeLeft:       return .down
        case .landscapeRight:      return .up
        case .unknown:             return .right
        @unknown default:          return .right
        }
    }
}
#endif
