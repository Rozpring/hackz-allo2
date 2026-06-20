import type { GameConfig } from "./config.js";

/** 手/ポインタの代表点サンプル（正規化座標・左上原点、時刻 秒）。 */
export interface SwingSample {
  /** 縦位置 0..1（下向き正＝下に行くほど大）。 */
  y: number;
  /** 横位置 0..1。 */
  x: number;
  timestamp: number;
}

export interface PunchEvent {
  peakVelocity: number;
  /** 着地点（0..1, 0..1）。 */
  x: number;
  y: number;
}

/**
 * 縦移動の時系列から下方向ピーク速度を求め、振り下ろし→急減速（着地）を台パンとして検出する。
 * 検出が途切れた（大きな dt）場合はスイング中なら着地確定し、状態をリセットする（反応漏れ対策）。
 */
export class SwingDetector {
  private last: SwingSample | null = null;
  private ema = 0;
  private peak = 0;
  private swinging = false;
  private lastPunchTime = -Infinity;
  private readonly emaAlpha = 0.6;

  constructor(private readonly config: GameConfig) {}

  process(sample: SwingSample): PunchEvent | null {
    const prev = this.last;
    if (!prev) {
      this.last = sample;
      return null;
    }
    const dt = sample.timestamp - prev.timestamp;
    if (dt <= 0) {
      this.last = sample;
      return null;
    }

    if (dt > this.config.maxSampleGap) {
      const event = this.swinging ? this.finalize(prev) : null;
      this.resetSwing();
      this.last = sample;
      return event;
    }

    const vyRaw = (sample.y - prev.y) / dt;
    this.ema = this.emaAlpha * vyRaw + (1 - this.emaAlpha) * this.ema;
    const vy = this.ema;
    this.last = sample;

    if (vy > this.config.swingVelocityThreshold) {
      this.swinging = true;
      this.peak = Math.max(this.peak, vy);
      return null;
    }
    if (this.swinging && vy < this.config.swingVelocityThreshold * 0.5) {
      const event = this.finalize(sample);
      this.resetSwing();
      return event;
    }
    return null;
  }

  /** 手/ポインタを見失ったときにスイング状態をリセットする。 */
  lost(): void {
    this.resetSwing();
    this.ema = 0;
    this.last = null;
  }

  private resetSwing(): void {
    this.swinging = false;
    this.peak = 0;
  }

  private finalize(at: SwingSample): PunchEvent | null {
    if (this.peak < this.config.swingVelocityThreshold) return null;
    if (at.timestamp - this.lastPunchTime < this.config.punchCooldown) return null;
    this.lastPunchTime = at.timestamp;
    return { peakVelocity: this.peak, x: at.x, y: at.y };
  }
}
