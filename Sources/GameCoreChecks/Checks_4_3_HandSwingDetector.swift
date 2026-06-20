import Combine
import CoreGraphics
import Foundation
import GameCore

private struct TestSwingConfig: SwingConfig {
    var swingVelocityThreshold: CGFloat = 1.5
    var punchCooldown: TimeInterval = 0.3
    var velocityEMAAlpha: CGFloat = 0.7
    var landingDecelerationFraction: CGFloat = 0.5
    var maxSampleGap: TimeInterval = 0.1
}

/// 指定した y 座標列を等間隔サンプルとして detector に流し、発火した台パンイベントを返す。
private func feed(
    yPositions: [CGFloat],
    config: TestSwingConfig,
    interval: TimeInterval = 1.0 / 60.0,
    x: CGFloat = 0.5
) -> [TablePunchEvent] {
    let provider = MockHandLandmarkProvider()
    let detector = HandSwingDetector(provider: provider, config: config)
    var punches: [TablePunchEvent] = []
    let c = detector.punches.sink { punches.append($0) }
    provider.emitSeries(yPositions: yPositions, x: x, startTime: 0, interval: interval)
    c.cancel()
    return punches
}

/// 下降→停止の1スイングを表す y 列を作る。
private func swing(descentFrames: Int, step: CGFloat, startY: CGFloat, stopFrames: Int) -> [CGFloat] {
    var ys: [CGFloat] = [startY]
    var y = startY
    for _ in 0..<descentFrames { y += step; ys.append(y) }
    for _ in 0..<stopFrames { ys.append(y) }  // 停止＝同じ y
    return ys
}

/// issue #21 (tasks 4.3): 振り下ろし速度算出と台パン成立判定。
func runChecks_4_3() {
    section("#21 (4.3) HandSwingDetector 台パン成立判定")
    let config = TestSwingConfig()

    // 1) しきい値超の振り下ろし→急減速で 1 回だけ成立
    do {
        // step 0.05 / dt(1/60) = 3.0/s のピーク（しきい値1.5超）
        let ys = swing(descentFrames: 10, step: 0.05, startY: 0.2, stopFrames: 5)
        let punches = feed(yPositions: ys, config: config)
        check(punches.count == 1, "強い振り下ろし→急減速でちょうど1回成立する (got \(punches.count))")
        if let p = punches.first {
            check(p.peakVelocity > config.swingVelocityThreshold, "ピーク速度がしきい値を超えている (\(p.peakVelocity))")
            check(p.peakVelocity > 2.5 && p.peakVelocity < 3.1, "ピーク速度が約3.0/sに収まる (\(p.peakVelocity))")
        }
    }

    // 2) しきい値未満の弱い振り下ろしは成立しない
    do {
        // step 0.02 / dt = 1.2/s < しきい値1.5
        let ys = swing(descentFrames: 12, step: 0.02, startY: 0.2, stopFrames: 5)
        let punches = feed(yPositions: ys, config: config)
        check(punches.isEmpty, "弱い振り下ろし（しきい値未満）は成立しない (got \(punches.count))")
    }

    // 3) クールダウン: 連続した2スイングは1回に抑制される
    do {
        // 1スイング = 下降10 + 停止2 フレーム ≈ 12フレーム × (1/60) ≈ 0.2s < cooldown 0.3s
        let s1 = swing(descentFrames: 10, step: 0.05, startY: 0.05, stopFrames: 2)
        let s2 = swing(descentFrames: 10, step: 0.05, startY: 0.05, stopFrames: 5)
        let punches = feed(yPositions: s1 + s2, config: config)
        check(punches.count == 1, "クールダウン窓内の2スイングは1回だけ成立する (got \(punches.count))")
    }

    // 4) クールダウンを越えれば2回成立する
    do {
        let s1 = swing(descentFrames: 10, step: 0.05, startY: 0.05, stopFrames: 2)
        // 30フレーム停止 ≈ 0.5s > cooldown 0.3s を挟む
        let gapStill = Array(repeating: CGFloat(0.55), count: 30)
        let s2 = swing(descentFrames: 10, step: 0.05, startY: 0.05, stopFrames: 5)
        let punches = feed(yPositions: s1 + gapStill + s2, config: config)
        check(punches.count == 2, "クールダウンを越えた2スイングは2回成立する (got \(punches.count))")
    }

    // 5) 手検出が途切れる（サンプル間隔がmaxSampleGap超）と進行中スイングはリセットされ成立しない
    do {
        let provider = MockHandLandmarkProvider()
        let detector = HandSwingDetector(provider: provider, config: config)
        var punches: [TablePunchEvent] = []
        let c = detector.punches.sink { punches.append($0) }
        // 下降を作りピークを育てる（まだ着地していない）
        var t = 0.0
        let dt = 1.0 / 60.0
        var y: CGFloat = 0.2
        for _ in 0..<8 {
            provider.emit(HandSample(screenPoint: CGPoint(x: 0.5, y: y), timestamp: t, confidence: 0.9))
            y += 0.05; t += dt
        }
        // 手ロスト相当の大きな間隔（0.2s > maxSampleGap 0.1s）の後に停止サンプル
        t += 0.2
        provider.emit(HandSample(screenPoint: CGPoint(x: 0.5, y: y), timestamp: t, confidence: 0.9))
        t += dt
        provider.emit(HandSample(screenPoint: CGPoint(x: 0.5, y: y), timestamp: t, confidence: 0.9))
        c.cancel()
        check(punches.isEmpty, "手検出ロスト（大きな間隔）で進行中スイングはリセットされ成立しない (got \(punches.count))")
    }

    // 6) 着地時の代表点が screenPoint に入る
    do {
        let landingX: CGFloat = 0.73
        let ys = swing(descentFrames: 10, step: 0.05, startY: 0.2, stopFrames: 5)
        let punches = feed(yPositions: ys, config: config, x: landingX)
        if let p = punches.first {
            checkClose(Double(p.screenPoint.x), Double(landingX), accuracy: 1e-9, "着地時の代表点xが screenPoint に入る")
        } else {
            check(false, "（前提）punchが1件ある")
        }
    }
}
