import CoreGraphics
import Foundation
import GameCore

private struct TestPowerConfig: PowerConfig {
    var minPower: Float = 0.2
    var maxPower: Float = 1.0
    var velocityForMinPower: CGFloat = 1.0
    var velocityForMaxPower: CGFloat = 5.0
}

/// issue #22 (tasks 4.4): ピーク速度→威力の正規化。
func runChecks_4_4() {
    section("#22 (4.4) PowerCalculator 威力正規化")
    let config = TestPowerConfig()
    let calc = PowerCalculator(config: config)

    // 範囲外クランプ
    check(calc.power(from: 0.0) == config.minPower, "velMin未満は minPower にクランプ")
    check(calc.power(from: 0.5) == config.minPower, "velMin境界未満は minPower")
    check(calc.power(from: 10.0) == config.maxPower, "velMax超は maxPower にクランプ")

    // 端点
    check(calc.power(from: config.velocityForMinPower) == config.minPower, "velMinちょうどで minPower")
    check(calc.power(from: config.velocityForMaxPower) == config.maxPower, "velMaxちょうどで maxPower")

    // 中点（線形補間）: 速度3.0は[1,5]の中点 → 威力は[0.2,1.0]の中点0.6
    checkClose(Double(calc.power(from: 3.0)), 0.6, accuracy: 1e-6, "中点速度で威力が中点値")

    // 単調増加
    var previous = calc.power(from: 0.0)
    var monotonic = true
    var v: CGFloat = 0.0
    while v <= 6.0 {
        let p = calc.power(from: v)
        if p < previous - 1e-6 { monotonic = false }
        previous = p
        v += 0.25
    }
    check(monotonic, "速度増加に対し威力が単調増加する")

    // 常に範囲内
    var inRange = true
    v = -2.0
    while v <= 8.0 {
        let p = calc.power(from: v)
        if p < config.minPower - 1e-6 || p > config.maxPower + 1e-6 { inRange = false }
        v += 0.3
    }
    check(inRange, "任意の速度で威力が [minPower, maxPower] に収まる")

    // 不正設定（vMax<=vMin）でも破綻しない
    struct BadConfig: PowerConfig {
        var minPower: Float = 0.1; var maxPower: Float = 0.9
        var velocityForMinPower: CGFloat = 5.0; var velocityForMaxPower: CGFloat = 5.0
    }
    let badCalc = PowerCalculator(config: BadConfig())
    check(badCalc.power(from: 3.0) == 0.1, "vMax<=vMin の不正設定でも minPower を返し破綻しない")
}
