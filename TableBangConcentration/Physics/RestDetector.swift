import Foundation

/// 速度しきい値による静止検出の状態機械（純ロジック）。
/// 線形/角速度がともにしきい値以下のフレームが連続 `settleFrameCount` 回で「静止」と確定する（R5-6）。
/// 確定は1回のみ発火し、動きを検知するか `reset()` で再武装する。
final class RestDetector {
    private let config: GameConfig
    private var quietFrames = 0
    private var hasSettled = false

    init(config: GameConfig) {
        self.config = config
    }

    /// 1フレーム分の可動カード最大速度を投入。静止確定の瞬間のみ true を返す。
    func update(maxLinearSpeed: Float, maxAngularSpeed: Float) -> Bool {
        let isQuiet = maxLinearSpeed <= config.settleLinearThreshold
            && maxAngularSpeed <= config.settleAngularThreshold

        guard isQuiet else {
            quietFrames = 0
            hasSettled = false
            return false
        }
        guard !hasSettled else { return false }

        quietFrames += 1
        if quietFrames >= config.settleFrameCount {
            hasSettled = true
            return true
        }
        return false
    }

    /// 台パンで動き出した直後などに静止監視を再武装する。
    func reset() {
        quietFrames = 0
        hasSettled = false
    }
}
