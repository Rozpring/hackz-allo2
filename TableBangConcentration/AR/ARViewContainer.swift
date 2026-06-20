import SwiftUI
import RealityKit
import UIKit

/// `ARView` を SwiftUI に橋渡しする（UIViewRepresentable）。
/// `onTap` を渡すと、ARView に直接 `UITapGestureRecognizer` を付けてタップ点（ビューの point 座標）を通知する。
/// SwiftUI のジェスチャは ARView のタッチ処理と競合しやすいため、配置タップはこちらで確実に拾う。
struct ARViewContainer: UIViewRepresentable {
    let controller: ARSceneController
    var onTap: ((CGPoint) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    func makeUIView(context: Context) -> ARView {
        controller.start()
        let recognizer = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        controller.arView.addGestureRecognizer(recognizer)
        return controller.arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.onTap = onTap
    }

    final class Coordinator: NSObject {
        var onTap: ((CGPoint) -> Void)?

        init(onTap: ((CGPoint) -> Void)?) {
            self.onTap = onTap
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let onTap, let view = recognizer.view else { return }
            onTap(recognizer.location(in: view))
        }
    }
}
