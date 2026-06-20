import Foundation
import simd
import RealityKit

/// 1枚のトランプ。薄い箱の剛体で、表面をローカル +Y、裏面を −Y に固定する（R2-2, R2-4, R5-4, R7-2）。
/// 表/伏せは時間では変化せず、物理静止後の `worldUp.y` 符号でのみ確定する（R7-6）。
final class CardEntity: Entity, HasModel, HasPhysics, RankedCard {
    let rank: Int
    private(set) var state: CardState

    /// 伏せ初期姿勢: 表面ローカル +Y を下に向ける（X軸まわり180°）。
    private static let faceDownOrientation = simd_quatf(angle: .pi, axis: SIMD3<Float>(1, 0, 0))

    var isFaceUp: Bool { state == .faceUp }

    init(rank: Int, config: GameConfig) {
        self.rank = rank
        self.state = .faceDown
        super.init()

        let mesh = MeshResource.generateBox(size: config.cardSize)
        let material = SimpleMaterial(color: .white, isMetallic: false)
        self.model = ModelComponent(mesh: mesh, materials: [material])

        let shape = ShapeResource.generateBox(size: config.cardSize)
        self.collision = CollisionComponent(shapes: [shape])
        let physicsMaterial = PhysicsMaterialResource.generate(
            friction: config.friction,
            restitution: config.restitution
        )
        self.physicsBody = PhysicsBodyComponent(
            shapes: [shape],
            mass: config.cardMass,
            material: physicsMaterial,
            mode: .dynamic
        )
        self.physicsMotion = PhysicsMotionComponent()

        // 伏せ初期姿勢を適用。
        self.orientation = Self.faceDownOrientation
    }

    @available(*, unavailable)
    required init() { fatalError("init() is unavailable; use init(rank:config:)") }

    /// 物理静止後にワールド上方向ベクトルの符号で表/伏せを確定する。回収済みは変更しない。
    @discardableResult
    func refreshFacing() -> CardState {
        guard state != .collected else { return state }
        let worldUp = orientation(relativeTo: nil).act(SIMD3<Float>(0, 1, 0))
        state = CoordinateMath.isFaceUp(worldUp: worldUp) ? .faceUp : .faceDown
        return state
    }

    /// 衝撃波インパルスを付与する。疑似スリープ中なら復帰させてから適用する（R7-3）。
    func applyShock(impulse: SIMD3<Float>, at position: SIMD3<Float>, torque: SIMD3<Float>) {
        guard state != .collected else { return }
        wakePhysics()
        applyImpulse(impulse, at: position, relativeTo: nil)
        applyAngularImpulse(torque, relativeTo: nil)
    }

    /// 回収：状態を確定し、物理対象外にしてシーンから除去する（R6-6）。
    func markCollected() {
        state = .collected
        physicsBody?.mode = .static
        removeFromParent()
    }

    /// 疑似スリープ化（静止カードの物理負荷削減, R10-4）。
    func sleepPhysics() {
        guard state != .collected else { return }
        physicsBody?.mode = .static
    }

    /// 疑似スリープからの復帰（後続台パンで再びインパルスを受ける, R7-3）。
    func wakePhysics() {
        guard state != .collected else { return }
        physicsBody?.mode = .dynamic
    }
}
