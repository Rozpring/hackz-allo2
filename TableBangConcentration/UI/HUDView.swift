import SwiftUI

/// プレイ中の HUD。残り時間・スコア・直近の威力ゲージ・コンボ・手未検出ガイドを表示する。
/// AR 盤面の視認を妨げないよう、情報は上下端に寄せ中央は空ける（要件 9.1〜9.5）。
struct HUDView: View {
    @ObservedObject private var game: GameStateManager

    /// 手が検出できているか（未検出なら補助ガイドを出す, 要件 9.4）。
    private let isHandDetected: Bool
    /// 威力ゲージの正規化に使う最大威力（lastPower をこの値で割って 0..1 にする）。
    private let maxPower: Float

    init(game: GameStateManager, isHandDetected: Bool, maxPower: Float) {
        self.game = game
        self.isHandDetected = isHandDetected
        self.maxPower = maxPower
    }

    var body: some View {
        VStack {
            topBar
            Spacer()
            if game.combo >= 2 {
                comboBadge
            }
            if !isHandDetected {
                handGuide
            }
            powerGauge
        }
        .padding()
        .allowsHitTesting(false) // HUD はタップを奪わない（盤面操作を妨げない）
    }

    private var topBar: some View {
        HStack {
            label(systemImage: "arrow.triangle.2.circlepath", text: "\(game.turns) ターン")
            Spacer()
            label(systemImage: "star.fill", text: "\(game.score)")
        }
    }

    private var comboBadge: some View {
        Text("COMBO ×\(game.combo)")
            .font(.headline.bold())
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.yellow.opacity(0.85), in: Capsule())
            .foregroundStyle(.black)
            .transition(.scale)
    }

    private var handGuide: some View {
        Text("手をカメラに写してください")
            .font(.subheadline.bold())
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.red.opacity(0.8), in: Capsule())
            .foregroundStyle(.white)
    }

    private var powerGauge: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("威力")
                .font(.caption).foregroundStyle(.white)
            ProgressView(value: Double(normalizedPower))
                .progressViewStyle(.linear)
                .tint(.orange)
        }
        .padding(10)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }

    private var normalizedPower: Float {
        guard maxPower > 0 else { return 0 }
        return min(max(game.lastPower / maxPower, 0), 1)
    }

    private func label(systemImage: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(text).font(.title3.monospacedDigit().bold())
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.black.opacity(0.35), in: Capsule())
        .foregroundStyle(.white)
    }
}
