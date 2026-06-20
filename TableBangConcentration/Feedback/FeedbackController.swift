#if canImport(CoreHaptics) && canImport(AVFoundation)
import AVFoundation
import CoreHaptics
import Foundation

/// 台パン・カードめくり・ペア成立に触覚（CoreHaptics）と効果音（AVAudioPlayer）を付与する。
///
/// 視覚エフェクト（衝撃波リング等）は AR シーン側（RealityKit）の責務が大きいため、本コントローラは
/// 触覚・効果音を担い、視覚は `onVisualEffect` フック経由でシーン層に委ねる。
///
/// 設計対応: design.md `FeedbackController`。要件 5.7。
///
/// - Note: iOS（CoreHaptics/AVFoundation）依存のため GameCore SPM ビルドには含めない。
///   触覚は実機のみ（シミュレータ非対応）。kyiku の Xcode + 実機で確認する。
public final class FeedbackController {

    /// 効果音ファイル名（拡張子込み、アプリバンドル内）。差し替え可能。
    public struct SoundSet {
        public var punch: String?
        public var flip: String?
        public var pair: String?
        public init(punch: String? = "punch.wav", flip: String? = "flip.wav", pair: String? = "pair.wav") {
            self.punch = punch; self.flip = flip; self.pair = pair
        }
    }

    /// 視覚エフェクトを起こしたい時に呼ばれるフック（中心威力などをシーン層が受けて演出）。
    public var onVisualEffect: ((_ kind: EffectKind, _ intensity: Float) -> Void)?

    public enum EffectKind { case punch, flip, pair }

    private var engine: CHHapticEngine?
    private let soundSet: SoundSet
    private var players: [String: AVAudioPlayer] = [:]

    public init(soundSet: SoundSet = SoundSet()) {
        self.soundSet = soundSet
        prepareHaptics()
        preloadSounds()
    }

    // MARK: - 公開イベント

    /// 台パン。威力 [0,1] に応じて触覚の強さを変える。
    public func playPunch(power: Float) {
        let intensity = clamp01(power)
        playTransient(intensity: intensity, sharpness: 0.7)
        playSound(soundSet.punch)
        onVisualEffect?(.punch, intensity)
    }

    /// カードがめくれた（反転）瞬間。
    public func playCardFlip() {
        playTransient(intensity: 0.4, sharpness: 0.5)
        playSound(soundSet.flip)
        onVisualEffect?(.flip, 0.4)
    }

    /// ペア成立。
    public func playPairMatched() {
        // 軽い二連打で「成立」感を出す。
        playTransient(intensity: 0.7, sharpness: 0.6)
        playTransient(intensity: 1.0, sharpness: 0.8, relativeTime: 0.08)
        playSound(soundSet.pair)
        onVisualEffect?(.pair, 1.0)
    }

    // MARK: - CoreHaptics

    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            // バックグラウンド復帰やリセット時に停止しても落ちないよう自動再開させる。
            engine.resetHandler = { [weak engine] in try? engine?.start() }
            engine.stoppedHandler = { _ in }
            try engine.start()
            self.engine = engine
        } catch {
            self.engine = nil  // 触覚なしでも他のフィードバックは継続（クラッシュさせない）
        }
    }

    private func playTransient(intensity: Float, sharpness: Float, relativeTime: TimeInterval = 0) {
        guard let engine else { return }
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: clamp01(intensity)),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: clamp01(sharpness)),
            ],
            relativeTime: relativeTime
        )
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // 触覚の単発失敗は無視（プレイ継続優先）
        }
    }

    // MARK: - 効果音

    private func preloadSounds() {
        for name in [soundSet.punch, soundSet.flip, soundSet.pair].compactMap({ $0 }) {
            guard players[name] == nil else { continue }
            guard let player = makePlayer(for: name) else { continue }
            players[name] = player
        }
    }

    private func makePlayer(for name: String) -> AVAudioPlayer? {
        let nsName = name as NSString
        let base = nsName.deletingPathExtension
        let ext = nsName.pathExtension.isEmpty ? "wav" : nsName.pathExtension
        guard let url = Bundle.main.url(forResource: base, withExtension: ext) else { return nil }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        return player
    }

    private func playSound(_ name: String?) {
        guard let name, let player = players[name] else { return }
        player.currentTime = 0
        player.play()
    }

    private func clamp01(_ v: Float) -> Float { min(max(v, 0), 1) }
}
#endif
