/// ペア判定に必要なカードの最小契約。
///
/// `MatchEvaluator` を RealityKit の `CardEntity`（issue #16, kyiku）から切り離すための抽象。
/// 本番では `CardEntity` がこの protocol に適合し、テストでは軽量な値型が適合する。
///
/// 設計対応: design.md `Card` / `MatchEvaluator`。要件 6.1（ランク一致のみ・スート無視）。
public protocol MatchableCard: Identifiable {
    /// 数字（ランク）。同一ランク2枚でペア成立。スートは判定に用いない。
    var rank: Int { get }
    /// 現在表向きか。物理静止後の確定状態。
    var isFaceUp: Bool { get }
}
