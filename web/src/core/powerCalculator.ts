import type { GameConfig } from "./config.js";

/** ピーク速度を威力 [minPower, maxPower] へクランプ正規化（単調増加）。 */
export function powerFromPeakVelocity(peakVelocity: number, config: GameConfig): number {
  const lo = config.swingVelocityThreshold;
  const hi = config.velocityForMaxPower;
  if (hi <= lo) return config.minPower;
  const t = Math.min(Math.max((peakVelocity - lo) / (hi - lo), 0), 1);
  return config.minPower + t * (config.maxPower - config.minPower);
}
