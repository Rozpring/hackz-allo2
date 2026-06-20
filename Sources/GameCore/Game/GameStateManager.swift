import Combine
import Foundation

/// ゲーム進行のフェーズ。
public enum GamePhase: Equatable, Sendable {
    case placing   // 盤面配置前/配置中
    case playing   // プレイ中（タイマ稼働）
    case clear     // 全ペアクリア
    case timeUp    // 制限時間切れ
}

/// スコア・コンボ・残ペア・制限時間・勝敗の単一情報源（single source of truth）。
///
/// HUD / 結果画面は `@Published` を購読して更新する。
///
/// ## 時間の扱い（テスト可能性）
/// 実時間タイマは持たず、`tickSecond()` を外部（iOS 側の `Timer`）から1秒ごとに呼ぶ設計。
/// これにより本ロジックはウォールクロックに依存せず**決定論的に単体検証**できる。
///
/// ## コンボの意味（design のあいまい点をここで確定）
/// design.md は「1回の確定で複数ペアならコンボ倍率を上げる」とだけ述べ、コンボの寿命が未定義だった。
/// 本実装では次のルールに確定する:
/// - `combo` = **連続して得点した確定回数**（≥1ペアの確定が続くほど増える。0ペアの確定でリセット）。
/// - 1回の確定で k ペア成立したときの加点 = `basePairScore * k * (1 + comboStep * (combo - 1))`。
///   → 同時複数ペア（k）と連続得点（combo）の両方を報酬にする。
///
/// 設計対応: design.md `GameStateManager`。要件 6.3, 6.4, 6.6, 8.1, 8.2, 8.3, 9.1, 9.3。
public final class GameStateManager: ObservableObject {
    @Published public private(set) var score: Int = 0
    @Published public private(set) var combo: Int = 0
    @Published public private(set) var remainingSeconds: Int = 0
    @Published public private(set) var remainingPairs: Int = 0
    @Published public private(set) var lastPower: Float = 0
    @Published public private(set) var phase: GamePhase = .placing

    private let config: ScoringConfig
    private let evaluator: MatchEvaluator

    public init(config: ScoringConfig, evaluator: MatchEvaluator = MatchEvaluator()) {
        self.config = config
        self.evaluator = evaluator
    }

    /// 盤面配置完了 → プレイ開始（タイマカウント開始）。要件 8.1。
    public func startGame() {
        score = 0
        combo = 0
        lastPower = 0
        remainingPairs = config.pairCount
        remainingSeconds = config.timeLimitSeconds
        phase = .playing
    }

    /// 台パン成立時に直近威力を記録（HUD の威力ゲージ用）。要件 9.2。
    public func recordPunch(power: Float) {
        lastPower = power
    }

    /// 盤面静止通知を受けて、表カードのペアを判定・回収・加点する。
    /// 回収すべきカードの組を返す（実際のシーン除去は呼び出し側＝AR/結線層が行う）。要件 6.2〜6.4, 7.4。
    ///
    /// - Returns: 成立して回収すべきペアの配列（各組2枚）。プレイ中以外・0成立なら空。
    @discardableResult
    public func onBoardSettled<C: MatchableCard>(faceUpCards: [C]) -> [[C]] {
        guard phase == .playing else { return [] }

        let pairs = evaluator.findPairs(in: faceUpCards)
        let k = pairs.count

        guard k > 0 else {
            combo = 0  // 得点しなかった確定でコンボ途切れ
            return []
        }

        combo += 1
        let multiplier = 1 + config.comboMultiplierStep * Float(combo - 1)
        let gained = Int((Float(config.basePairScore * k) * multiplier).rounded())
        score += gained

        remainingPairs = max(0, remainingPairs - k)
        if remainingPairs == 0 {
            phase = .clear
        }
        return pairs
    }

    /// 1秒経過。iOS 側の `Timer` から毎秒呼ぶ。要件 8.3。
    public func tickSecond() {
        guard phase == .playing else { return }
        remainingSeconds -= 1
        if remainingSeconds <= 0 {
            remainingSeconds = 0
            phase = .timeUp
        }
    }

    /// リトライ（再プレイ）。初期状態（配置前）へ戻す。要件 8.4。
    public func retry() {
        score = 0
        combo = 0
        lastPower = 0
        remainingPairs = 0
        remainingSeconds = 0
        phase = .placing
    }
}
