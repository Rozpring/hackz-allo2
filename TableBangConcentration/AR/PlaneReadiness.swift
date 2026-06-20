import Foundation

/// 検出平面が盤面配置に十分な広さかを判定する純ロジック（R1-5）。
enum PlaneReadiness {
    /// 幅・奥行がともに最小辺長以上なら配置可能とみなす。
    static func isPlaceable(planeWidth: Float, planeDepth: Float, minSide: Float) -> Bool {
        planeWidth >= minSide && planeDepth >= minSide
    }
}

/// 平面配置に向けてユーザーへ提示するガイダンス（R1-4, R1-5, R10-3）。
enum PlacementGuidance: Equatable {
    case searchingPlane   // 平面未検出 → 「テーブルにカメラを向けてください」
    case readyToPlace     // 十分な広さの平面検出 → 配置可能
    case trackingLimited  // トラッキング品質低下 → ガイド

    /// トラッキング品質低下を最優先し、次に平面検出状況でガイダンスを決める。
    static func evaluate(planeReady: Bool, trackingLimited: Bool) -> PlacementGuidance {
        if trackingLimited { return .trackingLimited }
        return planeReady ? .readyToPlace : .searchingPlane
    }
}
