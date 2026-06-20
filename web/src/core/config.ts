/** 調整パラメータ集約（Swift 版 GameConfig の Web 移植・2D 適応）。 */
export interface GameConfig {
  // 入力 / 威力（正規化画面座標 /s 基準）
  swingVelocityThreshold: number;
  velocityForMaxPower: number;
  punchCooldown: number;
  maxSampleGap: number;
  minPower: number;
  maxPower: number;

  // 衝撃波（盤面に対する割合 0..1 の影響半径）
  radiusForMinPower: number;
  radiusForMaxPower: number;
  /** 距離減衰係数に対し、めくれ判定に使う確率の下駄（falloff*flipChanceGain をクランプ）。 */
  flipChanceGain: number;

  // 盤面 / 進行
  gridColumns: number;
  comboMultiplierStep: number;
  scorePerPair: number;
}

export const defaultConfig: GameConfig = {
  swingVelocityThreshold: 1.5,
  velocityForMaxPower: 6.0,
  punchCooldown: 0.3,
  maxSampleGap: 0.2,
  minPower: 0,
  maxPower: 1,
  radiusForMinPower: 0.18,
  radiusForMaxPower: 0.6,
  flipChanceGain: 1.0,
  gridColumns: 8, // 52枚 → 8列×7行
  comboMultiplierStep: 0.5,
  scorePerPair: 100,
};
