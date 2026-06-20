import Foundation
import CoreGraphics
import Combine
import ARKit
import UIKit

/// 手の代表点サンプル（画面座標＋時刻＋信頼度）。
struct HandSample: Equatable {
    /// 画面座標（左上原点）。正規化(0..1) もしくは points。
    let screenPoint: CGPoint
    let timestamp: TimeInterval
    let confidence: Float
}

/// カメラフレームから手の代表点を供給する抽象。
/// Vision 実装と差し替え可能にし、将来の MediaPipe 移行余地を残す。
protocol HandLandmarkProvider: AnyObject {
    /// 検出した代表点を非同期に流す。未検出のフレームでは発行しない。
    var samples: AnyPublisher<HandSample, Never> { get }
    /// 1フレームを処理（前フレーム処理中はスキップ＝間引きは実装側の責務）。
    func process(frame: ARFrame, interfaceOrientation: UIInterfaceOrientation)
}
