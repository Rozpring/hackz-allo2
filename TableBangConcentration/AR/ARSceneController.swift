import Foundation
import Combine
import simd
import CoreGraphics
import ARKit
import RealityKit

/// 画面座標を平面のワールド座標へ投影する抽象（結線層のテスト容易性のため分離）。
protocol ScreenToWorldProjecting: AnyObject {
    /// 画面座標（ビューの point 座標）を平面のワールド座標へ投影（raycast）。平面外では nil（R4-4）。
    func worldPoint(fromScreen point: CGPoint) -> SIMD3<Float>?
    /// 正規化画面座標 [0,1]（Vision 由来）を平面のワールド座標へ投影する。
    /// 内部でビューの point 座標へ変換してから raycast する（#59: 単位不一致の解消）。平面外では nil。
    func worldPoint(fromNormalizedScreen normalizedPoint: CGPoint) -> SIMD3<Float>?
}

/// ARシーン運用の抽象（差し替え可能）。
protocol ARSceneControlling: ScreenToWorldProjecting {
    var trackingState: AnyPublisher<ARCamera.TrackingState, Never> { get }
    var planeReady: AnyPublisher<Bool, Never> { get }
    /// 指定画面座標を平面投影して盤面アンカーを固定する（R2-1）。投影できなければ nil。
    @discardableResult
    func placeBoardAnchor(atScreenPoint point: CGPoint) -> AnchorEntity?
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

    /// 画面座標（ビューの point 座標）を既存平面へ raycast 投影する（R4-4）。
    func worldPoint(fromScreen point: CGPoint) -> SIMD3<Float>? {
        guard let result = arView.raycast(
            from: point,
            allowing: .existingPlaneInfinite,
            alignment: .horizontal
        ).first else { return nil }
        let t = result.worldTransform.columns.3
        return SIMD3<Float>(t.x, t.y, t.z)
    }

    /// 正規化画面座標 [0,1] を、ビューの point 座標へ変換してから raycast する（#59）。
    /// 台パン中心（`VisionHandProvider` 由来の正規化座標）はこちらを使う。
    func worldPoint(fromNormalizedScreen normalizedPoint: CGPoint) -> SIMD3<Float>? {
        let viewPoint = CoordinateMath.viewPoint(fromNormalized: normalizedPoint, viewportSize: arView.bounds.size)
        return worldPoint(fromScreen: viewPoint)
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

    #if DEBUG
    /// デバッグ用: 平面タップなしでカメラ前方に固定アンカーを置く（R2-6）。
    func placeDebugAnchor(distance: Float = 0.5) -> AnchorEntity {
        let anchor = AnchorEntity(world: SIMD3<Float>(0, -0.1, -distance))
        arView.scene.addAnchor(anchor)
        boardAnchor = anchor
        return anchor
    }
    #endif

    // MARK: - ARSessionDelegate
    // NOTE: ARSession デリゲートは専用のシリアルキュー（メイン以外）で配信される。
    // 状態を SwiftUI/RealityKit へ反映する側（GameSession）でメインスレッドへホップする。

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
            // iOS 16+: planeExtent.height は平面の奥行（depth）を表す。
            let extent = plane.planeExtent
            planeSides[plane.identifier] = (width: extent.width, depth: extent.height)
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
