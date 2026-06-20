import Combine

/// カメラフレームから手の代表点（`HandSample`）を非同期に供給する抽象インターフェース。
///
/// この抽象は「出力の契約」だけを定義する。フレーム入力（`ARFrame` 等）は
/// プラットフォーム依存のため、ここには含めない。iOS 実装（`VisionHandProvider`, issue #20）が
/// 別途フレーム受け口（`FrameConsuming` 相当）を持ち、本プロトコルに適合する。
///
/// この分離により、本体ロジック（`HandSwingDetector` 等）は ARKit/Vision に一切依存せず、
/// `MockHandLandmarkProvider` を使って macOS 上で単体テストできる。
///
/// - 設計対応: design.md `HandLandmarkProvider`（Input Layer）。要件 3.1, 3.2。
public protocol HandLandmarkProvider: AnyObject {
    /// 検出した代表点を流すストリーム。未検出のフレームでは発行しない。
    /// 信頼度が閾値未満の点は供給側で破棄され、ここには流れない。
    var samples: AnyPublisher<HandSample, Never> { get }
}
