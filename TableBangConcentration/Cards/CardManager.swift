import Foundation
import simd
import RealityKit

/// ペア判定・回収・盤面配置の対象となるカード集合の管理（R2-1〜R2-6, R5-1, R5-8, R6-6, R7-1, R7-3, R7-5）。
protocol CardManaging: AnyObject {
    var cards: [CardEntity] { get }
    func buildBoard(config: GameConfig)
    func cards(within radius: Float, of center: SIMD3<Float>) -> [CardEntity]
    func collect(_ cards: [CardEntity])
    var remainingPairs: Int { get }
}

/// デッキ生成・格子配置・床/壁コライダー設置・半径内抽出・回収除去・残ペア管理を担う。
/// 盤面は `root` 配下に構築し、`attach(to:)` で AR アンカーに固定する。
final class CardManager: CardManaging {
    /// 盤面のルート。AR アンカー配下に取り付けて現実空間へ固定する（R10-3）。
    let root: Entity
    private(set) var cards: [CardEntity] = []
    /// 床1枚＋外周4枚の不可視壁（盤外へのこぼれ防止, R5-8）。
    private(set) var boundaries: [Entity] = []

    init(root: Entity = Entity()) {
        self.root = root
    }

    /// アンカー配下に取り付けて現実空間に固定する。
    func attach(to anchor: AnchorEntity) {
        anchor.addChild(root)
    }

    func buildBoard(config: GameConfig) {
        // 既存盤面をクリア。
        cards.forEach { $0.removeFromParent() }
        boundaries.forEach { $0.removeFromParent() }
        cards = []
        boundaries = []

        let ranks = DeckFactory.makeRanks(pairCount: config.pairCount)
        let positions = BoardLayout.gridPositions(
            count: ranks.count,
            columns: config.gridColumns,
            spacing: config.cardSpacing
        )

        for (rank, position) in zip(ranks, positions) {
            let card = CardEntity(rank: rank, config: config)
            card.position = position
            root.addChild(card)
            cards.append(card)
        }

        boundaries = makeBoundaries(for: positions, config: config)
        boundaries.forEach { root.addChild($0) }
    }

    func cards(within radius: Float, of center: SIMD3<Float>) -> [CardEntity] {
        cards.filter { card in
            card.state != .collected && simd.distance(card.position, center) <= radius
        }
    }

    func collect(_ cards: [CardEntity]) {
        cards.forEach { $0.markCollected() }
        self.cards.removeAll { card in cards.contains { $0 === card } }
    }

    var remainingPairs: Int {
        cards.filter { $0.state != .collected }.count / 2
    }

    // MARK: - Private

    /// 盤面外周に静的な床と4枚の不可視壁を生成する。
    private func makeBoundaries(for positions: [SIMD3<Float>], config: GameConfig) -> [Entity] {
        guard !positions.isEmpty else { return [] }

        // 最外列カードの中心 + カード半幅 + 余白 を盤面端とする（カード端が壁にめり込まない）。
        let maxX = positions.map { abs($0.x) }.max() ?? 0
        let maxZ = positions.map { abs($0.z) }.max() ?? 0
        let halfWidth = maxX + config.cardSize.x / 2 + config.boardInset
        let halfDepth = maxZ + config.cardSize.z / 2 + config.boardInset
        let wallHeight = config.boardWallHeight
        let cardHalfThickness = config.cardSize.y / 2

        let floor = makeStatic(
            size: SIMD3<Float>(halfWidth * 2, 0.002, halfDepth * 2),
            at: SIMD3<Float>(0, -cardHalfThickness, 0)
        )
        let left = makeStatic(
            size: SIMD3<Float>(0.002, wallHeight, halfDepth * 2),
            at: SIMD3<Float>(-halfWidth, wallHeight / 2, 0)
        )
        let right = makeStatic(
            size: SIMD3<Float>(0.002, wallHeight, halfDepth * 2),
            at: SIMD3<Float>(halfWidth, wallHeight / 2, 0)
        )
        let near = makeStatic(
            size: SIMD3<Float>(halfWidth * 2, wallHeight, 0.002),
            at: SIMD3<Float>(0, wallHeight / 2, halfDepth)
        )
        let far = makeStatic(
            size: SIMD3<Float>(halfWidth * 2, wallHeight, 0.002),
            at: SIMD3<Float>(0, wallHeight / 2, -halfDepth)
        )
        return [floor, left, right, near, far]
    }

    /// 不可視の静的コライダーを生成する。
    private func makeStatic(size: SIMD3<Float>, at position: SIMD3<Float>) -> Entity {
        let entity = Entity()
        let shape = ShapeResource.generateBox(size: size)
        entity.components.set(CollisionComponent(shapes: [shape]))
        entity.components.set(PhysicsBodyComponent(shapes: [shape], mass: 0, mode: .static))
        entity.position = position
        return entity
    }
}
