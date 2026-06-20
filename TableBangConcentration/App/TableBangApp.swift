import SwiftUI

@main
struct TableBangApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// 画面遷移の起点（権限 → タイトル → 配置 → プレイ → 結果, R8-1/R8-4）。
/// `GameEngine` のフェーズと `CameraPermission` の状態を `AppCoordinator` で集約して表示画面を切り替える。
struct RootView: View {
    @StateObject private var engine = GameEngine()
    @StateObject private var coordinator = AppCoordinator()
    private let permission = CameraPermission()

    var body: some View {
        content
            .onAppear { syncPermission() }
            .onReceive(engine.$phase) { coordinator.updatePhase($0) }
    }

    @ViewBuilder
    private var content: some View {
        switch coordinator.screen {
        case .permission:
            PermissionView(state: coordinator.permission) { requestPermission() }
        case .title:
            titleView
        case .placing:
            placingView
        case .playing:
            playingView
        case .result:
            resultView
        }
    }

    // MARK: - タイトル（スタート, #56）

    private var titleView: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("台パン神経衰弱")
                .font(.largeTitle.bold())
            Text("AR Table-Bang Concentration")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: { coordinator.markStarted() }) {
                Text("スタート")
                    .font(.title3.bold())
                    .frame(maxWidth: 240)
                    .padding(.vertical, 14)
                    .background(.orange, in: Capsule())
                    .foregroundStyle(.black)
            }
            Spacer()
        }
        .padding(32)
    }

    // MARK: - 配置（平面タップで盤面を置く, #55）

    private var placingView: some View {
        ZStack(alignment: .bottom) {
            ARViewContainer(controller: engine.scene, onTap: { point in
                engine.placeBoard(atScreenPoint: point)
            })
            .ignoresSafeArea()
            VStack(spacing: 12) {
                Text(engine.isPlaneReady
                     ? "平面をタップして盤面を配置してください"
                     : "テーブルにカメラを向けてください")
                    .font(.subheadline)
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                #if targetEnvironment(simulator)
                Button("（シミュレータ）中央に配置して開始") { engine.placeBoardForSimulator() }
                    .buttonStyle(.borderedProminent)
                #endif
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - プレイ（HUD #27 ＋ 中断リスタート #56）

    private var playingView: some View {
        ZStack(alignment: .topTrailing) {
            ARViewContainer(controller: engine.scene)
                .ignoresSafeArea()
            HUDView(
                game: engine.gameState,
                isHandDetected: engine.isHandDetected,
                maxPower: engine.config.maxPower
            )
            Button(action: { engine.retry() }) {
                Label("やり直す", systemImage: "arrow.clockwise")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.black.opacity(0.4), in: Capsule())
                    .foregroundStyle(.white)
            }
            .padding(.top, 60)
            .padding(.trailing, 16)
        }
    }

    // MARK: - 結果（#28）

    private var resultView: some View {
        ResultView(
            game: engine.gameState,
            onRetry: { engine.retry() }
        )
    }

    // MARK: - 権限

    private func syncPermission() {
        coordinator.updatePermission(permission.currentState)
        if permission.currentState == .notDetermined {
            requestPermission()
        }
    }

    private func requestPermission() {
        permission.request { state in
            coordinator.updatePermission(state)
        }
    }
}
