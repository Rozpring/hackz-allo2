import Combine
import CoreGraphics
import Foundation

/// 台パン成立イベント。下方向ピーク速度（威力の元）と、着地時の代表点（衝撃中心の投影元）を持つ。
/// 設計対応: design.md `TablePunchEvent`。
public struct TablePunchEvent: Equatable, Sendable {
    /// 下方向ピーク速度（画面正規化座標/秒）。`PowerCalculator` がこれを威力へ正規化する。
    public let peakVelocity: CGFloat
    /// 着地時の代表点（左上原点・正規化）。AR 平面へ投影して衝撃中心にする。
    public let screenPoint: CGPoint

    public init(peakVelocity: CGFloat, screenPoint: CGPoint) {
        self.peakVelocity = peakVelocity
        self.screenPoint = screenPoint
    }
}

/// 台パンイベントを発行する型の契約。
public protocol HandSwingDetecting: AnyObject {
    var punches: AnyPublisher<TablePunchEvent, Never> { get }
}

/// 手の代表点（`HandSample`）の時系列から、下方向の振り下ろし → 急減速（着地）を「台パン」として検出する。
///
/// アルゴリズム（research.md §2、design.md `HandSwingDetector`）:
/// - 画面座標は左上原点なので **下方向の移動は y の増加**。`vy = Δy/Δt` を実測 Δt で求める（固定値禁止）。
/// - EMA で平滑化し、下降中の `vy` の最大を「ピーク」として保持する。
/// - ピークがしきい値を超えた後に **急減速（ピークの一定割合以下へ低下）または反転（vy<=0）** したら台パン成立。
/// - 成立後はクールダウン窓内の再成立を抑制する。
/// - サンプル間隔が `maxSampleGap` を超えたら手検出が途切れたとみなし、進行中の下降状態をリセットする
///   （＝手未検出では成立しない。要件 4.6）。
///
/// 時刻はすべて `HandSample.timestamp`（実測）から取り、ウォールクロックを使わないため**完全に決定論的**で、
/// 合成サンプル列による単体検証が可能。
///
/// 設計対応: 要件 3.3, 4.1, 4.2, 4.5, 4.6。
public final class HandSwingDetector: HandSwingDetecting {

    public var punches: AnyPublisher<TablePunchEvent, Never> {
        punchSubject.eraseToAnyPublisher()
    }

    private let punchSubject = PassthroughSubject<TablePunchEvent, Never>()
    private let config: SwingConfig
    private var cancellable: AnyCancellable?

    // 検出状態
    private var lastSample: HandSample?
    private var smoothedVy: CGFloat = 0
    private var peakVy: CGFloat = 0
    private var lastPunchTime: TimeInterval?

    /// - Parameters:
    ///   - provider: 手サンプルの供給元（Vision 実装 / モック）。
    ///   - config: 速度/台パン判定パラメータ。
    public init(provider: HandLandmarkProvider, config: SwingConfig) {
        self.config = config
        self.cancellable = provider.samples.sink { [weak self] sample in
            self?.ingest(sample)
        }
    }

    /// テスト用に provider を介さず1サンプルずつ与えるための入口。
    public func ingest(_ sample: HandSample) {
        defer { lastSample = sample }

        guard let previous = lastSample else {
            // 最初のサンプルは基準点として保持するだけ。
            return
        }

        let dt = sample.timestamp - previous.timestamp
        guard dt > 0 else { return }  // 時刻逆行/重複は無視

        // 手検出が途切れた（大きな間隔）→ 進行中の下降状態をリセットして誤発火を防ぐ。
        if dt > config.maxSampleGap {
            resetSwing()
            return
        }

        // 下方向を正とした瞬間速度 → EMA 平滑化。
        let instantVy = (sample.screenPoint.y - previous.screenPoint.y) / CGFloat(dt)
        let alpha = config.velocityEMAAlpha
        smoothedVy = alpha * instantVy + (1 - alpha) * smoothedVy

        if smoothedVy > 0 {
            // 下降中: ピークを更新。
            if smoothedVy > peakVy {
                peakVy = smoothedVy
            }
        }

        // 着地判定: ピークがしきい値超過 かつ 急減速（ピークの一定割合以下）または反転。
        let decel = peakVy * config.landingDecelerationFraction
        let landed = peakVy >= config.swingVelocityThreshold && (smoothedVy <= decel || smoothedVy <= 0)

        if landed {
            if canFire(at: sample.timestamp) {
                punchSubject.send(
                    TablePunchEvent(peakVelocity: peakVy, screenPoint: sample.screenPoint)
                )
                lastPunchTime = sample.timestamp
            }
            // 着地したら次の振り下ろしへ向けて下降状態をリセット（クールダウン外でも再ピークが必要）。
            resetSwing()
        }
    }

    private func canFire(at time: TimeInterval) -> Bool {
        guard let last = lastPunchTime else { return true }
        return (time - last) >= config.punchCooldown
    }

    private func resetSwing() {
        peakVy = 0
        smoothedVy = 0
    }
}
