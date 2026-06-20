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

    private let emaAlpha: CGFloat = 0.5

    init(config: GameConfig) {
        self.config = config
    }

    /// 1サンプルを処理。台パン成立時は `TablePunchEvent` を返し、`punches` にも発行する。
    @discardableResult
    func process(_ sample: HandSample) -> TablePunchEvent? {
        defer { lastSample = sample }
        guard let prev = lastSample else { return nil }
        let dt = sample.timestamp - prev.timestamp
        guard dt > 0 else { return nil }

        // 下方向速度（実測Δt）。下向き = y増加 = 正。
        let vyRaw = (sample.screenPoint.y - prev.screenPoint.y) / CGFloat(dt)
        emaVelocity = emaAlpha * vyRaw + (1 - emaAlpha) * emaVelocity
        let vy = emaVelocity

        if vy > config.swingVelocityThreshold {
            isSwinging = true
            peakVelocity = max(peakVelocity, vy)
            return nil
        }

        // 振り下ろし後の急減速（しきい値の半分以下）→ 着地とみなす。
        if isSwinging, vy < config.swingVelocityThreshold * 0.5 {
            let event = finalizePunch(at: sample)
            isSwinging = false
            peakVelocity = 0
            return event
        }
        return nil
    }

    /// 手がロストしたときに呼ぶ。スイング状態をリセットし誤検出を防ぐ（R3-4, R4-6）。
    func handLost() {
        isSwinging = false
        peakVelocity = 0
        emaVelocity = 0
        lastSample = nil
    }

    private func finalizePunch(at sample: HandSample) -> TablePunchEvent? {
        guard peakVelocity >= config.swingVelocityThreshold else { return nil }
        guard sample.timestamp - lastPunchTime >= config.punchCooldown else { return nil }
        lastPunchTime = sample.timestamp
        let event = TablePunchEvent(peakVelocity: peakVelocity, screenPoint: sample.screenPoint)
        subject.send(event)
        return event
    }
}
