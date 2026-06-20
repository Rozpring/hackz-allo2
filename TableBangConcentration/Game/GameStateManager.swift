import Foundation
import Combine

/// ゲーム進行フェーズ。ターン制のためゲームオーバー（タイムアップ）は無い。
enum GamePhase: Equatable {
    case placing
    case playing
    case clear
}

/// スコア・コンボ・残ペア・ターン数・勝敗の単一情報源（R6-3, R6-4, R6-6, R8-1, R8-4, R9-1, R9-3）。
/// ターン制: 1ターン＝台パン1回。全ペア回収でクリア。時間制限・ゲームオーバーは無い。
final class GameStateManager: ObservableObject {
    @Published private(set) var score: Int = 0
    @Published private(set) var combo: Int = 0
    @Published private(set) var turns: Int = 0
    @Published private(set) var remainingPairs: Int = 0
    @Published private(set) var lastPower: Float = 0
    @Published private(set) var phase: GamePhase = .placing

    private let config: GameConfig

    init(config: GameConfig) {
        self.config = config
    }

    /// 盤面配置完了 → プレイ開始（R8-1）。`totalPairs` は残ペア表示・クリア判定に使う。
    func startPlaying(totalPairs: Int) {
        phase = .playing
        turns = 0
        remainingPairs = totalPairs
        score = 0
        combo = 0
    }

    /// 直近の台パン威力を記録（HUD表示用, R9-3）。
    func recordPower(_ power: Float) {
        lastPower = power
    }

    /// 1ターン（台パン1回）を加算する。プレイ中のみ。
    func incrementTurn() {
        guard phase == .playing else { return }
        turns += 1
    }

    /// 盤面静止で成立したペア数を反映する。複数同時成立はコンボ倍率を上げる（R6-3, R6-4）。
    /// プレイ中のみ処理する（クリア後の不正加算を防ぐ）。
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

    /// 初期状態へ戻す（リトライ, R8-4）。
    func retry() {
        score = 0
        combo = 0
        turns = 0
        lastPower = 0
        remainingPairs = 0
        phase = .placing
    }
}
