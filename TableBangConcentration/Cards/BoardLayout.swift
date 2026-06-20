import Foundation
import simd

/// 盤面の格子配置を計算する純関数ヘルパ（テスト容易性のためエンティティと分離）。
enum BoardLayout {
    /// `count` 枚を `columns` 列の格子に、原点中心で `spacing` 間隔に並べた XZ 平面（y=0）座標を返す。
    static func gridPositions(count: Int, columns: Int, spacing: Float) -> [SIMD3<Float>] {
        precondition(count >= 0, "count must be non-negative")
        precondition(columns > 0, "columns must be positive")
        guard count > 0 else { return [] }

        let rows = Int((Double(count) / Double(columns)).rounded(.up))
        let colCenter = Float(columns - 1) / 2
        let rowCenter = Float(rows - 1) / 2

        return (0..<count).map { index in
            let col = index % columns
            let row = index / columns
            let x = (Float(col) - colCenter) * spacing
            let z = (Float(row) - rowCenter) * spacing
            return SIMD3<Float>(x, 0, z)
        }
    }
}
