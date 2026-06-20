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
    /// 盤面の中心（ルートのワールド座標）。台パンの衝撃波中心に用いる。
    var boardCenterWorld: SIMD3<Float> { get }
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

        let deck = DeckFactory.makeStandardDeck()
        let positions = BoardLayout.gridPositions(
            count: deck.count,
            columns: config.gridColumns,
            spacing: config.cardSpacing
        )

        for (card, position) in zip(deck, positions) {
            let entity = CardEntity(rank: card.rank, suit: card.suit, config: config)
            entity.position = position
            root.addChild(entity)
            cards.append(entity)
        }

        boundaries = makeBoundaries(for: positions, config: config)
        boundaries.forEach { root.addChild($0) }
    }

    /// 中心 `center` はワールド座標（raycast 由来）。カードはアンカー配下に置かれるため、
    /// 比較もワールド座標（`position(relativeTo: nil)`）で行う（#59: ローカル/ワールド混同の解消）。
    func cards(within radius: Float, of center: SIMD3<Float>) -> [CardEntity] {
        cards.filter { card in
            card.state != .collected
                && simd.distance(card.position(relativeTo: nil), center) <= radius
        }
    }

    func collect(_ cards: [CardEntity]) {
        cards.forEach { $0.markCollected() }
        self.cards.removeAll { card in cards.contains { $0 === card } }
    }

    var remainingPairs: Int {
        cards.filter { $0.state != .collected }.count / 2
    }

    var boardCenterWorld: SIMD3<Float> {
        root.position(relativeTo: nil)
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
        let wallThickness: Float = 0.02 // 薄壁だと高速カードが貫通するため厚みを持たせる
        let floorThickness: Float = 0.1
        let cardHalfThickness = config.cardSize.y / 2

        // 床は盤面より十分大きく・厚くして、跳ねたカードが床外/床下（奈落）へ抜けないようにする。
        let floorTopY = -cardHalfThickness
        let floor = makeStatic(
            size: SIMD3<Float>(halfWidth * 2 + 1.0, floorThickness, halfDepth * 2 + 1.0),
            at: SIMD3<Float>(0, floorTopY - floorThickness / 2, 0)
        )
        let left = makeStatic(
            size: SIMD3<Float>(wallThickness, wallHeight, halfDepth * 2),
            at: SIMD3<Float>(-halfWidth, wallHeight / 2, 0)
        )
        let right = makeStatic(
            size: SIMD3<Float>(wallThickness, wallHeight, halfDepth * 2),
            at: SIMD3<Float>(halfWidth, wallHeight / 2, 0)
        )
        let near = makeStatic(
            size: SIMD3<Float>(halfWidth * 2, wallHeight, wallThickness),
            at: SIMD3<Float>(0, wallHeight / 2, halfDepth)
        )
        let far = makeStatic(
            size: SIMD3<Float>(halfWidth * 2, wallHeight, wallThickness),
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
