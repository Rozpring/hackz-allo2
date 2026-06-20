import SwiftUI

@main
struct TableBangApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// 画面遷移の起点（権限 → 配置 → プレイ → 結果, R8-1/R8-4）。
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
        case .placing:
            placingView
        case .playing:
            playingView
        case .result:
            resultView
        }
    }

    // MARK: - 配置

    private var placingView: some View {
        ZStack(alignment: .bottom) {
            ARViewContainer(controller: engine.scene)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                Text("テーブルにカメラを向けて、盤面を配置してください")
                    .font(.subheadline)
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                Button("盤面を配置して開始") { engine.placeBoardAndStart() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - プレイ（HUD #27）

    private var playingView: some View {
        ZStack {
            ARViewContainer(controller: engine.scene)
                .ignoresSafeArea()
            HUDView(
                game: engine.gameState,
                isHandDetected: engine.isHandDetected,
                maxPower: engine.config.maxPower
            )
        }
    }

    // MARK: - 結果（#28）

    private var resultView: some View {
        ResultView(
            game: engine.gameState,
            elapsedSeconds: engine.elapsedSeconds,
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
