import SwiftUI

/// ゲーム終了時の結果画面（要件 8.2, 8.3, 8.4）。
/// - クリア（`.clear`）: 経過時間とスコアを表示。
/// - タイムアップ（`.timeUp`）: 残ペア数とスコアを表示。
/// いずれもリトライ（再プレイ）導線を提供する。
struct ResultView: View {
    @ObservedObject private var game: GameStateManager

    /// クリア時に表示する経過秒数（= 制限時間 − 残り時間。結線層が算出して渡す）。
    private let elapsedSeconds: Int
    /// リトライ操作。結線層が初期状態へ戻す。
    private let onRetry: () -> Void

    init(game: GameStateManager, elapsedSeconds: Int, onRetry: @escaping () -> Void) {
        self.game = game
        self.elapsedSeconds = elapsedSeconds
        self.onRetry = onRetry
    }

    var body: some View {
        VStack(spacing: 24) {
            Text(title)
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            VStack(spacing: 12) {
                ForEach(rows, id: \.label) { row in
                    HStack {
                        Text(row.label).foregroundStyle(.white.opacity(0.8))
                        Spacer()
                        Text(row.value).font(.title3.monospacedDigit().bold()).foregroundStyle(.white)
                    }
                }
            }
            .padding()
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: 320)

            Button(action: onRetry) {
                Text("もう一度あそぶ")
                    .font(.headline.bold())
                    .frame(maxWidth: 280)
                    .padding(.vertical, 14)
                    .background(.orange, in: Capsule())
                    .foregroundStyle(.black)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.6))
    }

    private var isClear: Bool { game.phase == .clear }
    private var title: String { isClear ? "クリア！" : "タイムアップ" }

    private struct Row { let label: String; let value: String }

    private var rows: [Row] {
        if isClear {
            return [
                Row(label: "スコア", value: "\(game.score)"),
                Row(label: "経過時間", value: timeString(elapsedSeconds)),
            ]
        } else {
            return [
                Row(label: "スコア", value: "\(game.score)"),
                Row(label: "残りペア", value: "\(game.remainingPairs)"),
            ]
        }
    }

    private func timeString(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%01d:%02d", s / 60, s % 60)
    }
}
