import Foundation
import Combine

/// ゲーム進行フェーズ。
enum GamePhase: Equatable {
    case placing
    case playing
    case clear
    case timeUp
}

/// スコア・コンボ・残ペア・制限時間・勝敗の単一情報源（R6-3, R6-4, R6-6, R8-1〜R8-4, R9-1, R9-3）。
final class GameStateManager: ObservableObject {
    @Published private(set) var score: Int = 0
    @Published private(set) var combo: Int = 0
    @Published private(set) var remainingSeconds: Int
    @Published private(set) var remainingPairs: Int = 0
    @Published private(set) var lastPower: Float = 0
    @Published private(set) var phase: GamePhase = .placing

    private let config: GameConfig

    init(config: GameConfig) {
        self.config = config
        self.remainingSeconds = config.timeLimitSeconds
    }

    /// 盤面配置完了 → プレイ開始（タイマ開始, R8-1）。`totalPairs` は結果画面の残ペア表示に使う。
    func startPlaying(totalPairs: Int) {
        phase = .playing
        remainingSeconds = config.timeLimitSeconds
        remainingPairs = totalPairs
        score = 0
        combo = 0
    }

    /// 直近の台パン威力を記録（HUD表示用, R9-3）。
    func recordPower(_ power: Float) {
        lastPower = power
    }

    /// 盤面静止で成立したペア数を反映する。複数同時成立はコンボ倍率を上げる（R6-3, R6-4）。
    /// プレイ中のみ処理する（タイムアップ/クリア後の不正加算・不正遷移を防ぐ）。
    func onPairsMatched(_ pairCount: Int, remainingPairs newRemainingPairs: Int) {
        guard phase == .playing else { return }
        remainingPairs = newRemainingPairs
        guard pairCount > 0 else {
            combo = 0
            return
        }
        combo = pairCount
        let multiplier = 1 + Float(pairCount - 1) * config.comboMultiplierStep
        score += Int(Float(pairCount * config.scorePerPair) * multiplier)

        if newRemainingPairs == 0 {
            phase = .clear
        }
    }

    /// 1秒経過。残り0で時間切れ（R8-3）。クリア済みは上書きしない。
    func tick() {
        guard phase == .playing else { return }
        remainingSeconds = max(0, remainingSeconds - 1)
        if remainingSeconds == 0 {
            phase = .timeUp
        }
    }

    /// 初期状態へ戻す（リトライ, R8-4）。
    func retry() {
        score = 0
        combo = 0
        lastPower = 0
        remainingPairs = 0
        remainingSeconds = config.timeLimitSeconds
        phase = .placing
    }
}
