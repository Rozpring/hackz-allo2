import UIKit
import RealityKit

/// トランプの表面（ランク）・裏面のテクスチャ／マテリアルを生成する。ランク別にキャッシュする。
enum CardFace {
    /// ランク 0..n を表示用ラベルへ写す（A, 2..10, J, Q, K）。
    static let labels = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

    private static var faceTextures: [String: TextureResource] = [:]
    private static var backTextureCache: TextureResource?

    /// 表面マテリアル（ランク＋スート）。
    static func faceMaterial(rank: Int, suit: Suit) -> RealityKit.Material {
        guard let texture = faceTexture(rank: rank, suit: suit) else {
            return SimpleMaterial(color: .white, isMetallic: false)
        }
        return unlit(texture)
    }

    /// 裏面マテリアル（カード裏の模様）。
    static func backMaterial() -> RealityKit.Material {
        guard let texture = backTexture() else {
            return SimpleMaterial(color: .init(red: 0.15, green: 0.2, blue: 0.55, alpha: 1), isMetallic: false)
        }
        return unlit(texture)
    }

    // MARK: - Private

    private static func unlit(_ texture: TextureResource) -> UnlitMaterial {
        var material = UnlitMaterial()
        material.color = .init(tint: .white, texture: .init(texture))
        return material
    }

    private static func faceTexture(rank: Int, suit: Suit) -> TextureResource? {
        let key = "\(rank)\(suit.symbol)"
        if let cached = faceTextures[key] { return cached }
        let label = labels[min(max(rank, 0), labels.count - 1)]
        guard let cgImage = renderFace(label: label, suit: suit).cgImage,
              let texture = try? TextureResource.generate(from: cgImage, options: .init(semantic: .color))
        else { return nil }
        faceTextures[key] = texture
        return texture
    }

    private static func backTexture() -> TextureResource? {
        if let cached = backTextureCache { return cached }
        guard let cgImage = renderBack().cgImage,
              let texture = try? TextureResource.generate(from: cgImage, options: .init(semantic: .color))
        else { return nil }
        backTextureCache = texture
        return texture
    }

    private static func renderFace(label: String, suit: Suit) -> UIImage {
        let size = CGSize(width: 200, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // 枠
            let border = UIBezierPath(
                roundedRect: CGRect(x: 6, y: 6, width: size.width - 12, height: size.height - 12),
                cornerRadius: 16
            )
            UIColor(white: 0.82, alpha: 1).setStroke()
            border.lineWidth = 4
            border.stroke()

            let color: UIColor = suit.isRed ? .systemRed : .black

            // 中央の大きなスート記号
            let centerPara = NSMutableParagraphStyle()
            centerPara.alignment = .center
            (suit.symbol as NSString).draw(
                in: CGRect(x: 0, y: size.height / 2 - 70, width: size.width, height: 140),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 110),
                    .foregroundColor: color,
                    .paragraphStyle: centerPara,
                ]
            )

            // 左上・右下にランク＋スート
            let cornerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 38),
                .foregroundColor: color,
            ]
            (label as NSString).draw(at: CGPoint(x: 16, y: 12), withAttributes: cornerAttrs)
            (suit.symbol as NSString).draw(at: CGPoint(x: 16, y: 52), withAttributes: cornerAttrs)
            (label as NSString).draw(at: CGPoint(x: size.width - 46, y: size.height - 88), withAttributes: cornerAttrs)
            (suit.symbol as NSString).draw(at: CGPoint(x: size.width - 46, y: size.height - 48), withAttributes: cornerAttrs)
        }
    }

    private static func renderBack() -> UIImage {
        let size = CGSize(width: 200, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor(red: 0.15, green: 0.2, blue: 0.55, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // 白枠 + 斜め格子模様
            UIColor.white.setStroke()
            let frame = UIBezierPath(
                roundedRect: CGRect(x: 10, y: 10, width: size.width - 20, height: size.height - 20),
                cornerRadius: 14
            )
            frame.lineWidth = 6
            frame.stroke()

            UIColor(white: 1, alpha: 0.3).setStroke()
            let lattice = UIBezierPath()
            var x: CGFloat = -size.height
            while x < size.width {
                lattice.move(to: CGPoint(x: x, y: 0))
                lattice.addLine(to: CGPoint(x: x + size.height, y: size.height))
                x += 22
            }
            lattice.lineWidth = 2
            lattice.stroke()
        }
    }
}
