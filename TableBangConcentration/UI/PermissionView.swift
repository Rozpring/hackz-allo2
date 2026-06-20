import SwiftUI
import UIKit

/// カメラ権限の要求と、拒否時の設定アプリ導線を提示する（R1-1, R1-2）。
struct PermissionView: View {
    let state: CameraPermissionState
    let onRequest: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            switch state {
            case .notDetermined:
                Text("カメラの使用を許可してください")
                    .font(.headline)
                Text("AR盤面の表示と手の動きの検出にカメラを使用します。映像は端末内のみで処理されます。")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("カメラを許可", action: onRequest)
                    .buttonStyle(.borderedProminent)

            case .denied:
                Text("カメラが利用できません")
                    .font(.headline)
                Text("このゲームはカメラなしでは遊べません。設定アプリからカメラへのアクセスを許可してください。")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("設定を開く", action: Self.openSettings)
                    .buttonStyle(.borderedProminent)

            case .authorized:
                Text("カメラ準備完了")
                    .font(.headline)
            }
        }
        .padding(24)
    }

    /// 設定アプリの本アプリ設定ページを開く。
    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
}
