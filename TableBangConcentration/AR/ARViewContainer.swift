import SwiftUI
import RealityKit

/// `ARView` を SwiftUI に橋渡しする（UIViewRepresentable）。
struct ARViewContainer: UIViewRepresentable {
    let controller: ARSceneController

    func makeUIView(context: Context) -> ARView {
        controller.start()
        return controller.arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}
