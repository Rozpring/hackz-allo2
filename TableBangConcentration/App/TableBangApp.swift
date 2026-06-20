import SwiftUI

@main
struct TableBangApp: App {
    @StateObject private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(coordinator)
        }
    }
}

/// ルート。現状は土台のプレースホルダ。AR/プレイ画面は後続タスク（#2 以降）で接続する。
struct RootView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        VStack(spacing: 12) {
            Text("台パン神経衰弱")
                .font(.largeTitle.bold())
            Text("AR Table-Bang Concentration")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("現在の画面: \(String(describing: coordinator.screen))")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }
}
