import Foundation
import Combine
import simd
import CoreGraphics
import ARKit
import RealityKit

/// ARシーン運用の抽象（差し替え可能）。
protocol ARSceneControlling: AnyObject {
    var trackingState: AnyPublisher<ARCamera.TrackingState, Never> { get }
    var planeReady: AnyPublisher<Bool, Never> { get }
    /// 画面座標を平面のワールド座標へ投影（raycast）。平面外では nil（R4-4）。
    func worldPoint(fromScreen point: CGPoint) -> SIMD3<Float>?
}

/// ARセッション運用・水平面検出・配置可否通知・screen→plane raycast・盤面アンカー固定（R1-3〜R1-5, R2-1, R2-5, R4-4, R10-3）。
final class ARSceneController: NSObject, ARSceneControlling, ARSessionDelegate {
    let arView: ARView
    private let config: GameConfig

    private let trackingSubject = PassthroughSubject<ARCamera.TrackingState, Never>()
    private let planeReadySubject = CurrentValueSubject<Bool, Never>(false)

    var trackingState: AnyPublisher<ARCamera.TrackingState, Never> { trackingSubject.eraseToAnyPublisher() }
    var planeReady: AnyPublisher<Bool, Never> { planeReadySubject.removeDuplicates().eraseToAnyPublisher() }

    /// 検出中の水平面（id → 最大辺長）。配置可否評価に用いる。
    private var planeSides: [UUID: (width: Float, depth: Float)] = [:]
    /// フレーム到達ごとに capturedImage を委譲する手検出プロバイダ（#30 で結線）。
    weak var frameConsumer: ARFrameConsuming?
    /// 盤面の固定アンカー。
    private(set) var boardAnchor: AnchorEntity?

    init(arView: ARView = ARView(frame: .zero), config: GameConfig = .default) {
        self.arView = arView
        self.config = config
        super.init()
        arView.session.delegate = self
    }

    /// 水平面検出付きワールドトラッキングを開始する（R1-3）。
    func start() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    func pause() {
        arView.session.pause()
    }

    /// 画面座標を既存平面へ raycast 投影する（R4-4）。
    func worldPoint(fromScreen point: CGPoint) -> SIMD3<Float>? {
        guard let result = arView.raycast(
            from: point,
            allowing: .existingPlaneInfinite,
            alignment: .horizontal
        ).first else { return nil }
        let t = result.worldTransform.columns.3
        return SIMD3<Float>(t.x, t.y, t.z)
    }

    /// 指定画面座標を平面投影して盤面アンカーを固定する（R2-1）。投影できなければ false。
    @discardableResult
    func placeBoardAnchor(atScreenPoint point: CGPoint) -> AnchorEntity? {
        guard let world = worldPoint(fromScreen: point) else { return nil }
        let anchor = AnchorEntity(world: world)
        arView.scene.addAnchor(anchor)
        boardAnchor = anchor
        return anchor
    }

    /// デバッグ用: 平面タップなしでカメラ前方に固定アンカーを置く（R2-6）。
    func placeDebugAnchor(distance: Float = 0.5) -> AnchorEntity {
        let anchor = AnchorEntity(world: SIMD3<Float>(0, -0.1, -distance))
        arView.scene.addAnchor(anchor)
        boardAnchor = anchor
        return anchor
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        trackingSubject.send(frame.camera.trackingState)
        frameConsumer?.consume(frame: frame)
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        updatePlanes(anchors)
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        updatePlanes(anchors)
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        anchors.compactMap { $0 as? ARPlaneAnchor }.forEach { planeSides[$0.identifier] = nil }
        recomputePlaneReady()
    }

    // MARK: - Private

    private func updatePlanes(_ anchors: [ARAnchor]) {
        for plane in anchors.compactMap({ $0 as? ARPlaneAnchor }) where plane.alignment == .horizontal {
            planeSides[plane.identifier] = (plane.planeExtent.width, plane.planeExtent.height)
        }
        recomputePlaneReady()
    }

    private func recomputePlaneReady() {
        let ready = planeSides.values.contains { side in
            PlaneReadiness.isPlaceable(planeWidth: side.width, planeDepth: side.depth, minSide: config.minPlaneSide)
        }
        planeReadySubject.send(ready)
    }
}

/// ARフレームを消費する抽象（カメラ1フィードの二系統分配の受け手, #30）。
protocol ARFrameConsuming: AnyObject {
    func consume(frame: ARFrame)
}
