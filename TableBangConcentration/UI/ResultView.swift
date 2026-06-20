import SwiftUI

/// クリア結果画面（ターン制, R8-4）。全ペア回収で「Nターンでクリア！」とスコアを表示し、再プレイ導線を出す。
struct ResultView: View {
    @ObservedObject private var game: GameStateManager

    /// リトライ操作。結線層が初期状態へ戻す。
    private let onRetry: () -> Void

    init(game: GameStateManager, onRetry: @escaping () -> Void) {
        self.game = game
        self.onRetry = onRetry
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("クリア！")
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

    private struct Row { let label: String; let value: String }

    private var rows: [Row] {
        [
            Row(label: "ターン数", value: "\(game.turns)"),
            Row(label: "スコア", value: "\(game.score)"),
        ]
    }
}
