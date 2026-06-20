import type { GameConfig } from "./config.js";

/** 威力 [min,max] を影響半径 [radiusForMin, radiusForMax] へ線形写像（範囲外クランプ）。 */
export function radiusForPower(power: number, config: GameConfig): number {
  const lo = config.minPower;
  const hi = config.maxPower;
  if (hi <= lo) return config.radiusForMinPower;
  const t = Math.min(Math.max((power - lo) / (hi - lo), 0), 1);
  return config.radiusForMinPower + t * (config.radiusForMaxPower - config.radiusForMinPower);
}

/** 距離減衰係数 max(0, 1 - dist/radius)。中心で1、半径以遠で0。 */
export function falloff(distance: number, radius: number): number {
  if (radius <= 0) return 0;
  return Math.max(0, 1 - distance / radius);
}
