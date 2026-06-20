import Foundation
import CoreGraphics
import Combine

/// 手の代表点時系列から下方向ピーク速度を求め、振り下ろし→急減速（着地）を台パンとして検出する。
/// 画面座標は左上原点のため、下方向は y の増加（正）。
///
/// テスト容易性のため、判定本体は純粋な `process(_:)` 状態機械として実装し、
/// 成立時には戻り値とともに `punches` パブリッシャへも流す。
final class HandSwingDetector {
    private let config: GameConfig
    private let subject = PassthroughSubject<TablePunchEvent, Never>()
    var punches: AnyPublisher<TablePunchEvent, Never> { subject.eraseToAnyPublisher() }

    private var lastSample: HandSample?
    private var emaVelocity: CGFloat = 0
    private var peakVelocity: CGFloat = 0
    private var isSwinging = false
    private var lastPunchTime: TimeInterval = -.greatestFiniteMagnitude

    // 反応性を上げるため現在値重めの平滑化。
    private let emaAlpha: CGFloat = 0.6

    init(config: GameConfig) {
        self.config = config
    }

    /// 1サンプルを処理。台パン成立時は `TablePunchEvent` を返し、`punches` にも発行する。
    @discardableResult
    func process(_ sample: HandSample) -> TablePunchEvent? {
        guard let prev = lastSample else {
            lastSample = sample
            return nil
        }
        let dt = sample.timestamp - prev.timestamp
        guard dt > 0 else {
            lastSample = sample
            return nil
        }

        // 検出が途切れた（大きな dt）= 叩いた瞬間に手がブレて見失ったケース。
        // スイング中ならそこを着地とみなして成立させ、状態をリセットして再開する（反応漏れの主因対策）。
        if dt > config.maxSampleGap {
            let event = isSwinging ? finalizePunch(at: prev) : nil
            resetSwing()
            lastSample = sample
            return event
        }

        // 下方向の実寸速度（m/s）。LiDAR深度で正規化移動量を実寸に換算（高さ/距離に正確）。
        // 深度が取れないフレームは想定距離でフォールバック。下向き = y増加 = 正。
        let depth = sample.depth ?? prev.depth ?? config.nominalHandDepth
        let normalizedDeltaY = sample.screenPoint.y - prev.screenPoint.y
        let vyRaw = SwingMetrics.metricVerticalSpeed(
            normalizedDeltaY: normalizedDeltaY,
            dt: dt,
            depth: depth,
            depthToMetersFactor: config.depthToMetersFactor
        )
        emaVelocity = emaAlpha * vyRaw + (1 - emaAlpha) * emaVelocity
        let vy = emaVelocity
        lastSample = sample

        if vy > config.swingVelocityThreshold {
            isSwinging = true
            peakVelocity = max(peakVelocity, vy)
            return nil
        }

        // 振り下ろし後の急減速（しきい値の半分以下）→ 着地とみなす。
        if isSwinging, vy < config.swingVelocityThreshold * 0.5 {
            let event = finalizePunch(at: sample)
            resetSwing()
            return event
        }
        return nil
    }

    /// 手がロストしたときに呼ぶ。スイング状態をリセットし誤検出を防ぐ（R3-4, R4-6）。
    func handLost() {
        resetSwing()
        emaVelocity = 0
        lastSample = nil
    }

    private func resetSwing() {
        isSwinging = false
        peakVelocity = 0
    }

    private func finalizePunch(at sample: HandSample?) -> TablePunchEvent? {
        guard let sample else { return nil }
        guard peakVelocity >= config.swingVelocityThreshold else { return nil }
        guard sample.timestamp - lastPunchTime >= config.punchCooldown else { return nil }
        lastPunchTime = sample.timestamp
        let event = TablePunchEvent(peakVelocity: peakVelocity, screenPoint: sample.screenPoint)
        subject.send(event)
        return event
    }
}
